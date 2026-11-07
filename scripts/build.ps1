param(
    [string[]] $Files = @(),
    [string[]] $Exclude = @(),
    [string] $Label = 'all',
    [switch] $NoGateCache,
    [int] $Parallel = 1
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$env:FISCAL_ROOT = $root
$env:FISCAL_BUILD_TIME = [DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm') + ' UTC'
$Files = @($Files | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$Exclude = @($Exclude | ForEach-Object { $_ -split ',' } | Where-Object { $_ })

. (Join-Path $root 'deps/spiral/scripts/core.ps1')
. (Join-Path $root 'deps/spiral/lib/spiral/lib.ps1')
$spiral = Ensure-SpiralCompiler | Select-Object -Last 1
Write-Output "build.ps1 / compiler / $($spiral.Compiler)"
$runNotebook = (Resolve-Path (Join-Path $root 'deps/spiral/apps/cells/spi/run_notebook.ps1')).Path
if (-not $Files) {
    foreach ($product in 'generated', 'samples', 'notebooks', 'target/ci-metrics') {
        $path = Join-Path $root $product
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
    }
    Write-Output 'build.ps1 / build products cleared: generated, samples, notebooks, target/ci-metrics'
}
New-Item -ItemType Directory -Force (Join-Path $root 'samples') | Out-Null
$notebooks =(New-Item -ItemType Directory -Force (Join-Path $root 'notebooks')).FullName
$metrics = (New-Item -ItemType Directory -Force (Join-Path $root 'target/ci-metrics')).FullName
$labelSuffix = if ($Label -eq 'all') { '' } else { "-$Label" }
$Parallel = if ($Parallel -gt 0) { $Parallel } else { [math]::Max(1, [math]::Floor([Environment]::ProcessorCount / 2)) }

$fileRows = [Collections.Generic.List[object]]::new()
$testRows = [Collections.Generic.List[object]]::new()
$problems = [Collections.Generic.List[string]]::new()
$tested = [Collections.Generic.List[string]]::new()

function Select-TestFiles([scriptblock] $Where) {
    $units = @(Get-ChildItem (Join-Path $root 'src') -File -Filter '*.spi')
    $generated = Join-Path $root 'generated'
    if (Test-Path $generated) {
        $units += @(Get-ChildItem $generated -Directory | ForEach-Object { Get-ChildItem $_.FullName -File -Filter '*.spi' })
    }
    $units |
        Where-Object { !$Files -or $_.BaseName -in $Files } |
        Where-Object { $_.BaseName -notin $Exclude -and $_.BaseName -notin $tested } |
        Where-Object $Where |
        Where-Object { Select-String -Path $_.FullName -Pattern '^(test|:#) ' -Quiet } |
        Sort-Object { if ($_.BaseName -match '^generated_') { 1 } else { 0 } }, Name
}

$gateCache = Join-Path $root 'target/unit-gate-cache/green.tsv'
$gateKeys = [Collections.Generic.HashSet[string]]::new()
$gateContext = ''

function Get-GateKey([IO.FileInfo] $Source) {
    if ($NoGateCache -or !$script:gateContext -or $Source.BaseName -notmatch '^generated_') { return '' }
    "$($Source.BaseName)`t$((Get-FileHash -LiteralPath $Source.FullName -Algorithm SHA256).Hash)`t$script:gateContext"
}

function Set-GateContext {
    $lib = Join-Path $root 'deps/spiral/lib/spiral'
    $rows = Get-ChildItem $lib -File -Filter '*.spi' | Sort-Object Name | ForEach-Object { "$($_.Name):$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" }
    $libDigest = [BitConverter]::ToString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($rows -join "`n"))) -replace '-', ''
    $core = (Get-FileHash -LiteralPath (Join-Path (Split-Path $spiral.Compiler) 'SpiralCompilerCore.dll') -Algorithm SHA256).Hash
    $runtimeUnit = Join-Path $root 'generated/generated_fiscal_runtime/generated_fiscal_runtime.spi'
    $runtime = if (Test-Path -LiteralPath $runtimeUnit) { (Get-FileHash -LiteralPath $runtimeUnit -Algorithm SHA256).Hash } else { 'none' }
    $script:gateContext = "$libDigest`t$core`t$runtime"
    if (Test-Path -LiteralPath $gateCache) { foreach ($line in [IO.File]::ReadAllLines($gateCache)) { [void]$script:gateKeys.Add($line) } }
    Write-Output "build.ps1 / gate cache / $($script:gateKeys.Count) green rows, lib $($libDigest.Substring(0, 12)), core $($core.Substring(0, 12))"
}

function Start-TestFile([IO.FileInfo] $Source, [int] $Slot = -1) {
    $name = $Source.BaseName
    $tested.Add($name)
    $gateKey = Get-GateKey $Source
    if ($gateKey -and $gateKeys.Contains($gateKey)) {
        Write-Output "build.ps1 / $name / gate cache: same unit, lib, compiler and runtime as a green run; skipped"
        return
    }
    $output = Join-Path $metrics "$name.out"
    $cellsMetrics = Join-Path $metrics "cells-$name"
    Remove-Item $cellsMetrics -Recurse -Force -ErrorAction Ignore
    $notebook = Join-Path $notebooks "$name.spi.ipynb"
    $arguments = @('-NoProfile', '-File', $runNotebook, '--path', $Source.FullName, '--output-path', $notebook, '--no-spi',
        '--metrics', $cellsMetrics) | ForEach-Object { "`"$_`"" }
    $options = @{ ArgumentList = $arguments; NoNewWindow = $true; PassThru = $true; RedirectStandardOutput = $output; RedirectStandardError = "$output.err" }
    if ($Slot -ge 0) { $options.Environment = @{ MIX_BUILD_PATH = (New-Item -ItemType Directory -Force (Join-Path $root "target/mix-workers/$Slot")).FullName } }
    $started = Get-Date
    $run = Start-Process pwsh @options
    $null = $run.Handle
    [pscustomobject]@{ Name = $name; Run = $run; Clock = [Diagnostics.Stopwatch]::StartNew(); Started = $started; Output = $output; CellsMetrics = $cellsMetrics; GateKey = $gateKey; Slot = $Slot }
}

function Invoke-TestFile([IO.FileInfo] $Source) {
    $started = @(Start-TestFile $Source)
    $started | Where-Object { $_ -is [string] }
    $job = $started | Where-Object { $_ -isnot [string] }
    if (!$job) { return }
    while (!$job.Run.WaitForExit(60000)) { Write-Output "build.ps1 / $($job.Name) / running $([int]$job.Clock.Elapsed.TotalSeconds) s" }
    Complete-TestFile $job
}

function Invoke-TestFiles([IO.FileInfo[]] $Sources) {
    if ($Parallel -le 1) { foreach ($source in $Sources) { Invoke-TestFile $source }; return }
    Write-Output "build.ps1 / parallel / $($Sources.Count) units, at most $Parallel at once, one MIX_BUILD_PATH per worker slot"
    $pending = [Collections.Generic.Queue[IO.FileInfo]]::new([IO.FileInfo[]] @($Sources))
    $free = [Collections.Generic.Queue[int]]::new([int[]] @(0..($Parallel - 1)))
    $running = [Collections.Generic.List[object]]::new()
    $beat = [Diagnostics.Stopwatch]::StartNew()
    while ($pending.Count -or $running.Count) {
        while ($pending.Count -and $free.Count) {
            $slot = $free.Dequeue()
            $started = @(Start-TestFile $pending.Dequeue() $slot)
            $started | Where-Object { $_ -is [string] }
            $job = $started | Where-Object { $_ -isnot [string] }
            if ($job) { $running.Add($job) } else { $free.Enqueue($slot) }
        }
        $done = @($running | Where-Object { $_.Run.WaitForExit(0) })
        $doneIds = @($done | ForEach-Object { $_.Run.Id })
        $still = @($running | Where-Object { $_.Run.Id -notin $doneIds })
        $running.Clear(); foreach ($job in $still) { $running.Add($job) }
        foreach ($job in $done) { $free.Enqueue($job.Slot); Complete-TestFile $job }
        if (!$done -and $running.Count) {
            [void]$running[0].Run.WaitForExit(2000)
            if ($beat.Elapsed.TotalSeconds -ge 60) { $beat.Restart(); Write-Output "build.ps1 / parallel / running $(@($running | ForEach-Object { "$($_.Name) $([int]$_.Clock.Elapsed.TotalSeconds) s" }) -join ', ')" }
        }
    }
}

function Complete-TestFile($Job) {
    $name = $Job.Name; $run = $Job.Run; $clock = $Job.Clock; $started = $Job.Started; $output = $Job.Output; $cellsMetrics = $Job.CellsMetrics; $gateKey = $Job.GateKey
    $run.WaitForExit()
    $lines = @(Get-Content $output, "$output.err" -ErrorAction Ignore)
    if ($IsWindows -and ($lines | Select-String 'compiler socket failed' -Quiet)) {
        Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'Application Error'; StartTime = $started } -ErrorAction Ignore |
            Where-Object { $_.Message -match 'Faulting application name: dotnet\.exe' } |
            ForEach-Object { $_.Message -split "`r?`n" | Where-Object { $_ -match '^(Faulting module name|Exception code|Fault offset):' } } |
            ForEach-Object { Write-Output "build.ps1 / $name / compiler crash / $($_.Trim())" }
    }
    Write-Output "build.ps1 / $name / done in $([int]$clock.Elapsed.TotalSeconds) s"
    $seconds = [math]::Round($clock.Elapsed.TotalSeconds, 1)
    $fileRows.Add([pscustomobject]@{ File = $name; Seconds = $seconds; ExitCode = $run.ExitCode })
    $testsTable = Join-Path $cellsMetrics 'tests.tsv'
    foreach ($row in @(if (Test-Path -LiteralPath $testsTable) { Import-Csv $testsTable -Delimiter "`t" })) {
        $testRows.Add([pscustomobject]@{ File = $name; Test = $row.Test; Target = $row.Target; Status = $row.Status; Ms = [int]$row.Ms })
    }
    $total = $lines | Select-String 'spiral-tests total (\{.*\})' | Select-Object -Last 1
    if (!$total) {
        $lines | Select-Object -Last 20 | ForEach-Object { Write-Output "build.ps1 / $name / $_" }
        $problems.Add("${name}: no spiral-tests total line (exit code $($run.ExitCode))")
        return
    }
    $s = $total.Matches[0].Groups[1].Value | ConvertFrom-Json
    Write-Output ("build.ps1 / {0} / discovered {1} executed {2} passed {3} failed {4} static {5} skipped {6} not_run {7}" -f
        $name, $s.discovered, $s.executed, $s.passed, $s.failed, $s.static, $s.skipped, $s.not_run)
    $missing = $s.discovered - $s.executed - $s.static
    if ($s.failed -or $s.unsupported -or $s.skipped -or $s.not_run -or $missing -or $s.passed -ne $s.executed -or !$s.executed) {
        $failedTests = ($lines | Select-String 'spiral-tests file (\{.*\})' |
            ForEach-Object { ($_.Matches[0].Groups[1].Value | ConvertFrom-Json).failed_tests }) -join ', '
        $problems.Add("${name}: failed $($s.failed), skipped $($s.skipped), not run $($s.not_run), not executed $missing ($failedTests)")
        $lines | Select-String -Pattern 'error|failed|assert|panic|timeout|timed out' | Where-Object { $_.Line -notmatch '^spiral-tests ' } |
            Select-Object -First 40 | ForEach-Object { Write-Output "build.ps1 / $name / detail / $($_.Line)" }
    }
    elseif ($gateKey) {
        New-Item -ItemType Directory -Force (Split-Path $gateCache) | Out-Null
        Add-Content -LiteralPath $gateCache -Value $gateKey
        [void]$gateKeys.Add($gateKey)
    }
}

& (Join-Path $PSScriptRoot 'pattern-oracle.ps1') -Write | ForEach-Object { Write-Output "build.ps1 / pattern oracle / $_" }
foreach ($source in @(Select-TestFiles { $_.BaseName -eq 'generator' })) { Invoke-TestFile $source }
$formatting = @(& (Join-Path $PSScriptRoot 'format-generated.ps1') -Compiler $spiral.Compiler -Dotnet $spiral.Dotnet -Root $root)
$formatting | ForEach-Object { Write-Output "build.ps1 / $_" }
if ($LASTEXITCODE) { $problems.Add("format: $(@($formatting | Where-Object { $_ -match ' / failed ' }).Count) generated units did not format") }
if (-not $Files) {
    $drift = @(git -C $root -c core.quotepath=off status --porcelain --untracked-files=all -- generated)
    if ($LASTEXITCODE) { throw "build.ps1 / git status failed on generated (exit code $LASTEXITCODE)" }
    $drift | Select-Object -First 20 | ForEach-Object { Write-Output "build.ps1 / generated drift / $_" }
    if ($drift) { $problems.Add("generated: $($drift.Count) files differ from the committed copy; commit the regenerated generated/") }
    else { Write-Output 'build.ps1 / generated / matches the committed copy' }
}
if (-not $NoGateCache) { Set-GateContext }
Invoke-TestFiles @(Select-TestFiles { $_.BaseName -notin 'generator', 'reports' })

if (!$Files -or $Files -contains 'examples') {
    $validation = @(& (Join-Path $PSScriptRoot 'family-gates.ps1'))
    $validation | ForEach-Object { Write-Output "build.ps1 / examples / $_" }
    $bad = @($validation | Where-Object { $_ -match 'validation messages [1-9]|not written' })
    if ($bad) { $problems.Add("examples: $($bad.Count) documents do not validate against their XSD") }
    $exampleRows = [Collections.Generic.List[object]]::new()
    $current = $null
    foreach ($line in $validation) {
        if ($line -match '^== (\S+)( :: not written)?') { $current = [pscustomobject]@{ Example = $Matches[1]; Bytes = ''; Messages = ''; SignaturePending = ''; First = ''; Written = $(if ($Matches[2]) { '0' } else { '1' }) }; $exampleRows.Add($current) }
        elseif ($current -and $line -match '^document (\d+) bytes; validation messages (\d+)(?:; signature pending (\d+))?') { $current.Bytes = $Matches[1]; $current.Messages = $Matches[2]; $current.SignaturePending = "$($Matches[3])" }
        elseif ($current -and -not $current.First -and $line -match '^\s+x\d+: (.*)') { $current.First = $Matches[1] }
    }
    $exampleRows | ConvertTo-Csv -Delimiter "`t" -UseQuotes Never | Set-Content (Join-Path $metrics "examples$labelSuffix.tsv")
}

$benchSources = @(Get-ChildItem -LiteralPath $metrics -Filter '*.out' -File) + @(Get-ChildItem -LiteralPath $notebooks -Filter '*.ipynb' -File)
$benchSeen = [Collections.Generic.HashSet[string]]::new()
$benchRows = foreach ($source in $benchSources) {
    foreach ($m in [regex]::Matches([IO.File]::ReadAllText($source.FullName), '(generated_\w+) parse_us (\d+) write_us (\d+) runs (\d+) bytes (\d+)')) {
        if (-not $benchSeen.Add($m.Groups[1].Value)) { continue }
        [pscustomobject]@{ Unit = $m.Groups[1].Value; ParseUs = [int]$m.Groups[2].Value; WriteUs = [int]$m.Groups[3].Value; Runs = [int]$m.Groups[4].Value; Bytes = [long]$m.Groups[5].Value; Os = [Runtime.InteropServices.RuntimeInformation]::OSDescription }
    }
}
@($benchRows | Sort-Object Unit) | ConvertTo-Csv -Delimiter "`t" -UseQuotes Never | Set-Content (Join-Path $metrics "bench$labelSuffix.tsv")
Write-Output "build.ps1 / bench / $(@($benchRows).Count) units measured (median of the runs, microseconds) -> bench$labelSuffix.tsv"

$fileRows | ConvertTo-Csv -Delimiter "`t" -UseQuotes Never | Set-Content (Join-Path $metrics "files$labelSuffix.tsv")
$testRows | ConvertTo-Csv -Delimiter "`t" -UseQuotes Never | Set-Content (Join-Path $metrics "tests$labelSuffix.tsv")
$env:FISCAL_METRICS_SUFFIX = $labelSuffix
foreach ($source in @(Select-TestFiles { $_.BaseName -eq 'reports' })) { Invoke-TestFile $source }
if ($env:GITHUB_STEP_SUMMARY) {
    $minutes = [math]::Round(($fileRows | Measure-Object Seconds -Sum).Sum / 60, 1)
    $summary = @("### fiscal $Label", "", "$($fileRows.Count) files in $minutes min", "")
    $report = Join-Path $metrics 'reports.md'
    if (Test-Path -LiteralPath $report) { $summary += Get-Content -LiteralPath $report | Select-Object -Skip 1 }
    $summary | Add-Content $env:GITHUB_STEP_SUMMARY
}
if (!$tested.Count) { throw "build.ps1 / no test files matched $($Files -join ', ')" }
if ($problems.Count) { throw "build.ps1 / $($problems.Count) problems:`n$($problems -join "`n")" }
Write-Output "build.ps1 / all $($tested.Count) test files green and every example validates"
