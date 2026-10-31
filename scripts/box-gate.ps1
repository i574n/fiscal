param(
    [Parameter(Mandatory)] [string] $Lib,
    [Parameter(Mandatory)] [string] $File,
    [string] $Test = '',
    [Parameter(Mandatory)] [string] $Raw,
    [string] $FiscalRoot = (Split-Path $PSScriptRoot),
    [string] $GateRoot = (Join-Path $env:LOCALAPPDATA 'fiscal-gate'),
    [string] $Compiler = (Join-Path $env:LOCALAPPDATA 'fiscal-gate\compiler\net11.0\SpiralCompiler.dll'),
    [string] $LibGate = 'C:\home\git\spiral\apps\cells\spi\lib_gate.ps1'
)
$env:SPIRAL_COMPILER_DLL = $Compiler
$env:SPIRAL_CELLS_SERVER = '0'
$env:SPIRAL_CELLS_COMPILER = 'process'
$env:SPIRAL_CELLS_MEMO = '0'
$env:FISCAL_ROOT = $FiscalRoot
"box-gate / $File $((Get-FileHash (Join-Path $Lib $File)).Hash.Substring(0, 12)) / test $Test / compiler $((Get-FileHash $Compiler).Hash.Substring(0, 12))"
$owner = Split-Path (Split-Path $Lib) -Parent | Split-Path -Leaf
$build = Join-Path $GateRoot "mix-build-$owner-$([IO.Path]::GetFileNameWithoutExtension($File))"
$arguments = @('-NoProfile', '-File', $LibGate, '-Lib', $Lib, '-File', $File, '-Show', '12', '-Compiler', 'process', '-RawOut', $Raw, '-BuildPath', $build)
if ($Test) { $arguments += @('-Test', $Test) }
& pwsh @arguments 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -match 'tests:|type errors|failed|ETY|VERDICT|panicked|has fatal|changed its|row / |timed out' }
"box-gate / exit $LASTEXITCODE"
exit $LASTEXITCODE
