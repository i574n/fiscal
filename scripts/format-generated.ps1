param(
    [Parameter(Mandatory)] [string] $Compiler,
    [string] $Dotnet = 'dotnet',
    [string] $Root = (Split-Path $PSScriptRoot),
    [int] $Jobs = 2
)
$ErrorActionPreference = 'Stop'
$generated = Join-Path $Root 'generated'
if (-not (Test-Path $generated)) { exit 0 }
$cache = (New-Item -ItemType Directory -Force (Join-Path $Root 'target/format-cache')).FullName
$clock = [Diagnostics.Stopwatch]::StartNew()
$units = @(Get-ChildItem $generated -Directory | ForEach-Object { Get-ChildItem $_.FullName -File -Filter '*.spi' })
$results = @($units | ForEach-Object -ThrottleLimit $Jobs -Parallel {
    $raw = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    $cached = Join-Path $using:cache "$raw.spi"
    if (Test-Path -LiteralPath $cached) { Copy-Item -LiteralPath $cached $_.FullName -Force; return "cached $($_.BaseName)" }
    $stable = $false
    for ($pass = 1; $pass -le 3 -and -not $stable; $pass++) {
        $out = @(& $using:Dotnet $using:Compiler format $_.FullName 2>&1)
        if ($LASTEXITCODE -ne 0) { return "failed $($_.BaseName): $(($out | Select-Object -First 2) -join ' | ')" }
        $null = & $using:Dotnet $using:Compiler format $_.FullName --check 2>&1
        $stable = $LASTEXITCODE -eq 0
    }
    if (-not $stable) { return "failed $($_.BaseName): still not formatter-stable after 3 passes" }
    Copy-Item -LiteralPath $_.FullName $cached -Force
    $formatted = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    if ($formatted -ne $raw) { Copy-Item -LiteralPath $_.FullName (Join-Path $using:cache "$formatted.spi") -Force }
    "formatted $($_.BaseName)"
})
$failed = @($results | Where-Object { $_ -match '^failed ' })
$failed | ForEach-Object { Write-Output "format-generated / $_" }
Write-Output ("format-generated / {0} units: {1} formatted, {2} from cache, {3} failed, {4} s" -f $units.Count,
    @($results | Where-Object { $_ -match '^formatted ' }).Count, @($results | Where-Object { $_ -match '^cached ' }).Count,
    $failed.Count, [int]$clock.Elapsed.TotalSeconds)
exit $(if ($failed.Count) { 1 } else { 0 })
