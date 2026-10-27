$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$deps = Join-Path $root 'deps'
New-Item -ItemType Directory -Force $deps | Out-Null
New-Item -ItemType Directory -Force (Join-Path $root 'samples') | Out-Null
$spiral = Join-Path $deps 'spiral'
if (-not (Test-Path $spiral)) {
    $sibling = [IO.Path]::GetFullPath((Join-Path $root '../spiral'))
    if (Test-Path (Join-Path $sibling '.git')) { New-Item -ItemType Junction -Path $spiral -Target $sibling | Out-Null; "deps/spiral -> $sibling" }
    else { git clone --recurse-submodules https://github.com/i574n/spiral.git $spiral; if ($LASTEXITCODE) { throw 'init.ps1 / git clone spiral failed' } }
}
$corpus = Join-Path $deps 'corpus/DFe.NET'
if (-not (Test-Path $corpus)) {
    $clone = Join-Path $deps 'DFe.NET-clone'
    git clone --filter=blob:none --sparse --depth 1 https://github.com/ZeusAutomacao/DFe.NET.git $clone
    if ($LASTEXITCODE) { throw 'init.ps1 / git clone DFe.NET failed' }
    $folders = 'NFe.AppTeste/Schemas', 'CTe.AppTeste/schemas', 'CTe.AppTeste.NetCore/schemas', 'MDFe.AppTeste/Schemas'
    git -C $clone sparse-checkout set @folders
    foreach ($folder in $folders) {
        $to = Join-Path $corpus $folder
        New-Item -ItemType Directory -Force (Split-Path $to) | Out-Null
        Copy-Item (Join-Path $clone $folder) $to -Recurse
    }
    Remove-Item -LiteralPath $clone -Recurse -Force
    "deps/corpus: $(@(Get-ChildItem $corpus -Recurse -Filter *.xsd).Count) schemas"
}
$dfeNet = Join-Path $deps 'bench/DFe.NET'
if (-not (Test-Path $dfeNet)) {
    git clone --filter=blob:none --sparse --no-checkout https://github.com/ZeusAutomacao/DFe.NET.git $dfeNet
    if ($LASTEXITCODE) { throw 'init.ps1 / git clone DFe.NET for the bench failed' }
    git -C $dfeNet sparse-checkout set --no-cone /DFe.Classes/** /DFe.Utils/** /DFe.Wsdl/** /NFe.Classes/** /NFe.Utils/** /CTe.Classes/** /CTe.Utils/** /MDFe.Classes/** /MDFe.Utils/**
    git -C $dfeNet checkout 08743cd5f5b82769a26ad9ae0093b1b0ae60c74f
    if ($LASTEXITCODE) { throw 'init.ps1 / DFe.NET bench checkout failed' }
    "deps/bench/DFe.NET: $(@(Get-ChildItem $dfeNet -Recurse -Filter *.csproj).Count) projects at 08743cd5"
}
$acbr = Join-Path $deps 'bench/ACBr'
if (-not (Test-Path $acbr)) {
    if (-not (Get-Command svn -ErrorAction SilentlyContinue)) { throw 'init.ps1 / the ACBr bench source needs an svn client (scoop install svn)' }
    $trunk = 'svn://svn.code.sf.net/p/acbr/code/trunk2/Fontes'
    $whole = @('ACBrCapicom', 'ACBrComum', 'ACBrDiversos', 'ACBrIntegrador', 'ACBrLibXML2', 'ACBrOpenSSL', 'ACBrTCP', 'PCNComum') +
        @('CodeGear', 'FastStringReplace', 'GZIPUtils', 'json4delphi', 'JsonDataObjects', 'LibXmlSec', 'Ole', 'synalist', 'ZLibExGZ' | ForEach-Object { "Terceiros/$_" }) +
        @('ACBrCIOT', 'ACBrCTe', 'ACBrDI', 'ACBrGTIN', 'ACBrMDFe', 'ACBrNFAg', 'ACBrNFe', 'ACBrNFGas', 'ACBrSATWS', 'Comum' | ForEach-Object { "ACBrDFe/$_" })
    foreach ($folder in $whole) {
        New-Item -ItemType Directory -Force (Split-Path (Join-Path $acbr "Fontes/$folder")) | Out-Null
        svn export --quiet -r 48801 "$trunk/$folder" (Join-Path $acbr "Fontes/$folder")
        if ($LASTEXITCODE) { throw "init.ps1 / svn export of ACBr Fontes/$folder failed" }
    }
    svn export --quiet --force --depth files -r 48801 "$trunk/ACBrDFe" (Join-Path $acbr 'Fontes/ACBrDFe')
    if ($LASTEXITCODE) { throw 'init.ps1 / svn export of the ACBrDFe root units failed' }
    "deps/bench/ACBr: $(@(Get-ChildItem $acbr -Recurse -Filter *.pas).Count) units at trunk2 r48801"
}
$lazarus = Join-Path $deps 'bench/lazarus'
if (-not (Test-Path $lazarus)) {
    git clone --filter=blob:none --sparse --no-checkout https://gitlab.com/freepascal.org/lazarus/lazarus.git $lazarus
    if ($LASTEXITCODE) { throw 'init.ps1 / git clone Lazarus for the bench failed' }
    git -C $lazarus sparse-checkout set components/lazutils lcl
    git -C $lazarus checkout ebadd0b458c682b1fa3144f3c44c0e807d79b550
    if ($LASTEXITCODE) { throw 'init.ps1 / Lazarus bench checkout failed' }
    "deps/bench/lazarus: lazutils + lcl at ebadd0b"
}
$cfdi = Join-Path $deps 'corpus/mx/cfdi'
if (-not (Test-Path $cfdi)) {
    New-Item -ItemType Directory -Force $cfdi | Out-Null
    foreach ($url in 'http://www.sat.gob.mx/sitio_internet/cfd/4/cfdv40.xsd', 'http://www.sat.gob.mx/sitio_internet/cfd/catalogos/catCFDI.xsd', 'http://www.sat.gob.mx/sitio_internet/cfd/tipoDatos/tdCFDI/tdCFDI.xsd') {
        Invoke-WebRequest -Uri $url -OutFile (Join-Path $cfdi (Split-Path $url -Leaf)) -TimeoutSec 120 -UseBasicParsing
    }
    "deps/corpus/mx/cfdi: $(@(Get-ChildItem $cfdi -Filter *.xsd).Count) schemas"
}
$en16931 = Join-Path $deps 'corpus/eu/en16931'
if (-not (Test-Path $en16931)) {
    New-Item -ItemType Directory -Force $en16931 | Out-Null
    $release = 'https://raw.githubusercontent.com/ConnectingEurope/eInvoicing-EN16931/validation-1.3.16/ubl/schematron/'
    foreach ($file in 'preprocessed/EN16931-UBL-validation-preprocessed.sch', 'UBL/EN16931-UBL-model.sch', 'abstract/EN16931-model.sch', 'codelist/EN16931-UBL-codes.sch') {
        Invoke-WebRequest -Uri ($release + $file) -OutFile (Join-Path $en16931 (Split-Path $file -Leaf)) -TimeoutSec 120 -UseBasicParsing
    }
    "deps/corpus/eu/en16931: $(@(Get-ChildItem $en16931 -Filter *.sch).Count) schematron files (EUPL 1.2, validation-1.3.16)"
}
$examples = Join-Path $deps 'corpus/eu/en16931/examples'
if (-not (Test-Path $examples)) {
    New-Item -ItemType Directory -Force $examples | Out-Null
    $tag = 'https://raw.githubusercontent.com/ConnectingEurope/eInvoicing-EN16931/validation-1.3.16/ubl/examples/'
    foreach ($file in @(1..10 | ForEach-Object { "ubl-tc434-example$_.xml" }) + 'ubl-tc434-creditnote1.xml') {
        Invoke-WebRequest -Uri ($tag + $file) -OutFile (Join-Path $examples $file) -TimeoutSec 120 -UseBasicParsing
    }
    "deps/corpus/eu/en16931/examples: $(@(Get-ChildItem $examples -Filter *.xml).Count) CEN TC434 example documents"
}
$fatturapa = Join-Path $deps 'corpus/it/fatturapa'
if (-not (Test-Path $fatturapa)) {
    New-Item -ItemType Directory -Force $fatturapa | Out-Null
    foreach ($file in 'Schema_VFPA12_V1.2.3.xsd', 'Schema_VFPR12_v1.2.3.xsd', 'Schema_VFSM10v_1.0.2.xsd') {
        Invoke-WebRequest -Uri "https://www.fatturapa.gov.it/export/documenti/fatturapa/v1.4/$file" -OutFile (Join-Path $fatturapa $file) -TimeoutSec 120 -UseBasicParsing
    }
    "deps/corpus/it/fatturapa: 3 schemas (FatturaPA/ordinaria 1.2.3, semplificata 1.0.2)"
}
$ksef = Join-Path $deps 'corpus/pl/ksef'
if (-not (Test-Path $ksef)) {
    New-Item -ItemType Directory -Force $ksef | Out-Null
    Invoke-WebRequest -Uri 'http://crd.gov.pl/wzor/2025/06/25/13775/schemat.xsd' -OutFile (Join-Path $ksef 'schemat_FA3.xsd') -TimeoutSec 120 -UseBasicParsing
    foreach ($file in 'StrukturyDanych_v10-0E.xsd', 'ElementarneTypyDanych_v10-0E.xsd', 'KodyKrajow_v10-0E.xsd') {
        Invoke-WebRequest -Uri "http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2022/01/05/eD/DefinicjeTypy/$file" -OutFile (Join-Path $ksef $file) -TimeoutSec 120 -UseBasicParsing
    }
    "deps/corpus/pl/ksef: 4 schemas (KSeF FA(3) and its CRD type definitions)"
}
$ubl = Join-Path $deps 'corpus/eu/ubl21'
if (-not (Test-Path $ubl)) {
    $oasis = 'https://docs.oasis-open.org/ubl/os-UBL-2.1/xsd/'
    $common = 'CCTS_CCT_SchemaModule', 'UBL-CommonAggregateComponents', 'UBL-CommonBasicComponents', 'UBL-CommonExtensionComponents', 'UBL-CommonSignatureComponents', 'UBL-ExtensionContentDataType', 'UBL-QualifiedDataTypes', 'UBL-SignatureAggregateComponents', 'UBL-SignatureBasicComponents', 'UBL-UnqualifiedDataTypes', 'UBL-XAdESv132', 'UBL-XAdESv141', 'UBL-xmldsig-core-schema'
    $files = @($common | ForEach-Object { "common/$_-2.1.xsd" }) + 'maindoc/UBL-Invoice-2.1.xsd', 'maindoc/UBL-CreditNote-2.1.xsd'
    foreach ($file in $files) {
        $to = Join-Path $ubl $file
        New-Item -ItemType Directory -Force (Split-Path $to) | Out-Null
        Invoke-WebRequest -Uri ($oasis + $file) -OutFile $to -TimeoutSec 120 -UseBasicParsing
    }
    "deps/corpus/eu/ubl21: $(@(Get-ChildItem $ubl -Recurse -Filter *.xsd).Count) schemas (OASIS UBL 2.1)"
}
