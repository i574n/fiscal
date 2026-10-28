$root = Split-Path $PSScriptRoot
$validate = Join-Path $PSScriptRoot 'validate-example.ps1'
$schemas = Join-Path $root 'deps/corpus/DFe.NET'
$examples = [ordered]@{
    'nfe_v4_example.xml' = 'NFe.AppTeste/Schemas/nfe_v4.00.xsd'
    'generated_nfe_v2_00_example.xml' = 'NFe.AppTeste/Schemas/nfe_v2.00.xsd'
    'generated_nfe_v3_10_example.xml' = 'NFe.AppTeste/Schemas/nfe_v3.10.xsd'
    'generated_cte_v2_00_example.xml' = 'CTe.AppTeste/schemas/cte_v2.00.xsd'
    'generated_cte_v3_00_example.xml' = 'CTe.AppTeste/schemas/cte_v3.00.xsd'
    'generated_cte_v4_00_example.xml' = 'CTe.AppTeste/schemas/cte_v4.00.xsd'
    'generated_cte_os_v3_00_example.xml' = 'CTe.AppTeste/schemas/cteOS_v3.00.xsd'
    'generated_cte_os_v4_00_example.xml' = 'CTe.AppTeste/schemas/cteOS_v4.00.xsd'
    'generated_cte_simp_v4_00_example.xml' = 'CTe.AppTeste/schemas/cteSimp_v4.00.xsd'
    'generated_gtve_v3_00_example.xml' = 'CTe.AppTeste/schemas/GTVe_v3.00.xsd'
    'generated_gtve_v4_00_example.xml' = 'CTe.AppTeste/schemas/GTVe_v4.00.xsd'
    'generated_mdfe_v1_00_example.xml' = 'MDFe.AppTeste/Schemas/mdfe_v1.00.xsd'
    'generated_mdfe_v3_00_example.xml' = 'MDFe.AppTeste/Schemas/mdfe_v3.00.xsd'
}
$mx = Join-Path $root 'deps/corpus/mx/cfdi'
$cfdi = Join-Path $root 'samples/generated_cfdi_v4_0_example.xml'
if (Test-Path $cfdi) {
    '== generated_cfdi_v4_0_example.xml'
    & $validate -Document $cfdi -Schema (Join-Path $mx 'cfdv40.xsd') -Preload (Join-Path $mx 'catCFDI.xsd'), (Join-Path $mx 'tdCFDI.xsd') -Show 8
}
$ubl = Join-Path $root 'samples/generated_ubl_invoice_2_1_example.xml'
if (Test-Path $ubl) {
    '== generated_ubl_invoice_2_1_example.xml'
    pwsh -NoProfile -File $validate -Document $ubl -Schema (Join-Path $root 'deps/corpus/eu/ubl21/maindoc/UBL-Invoice-2.1.xsd') -Preload (Join-Path $root 'deps/corpus/eu/ubl21/common/UBL-xmldsig-core-schema-2.1.xsd') -Resolve -Show 8
}
$it = Join-Path $root 'deps/corpus/it/fatturapa'
$pl = Join-Path $root 'deps/corpus/pl/ksef'
$regimes = @(
    @{ Sample = 'generated_fatturapa_1_2_3_example.xml'; Schema = Join-Path $it 'Schema_VFPR12_v1.2.3.xsd'; Preload = @(Join-Path $root 'deps/corpus/DFe.NET/CTe.AppTeste/schemas/xmldsig-core-schema_v1.01.xsd') }
    @{ Sample = 'generated_ksef_fa_3_example.xml'; Schema = Join-Path $pl 'schemat_FA3.xsd'; Preload = @('ElementarneTypyDanych_v10-0E.xsd', 'KodyKrajow_v10-0E.xsd', 'StrukturyDanych_v10-0E.xsd' | ForEach-Object { Join-Path $pl $_ }) }
)
foreach ($regime in $regimes) {
    $document = Join-Path $root "samples/$($regime.Sample)"
    if (-not (Test-Path $document)) { continue }
    "== $($regime.Sample)"
    & $validate -Document $document -Schema $regime.Schema -Preload $regime.Preload -Show 8
}
foreach ($name in $examples.Keys) {
    $document = Join-Path $root "samples/$name"
    if (-not (Test-Path $document)) { "== $name :: not written"; continue }
    "== $name"
    pwsh -NoProfile -File $validate -Document $document -Schema (Join-Path $schemas $examples[$name]) -Show 8
}
$gst = Join-Path $root 'samples/generated_in_gst_inv01_1_1_example.json'
if (Test-Path $gst) {
    '== generated_in_gst_inv01_1_1_example.json'
    $document = Get-Content -Raw -LiteralPath $gst
    try {
        $null = Test-Json -Json $document -Schema (Get-Content -Raw -LiteralPath (Join-Path $root 'deps/corpus/in/gst/inv01_1.1.json')) -ErrorAction Stop
        "document $($document.Length) bytes; validation messages 0"
    }
    catch { "document $($document.Length) bytes; validation messages 1"; "  $($_.Exception.Message)" }
}
