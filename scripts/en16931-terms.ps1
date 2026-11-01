param(
    [string] $Structure = (Join-Path $PSScriptRoot '..\deps\corpus\eu\peppol-bis3\structure'),
    [string] $Out = (Join-Path $PSScriptRoot '..\canon\en16931-terms.json')
)
$ErrorActionPreference = 'Stop'
$terms = @{}
function Get-Child([System.Xml.XmlNode] $node, [string] $name) { $node.SelectSingleNode("*[local-name()='$name']") }
function Visit-Element([System.Xml.XmlNode] $element, [string] $path, [string] $folder, [string] $document) {
    $here = "$path/$((Get-Child $element 'Term').InnerText.Trim())"
    $ids = @(foreach ($reference in $element.SelectNodes("*[local-name()='Reference'][@type='BUSINESS_TERM']")) { $reference.InnerText -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } })
    $names = @("$((Get-Child $element 'Name').InnerText)".Trim())
    if ($ids.Count -gt 1) { $split = @($names[0] -split ',\s*'); if ($split.Count -eq $ids.Count) { $names = $split } }
    for ($i = 0; $i -lt $ids.Count; $i++) {
        $id = $ids[$i]
        if (-not $terms.ContainsKey($id)) {
            $terms[$id] = [ordered]@{
                id = $id
                kind = if ($id -like 'BG-*') { 'group' } else { 'term' }
                name = $names[[Math]::Min($i, $names.Count - 1)]
                data_type = "$((Get-Child $element 'DataType').InnerText)".Trim()
                cardinality = if ($element.Attributes['cardinality']) { $element.Attributes['cardinality'].Value } else { '1..1' }
                ubl = [ordered]@{}
            }
        }
        $terms[$id].ubl[$document] = $here
    }
    Read-Children $element $here $folder $document
}
function Read-Children([System.Xml.XmlNode] $node, [string] $path, [string] $folder, [string] $document) {
    foreach ($child in $node.ChildNodes) {
        if ($child.LocalName -eq 'Include') {
            $file = Join-Path $folder $child.InnerText.Trim()
            Visit-Element ([xml][IO.File]::ReadAllText($file)).DocumentElement $path (Split-Path $file) $document
        } elseif ($child.LocalName -eq 'Element') {
            Visit-Element $child $path $folder $document
        }
    }
}
foreach ($file in 'ubl-invoice.xml', 'ubl-creditnote.xml') {
    $root = [xml][IO.File]::ReadAllText((Join-Path $Structure $file))
    $document = Get-Child $root.DocumentElement 'Document'
    Read-Children $document (Get-Child $document 'Term').InnerText.Trim() $Structure ([IO.Path]::GetFileNameWithoutExtension($file))
}
$rows = @($terms.Values | Sort-Object @{ Expression = { $_.kind }; Descending = $true }, @{ Expression = { [int]($_.id -replace '^B[TG]-', '') } })
New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
$json = [ordered]@{ source = 'OpenPeppol peppol-bis-invoice-3 v3.0.20 structure/syntax (EN 16931 UBL binding)'; terms = $rows } | ConvertTo-Json -Depth 6
[IO.File]::WriteAllText($Out, $json + "`n")
"en16931-terms / $(@($rows | Where-Object kind -eq 'term').Count) terms, $(@($rows | Where-Object kind -eq 'group').Count) groups -> $Out"
