param(
    [string[]] $Files = @(),
    [string[]] $Exclude = @(),
    [string] $Label = 'all',
    [switch] $NoGateCache,
    [int] $Parallel = ($env:CI ? 0 : 1),
    [int] $Shards = 1,
    [string[]] $ShardSet = @(),
    [string[]] $ShardWeights = @(),
    [string[]] $ShardMaxUnitKB = @(),
    [string] $VerdictUrls = '',
    [switch] $PagesVerdicts,
    [double] $UnitBudgetMinutes = 60,
    [switch] $ListOnly,
    [switch] $ListReach,
    [switch] $MergeShards
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$env:FISCAL_ROOT = $root
$env:FISCAL_BUILD_TIME = [DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm') + ' UTC'
$Files = @($Files | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$Exclude = @($Exclude | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
if ($Shards -lt 1) { throw "build.ps1 / -Shards must be 1 or more (got $Shards)" }
[int[]] $shardIds = @($ShardSet | ForEach-Object { $_ -split ',' } | Where-Object { $_ -ne '' } | ForEach-Object { [int]$_ } | Sort-Object -Unique)
if (!$shardIds) { $shardIds = @(0..($Shards - 1)) }
foreach ($shard in $shardIds) { if ($shard -lt 0 -or $shard -ge $Shards) { throw "build.ps1 / shard $shard is outside 0..$($Shards - 1)" } }
[double[]] $weights = @($ShardWeights | ForEach-Object { $_ -split ',' } | Where-Object { $_ -ne '' } | ForEach-Object { [double]$_ })
if (!$weights) { $weights = @(1) * $Shards }
if ($weights.Count -ne $Shards -or @($weights | Where-Object { $_ -le 0 }).Count) { throw "build.ps1 / -ShardWeights needs $Shards positive weights, one per shard (got $($weights -join ','))" }
[double[]] $caps = @($ShardMaxUnitKB | ForEach-Object { $_ -split ',' } | Where-Object { $_ -ne '' } | ForEach-Object { [double]$_ })
if (!$caps) { $caps = [double[]]::new($Shards) }
if ($caps.Count -ne $Shards -or @($caps | Where-Object { $_ -lt 0 }).Count) { throw "build.ps1 / -ShardMaxUnitKB needs $Shards non-negative caps in KB, one per shard (0 = no cap)" }
$sharded = $Shards -gt 1 -and !$MergeShards
$shardSuffix = if ($sharded) { "-shard$($shardIds -join '+')of$Shards" } else { '' }
$cellsRoot = $env:SPIRAL_CELLS_ROOT ? $env:SPIRAL_CELLS_ROOT : (Join-Path $root 'deps/spiral/apps/cells')
$labelSuffix = if ($Label -eq 'all') { '' } else { "-$Label" }
$Parallel = if ($Parallel -gt 0) { $Parallel } else { [math]::Max(1, [math]::Floor([Environment]::ProcessorCount / 2)) }
if (-not $env:SPIRAL_CELLS_TIMEOUT_SCALE) { $env:SPIRAL_CELLS_TIMEOUT_SCALE = [string]([math]::Max(1, $Parallel / 2)) }

$fileRows = [Collections.Generic.List[object]]::new()
$testRows = [Collections.Generic.List[object]]::new()
$costRows = [Collections.Generic.List[object]]::new()
$hostName = [Environment]::MachineName
$pages = $env:FISCAL_PAGES_URL ? $env:FISCAL_PAGES_URL : 'https://i574n.github.io/fiscal'
$runId = [DateTime]::UtcNow.ToString('yyyyMMddHHmm') + '-' + $hostName
$osName = if ($IsWindows) { 'windows' } elseif ($IsLinux) { 'linux' } else { 'other' }
$shardTag = if ($sharded) { "$($shardIds -join '+')of$Shards" } else { 'all' }
$coreTag = '-'
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
        Sort-Object { if ($_.BaseName -match '^generated_') { 1 } else { 0 } }, @{ Expression = { $_.Length }; Descending = $true }, Name
}

function Select-UnitFiles { Select-TestFiles { $_.BaseName -notin 'generator', 'reports' } }

function Get-ShardOwners([IO.FileInfo[]] $Sources) {
    $loads = [long[]]::new($Shards)
    $owners = [ordered]@{}
    foreach ($source in @($Sources | Sort-Object @{ Expression = { $_.Length }; Descending = $true }, Name)) {
        $target = -1
        for ($candidate = 0; $candidate -lt $Shards; $candidate++) {
            if ($caps[$candidate] -gt 0 -and ($source.Length -gt $caps[$candidate] * 1KB -or $source.BaseName -notmatch '^generated_')) { continue }
            if ($target -lt 0 -or ($loads[$candidate] + $source.Length) / $weights[$candidate] -lt ($loads[$target] + $source.Length) / $weights[$target]) { $target = $candidate }
        }
        if ($target -lt 0) { throw ("build.ps1 / {0} ({1:N0} KB) fits no shard under -ShardMaxUnitKB" -f $source.BaseName, ($source.Length / 1KB)) }
        $loads[$target] += $source.Length
        $owners[$source.BaseName] = $target
    }
    $owners
}

$libDir = Join-Path $root 'deps/spiral/lib/spiral'
$libHashes = @{}
$libRefs = @{}
$libPrelude = [Collections.Generic.List[string]]::new()

function Get-ModuleRefs([string] $Path) {
    $text = [IO.File]::ReadAllText($Path)
    $names = [Collections.Generic.HashSet[string]]::new()
    foreach ($m in [regex]::Matches($text, "(?m)^\s*(?::<|open)\s+([A-Za-z_][\w']*)")) { [void]$names.Add($m.Groups[1].Value) }
    foreach ($m in [regex]::Matches($text, "\b([a-z_][\w']*)(?:\.|::)[A-Za-z_]")) { [void]$names.Add($m.Groups[1].Value) }
    $names
}

function Read-LibModules {
    if ($script:libHashes.Count) { return }
    foreach ($file in Get-ChildItem $libDir -File -Filter '*.spi') {
        $script:libHashes[$file.BaseName] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        $script:libRefs[$file.BaseName] = Get-ModuleRefs $file.FullName
    }
    $toml = Join-Path $libDir 'spiral.toml'
    if (Test-Path -LiteralPath $toml) {
        $script:libHashes['spiral.toml'] = (Get-FileHash -LiteralPath $toml -Algorithm SHA256).Hash
        $line = [regex]::Match([IO.File]::ReadAllText($toml), '(?m)^\s*prelude\s*=\s*\[([^\]]*)\]')
        foreach ($m in [regex]::Matches($line.Groups[1].Value, '"([^"]+)"')) { $script:libPrelude.Add($m.Groups[1].Value) }
    }
}

function Get-UnitReach([IO.FileInfo] $Source) {
    Read-LibModules
    $seen = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
    $siblings = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
    $queue = [Collections.Generic.Queue[string]]::new()
    if ($libHashes.ContainsKey('spiral.toml')) { [void]$seen.Add('spiral.toml') }
    foreach ($name in $libPrelude) { if ($libHashes.ContainsKey($name)) { $queue.Enqueue($name) } }
    foreach ($name in Get-ModuleRefs $Source.FullName) {
        if ($libHashes.ContainsKey($name)) { $queue.Enqueue($name) }
        elseif ($name -ne $Source.BaseName -and (Test-Path -LiteralPath (Join-Path $root "generated/$name/$name.spi"))) { [void]$siblings.Add($name) }
    }
    while ($queue.Count) {
        $name = $queue.Dequeue()
        if (-not $seen.Add($name)) { continue }
        foreach ($next in $libRefs[$name]) { if ($libHashes.ContainsKey($next) -and -not $seen.Contains($next)) { $queue.Enqueue($next) } }
    }
    [pscustomobject]@{ Lib = @($seen); Siblings = @($siblings) }
}

if ($ListOnly) {
    $units = @(Select-UnitFiles)
    if ($ListReach) {
        foreach ($unit in @($units | Where-Object { $_.BaseName -match '^generated_' } | Sort-Object Name)) {
            $reach = Get-UnitReach $unit
            Write-Output "build.ps1 / reach / $($unit.BaseName) / lib $($reach.Lib.Count): $($reach.Lib -join ',') / packages: $($reach.Siblings -join ',')"
        }
        return
    }
    $owners = Get-ShardOwners $units
    Write-Output ("build.ps1 / shards / {0} over {1} units, {2:N0} KB" -f $Shards, $units.Count, (($units | Measure-Object Length -Sum).Sum / 1KB))
    foreach ($shard in 0..($Shards - 1)) {
        $mine = @($units | Where-Object { $owners[$_.BaseName] -eq $shard })
        Write-Output ("build.ps1 / shard {0} / {1} units, {2:N0} KB: {3}" -f $shard, $mine.Count, (($mine | Measure-Object Length -Sum).Sum / 1KB), (($mine | ForEach-Object BaseName) -join ', '))
    }
    return
}

. (Join-Path $root 'deps/spiral/scripts/core.ps1')
. (Join-Path $root 'deps/spiral/lib/spiral/lib.ps1')
$spiral = Ensure-SpiralCompiler | Select-Object -Last 1
Write-Output "build.ps1 / compiler / $($spiral.Compiler)"
Write-Output "build.ps1 / cell budgets / header and default timeouts x$($env:SPIRAL_CELLS_TIMEOUT_SCALE) (SPIRAL_CELLS_TIMEOUT_SCALE; parallel $Parallel)"
$runNotebook = (Resolve-Path (Join-Path $cellsRoot 'spi/run_notebook.ps1')).Path
$coreDll = Join-Path (Split-Path ($env:SPIRAL_COMPILER_DLL ? $env:SPIRAL_COMPILER_DLL : $spiral.Compiler)) 'SpiralCompilerCore.dll'
if (Test-Path -LiteralPath $coreDll) { $coreTag = (Get-FileHash -LiteralPath $coreDll -Algorithm SHA256).Hash.Substring(0, 16) }

function Get-HostLoad {
    try {
        if ($IsWindows) { return [int](Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average }
        $average = [double]((Get-Content /proc/loadavg -TotalCount 1).Split(' ')[0])
        [int][math]::Min(100, 100 * $average / [Environment]::ProcessorCount)
    } catch { -1 }
}

function Get-FreeMb {
    try {
        if ($IsWindows) { return [int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024) }
        [int]([long](Select-String -Path /proc/meminfo -Pattern '^MemAvailable:\s+(\d+)').Matches[0].Groups[1].Value / 1024)
    } catch { -1 }
}

function Add-Cost([string] $Unit, [string] $Phase, [double] $Seconds, [IO.FileInfo] $Source, [string] $Target, [int] $LoadStart, [int] $LoadEnd, [int] $FreeStart, [int] $Exit) {
    $lines = if ($Source) { [IO.File]::ReadAllLines($Source.FullName).Count } else { 0 }
    $costRows.Add([pscustomobject]@{
        Run = $runId; Host = $hostName; Os = $osName; Core = $coreTag; Shard = $shardTag; Slots = $Parallel; Unit = $Unit; Phase = $Phase
        Seconds = [math]::Round($Seconds, 1); InputLines = $lines; InputBytes = $(if ($Source) { $Source.Length } else { 0 }); Target = $(if ($Target) { $Target } else { '-' })
        LoadStart = $LoadStart; LoadEnd = $LoadEnd; FreeMbStart = $FreeStart; Exit = $Exit
    })
}
if (-not $Files -and -not $sharded -and -not $MergeShards) {
    foreach ($product in 'generated', 'samples', 'notebooks', 'target/ci-metrics') {
        $path = Join-Path $root $product
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
    }
    Write-Output 'build.ps1 / build products cleared: generated, samples, notebooks, target/ci-metrics'
}
New-Item -ItemType Directory -Force (Join-Path $root 'samples') | Out-Null
$notebooks =(New-Item -ItemType Directory -Force (Join-Path $root 'notebooks')).FullName
$metrics = (New-Item -ItemType Directory -Force (Join-Path $root 'target/ci-metrics')).FullName

$gateCache = Join-Path $root 'target/unit-gate-cache/green.tsv'
$gateKeys = [Collections.Generic.HashSet[string]]::new()
$storeUrls = @{}

function Test-StoreVerdict([string] $GateKey) {
    if (-not $script:storeUrls.Count) { return $false }
    $sha = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($GateKey + "`n"))).ToLower()
    if (-not $script:storeUrls.ContainsKey($sha)) { return $false }
    try { (Invoke-WebRequest -Uri $script:storeUrls[$sha] -TimeoutSec 20 -ErrorAction Stop).Content -eq ($GateKey + "`n") } catch { $false }
}
$gateContext = ''

function Get-Fingerprint([string[]] $Rows) { [BitConverter]::ToString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Rows -join "`n"))) -replace '-', '' }

