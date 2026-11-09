$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$acbr = Join-Path $root 'deps\bench\ACBr\Fontes'
$lazarus = Join-Path $root 'deps\bench\lazarus'
$out = (New-Item -ItemType Directory -Force (Join-Path $root 'target\bench\acbr')).FullName
$units = (New-Item -ItemType Directory -Force (Join-Path $out 'units')).FullName
$reportEngines = '\\(DANFE|DACTE|DAMDFE|DANFAg|DANFGas)\\.'
$folders = @($acbr) + @(Get-ChildItem $acbr -Recurse -Directory | Where-Object { $_.FullName -notmatch $reportEngines -and @(Get-ChildItem $_.FullName -File -Include *.pas, *.inc -Name).Count } | ForEach-Object FullName)
$search = @($folders | ForEach-Object { "-Fu$_"; "-Fi$_" }) + @(
    "-Fu$lazarus\components\lazutils", "-Fi$lazarus\components\lazutils",
    "-Fu$lazarus\lcl", "-Fi$lazarus\lcl\include", "-Fu$lazarus\lcl\widgetset"
)
& fpc -Px86_64 -Twin64 -Mdelphi -O2 -dNOGUI -vewn "-FU$units" "-FE$out" @search (Join-Path $PSScriptRoot 'bench_acbr.lpr')
exit $LASTEXITCODE
