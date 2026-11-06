param(
    [Parameter(Mandatory)] [string] $From,
    [Parameter(Mandatory)] [string] $Pattern,
    [string] $Compiler = (Join-Path $env:LOCALAPPDATA 'fiscal-gate\compiler\net11.0\SpiralCompiler.dll'),
    [string] $Dotnet = (Join-Path $env:LOCALAPPDATA 'spiral-bin\toolchains\dotnet\dotnet.exe'),
    [string] $Root = (Split-Path $PSScriptRoot)
)
$ErrorActionPreference = 'Stop'
$units = @(Get-ChildItem -LiteralPath (Join-Path $From 'generated') -Directory | Where-Object Name -match $Pattern)
if (-not $units) { "bring-generated-home / no unit under $From\generated matches $Pattern"; exit 2 }
$scratch = Join-Path ([IO.Path]::GetTempPath()) "bring-generated-home-$PID"
New-Item -ItemType Directory -Force (Join-Path $scratch 'generated') | Out-Null
try {
    foreach ($unit in $units) { Copy-Item -LiteralPath $unit.FullName (Join-Path $scratch "generated\$($unit.Name)") -Recurse }
    & (Join-Path $PSScriptRoot 'format-generated.ps1') -Compiler $Compiler -Dotnet $Dotnet -Root $scratch
    if ($LASTEXITCODE) { "bring-generated-home / format failed; nothing copied into $Root"; exit 1 }
    foreach ($unit in $units) {
        $target = Join-Path $Root "generated\$($unit.Name)"
        New-Item -ItemType Directory -Force $target | Out-Null
        Copy-Item -Path (Join-Path $scratch "generated\$($unit.Name)\*") -Destination $target -Force
    }
    "bring-generated-home / $($units.Count) units formatted into $Root\generated: $(($units | ForEach-Object Name) -join ', ')"
    git -C $Root -c core.quotepath=off diff --stat -- ($units | ForEach-Object { "generated/$($_.Name)" })
    git -C $Root -c core.quotepath=off status --porcelain -- ($units | ForEach-Object { "generated/$($_.Name)" }) | Where-Object { $_ -match '^\?\?' }
} finally { Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue }
