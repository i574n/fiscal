param([switch] $ShowInvalid)
$root = Split-Path $PSScriptRoot
$corpus = Join-Path $root 'deps/corpus'
$validate = Join-Path $PSScriptRoot 'validate-example.ps1'
$ubl = Join-Path $corpus 'eu/ubl21'
$ublSignature = Join-Path $ubl 'common/UBL-xmldsig-core-schema-2.1.xsd'
$hu = Join-Path $corpus 'hu/nav'
$referees = [ordered]@{
    'ubl-invoice' = @{ Schema = "$ubl/maindoc/UBL-Invoice-2.1.xsd"; Preload = @($ublSignature); Resolve = $true }
    'ubl-creditnote' = @{ Schema = "$ubl/maindoc/UBL-CreditNote-2.1.xsd"; Preload = @($ublSignature); Resolve = $true }
    'ubl-debitnote' = @{ Schema = "$ubl/maindoc/UBL-DebitNote-2.1.xsd"; Preload = @($ublSignature); Resolve = $true }
    'ubl-applicationresponse' = @{ Schema = "$ubl/maindoc/UBL-ApplicationResponse-2.1.xsd"; Preload = @($ublSignature); Resolve = $true }
    'ubl-despatchadvice' = @{ Schema = "$ubl/maindoc/UBL-DespatchAdvice-2.1.xsd"; Preload = @($ublSignature); Resolve = $true }
    'ubl-receiptadvice' = @{ Schema = "$ubl/maindoc/UBL-ReceiptAdvice-2.1.xsd"; Preload = @($ublSignature); Resolve = $true }
    'hu-nav-invoicedata' = @{ Schema = "$hu/invoiceData.xsd"; Preload = @("$hu/common.xsd", "$hu/invoiceBase.xsd"); Resolve = $false }
    'gr-mydata-invoicesdoc' = @{ Schema = "$corpus/gr/mydata/InvoicesDoc-v2.0.2.xsd"; Preload = @(); Resolve = $false }
}
$rows = foreach ($name in $referees.Keys) {
    $manifest = Join-Path $corpus "$name-documents.txt"
    if (-not (Test-Path $manifest)) { [pscustomobject]@{ Manifest = $name; Documents = 0; Valid = 0; Invalid = 'manifest missing' }; continue }
    $referee = $referees[$name]
    $documents = @(Get-Content $manifest | Where-Object { $_ })
    $invalid = [System.Collections.Generic.List[string]]::new()
    $refereeLimited = 0
    $unsigned = 0
    foreach ($relative in $documents) {
        $arguments = @{ Document = (Join-Path $corpus $relative); Schema = $referee.Schema; Show = 1 }
        if ($referee.Preload.Count) { $arguments.Preload = $referee.Preload }
        if ($referee.Resolve) { $arguments.Resolve = $true }
        $report = (@(& $validate @arguments 2>&1 | ForEach-Object { "$_" }) -join ' | ')
        if ($report -match 'validation messages 0\b') { continue }
        if ($report -match 'validation messages 1\b' -and $report -match "X509SerialNumber' element is invalid - The value '\d{29,}") { $refereeLimited++; continue }
        if ($report -match 'validation messages 1\b' -and $report -match "ExtensionContent' in namespace '[^']+' has incomplete content") {
            $parsed = [xml][IO.File]::ReadAllText((Join-Path $corpus $relative))
            $slots = @($parsed.SelectNodes("//*[local-name()='ExtensionContent']"))
            if ($slots.Count -and -not @($slots | Where-Object { @($_.ChildNodes | Where-Object { $_ -is [Xml.XmlElement] -or $_.Value.Trim() }).Count }).Count) { $unsigned++; continue }
        }
        $invalid.Add("${relative}: $($report.Substring(0, [Math]::Min(200, $report.Length)))")
    }
    [pscustomobject]@{ Manifest = $name; Documents = $documents.Count; Valid = $documents.Count - $invalid.Count - $refereeLimited - $unsigned; RefereeLimited = $refereeLimited; Unsigned = $unsigned; Invalid = $invalid }
}
foreach ($row in $rows) {
    "{0,-26} {1,4} documents, {2,4} schema-valid, {3,2} past the .NET decimal cap (X509SerialNumber > 28 digits), {4,2} unsigned (only an empty ExtensionContent)" -f $row.Manifest, $row.Documents, $row.Valid, $row.RefereeLimited, $row.Unsigned
    if ($ShowInvalid -and $row.Invalid -is [System.Collections.IEnumerable] -and $row.Invalid -isnot [string]) { $row.Invalid | ForEach-Object { "    $_" } }
}