function Get-GateKey([IO.FileInfo] $Source) {
    if ($NoGateCache -or !$script:gateContext -or $Source.BaseName -notmatch '^generated_') { return '' }
    $reach = Get-UnitReach $Source
    $rows = @($reach.Lib | ForEach-Object { "$_`:$($libHashes[$_])" }) + @($reach.Siblings | ForEach-Object { "$_`:$((Get-FileHash -LiteralPath (Join-Path $root "generated/$_/$_.spi") -Algorithm SHA256).Hash)" })
    $unitToml = Join-Path $Source.DirectoryName 'spiral.toml'
    if (Test-Path -LiteralPath $unitToml) { $rows += "unit-spiral.toml:$((Get-FileHash -LiteralPath $unitToml -Algorithm SHA256).Hash)" }
    "$($Source.BaseName)`t$((Get-FileHash -LiteralPath $Source.FullName -Algorithm SHA256).Hash)`treach:$(Get-Fingerprint $rows)`t$script:gateContext"
}

function Set-GateContext {
    Read-LibModules
    $core = (Get-FileHash -LiteralPath (Join-Path (Split-Path $spiral.Compiler) 'SpiralCompilerCore.dll') -Algorithm SHA256).Hash
    $runtimeUnit = Join-Path $root 'generated/generated_fiscal_runtime/generated_fiscal_runtime.spi'
    $runtime = if (Test-Path -LiteralPath $runtimeUnit) { (Get-FileHash -LiteralPath $runtimeUnit -Algorithm SHA256).Hash } else { 'none' }
    $corePackage = Join-Path $root 'deps/spiral/deps/The-Spiral-Language/VS Code Plugin/core'
    $package = if (Test-Path -LiteralPath $corePackage) {
        Get-Fingerprint @(Get-ChildItem -LiteralPath $corePackage -Recurse -File | Sort-Object FullName | ForEach-Object { "$($_.FullName.Substring($corePackage.Length + 1).Replace('\', '/')):$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" })
    } else { 'none' }
    $script:gateContext = "$core`t$runtime`tcore-package:$($package.Substring(0, [Math]::Min(16, $package.Length)))"
    if (Test-Path -LiteralPath $gateCache) { foreach ($line in [IO.File]::ReadAllLines($gateCache)) { [void]$script:gateKeys.Add($line) } }
    if ($PagesVerdicts) {
        try {
            $content = (Invoke-WebRequest -Uri "$pages/target/unit-gate-cache/green.tsv" -TimeoutSec 20 -ErrorAction Stop).Content
            if ($content -is [byte[]]) { $content = [Text.Encoding]::UTF8.GetString($content) }
            $published = @($content -split "`r?`n" | Where-Object { $columns = $_ -split "`t"; $columns.Count -eq 6 -and $columns[3] -eq $core })
            $seeded = @($published | Where-Object { $script:gateKeys.Add($_) })
            if ($seeded.Count) { New-Item -ItemType Directory -Force (Split-Path $gateCache) | Out-Null; Add-Content -LiteralPath $gateCache -Value $seeded }
            Write-Output "build.ps1 / gate cache / $($seeded.Count) green rows seeded from $pages ($($published.Count) published on core $($core.Substring(0, 12)))"
        } catch { Write-Output "build.ps1 / gate cache / no published green rows ($($_.Exception.Message.Split([Environment]::NewLine)[0]))" }
    }
    if ($VerdictUrls -and (Test-Path -LiteralPath $VerdictUrls)) {
        foreach ($line in [IO.File]::ReadAllLines($VerdictUrls)) { $sha, $url = $line -split "`t", 2; if ($sha -and $url) { $script:storeUrls[$sha.ToLower()] = $url } }
        Write-Output "build.ps1 / gate cache / $($script:storeUrls.Count) shared verdicts offered by $VerdictUrls"
    }
    Write-Output "build.ps1 / gate cache / $($script:gateKeys.Count) green rows, keyed per unit on the $($libHashes.Count)-module lib by reach, core $($core.Substring(0, 12))"
}

