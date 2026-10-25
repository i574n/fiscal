$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
& (Join-Path $root 'deps/spiral/scripts/publish-tree.ps1') -Root $root -Include '*.xml', '*.txt', '*.tsv'
