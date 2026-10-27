param(
    [Parameter(Mandatory)] [string] $Documents,
    [Parameter(Mandatory)] [string] $Written,
    [Parameter(Mandatory)] [string] $Out
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Xml.Linq

function Get-Normalized([string] $path) {
    $root = [Xml.Linq.XElement]::Parse([IO.File]::ReadAllText($path), [Xml.Linq.LoadOptions]::None)
    @($root.DescendantsAndSelf().Attributes() | Where-Object IsNamespaceDeclaration) | ForEach-Object { $_.Remove() }
    @($root.DescendantNodes() | Where-Object { $_ -is [Xml.Linq.XText] }) | ForEach-Object { $_.Value = $_.Value.Trim() }
    $root
}

function Get-FirstDifference([Xml.Linq.XElement] $expected, [Xml.Linq.XElement] $actual, [string] $path) {
    $here = "$path/$($expected.Name.LocalName)"
    if ($expected.Name -ne $actual.Name) { return "${here}: element $($actual.Name.LocalName)" }
    $expectedAttributes = @($expected.Attributes() | Sort-Object { $_.Name.ToString() } | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ' '
    $actualAttributes = @($actual.Attributes() | Sort-Object { $_.Name.ToString() } | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ' '
    if ($expectedAttributes -ne $actualAttributes) { return "${here}: attributes [$expectedAttributes] vs [$actualAttributes]" }
    $expectedChildren = @($expected.Elements())
    $actualChildren = @($actual.Elements())
    if ($expectedChildren.Count -eq 0 -and $actualChildren.Count -eq 0) {
        if ($expected.Value -ne $actual.Value) { return "${here}: text '$($expected.Value)' vs '$($actual.Value)'" }
        return $null
    }
    for ($i = 0; $i -lt [Math]::Max($expectedChildren.Count, $actualChildren.Count); $i++) {
        if ($i -ge $expectedChildren.Count) { return "${here}: extra $($actualChildren[$i].Name.LocalName)" }
        if ($i -ge $actualChildren.Count) { return "${here}: missing $($expectedChildren[$i].Name.LocalName)" }
        $difference = Get-FirstDifference $expectedChildren[$i] $actualChildren[$i] $here
        if ($difference) { return $difference }
    }
    $null
}

$rows = [Collections.Generic.List[string]]::new()
$rows.Add("library`tdocument`tverdict`tfirst_difference")
foreach ($output in Get-ChildItem -LiteralPath $Written -File -Filter '*-*.xml') {
    $library, $document = $output.Name.Split('-', 2)
    $source = Join-Path $Documents $document
    if (-not (Test-Path -LiteralPath $source)) { $rows.Add("$library`t$document`tno-source`t"); continue }
    try { $difference = Get-FirstDifference (Get-Normalized $source) (Get-Normalized $output.FullName) '' }
    catch { $difference = "unparsable: $($_.Exception.Message)" }
    $rows.Add("$library`t$document`t$(if ($difference) { 'roundtrip-differs' } else { 'roundtrip-equal' })`t$difference")
}
[IO.File]::WriteAllLines($Out, $rows)
"compare-roundtrip.ps1 / $($rows.Count - 1) written documents compared"
