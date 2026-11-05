$root = Split-Path $PSScriptRoot
$validate = Join-Path $PSScriptRoot 'validate-example.ps1'
$schemas = Join-Path $root 'deps/corpus/DFe.NET'
$examples = [ordered]@{
    'generated_nfe_v4_example.xml' = 'NFe.AppTeste/Schemas/nfe_v4.00.xsd'
    'generated_nfe_evento_canc_v1_00_example.xml' = 'NFe.AppTeste/Schemas/procEventoCancNFe_v1.00.xsd'
    'generated_nfe_evento_cce_v1_00_example.xml' = 'NFe.AppTeste/Schemas/procCCeNFe_v1.00.xsd'
    'generated_nfe_evento_conf_recebto_v1_00_example.xml' = 'NFe.AppTeste/Schemas/procConfRecebtoNFe_v1.00.xsd'
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
$ubl21 = Join-Path $root 'deps/corpus/eu/ubl21'
foreach ($document in 'Invoice', 'CreditNote', 'DebitNote', 'DespatchAdvice', 'ReceiptAdvice', 'ApplicationResponse') {
    $name = "generated_ubl_$($document.ToLowerInvariant())_2_1_example.xml"
    $sample = Join-Path $root "samples/$name"
    if (-not (Test-Path $sample)) { "== $name :: not written"; continue }
    "== $name"
    pwsh -NoProfile -File $validate -Document $sample -Schema (Join-Path $ubl21 "maindoc/UBL-$document-2.1.xsd") -Preload (Join-Path $ubl21 'common/UBL-xmldsig-core-schema-2.1.xsd') -Resolve -Show 8
}
$it = Join-Path $root 'deps/corpus/it/fatturapa'
$pl = Join-Path $root 'deps/corpus/pl/ksef'
$regimes = @(
    @{ Sample = 'generated_fatturapa_1_2_3_example.xml'; Schema = Join-Path $it 'Schema_VFPR12_v1.2.3.xsd'; Preload = @(Join-Path $ubl21 'common/UBL-xmldsig-core-schema-2.1.xsd') }
    @{ Sample = 'generated_ksef_fa_3_example.xml'; Schema = Join-Path $pl 'schemat_FA3.xsd'; Preload = @('ElementarneTypyDanych_v10-0E.xsd', 'KodyKrajow_v10-0E.xsd', 'StrukturyDanych_v10-0E.xsd' | ForEach-Object { Join-Path $pl $_ }) }
)
foreach ($regime in $regimes) {
    $document = Join-Path $root "samples/$($regime.Sample)"
    if (-not (Test-Path $document)) { continue }
    "== $($regime.Sample)"
    & $validate -Document $document -Schema $regime.Schema -Preload $regime.Preload -Show 8
}
$dsig = Join-Path $ubl21 'common/UBL-xmldsig-core-schema-2.1.xsd'
$cr = 'deps/corpus/cr/hacienda/v4.4/'
$resolved = [ordered]@{
    'generated_cfdi_pagos_2_0_example.xml' = 'deps/corpus/mx/complements/Pagos20.xsd'
    'generated_cfdi_tfd_1_1_example.xml' = 'deps/corpus/mx/complements/TimbreFiscalDigitalv11.xsd'
    'generated_cl_dte_v10_example.xml' = 'deps/corpus/cl/dte/DTE_v10.xsd'
    'generated_cl_envio_dte_v10_example.xml' = 'deps/corpus/cl/dte/EnvioDTE_v10.xsd'
    'generated_cr_factura_4_4_example.xml' = "${cr}FacturaElectronica_V4.4.xsd"
    'generated_cr_factura_compra_4_4_example.xml' = "${cr}FacturaElectronicaCompra_V4.4.xsd"
    'generated_cr_factura_exportacion_4_4_example.xml' = "${cr}FacturaElectronicaExportacion_V4.4.xsd"
    'generated_cr_mensaje_hacienda_4_4_example.xml' = "${cr}MensajeHacienda_V4.4.xsd"
    'generated_cr_mensaje_receptor_4_4_example.xml' = "${cr}MensajeReceptor_V4.4.xsd"
    'generated_cr_nota_credito_4_4_example.xml' = "${cr}NotaCreditoElectronica_V4.4.xsd"
    'generated_cr_nota_debito_4_4_example.xml' = "${cr}NotaDebitoElectronica_V4.4.xsd"
    'generated_cr_recibo_pago_4_4_example.xml' = "${cr}ReciboElectronicoPago_V4.4.xsd"
    'generated_cr_tiquete_4_4_example.xml' = "${cr}TiqueteElectronico_V4.4.xsd"
    'generated_es_facturae_3_2_2_example.xml' = 'deps/corpus/es/facturae/Facturaev3_2_2.xsd'
    'generated_es_verifactu_example.xml' = 'deps/corpus/es/verifactu/SuministroLR.xsd'
    'generated_gr_mydata_2_0_2_example.xml' = 'deps/corpus/gr/mydata/InvoicesDoc-v2.0.2.xsd'
}
$ownSignatureImport = @('generated_cl_dte_v10_example.xml', 'generated_cl_envio_dte_v10_example.xml')
foreach ($name in $resolved.Keys) {
    $document = Join-Path $root "samples/$name"
    if (-not (Test-Path $document)) { "== $name :: not written"; continue }
    "== $name"
    $arguments = @('-NoProfile', '-File', $validate, '-Document', $document, '-Schema', (Join-Path $root $resolved[$name]), '-Resolve', '-Show', '8')
    if ($name -notin $ownSignatureImport) { $arguments += '-Preload', $dsig }
    pwsh @arguments
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
