param(
    [string[]] $Files = @(),
    [string[]] $Exclude = @(),
    [string] $Label = 'all'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$env:FISCAL_ROOT = $root
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

function Invoke-TestFile([IO.FileInfo] $Source) {
    $name = $Source.BaseName
    $tested.Add($name)
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $output = Join-Path $metrics "$name.out"
    $cellsMetrics = Join-Path $metrics "cells-$name"
    Remove-Item $cellsMetrics -Recurse -Force -ErrorAction Ignore
    $notebook = Join-Path $notebooks "$name.spi.ipynb"
    $arguments = @('-NoProfile', '-File', $runNotebook, '--path', $Source.FullName, '--output-path', $notebook, '--no-spi',
        '--metrics', $cellsMetrics) | ForEach-Object { "`"$_`"" }
    $run = Start-Process pwsh -ArgumentList $arguments -NoNewWindow -PassThru `
        -RedirectStandardOutput $output -RedirectStandardError "$output.err"
    $null = $run.Handle
    while (!$run.WaitForExit(60000)) { Write-Output "build.ps1 / $name / running $([int]$clock.Elapsed.TotalSeconds) s" }
    $lines = @(Get-Content $output, "$output.err" -ErrorAction Ignore)
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
    if ($s.failed -or $s.unsupported -or $s.skipped -or $s.not_run -or $missing -or $s.passed -ne $s.executed) {
        $failedTests = ($lines | Select-String 'spiral-tests file (\{.*\})' |
            ForEach-Object { ($_.Matches[0].Groups[1].Value | ConvertFrom-Json).failed_tests }) -join ', '
        $problems.Add("${name}: failed $($s.failed), skipped $($s.skipped), not run $($s.not_run), not executed $missing ($failedTests)")
        $lines | Select-String -Pattern 'error|failed|assert|panic|timeout|timed out' | Where-Object { $_.Line -notmatch '^spiral-tests ' } |
            Select-Object -First 40 | ForEach-Object { Write-Output "build.ps1 / $name / detail / $($_.Line)" }
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
foreach ($source in @(Select-TestFiles { $_.BaseName -ne 'generator' })) { Invoke-TestFile $source }

if (!$Files -or $Files -contains 'examples') {
    $validation = @(& (Join-Path $PSScriptRoot 'family-gates.ps1'))
    $validation | ForEach-Object { Write-Output "build.ps1 / examples / $_" }
    $bad = @($validation | Where-Object { $_ -match 'validation messages [1-9]|not written' })
    if ($bad) { $problems.Add("examples: $($bad.Count) documents do not validate against their XSD") }
}

$fileRows | ConvertTo-Csv -Delimiter "`t" -UseQuotes Never | Set-Content (Join-Path $metrics "files$labelSuffix.tsv")
$testRows | ConvertTo-Csv -Delimiter "`t" -UseQuotes Never | Set-Content (Join-Path $metrics "tests$labelSuffix.tsv")
if ($env:GITHUB_STEP_SUMMARY) {
    $minutes = [math]::Round(($fileRows | Measure-Object Seconds -Sum).Sum / 60, 1)
    $summary = @("### fiscal $Label", "", "$($fileRows.Count) files in $minutes min", "", "| slowest file | s |", "|---|---|")
    $summary += $fileRows | Sort-Object Seconds -Descending | Select-Object -First 8 | ForEach-Object { "| $($_.File) | $($_.Seconds) |" }
    $summary | Add-Content $env:GITHUB_STEP_SUMMARY
}
if (!$tested.Count) { throw "build.ps1 / no test files matched $($Files -join ', ')" }
if ($problems.Count) { throw "build.ps1 / $($problems.Count) problems:`n$($problems -join "`n")" }
Write-Output "build.ps1 / all $($tested.Count) test files green and every example validates"