function Start-TestFile([IO.FileInfo] $Source, [int] $Slot = -1) {
    $name = $Source.BaseName
    $tested.Add($name)
    $gateKey = Get-GateKey $Source
    if ($gateKey -and $gateKeys.Contains($gateKey)) {
        Write-Output "build.ps1 / $name / gate cache: same unit, lib, compiler and runtime as a green run; skipped"
        return
    }
    if ($gateKey -and (Test-StoreVerdict $gateKey)) {
        Write-Output "build.ps1 / $name / gate cache: oort hit, a shared verdict proved the same key green; skipped"
        New-Item -ItemType Directory -Force (Split-Path $gateCache) | Out-Null
        Add-Content -LiteralPath $gateCache -Value $gateKey
        [void]$gateKeys.Add($gateKey)
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
    $loadStart = Get-HostLoad; $freeStart = Get-FreeMb
    $run = Start-Process pwsh @options
    $null = $run.Handle
    [pscustomobject]@{ Name = $name; Source = $Source; Run = $run; Clock = [Diagnostics.Stopwatch]::StartNew(); Started = $started; Output = $output; CellsMetrics = $cellsMetrics; GateKey = $gateKey; Slot = $Slot; LoadStart = $loadStart; FreeStart = $freeStart }
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
    $loadEnd = Get-HostLoad
    Add-Cost $name $(if ($name -eq 'generator') { 'Regen' } else { 'Unit' }) $clock.Elapsed.TotalSeconds $Job.Source '' $Job.LoadStart $loadEnd $Job.FreeStart $run.ExitCode
    $testsTable = Join-Path $cellsMetrics 'tests.tsv'
    foreach ($row in @(if (Test-Path -LiteralPath $testsTable) { Import-Csv $testsTable -Delimiter "`t" })) {
        $testRows.Add([pscustomobject]@{ File = $name; Test = $row.Test; Target = $row.Target; Status = $row.Status; Ms = [int]$row.Ms })
        Add-Cost "$name/$($row.Test)" 'Test' ([int]$row.Ms / 1000) $null $row.Target $Job.LoadStart $loadEnd $Job.FreeStart $(if ($row.Status -eq 'passed') { 0 } else { 1 })
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

function Write-Table($Rows, [string] $Name) { @($Rows) | ConvertTo-Csv -Delimiter "`t" -UseQuotes Never | Set-Content (Join-Path $metrics $Name) }

if ($MergeShards) {
    $mergeTag = "of$Shards"
    $owned = @(Get-ChildItem -LiteralPath $metrics -Filter "units$labelSuffix-shard*$mergeTag.tsv" -File | ForEach-Object { Import-Csv $_.FullName -Delimiter "`t" })
    $expected = @(Select-UnitFiles | ForEach-Object BaseName)
    $missingUnits = @($expected | Where-Object { $_ -notin $owned.Unit })
    if ($missingUnits) { $problems.Add("merge: $($missingUnits.Count) units have no shard result ($(($missingUnits | Select-Object -First 8) -join ', '))") }
    Write-Output "build.ps1 / merge / $(@($owned).Count) units reported by the shards, $($expected.Count) expected"
    foreach ($part in @(Get-ChildItem -LiteralPath $metrics -Filter "problems$labelSuffix-shard*$mergeTag.txt" -File)) {
        foreach ($line in @(Get-Content -LiteralPath $part.FullName | Where-Object { $_ })) { $problems.Add("$($part.BaseName): $line") }
    }
    foreach ($kind in 'files', 'tests', 'bench', 'gate-cost') {
        $rows = @(Get-ChildItem -LiteralPath $metrics -Filter "$kind$labelSuffix-shard*$mergeTag.tsv" -File | ForEach-Object { Import-Csv $_.FullName -Delimiter "`t" })
        if ($kind -eq 'files') { foreach ($row in $rows) { $fileRows.Add($row) } }
        if ($kind -eq 'gate-cost') { foreach ($row in $rows) { $costRows.Add($row) } }
        else { Write-Table $rows "$kind$labelSuffix.tsv" }
        Write-Output "build.ps1 / merge / $kind / $($rows.Count) rows"
    }
}
else {
    & (Join-Path $PSScriptRoot 'pattern-oracle.ps1') -Write | ForEach-Object { Write-Output "build.ps1 / pattern oracle / $_" }
    if ($sharded) {
        if (!(Test-Path -LiteralPath (Join-Path $root 'generated'))) { throw 'build.ps1 / a sharded run tests an existing generated/; regenerate first (build.ps1 -Files generator)' }
        Write-Output "build.ps1 / shards / running $($shardIds -join ', ') of $Shards over the existing generated/"
    }
    else {
        foreach ($source in @(Select-TestFiles { $_.BaseName -eq 'generator' })) { Invoke-TestFile $source }
        $formatLoad = Get-HostLoad; $formatFree = Get-FreeMb; $formatClock = [Diagnostics.Stopwatch]::StartNew()
        $formatting = @(& (Join-Path $PSScriptRoot 'format-generated.ps1') -Compiler $spiral.Compiler -Dotnet $spiral.Dotnet -Root $root)
        $formatExit = $LASTEXITCODE
        Add-Cost 'generated' 'Format' $formatClock.Elapsed.TotalSeconds $null '' $formatLoad (Get-HostLoad) $formatFree $formatExit
        $formatting | ForEach-Object { Write-Output "build.ps1 / $_" }
        if ($formatExit) { $problems.Add("format: $(@($formatting | Where-Object { $_ -match ' / failed ' }).Count) generated units did not format") }
        if (-not $Files) {
            $drift = @(git -C $root -c core.quotepath=off status --porcelain --untracked-files=all -- generated)
            if ($LASTEXITCODE) { throw "build.ps1 / git status failed on generated (exit code $LASTEXITCODE)" }
            $drift | Select-Object -First 20 | ForEach-Object { Write-Output "build.ps1 / generated drift / $_" }
            if ($drift) { $problems.Add("generated: $($drift.Count) files differ from the committed copy; commit the regenerated generated/") }
            else { Write-Output 'build.ps1 / generated / matches the committed copy' }
        }
    }
    if (-not $NoGateCache) { Set-GateContext }
    $units = @(Select-UnitFiles)
    if ($sharded) {
        $owners = Get-ShardOwners $units
        $units = @($units | Where-Object { $owners[$_.BaseName] -in $shardIds })
        Write-Table @($units | ForEach-Object { [pscustomobject]@{ Unit = $_.BaseName; Shard = $owners[$_.BaseName]; Bytes = $_.Length } }) "units$labelSuffix$shardSuffix.tsv"
        Write-Output ("build.ps1 / shards / {0} units, {1:N0} KB in this run" -f $units.Count, (($units | Measure-Object Length -Sum).Sum / 1KB))
    }
    Invoke-TestFiles $units
}

if (!$sharded -and (!$Files -or $Files -contains 'examples')) {
    $examplesLoad = Get-HostLoad; $examplesFree = Get-FreeMb; $examplesClock = [Diagnostics.Stopwatch]::StartNew()
    $validation = @(try { & (Join-Path $PSScriptRoot 'family-gates.ps1') } catch { $problems.Add("examples: $($_.Exception.Message)") })
    Add-Cost 'examples' 'Examples' $examplesClock.Elapsed.TotalSeconds $null '' $examplesLoad (Get-HostLoad) $examplesFree $(@($validation | Where-Object { $_ -match 'validation messages [1-9]|not written' }).Count)
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
    Write-Table $exampleRows "examples$labelSuffix.tsv"
}

if (!$MergeShards) {
    $benchSources = @(Get-ChildItem -LiteralPath $metrics -Filter '*.out' -File) + @(Get-ChildItem -LiteralPath $notebooks -Filter '*.ipynb' -File)
    $benchSeen = [Collections.Generic.HashSet[string]]::new()
    $benchRows = foreach ($source in $benchSources) {
        foreach ($m in [regex]::Matches([IO.File]::ReadAllText($source.FullName), '(generated_\w+) parse_us (\d+) write_us (\d+) runs (\d+) bytes (\d+)')) {
            if (-not $benchSeen.Add($m.Groups[1].Value)) { continue }
            [pscustomobject]@{ Unit = $m.Groups[1].Value; ParseUs = [int]$m.Groups[2].Value; WriteUs = [int]$m.Groups[3].Value; Runs = [int]$m.Groups[4].Value; Bytes = [long]$m.Groups[5].Value; Os = [Runtime.InteropServices.RuntimeInformation]::OSDescription }
        }
    }
    Write-Table @($benchRows | Sort-Object Unit) "bench$labelSuffix$shardSuffix.tsv"
    Write-Output "build.ps1 / bench / $(@($benchRows).Count) units measured (median of the runs, microseconds) -> bench$labelSuffix$shardSuffix.tsv"
    Write-Table $fileRows "files$labelSuffix$shardSuffix.tsv"
    Write-Table $testRows "tests$labelSuffix$shardSuffix.tsv"
}
$budgetWaivers = @{}
foreach ($row in @($costRows | Where-Object { $_.Phase -in 'Unit', 'Regen' -and $_.Seconds -gt $UnitBudgetMinutes * 60 })) {
    $waiver = $budgetWaivers[$row.Unit]
    if ($waiver -and [datetime]$waiver[0] -ge (Get-Date).Date) { Write-Output "build.ps1 / budget / $($row.Unit) $($row.Seconds) s over $UnitBudgetMinutes min, waived until $($waiver[0]) by $($waiver[1])"; continue }
    $problems.Add("budget: $($row.Unit) took $($row.Seconds) s, over the $UnitBudgetMinutes min unit budget; cut it, or waive it in build.ps1 with a date and the item that cuts it")
}
$previousCost = @($(foreach ($folder in 'ci-metrics-windows-2025', 'ci-metrics-ubuntu-24.04') {
    try { (Invoke-WebRequest -Uri "$pages/target/$folder/gate-cost.tsv" -TimeoutSec 20 -ErrorAction Stop).Content | ConvertFrom-Csv -Delimiter "`t" } catch { }
}) | Where-Object { $_.Os -eq $osName -and $_.Core -eq $coreTag -and $_.Phase -eq 'Unit' })
$growth = @(foreach ($row in @($costRows | Where-Object Phase -eq 'Unit')) {
    $before = $previousCost | Where-Object { $_.Unit -eq $row.Unit -and $_.InputBytes -eq [string]$row.InputBytes -and $_.Slots -eq [string]$row.Slots } | Select-Object -First 1
    if ($before -and $row.Seconds -gt [double]$before.Seconds * 1.25 -and $row.Seconds - [double]$before.Seconds -gt 60) {
        [pscustomobject]@{ Unit = $row.Unit; Before = [double]$before.Seconds; Now = $row.Seconds; Percent = [math]::Round(100 * ($row.Seconds / [double]$before.Seconds - 1)); BeforeRun = $before.Run }
    }
})
$growth | ForEach-Object { Write-Output "build.ps1 / growth / $($_.Unit) $($_.Before) s -> $($_.Now) s (+$($_.Percent) %) at the same core, slots and input as run $($_.BeforeRun)" }
Write-Output "build.ps1 / growth / $($growth.Count) units grew over 25 % against $($previousCost.Count) comparable published rows"
Write-Table $growth "growth$labelSuffix$shardSuffix.tsv"
Write-Table $costRows "gate-cost$labelSuffix$shardSuffix.tsv"
Write-Output "build.ps1 / gate cost / $($costRows.Count) rows -> gate-cost$labelSuffix$shardSuffix.tsv"
if ($sharded) {
    $problems | Set-Content (Join-Path $metrics "problems$labelSuffix$shardSuffix.txt")
    $slowest = $fileRows | Sort-Object { [double]$_.Seconds } -Descending | Select-Object -First 1
    if ($slowest) { Write-Output "build.ps1 / shards / slowest unit $($slowest.File) $($slowest.Seconds) s; sum $([math]::Round(($fileRows | ForEach-Object { [double]$_.Seconds } | Measure-Object -Sum).Sum / 60, 1)) min" }
}
else {
    $env:FISCAL_METRICS_SUFFIX = $labelSuffix
    try {
        Invoke-WebRequest -Uri "$pages/target/ci-metrics/modeling-ceiling$labelSuffix.tsv" -OutFile (Join-Path $metrics "modeling-ceiling.previous$labelSuffix.tsv") -TimeoutSec 20 -ErrorAction Stop
        Write-Output "build.ps1 / reports / previous modeling ceiling read from $pages"
    } catch { Write-Output "build.ps1 / reports / no previous modeling ceiling ($($_.Exception.Message.Split([Environment]::NewLine)[0]))" }
    foreach ($source in @(Select-TestFiles { $_.BaseName -eq 'reports' })) { Invoke-TestFile $source }
}
if ($env:GITHUB_STEP_SUMMARY -and !$sharded) {
    $minutes = [math]::Round(($fileRows | ForEach-Object { [double]$_.Seconds } | Measure-Object -Sum).Sum / 60, 1)
    $summary = @("### fiscal $Label", "", "$($fileRows.Count) files in $minutes min", "")
    $report = Join-Path $metrics 'reports.md'
    if (Test-Path -LiteralPath $report) { $summary += Get-Content -LiteralPath $report | Select-Object -Skip 1 }
    $summary | Add-Content $env:GITHUB_STEP_SUMMARY
}
if (!$tested.Count -and !$MergeShards) { throw "build.ps1 / no test files matched $($Files -join ', ')" }
if ($problems.Count) { throw "build.ps1 / $($problems.Count) problems:`n$($problems -join "`n")" }
Write-Output $(if ($sharded) { "build.ps1 / shard $($shardIds -join ', ') of $Shards green" } elseif ($MergeShards) { "build.ps1 / merge / all shards green, every unit covered, every example validates" } else { "build.ps1 / all $($tested.Count) test files green and every example validates" })
