param([switch] $Bench)
$ErrorActionPreference = 'Stop'
$filling = $null
trap { if ($filling -and (Test-Path $filling)) { Remove-Item -LiteralPath $filling -Recurse -Force; "init.ps1 / removed the partly fetched $filling" }; break }
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$deps = Join-Path $root 'deps'
New-Item -ItemType Directory -Force $deps | Out-Null
New-Item -ItemType Directory -Force (Join-Path $root 'samples') | Out-Null
$spiral = Join-Path $deps 'spiral'
if (-not (Test-Path $spiral)) {
    $filling = $spiral
    $sibling = [IO.Path]::GetFullPath((Join-Path $root '../spiral'))
    if (Test-Path (Join-Path $sibling '.git')) { New-Item -ItemType Junction -Path $spiral -Target $sibling | Out-Null; "deps/spiral -> $sibling" }
    else { git clone --recurse-submodules https://github.com/i574n/spiral.git $spiral; if ($LASTEXITCODE) { throw 'init.ps1 / git clone spiral failed' } }
}
if (-not (Test-Path (Join-Path $spiral 'deps/The-Spiral-Language/.git'))) {
    pwsh -NoProfile -File (Join-Path $spiral 'scripts/init-app-build.ps1') -fast 1
    if ($LASTEXITCODE) { throw "init.ps1 / spiral init-app-build failed (exit code $LASTEXITCODE)" }
    "deps/spiral/deps/The-Spiral-Language: the Spiral fork the Cells packages load core from"
}
$corpus = Join-Path $deps 'corpus/DFe.NET'
if (-not (Test-Path $corpus)) {
    $filling = $corpus
    $clone = Join-Path $deps 'DFe.NET-clone'
    git clone --filter=blob:none --sparse --no-checkout https://github.com/ZeusAutomacao/DFe.NET.git $clone
    if ($LASTEXITCODE) { throw 'init.ps1 / git clone DFe.NET failed' }
    $folders = 'NFe.AppTeste/Schemas', 'CTe.AppTeste/schemas', 'CTe.AppTeste.NetCore/schemas', 'MDFe.AppTeste/Schemas'
    git -C $clone sparse-checkout set @folders
    git -C $clone checkout 56ad28209d0206ba3b19a194dd39f7a51f362df3
    if ($LASTEXITCODE) { throw 'init.ps1 / DFe.NET corpus checkout failed' }
    foreach ($folder in $folders) {
        $to = Join-Path $corpus $folder
        New-Item -ItemType Directory -Force (Split-Path $to) | Out-Null
        Copy-Item (Join-Path $clone $folder) $to -Recurse
    }
    Remove-Item -LiteralPath $clone -Recurse -Force
    $schemaFiles = @(Get-ChildItem $corpus -Recurse -File).Count
    if ($schemaFiles -ne 580) { throw "init.ps1 / DFe.NET at 56ad2820 should give 580 files, got $schemaFiles" }
    "deps/corpus: $(@(Get-ChildItem $corpus -Recurse -Filter *.xsd).Count) schemas at DFe.NET 56ad2820"
}
$dfeNet = Join-Path $deps 'bench/DFe.NET'
if ($Bench -and -not (Test-Path $dfeNet)) {
    $filling = $dfeNet
    git clone --filter=blob:none --sparse --no-checkout https://github.com/ZeusAutomacao/DFe.NET.git $dfeNet
    if ($LASTEXITCODE) { throw 'init.ps1 / git clone DFe.NET for the bench failed' }
    git -C $dfeNet sparse-checkout set --no-cone /DFe.Classes/** /DFe.Utils/** /DFe.Wsdl/** /NFe.Classes/** /NFe.Utils/** /CTe.Classes/** /CTe.Utils/** /MDFe.Classes/** /MDFe.Utils/**
    git -C $dfeNet checkout 08743cd5f5b82769a26ad9ae0093b1b0ae60c74f
    if ($LASTEXITCODE) { throw 'init.ps1 / DFe.NET bench checkout failed' }
    "deps/bench/DFe.NET: $(@(Get-ChildItem $dfeNet -Recurse -Filter *.csproj).Count) projects at 08743cd5"
}
$acbr = Join-Path $deps 'bench/ACBr'
if ($Bench -and -not (Test-Path $acbr)) {
    $filling = $acbr
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
if ($Bench -and -not (Test-Path $lazarus)) {
    $filling = $lazarus
    git clone --filter=blob:none --sparse --no-checkout https://gitlab.com/freepascal.org/lazarus/lazarus.git $lazarus
    if ($LASTEXITCODE) { throw 'init.ps1 / git clone Lazarus for the bench failed' }
    git -C $lazarus sparse-checkout set components/lazutils lcl
    git -C $lazarus checkout ebadd0b458c682b1fa3144f3c44c0e807d79b550
    if ($LASTEXITCODE) { throw 'init.ps1 / Lazarus bench checkout failed' }
    "deps/bench/lazarus: lazutils + lcl at ebadd0b"
}
$cfdi = Join-Path $deps 'corpus/mx/cfdi'
if (-not (Test-Path $cfdi)) {
    $filling = $cfdi
    New-Item -ItemType Directory -Force $cfdi | Out-Null
    foreach ($url in 'http://www.sat.gob.mx/sitio_internet/cfd/4/cfdv40.xsd', 'http://www.sat.gob.mx/sitio_internet/cfd/catalogos/catCFDI.xsd', 'http://www.sat.gob.mx/sitio_internet/cfd/tipoDatos/tdCFDI/tdCFDI.xsd') {
        Invoke-WebRequest -Uri $url -OutFile (Join-Path $cfdi (Split-Path $url -Leaf)) -TimeoutSec 120 -UseBasicParsing
    }
    "deps/corpus/mx/cfdi: $(@(Get-ChildItem $cfdi -Filter *.xsd).Count) schemas"
}
$en16931 = Join-Path $deps 'corpus/eu/en16931'
if (-not (Test-Path $en16931)) {
    $filling = $en16931
    New-Item -ItemType Directory -Force $en16931 | Out-Null
    $release = 'https://raw.githubusercontent.com/ConnectingEurope/eInvoicing-EN16931/validation-1.3.17/ubl/schematron/'
    foreach ($file in 'preprocessed/EN16931-UBL-validation-preprocessed.sch', 'UBL/EN16931-UBL-model.sch', 'abstract/EN16931-model.sch', 'codelist/EN16931-UBL-codes.sch') {
        Invoke-WebRequest -Uri ($release + $file) -OutFile (Join-Path $en16931 (Split-Path $file -Leaf)) -TimeoutSec 120 -UseBasicParsing
    }
    "deps/corpus/eu/en16931: $(@(Get-ChildItem $en16931 -Filter *.sch).Count) schematron files (EUPL 1.2, validation-1.3.17)"
}
$examples = Join-Path $deps 'corpus/eu/en16931/examples'
if (-not (Test-Path $examples)) {
    $filling = $examples
    New-Item -ItemType Directory -Force $examples | Out-Null
    $tag = 'https://raw.githubusercontent.com/ConnectingEurope/eInvoicing-EN16931/validation-1.3.17/ubl/examples/'
    foreach ($file in @(1..10 | ForEach-Object { "ubl-tc434-example$_.xml" }) + 'ubl-tc434-creditnote1.xml') {
        Invoke-WebRequest -Uri ($tag + $file) -OutFile (Join-Path $examples $file) -TimeoutSec 120 -UseBasicParsing
    }
    "deps/corpus/eu/en16931/examples: $(@(Get-ChildItem $examples -Filter *.xml).Count) CEN TC434 example documents"
}
$fatturapa = Join-Path $deps 'corpus/it/fatturapa'
if (-not (Test-Path $fatturapa)) {
    $filling = $fatturapa
    New-Item -ItemType Directory -Force $fatturapa | Out-Null
    foreach ($file in 'Schema_VFPA12_V1.2.3.xsd', 'Schema_VFPR12_v1.2.3.xsd', 'Schema_VFSM10v_1.0.2.xsd') {
        Invoke-WebRequest -Uri "https://www.fatturapa.gov.it/export/documenti/fatturapa/v1.4/$file" -OutFile (Join-Path $fatturapa $file) -TimeoutSec 120 -UseBasicParsing
    }
    "deps/corpus/it/fatturapa: 3 schemas (FatturaPA/ordinaria 1.2.3, semplificata 1.0.2)"
}
$ksef = Join-Path $deps 'corpus/pl/ksef'
if (-not (Test-Path $ksef)) {
    $filling = $ksef
    New-Item -ItemType Directory -Force $ksef | Out-Null
    Invoke-WebRequest -Uri 'http://crd.gov.pl/wzor/2025/06/25/13775/schemat.xsd' -OutFile (Join-Path $ksef 'schemat_FA3.xsd') -TimeoutSec 120 -UseBasicParsing
    foreach ($file in 'StrukturyDanych_v10-0E.xsd', 'ElementarneTypyDanych_v10-0E.xsd', 'KodyKrajow_v10-0E.xsd') {
        Invoke-WebRequest -Uri "http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2022/01/05/eD/DefinicjeTypy/$file" -OutFile (Join-Path $ksef $file) -TimeoutSec 120 -UseBasicParsing
    }
    "deps/corpus/pl/ksef: 4 schemas (KSeF FA(3) and its CRD type definitions)"
}
$chile = Join-Path $deps 'corpus/cl/dte'
if (-not (Test-Path $chile)) {
    $filling = $chile
    New-Item -ItemType Directory -Force $chile | Out-Null
    $zip = Join-Path $chile 'schema_dte.zip'
    Invoke-WebRequest -Uri 'https://www.sii.cl/servicios_online/docs/xml/schema_dte.zip' -OutFile $zip -TimeoutSec 120 -UseBasicParsing
    Expand-Archive -LiteralPath $zip -DestinationPath $chile -Force
    Remove-Item -LiteralPath $zip
    "deps/corpus/cl/dte: $(@(Get-ChildItem $chile -Recurse -Filter *.xsd).Count) schemas (SII DTE v10)"
}
$facturae = Join-Path $deps 'corpus/es/facturae'
if (-not (Test-Path $facturae)) {
    $filling = $facturae
    New-Item -ItemType Directory -Force $facturae | Out-Null
    Invoke-WebRequest -Uri 'https://www.facturae.gob.es/content/dam/facturae/formato/versiones/Facturaev3_2_2.xml' -OutFile (Join-Path $facturae 'Facturaev3_2_2.xsd') -TimeoutSec 120 -UseBasicParsing
    "deps/corpus/es/facturae: Facturae 3.2.2"
}
$saft = Join-Path $deps 'corpus/pt/saft'
if (-not (Test-Path $saft)) {
    $filling = $saft
    New-Item -ItemType Directory -Force $saft | Out-Null
    $bytes = (Invoke-WebRequest -Uri 'https://info.portaldasfinancas.gov.pt/apps/saft-pt04/saftpt1.04_01.xsd' -TimeoutSec 120 -UseBasicParsing).RawContentStream.ToArray()
    $text = [Text.Encoding]::GetEncoding(1252).GetString($bytes) -replace 'encoding="(?i:windows-1252)"', 'encoding="utf-8"'
    [IO.File]::WriteAllText((Join-Path $saft 'saftpt1.04_01.xsd'), $text, [Text.UTF8Encoding]::new($false))
    "deps/corpus/pt/saft: SAF-T PT 1.04_01 (transcoded from Windows-1252)"
}
$saftSamples = Join-Path $saft 'samples'
if (-not (Test-Path $saftSamples)) {
    $filling = $saftSamples
    New-Item -ItemType Directory -Force $saftSamples | Out-Null
    $bytes = (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/joaomfrebelo/saft-pt_4_php/051074b646340eac897d240d83e7e28a2fd5cf80/tests/Resources/saft_idemo599999999.xml' -TimeoutSec 120 -UseBasicParsing).RawContentStream.ToArray()
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
    if ($hash -ne 'D05D18AE86239CA9D910F6C746FDBF6C2B9E5849BD1D994422D505931A9DC169') { throw "init.ps1 / SAF-T sample changed (sha256 $hash)" }
    $text = [Text.Encoding]::GetEncoding(1252).GetString($bytes) -replace 'encoding="(?i:windows-1252)"', 'encoding="utf-8"'
    [IO.File]::WriteAllText((Join-Path $saftSamples 'saft_idemo599999999.xml'), $text, [Text.UTF8Encoding]::new($false))
    "deps/corpus/pt/saft/samples: 1 SAF-T PT 1.04_01 AuditFile (AT demo NIF 599999993, 24 invoices; MIT test fixture of joaomfrebelo/saft-pt_4_php, no AT-published sample exists), transcoded from Windows-1252"
}
$mydata = Join-Path $deps 'corpus/gr/mydata'
if (-not (Test-Path $mydata)) {
    $filling = $mydata
    New-Item -ItemType Directory -Force $mydata | Out-Null
    $mirror = 'https://raw.githubusercontent.com/firebed/aade-mydata/1244dd9296606f63f1390d88c2faeaf8049b5d09/xsd/'
    foreach ($file in 'InvoicesDoc', 'SimpleTypes', 'TransportTypes', 'incomeClassification', 'expensesClassification') {
        Invoke-WebRequest -Uri "$mirror$file-v2.0.2.xsd" -OutFile (Join-Path $mydata "$file-v2.0.2.xsd") -TimeoutSec 120 -UseBasicParsing
    }
    "deps/corpus/gr/mydata: myDATA v2.0.2 (aade.gr refuses scripts; firebed/aade-mydata mirror at 1244dd92)"
}
$hacienda = Join-Path $deps 'corpus/cr/hacienda/v4.4'
if (-not (Test-Path $hacienda)) {
    $filling = $hacienda
    New-Item -ItemType Directory -Force $hacienda | Out-Null
    $mirror = 'https://raw.githubusercontent.com/BoltbitCR/API_Hacienda_Laravel/1a8c1cea22401b57541398da9a3e833016941ea1/resources/xsd/'
    foreach ($file in 'FacturaElectronica', 'NotaCreditoElectronica', 'NotaDebitoElectronica', 'TiqueteElectronico', 'FacturaElectronicaCompra', 'FacturaElectronicaExportacion', 'ReciboElectronicoPago', 'MensajeReceptor', 'MensajeHacienda') {
        Invoke-WebRequest -Uri "${mirror}v4.4/${file}_V4.4.xsd" -OutFile (Join-Path $hacienda "${file}_V4.4.xsd") -TimeoutSec 120 -UseBasicParsing
    }
    "deps/corpus/cr/hacienda: comprobantes v4.4 (hacienda.go.cr refuses scripts; BoltbitCR mirror at 1a8c1cea, the 2026-04 revision)"
}
$nav = Join-Path $deps 'corpus/hu/nav'
if (-not (Test-Path $nav)) {
    $filling = $nav
    New-Item -ItemType Directory -Force $nav | Out-Null
    $osa = 'https://raw.githubusercontent.com/nav-gov-hu/Online-Invoice/cc7a775d6dce361311e409abb9934eb755f2749c/src/schemas/nav/gov/hu/OSA/'
    foreach ($file in 'invoiceData', 'invoiceApi', 'invoiceBase', 'invoiceAnnulment', 'serviceMetrics') {
        Invoke-WebRequest -Uri "$osa$file.xsd" -OutFile (Join-Path $nav "$file.xsd") -TimeoutSec 120 -UseBasicParsing
    }
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/nav-gov-hu/Common/1f37f991fd9fb606b29aac9d8e367d52616e3d69/src/schemas/nav/gov/hu/NTCA/common.xsd' -OutFile (Join-Path $nav 'common.xsd') -TimeoutSec 120 -UseBasicParsing
    "deps/corpus/hu/nav: Online Szamla 3.0 at cc7a775d + NTCA common at Common-1.0.RC3 (imports carry no schemaLocation)"
}
function ConvertTo-Caseless([string] $pattern) {
    if (-not $pattern.StartsWith('(?i)')) { return $null }
    $body = $pattern.Substring(4)
    if ($body -match '[\[\\]') { throw "init.ps1 / a case-insensitive pattern with classes or escapes: $pattern" }
    -join ($body.ToCharArray() | ForEach-Object { if ([char]::IsLetter($_)) { '[' + [char]::ToLowerInvariant($_) + [char]::ToUpperInvariant($_) + ']' } else { $_ } })
}function ConvertTo-NonZeroRuns([string] $pattern) {
    $m = [regex]::Match($pattern, '^\^\(\?!0\+\$\)\((.*)\)\$$')
    if (-not $m.Success) { return $null }
    $alternatives = foreach ($token in $m.Groups[1].Value.Split('|')) {
        $range = [regex]::Match($token, '^\[0-9\]\{(\d+)(?:,(\d+))?\}$')
        if (-not $range.Success) { throw "unsupported run '$token' in $pattern" }
        $low = [int]$range.Groups[1].Value
        $high = if ($range.Groups[2].Success) { [int]$range.Groups[2].Value } else { $low }
        foreach ($n in $low..$high) {
            foreach ($k in 0..($n - 1)) {
                $tail = $n - $k - 1
                $suffix = if ($tail -gt 0) { '[0-9]{' + $tail + '}' } else { '' }
                ('0' * $k) + '[1-9]' + $suffix
            }
        }
    }
    '^(' + (($alternatives | Select-Object -Unique) -join '|') + ')$'
}
function ConvertTo-TrimmedKeys($node) {
    if ($node -is [System.Collections.IDictionary]) {
        $out = [ordered]@{}
        foreach ($key in $node.Keys) {
            $name = $key.Trim()
            $value = $node[$key]
            $out[$name] = if ($name -eq 'type' -and $value -is [string]) { $value.Trim().ToLowerInvariant() }
            elseif ($name -eq 'pattern' -and $value -is [string] -and $value.Contains('(?')) {
                $plain = ConvertTo-Caseless $value
                if (-not $plain) { $plain = ConvertTo-NonZeroRuns $value }
                if (-not $plain) { throw "init.ps1 / a lookaround pattern that is not the not-all-zeros idiom: $value" }
                $plain
            }
            else { ConvertTo-TrimmedKeys $value }
        }
        return $out
    }
    if ($node -is [System.Collections.IList]) { return , @($node | ForEach-Object { ConvertTo-TrimmedKeys $_ }) }
    $node
}
function Get-RequiredOwner($node, [string[]] $names) {
    if ($node -isnot [System.Collections.IDictionary]) { return $null }
    $target = if ($node.Contains('items') -and $node['items'] -is [System.Collections.IDictionary]) { $node['items'] } else { $node }
    if ($target.Contains('properties') -and @($names | Where-Object { -not $target['properties'].Contains($_) }).Count -eq 0) { $target } else { $null }
}
function ConvertTo-StandardProperties($schema) {
    if ($schema -isnot [System.Collections.IDictionary]) { return $schema }
    if ($schema.Contains('required') -and $schema['required'] -is [System.Collections.IList]) {
        $schema['required'] = @($schema['required'] | ForEach-Object { if ($_ -is [string]) { $_.Trim() } else { $_ } })
    }
    if ($schema.Contains('properties')) {
        $properties = [ordered]@{}
        $strayLists = [System.Collections.Generic.List[string[]]]::new()
        foreach ($key in $schema['properties'].Keys) {
            $value = $schema['properties'][$key]
            if ($key -eq 'required' -and $value -is [System.Collections.IList] -and @($value | Where-Object { $_ -isnot [string] }).Count -eq 0) {
                $strayLists.Add([string[]] @($value | ForEach-Object { "$_".Trim() }))
                continue
            }
            if ($value -is [System.Collections.IList] -and $value.Count -eq 1 -and $value[0] -is [System.Collections.IDictionary]) { $value = [ordered]@{ type = 'array'; items = $value[0] } }
            $properties[$key] = ConvertTo-StandardProperties $value
        }
        $schema['properties'] = $properties
        foreach ($names in $strayLists) {
            $owner = $null
            foreach ($key in $properties.Keys) { $owner = Get-RequiredOwner $properties[$key] $names; if ($owner) { break } }
            if (-not $owner -and @($names | Where-Object { -not $properties.Contains($_) }).Count -eq 0) { $owner = $schema }
            if ($owner) { $owner['required'] = @(@($owner['required']) + @($names) | Where-Object { $_ } | Select-Object -Unique) }
            else { Write-Warning "init.ps1 / a stray required list [$($names -join ', ')] names no object's properties; dropped" }
        }
    }
    if ($schema.Contains('items')) { $schema['items'] = ConvertTo-StandardProperties $schema['items'] }
    $schema
}
$gst = Join-Path $deps 'corpus/in/gst'
$gstPublished = Join-Path $gst 'inv01_published.json'
if (-not (Test-Path $gstPublished)) {
    $filling = $gst
    $page = (Invoke-WebRequest -Uri 'https://web.archive.org/web/20241005055248/https://einv-apisandbox.nic.in/version1.03/generate-irn.html' -TimeoutSec 120 -UseBasicParsing).Content
    $block = $page.IndexOf('id="example6"')
    $start = $page.IndexOf('>', $page.IndexOf('<pre', $block)) + 1
    $fetched = [System.Net.WebUtility]::HtmlDecode($page.Substring($start, $page.IndexOf('</pre>', $start) - $start)) -replace '<[^>]+>', ''
    New-Item -ItemType Directory -Force $gst | Out-Null
    [IO.File]::WriteAllText($gstPublished, $fetched, [Text.UTF8Encoding]::new($false))
    "deps/corpus/in/gst: INV-01 1.1 published schema (NIC sandbox page via the Wayback snapshot of 2024-10-05)"
}
$raw = [IO.File]::ReadAllText($gstPublished)
$fingerprint = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($raw))).Replace('-', '')
if (-not $fingerprint.StartsWith('2F53D00F2F754722')) { throw "init.ps1 / the GST INV-01 published schema is not the pinned one (sha256 $fingerprint)" }
$published = ConvertTo-TrimmedKeys ($raw | ConvertFrom-Json -AsHashtable)
$sections = [ordered]@{}
foreach ($key in $published.Keys) { if ($key -notin '$schema', 'Title', 'Description', 'required') { $sections[$key] = $published[$key] } }
$standard = ConvertTo-StandardProperties ([ordered]@{ '$schema' = $published['$schema']; title = $published['Title'].Trim(); description = $published['Description']; type = 'object'; required = $published['required']; properties = $sections })
[IO.File]::WriteAllText((Join-Path $gst 'inv01_1.1.json'), ($standard | ConvertTo-Json -Depth 64), [Text.UTF8Encoding]::new($false))
$filling = $null
function Remove-JsonNulls($node) {
    if ($node -is [System.Collections.IDictionary]) {
        $kept = [ordered]@{}
        foreach ($key in $node.Keys) { if ($null -ne $node[$key]) { $kept[$key] = Remove-JsonNulls $node[$key] } }
        return $kept
    }
    if ($node -is [System.Collections.IList] -and $node -isnot [string]) { return , @($node | Where-Object { $null -ne $_ } | ForEach-Object { Remove-JsonNulls $_ }) }
    $node
}
$gstExamples = Join-Path $gst 'examples'
if (-not (Test-Path $gstExamples)) {
    $filling = $gstExamples
    $page = (Invoke-WebRequest -Uri 'https://web.archive.org/web/20241005055248/https://einv-apisandbox.nic.in/version1.03/generate-irn.html' -TimeoutSec 120 -UseBasicParsing).Content
    $block = $page.IndexOf('id="example1"')
    $start = $page.IndexOf('>', $page.IndexOf('<pre', $block)) + 1
    $payload = [System.Net.WebUtility]::HtmlDecode($page.Substring($start, $page.IndexOf('</pre>', $start) - $start)) -replace '<[^>]+>', ''
    $payloadFingerprint = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($payload))).Replace('-', '')
    if (-not $payloadFingerprint.StartsWith('AB5BC97C9138D4C1')) { throw "init.ps1 / the GST sample request on the pinned page changed (sha256 $payloadFingerprint)" }
    New-Item -ItemType Directory -Force $gstExamples | Out-Null
    $request = Remove-JsonNulls ($payload | ConvertFrom-Json -AsHashtable)
    [IO.File]::WriteAllText((Join-Path $gstExamples 'irn-request-example.json'), ($request | ConvertTo-Json -Depth 64), [Text.UTF8Encoding]::new($false))
    $filling = $null
    "deps/corpus/in/gst/examples: the NIC sandbox's sample IRN request (null members dropped, as the IRP reads them)"
}
function Save-Pinned([string] $uri, [string] $path, [string] $sha256) {
    $bytes = $null
    for ($attempt = 1; -not $bytes; $attempt++) {
        try { $bytes = (Invoke-WebRequest -Uri $uri -TimeoutSec 600 -UseBasicParsing).RawContentStream.ToArray() }
        catch { if ($attempt -ge 3) { throw } }
    }
    $fingerprint = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($bytes)).Replace('-', '')
    if (-not $fingerprint.StartsWith($sha256)) { throw "init.ps1 / $uri changed (sha256 $fingerprint, pinned $sha256)" }
    [IO.File]::WriteAllBytes($path, $bytes)
}
function Remove-EmptySigningSlot([string] $path) {
    $document = [System.Xml.XmlDocument]::new()
    $document.PreserveWhitespace = $true
    $document.Load($path)
    $extensions = @($document.SelectNodes("/*/*[local-name()='UBLExtensions']"))
    if (-not $extensions.Count) { return $false }
    foreach ($block in $extensions) {
        $filled = @($block.SelectNodes(".//*[local-name()='ExtensionContent']") | Where-Object { @($_.ChildNodes | Where-Object { $_ -is [System.Xml.XmlElement] -or $_.Value.Trim() }).Count })
        if ($filled.Count) { throw "init.ps1 / $path carries extension content; only empty signing slots are dropped" }
        [void]$block.ParentNode.RemoveChild($block)
    }
    $settings = [System.Xml.XmlWriterSettings]::new()
    $settings.Encoding = [Text.UTF8Encoding]::new($false)
    $writer = [System.Xml.XmlWriter]::Create($path, $settings)
    try { $document.Save($writer) } finally { $writer.Dispose() }
    $true
}
function Expand-Pinned([string] $uri, [string] $sha256, [string] $folder, [int] $nameCodePage = 0) {
    $zip = Join-Path $folder 'download.zip'
    Save-Pinned $uri $zip $sha256
    if ($nameCodePage) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        if ('System.Text.CodePagesEncodingProvider' -as [type]) { [Text.Encoding]::RegisterProvider([Text.CodePagesEncodingProvider]::Instance) }
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $folder, [Text.Encoding]::GetEncoding($nameCodePage))
    } else {
        Expand-Archive -LiteralPath $zip -DestinationPath $folder -Force
    }
    Remove-Item -LiteralPath $zip
}
$verifactu = Join-Path $deps 'corpus/es/verifactu'
if (-not (Test-Path $verifactu)) {
    $filling = $verifactu
    New-Item -ItemType Directory -Force $verifactu | Out-Null
    $aeat = 'https://www2.agenciatributaria.gob.es/static_files/common/internet/dep/aplicaciones/es/aeat/tike/cont/ws/'
    Save-Pinned "${aeat}SuministroLR.xsd" (Join-Path $verifactu 'SuministroLR.xsd') 'CBDAC8D427CC5AB5'
    Save-Pinned "${aeat}SuministroInformacion.xsd" (Join-Path $verifactu 'SuministroInformacion.xsd') 'EE4C1655175644DE'
    "deps/corpus/es/verifactu: AEAT VeriFactu SuministroLR + SuministroInformacion"
}
$ciiCorpus = Join-Path $deps 'corpus/eu/en16931-cii'
if (-not (Test-Path $ciiCorpus)) {
    $filling = $ciiCorpus
    New-Item -ItemType Directory -Force $ciiCorpus | Out-Null
    $en16931 = 'https://raw.githubusercontent.com/ConnectingEurope/eInvoicing-EN16931/6e35e0ab8b09eb183f7d84b282e24ef95f9f5715/'
    $ciiPins = [ordered]@{
        'cii/examples/CII-BR-CO-10-RoundingIssue.xml' = '04711E7A649E3F28'
        'cii/examples/CII_business_example_01.xml' = '2CE8286333F4C201'
        'cii/examples/CII_business_example_02.xml' = '53A636AC10592AA6'
        'cii/examples/CII_business_example_Z.xml' = '68222346E14DFFF6'
        'cii/examples/CII_example1.xml' = '0C12E3CA9AAB5829'
        'cii/examples/CII_example2.xml' = '2CE8286333F4C201'
        'cii/examples/CII_example3.xml' = '5C2E9DE624DC72FC'
        'cii/examples/CII_example4.xml' = 'DEB7101F27855D21'
        'cii/examples/CII_example5.xml' = '473B2F9BD47B8078'
        'cii/examples/CII_example6.xml' = '23EF86C42478EDD7'
        'cii/examples/CII_example7.xml' = '0F3CCC7DD0F96E87'
        'cii/examples/CII_example8.xml' = '28AF1D24E201BE9C'
        'cii/examples/CII_example9.xml' = 'E43F32E9307D7977'
        'cii/examples/XRechnung-O.xml' = '399ACF31A9C7CE47'
        'cii/examples/huf_example_cii.xml' = 'FAD73604FC1FF6AC'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/EDIFICAS-EU_AccountingAccountType_D11A.xsd' = 'B361D255F47705F6'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/EDIFICAS-EU_AccountingAmountType_D11A.xsd' = '92D067BA81B98697'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/ISO_ISO3AlphaCurrencyCode_2012-08-31.xsd' = 'AA9CBC3E4BA0DEF7'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_ActionCode_D16A.xsd' = '5CD5ABCBA783A09D'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_AdjustmentReasonDescriptionCode_D16A.xsd' = '166049478C09D64C'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_AllowanceChargeIdentificationCode_D16A.xsd' = '636FE3EDAFD159D5'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_AllowanceChargeReasonCode_D16A.xsd' = 'C2C444EB7ECD086F'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_AutomaticDataCaptureMethodCode_D16A.xsd' = 'B1DC8D783F4FDA8B'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_CargoOperationalCategoryCode_D16A.xsd' = 'CAB6E7D436617500'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_CargoTypeCode_1996Rev2Final.xsd' = 'AAA666B36E590FA1'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_CommodityIdentificationCode_D16A.xsd' = '482155316EEFBBF1'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_CommunicationMeansTypeCode_D16A.xsd' = 'EB44F72BD9BA8772'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_ContactFunctionCode_D16A.xsd' = 'D384D467BC164281'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_DeliveryTermsCode_2010.xsd' = '408859328850274E'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_DimensionTypeCode_D16A.xsd' = '076690B1F51A15BB'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_DocumentNameCode_Accounting_D16A.xsd' = '6C6BD43FEE17DD35'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_DocumentNameCode_D16A.xsd' = '213ED454CCDD6386'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_DocumentStatusCode_D16A.xsd' = 'F253EEABC2120310'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_DutyTaxFeeTypeCode_D16A.xsd' = 'B2BD6B78FAA666B0'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_DutyorTaxorFeeCategoryCode_D16A.xsd' = '9C067673378BB8B5'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_EquipmentSizeTypeDescriptionCode_D16A.xsd' = '7936B66984DF6922'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_EventTimeReferenceCodePaymentTermsEvent_D16A.xsd' = '739BFDA0EF837695'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_EventTimeReferenceCode_D16A.xsd' = '2BD1AAFB7FF7DD00'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_FreightChargeQuantityUnitBasisCode_D16A.xsd' = 'BC73D4F16067D57C'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_FreightChargeTariffCode_D16A.xsd' = 'AEF84F453A450528'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_GoodsTypeCode_D16A.xsd' = '1FAA4D576617FB8C'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_GoodsTypeExtensionCode_D16A.xsd' = '1B464672338AE2A7'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_MeasurementUnitCommonCodeLinear_4.xsd' = 'D4E48AB51445AE02'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_MeasurementUnitCommonCodeVolume_4.xsd' = '96B42244D774BBBD'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_MeasurementUnitCommonCodeWeight_4.xsd' = 'A1E85E992E9D071B'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_MessageFunctionCode_D16A.xsd' = '884E2DE87556D44E'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_PackageTypeCode_2006.xsd' = '24B52C6DAA4E25C8'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_PackagingMarkingCode_D16A.xsd' = '23264A849C7D1C10'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_PartyRoleCode_ChargePaying_D16A.xsd' = '9B0FDC65DC42B632'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_PartyRoleCode_D16A.xsd' = '6964994CBDDCF4BD'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_PaymentGuaranteeMeansCode_D16A.xsd' = '410D9664834C4386'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_PaymentMeansChannelCode_D16A.xsd' = '32096394AA869A68'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_PaymentMeansCode_D16A.xsd' = '6C3B02F1B0900F40'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_PaymentTermsTypeCode_D16A.xsd' = 'F53F9B980EAA3ADF'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_PriceTypeCode_D16A.xsd' = '9753C0E3350B2140'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_ReferenceTypeCode_D16A.xsd' = 'D23F6D424F0B050E'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_TimePointFormatCode_D16A.xsd' = '43E8C9BF574BFFE7'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_TransportEquipmentCategoryCode_D16A.xsd' = 'B05E90441F1FB520'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_TransportEquipmentFullnessCode_D16A.xsd' = '7CEAF04B36E28594'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_TransportMeansTypeCode_2007.xsd' = '74840FC911E38EFC'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_TransportModeCode_2.xsd' = '73784D1E62B6CAC2'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/codelist/standard/UNECE_TransportMovementStageCode_D16A.xsd' = '745E2E548ADE9C3A'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/data/standard/CrossIndustryInvoice_100pD16B.xsd' = 'B9798AAFCBA039D0'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/data/standard/CrossIndustryInvoice_QualifiedDataType_100pD16B.xsd' = 'A39E0662C31FBDCA'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/data/standard/CrossIndustryInvoice_ReusableAggregateBusinessInformationEntity_100pD16B.xsd' = 'CC682D67791FFE16'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/data/standard/CrossIndustryInvoice_UnqualifiedDataType_100pD16B.xsd' = '5D4CE8A6445CAA4B'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/identifierlist/standard/ISO_ISOTwo-letterCountryCode_SecondEdition2006.xsd' = '9260E5B7ABD9A419'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/identifierlist/standard/UNECE_FreightCostCode_4.xsd' = '30778D3ED87F425C'
        'cii/schema/D16B SCRDM (Subset)/uncoupled clm/CII/uncefact/identifierlist/standard/UNECE_PaymentTermsDescriptionIdentifier_D16A.xsd' = '8C5500644C0ECE33'
    }
    foreach ($file in $ciiPins.Keys) {
        $target = Join-Path $ciiCorpus $file
        New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
        Save-Pinned ($en16931 + (($file -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')) $target $ciiPins[$file]
    }
    "deps/corpus/eu/en16931-cii: CEN EN 16931 validation artefacts 1.3.17 (EUPL 1.2): UN/CEFACT CII D16B (uncoupled code lists) + 15 CII examples"
}
$facturaeSamples = Join-Path $deps 'corpus/es/facturae/samples'
if (-not (Test-Path $facturaeSamples)) {
    $filling = $facturaeSamples
    New-Item -ItemType Directory -Force $facturaeSamples | Out-Null
    $gobl = 'https://raw.githubusercontent.com/invopop/gobl.facturae/b702b599515357b1b682756bc2f0cff9701ade90/test/data/convert/out/'
    $pins = [ordered]@{
        'corrective.xml' = '2A1260BE34C04B2A'; 'credit-note.xml' = '74147B72B1C725EA'; 'invoice-complete.xml' = 'CF175071A21F9ABB'
        'invoice-face.xml' = '47BE48317E98228E'; 'invoice-overseas-individual.xml' = '98C425809B1050FD'
        'invoice-usd.xml' = 'BFAD2E5E1D1BA3F7'; 'invoice-vat-irpf-inc.xml' = '34189F69F6011C11'
        'invoice-vat-irpf.xml' = 'EBB32E8046A92595'; 'invoice-vat-provider.xml' = '8DB07EF2051B3EF1'; 'invoice-vat.xml' = 'AFA5D0B988F1A0B3'
    }
    foreach ($name in $pins.Keys) { Save-Pinned "$gobl$name" (Join-Path $facturaeSamples $name) $pins[$name] }
    "deps/corpus/es/facturae/samples: 10 signed Facturae 3.2.2 documents (invopop/gobl.facturae test data, Apache-2.0); facturae.gob.es publishes no example"
}
$chileExamples = Join-Path $deps 'corpus/cl/examples'
if (-not (Test-Path $chileExamples)) {
    $filling = $chileExamples
    New-Item -ItemType Directory -Force $chileExamples | Out-Null
    Expand-Pinned 'https://www.sii.cl/servicios_online/docs/xml/ejemplo_xml.zip' '30080A3551B0C579' $chileExamples
    "deps/corpus/cl/examples: SII's EnvioDTE example (a type 33 factura)"
}
$roCius = Join-Path $deps 'corpus/ro/cius'
if (-not (Test-Path $roCius)) {
    $filling = $roCius
    New-Item -ItemType Directory -Force (Join-Path $roCius 'examples') | Out-Null
    Expand-Pinned 'https://mfinante.gov.ro/static/10/eFactura/ro16931-ubl-1.0.9.zip' '818E7DD77E429F5D' $roCius
    Expand-Pinned 'https://mfinante.gov.ro/static/10/eFactura/exemple_Invoice_CreditNote.zip' '3C1DDCFC8BE8CA3E' (Join-Path $roCius 'examples')
    "deps/corpus/ro/cius: RO_CIUS 1.0.9 schematron + ANAF examples"
}
$ublTr = Join-Path $deps 'corpus/tr/ubltr'
$gibNameCodePage = 857
if ((Test-Path $ublTr) -and @(Get-ChildItem -LiteralPath $ublTr -Recurse | Where-Object { $_.Name -match '�' }).Count) {
    Remove-Item -LiteralPath $ublTr -Recurse -Force
    "deps/corpus/tr/ubltr: file names were extracted without code page $gibNameCodePage; fetching again"
}
if (-not (Test-Path $ublTr)) {
    $filling = $ublTr
    New-Item -ItemType Directory -Force (Join-Path $ublTr 'efatura') | Out-Null
    Expand-Pinned 'https://ebelge.gib.gov.tr/dosyalar/kilavuzlar/UBL-TR1.2.1_Paketi.zip' 'CB583941B8A8A239' $ublTr $gibNameCodePage
    Expand-Pinned 'https://ebelge.gib.gov.tr/dosyalar/kilavuzlar/e-FaturaPaketi%20(29).zip' '12901476CD424FD6' (Join-Path $ublTr 'efatura') $gibNameCodePage
    "deps/corpus/tr/ubltr: UBL-TR 1.2.1 (xsdrt, examples) + e-Fatura package (29) with its schematron"
}
foreach ($unsignedSample in 'HKS-Ornek1.xml', 'HKS-Ornek2.xml') {
    $samplePath = Join-Path $ublTr "UBLTR_1.2.1_Paketi/xml/$unsignedSample"
    if ((Test-Path -LiteralPath $samplePath) -and (Remove-EmptySigningSlot $samplePath)) { "deps/corpus/tr/ubltr: $unsignedSample is unsigned; its empty signing slot (UBLExtensions) is dropped" }
}
$dian = Join-Path $deps 'corpus/co/dian'
if (-not (Test-Path $dian)) {
    $filling = $dian
    New-Item -ItemType Directory -Force $dian | Out-Null
    Expand-Pinned 'https://www.dian.gov.co/impuestos/factura-electronica/Documents/Caja-de-herramientas-FE_V19_v2026.zip' '036EAC8CA529EE7D' $dian
    "deps/corpus/co/dian: Caja de herramientas FE V19 (v2026): UBL 2.1 structures, XSL rules, examples"
}
$cnEinv = Join-Path $deps 'corpus/cn/einv'
if (-not (Test-Path $cnEinv)) {
    $filling = $cnEinv
    New-Item -ItemType Directory -Force $cnEinv | Out-Null
    Expand-Pinned 'http://kjs.mof.gov.cn/zt/kuaijixinxihuajianshe/dzpzkjsjbzshsd/sjbz/202505/P020250617561583232009.zip' 'EB75E173C1315742' $cnEinv
    "deps/corpus/cn/einv: MOF e-voucher accounting data standard, fully digitalized e-invoice (XBRL taxonomy einv-20231231, element list, 2 instances)"
}
$myInvois = Join-Path $deps 'corpus/my/myinvois'
if (-not (Test-Path $myInvois)) {
    $filling = $myInvois
    New-Item -ItemType Directory -Force $myInvois | Out-Null
    Save-Pinned 'https://sdk.myinvois.hasil.gov.my/files/sdksamples/1.1-Invoice-Sample.xml' (Join-Path $myInvois '1.1-Invoice-Sample.xml') 'CA703B482E5DAF80'
    Save-Pinned 'https://sdk.myinvois.hasil.gov.my/files/sdksamples/1.1-Invoice-Sample.json' (Join-Path $myInvois '1.1-Invoice-Sample.json') '60CC77C5A4EFCD48'
    "deps/corpus/my/myinvois: LHDN 1.1 invoice samples (stock UBL 2.1 XML and UBL-2.1-JSON)"
}
$myInvoisSamples = Join-Path $deps 'corpus/my/samples'
if (-not (Test-Path $myInvoisSamples)) {
    $filling = $myInvoisSamples
    New-Item -ItemType Directory -Force $myInvoisSamples | Out-Null
    $samples = [ordered]@{
        '1.0-Invoice-Sample.xml' = '2EF20EBFE8A20F8D'
        '1.0-Invoice-Sample.json' = 'B2188342D5E95559'
        '1.0-Invoice-ForeignCurrency-Sample.xml' = '1E2A7801123D2735'
        '1.0-Invoice-ForeignCurrency-Sample.json' = 'F80237E39EA96E79'
        '1.0-Invoice-MultiLineItem-Sample.xml' = '80E2B461EB67757C'
        '1.0-Invoice-MultiLineItem-Sample.json' = '8AD588691FD07209'
        '1.0-Invoice-Consolidated-Sample.xml' = '3A012F5139B3110B'
        '1.0-Invoice-Consolidated-Sample.json' = '811536B5139DCA60'
        '1.1-Invoice-ForeignCurrency-Sample.xml' = '4089CFFFDDE41C43'
        '1.1-Invoice-ForeignCurrency-Sample.json' = '8159CE7732AA919C'
        '1.1-Invoice-MultiLineItem-Sample.xml' = 'DEE204D33B2F71BB'
        '1.1-Invoice-MultiLineItem-Sample.json' = 'CC2A3F8DC74146D6'
        '1.1-Invoice-Consolidated-Sample.xml' = '1804CD2695E8D1EF'
        '1.1-Invoice-Consolidated-Sample.json' = '23BB6304AD926575'
        '1.0-Credit-Note-Sample.xml' = '1C856944A50A2AE4'
        '1.0-Credit-Note-Sample.json' = '41B5EA66A3E0671C'
        '1.1-Credit-Note-Sample.xml' = '3E8B4E18156035FA'
        '1.1-Credit-Note-Sample.json' = 'DF47E44DC8A60E3E'
        '1.0-Debit-Note-Sample.xml' = '268C9E262269D73E'
        '1.0-Debit-Note-Sample.json' = '3A833F9A5FF60B09'
        '1.1-Debit-Note-Sample.xml' = 'A1F3669F6C18E399'
        '1.1-Debit-Note-Sample.json' = '356F863681F00A23'
        '1.0-Refund-Note-Sample.xml' = '27A5FD482904C18E'
        '1.0-Refund-Note-Sample.json' = 'BBFC29CB8B46A7B7'
        '1.1-Refund-Note-Sample.xml' = 'F4C9CA5DA5C784AA'
        '1.1-Refund-Note-Sample.json' = 'DA6C268504D0EE23'
        '1.0-Self-Billed-Invoice-Sample.xml' = '9E12156798FE406F'
        '1.0-Self-Billed-Invoice-Sample.json' = 'C82DED42EC98EA26'
        '1.1-Self-Billed-Invoice-Sample.xml' = '97758351AC3CAE7C'
        '1.1-Self-Billed-Invoice-Sample.json' = 'D54FD101DBD2D52C'
        '1.0-Self-Billed-Credit-Sample.xml' = '0075A64B3988BC77'
        '1.0-Self-Billed-Credit-Sample.json' = '67F812CF728C1487'
        '1.1-Self-Billed-Credit-Sample.xml' = '3A9B53849AA40AE9'
        '1.1-Self-Billed-Credit-Sample.json' = '8D1C7D5A32CFAC6F'
        '1.0-Self-Billed-Debit-Sample.xml' = 'B4504812BB715661'
        '1.0-Self-Billed-Debit-Sample.json' = 'EA892894400061CD'
        '1.1-Self-Billed-Debit-Sample.xml' = '4936B23173B28A7E'
        '1.1-Self-Billed-Debit-Sample.json' = '1569898927821A62'
        '1.0-Self-Billed-Refund-Sample.xml' = '0A7D8120861A8390'
        '1.0-Self-Billed-Refund-Sample.json' = '8C4FCA02FBD6C5EC'
        '1.1-Self-Billed-Refund-Sample.xml' = '90C32E6910B3DBC2'
        '1.1-Self-Billed-Refund-Sample.json' = '356F01998C5EE343'
    }
    foreach ($name in $samples.Keys) {
        Save-Pinned "https://sdk.myinvois.hasil.gov.my/files/sdksamples/$name" (Join-Path $myInvoisSamples $name) $samples[$name]
    }
    "deps/corpus/my/samples: $($samples.Count) LHDN SDK samples (1.0 and 1.1; invoice, credit, debit, refund, self-billed; XML and UBL-JSON)"
}
$zatca = Join-Path $deps 'corpus/sa/zatca'
if (-not (Test-Path $zatca)) {
    $filling = $zatca
    $sdkData = 'https://raw.githubusercontent.com/amnahid/zatca-sdk/2dd12e962d12624c7322314c057653f61f628d63/Data'
    $files = [ordered]@{
        'Rules/Schematrons/20210819_ZATCA_E-invoice_Validation_Rules.xsl' = '3312E1938829B897'
        'Rules/Schematrons/CEN-EN16931-UBL.xsl' = '378A7A4D697AA96E'
        'Samples/Simplified/Credit/Simplified_Credit_Note.xml' = 'A3D9E4DB1482E88A'
        'Samples/Simplified/Debit/Simplified_Debit_Note.xml' = '0F59160E357847A2'
        'Samples/Simplified/Invoice/Nominal supply invoice.xml' = '99B6E444475F9C85'
        'Samples/Simplified/Invoice/Simplified Tax Invoice with Zero Rated Item.xml' = '7E72BD17FBD19D8D'
        'Samples/Simplified/Invoice/Simplified_Invoice.xml' = '4BAED3C7D76BB71D'
        'Samples/Standard/Credit/Standard_Credit_Note.xml' = 'DE36C1554368423D'
        'Samples/Standard/Debit/Standard_Debit_Note.xml' = 'C0D7719D13E1F47E'
        'Samples/Standard/Invoice/Advance Payment adjustments with foreign currency invoice.xml' = '45CB49CE0F4CEA4B'
        'Samples/Standard/Invoice/Advance Payment adjustments with rate change scenarios.xml' = '2C7166A70F9816B4'
        'Samples/Standard/Invoice/Advance Payment adjustments.xml' = '337F9B49BEE5D771'
        'Samples/Standard/Invoice/Exempt Tax Invoice.xml' = 'D2C064C8C423AC91'
        'Samples/Standard/Invoice/Export invoice.xml' = '0B5985E74F4483C5'
        'Samples/Standard/Invoice/Out of Scope Standard Tax Invoice.xml' = '09C1E4E65D849E74'
        'Samples/Standard/Invoice/Self-billing invoice.xml' = 'F5DDB620EA0CA6DE'
        'Samples/Standard/Invoice/Standard Invoice with Document Level Charge.xml' = '2B6F77A23E7DE80B'
        'Samples/Standard/Invoice/Standard Invoice with Payable Rounding Adjustment.xml' = '00E9AB28A931858F'
        'Samples/Standard/Invoice/Standard_Invoice.xml' = 'D5991B80316AA0C4'
        'Samples/Standard/Invoice/Summary Invoice.xml' = '68D78ECA5A2962A9'
        'Samples/Standard/Invoice/Third party billing.xml' = '44FB7A7392E6DBC7'
    }
    foreach ($relative in $files.Keys) {
        $target = Join-Path $zatca $relative
        New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
        $escaped = ($relative.Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
        Save-Pinned "$sdkData/$escaped" $target $files[$relative]
    }
    "deps/corpus/sa/zatca: ZATCA e-invoicing SDK 238-R3.4.8 data: $($files.Count - 2) signed UBL 2.1 samples (standard and simplified) and its two rule XSLs (ZATCA, CEN EN16931)"
}
foreach ($compiledRules in @(Get-ChildItem -LiteralPath (Join-Path $zatca 'Rules/Schematrons') -Filter *.xsl -ErrorAction SilentlyContinue)) {
    $rebuilt = [IO.Path]::ChangeExtension($compiledRules.FullName, '.sch')
    if (Test-Path -LiteralPath $rebuilt) { continue }
    $filling = $rebuilt
    & (Join-Path $PSScriptRoot 'schxslt-to-schematron.ps1') -Compiled $compiledRules.FullName -Output $rebuilt
    $filling = $null
}
$sunat = Join-Path $deps 'corpus/pe/sunat-homologacion'
if (-not (Test-Path $sunat)) {
    $filling = $sunat
    $homologacion = 'https://raw.githubusercontent.com/project-openubl/xhandler-java/9b0af749cc92e0669ec36eb85f111cb73320fa72/xbuilder/core/src/test/resources/e2e/homologacion'
    $files = [ordered]@{
        'Group1Test/factura1Con3Items.xml' = 'B81843D09F5AE4B5'
        'Group1Test/factura2Con2Items.xml' = 'F4AE0FBBAC2F7E3B'
        'Group1Test/factura3Con1Items.xml' = '210F68D48C3A4763'
        'Group1Test/factura4Con5Items.xml' = 'C47CCBDA273E5FC5'
        'Group1Test/factura5Con4Items.xml' = '70941C53BED08F73'
        'Group1Test/notaDeCreditoDeFactura2.xml' = '1044BFFA27646FD2'
        'Group1Test/notaDeCreditoDeFactura3.xml' = '27421C44F67ABF9D'
        'Group1Test/notaDeCreditoDeFactura4.xml' = '69B5AC7BAD4E10E3'
        'Group1Test/notaDeDebitoDeFactura2.xml' = '9B85C0539EB3480D'
        'Group1Test/notaDeDebitoDeFactura3.xml' = 'B7C7F4A0C518B843'
        'Group1Test/notaDeDebitoDeFactura4.xml' = 'FFF5E3FD7D091434'
        'Group2ExoneradoTest/factura1Con1Items.xml' = '2206B76B3590ACE0'
        'Group2ExoneradoTest/factura2Con4Items.xml' = '9E10B1C97C594FED'
        'Group2ExoneradoTest/factura3Con7Items.xml' = '4F830E79822A1C23'
        'Group2ExoneradoTest/factura4Con5Items.xml' = '654A0E82DD561C80'
        'Group2ExoneradoTest/factura5Con6Items.xml' = '8310F5B205F1B4ED'
        'Group2ExoneradoTest/notaDeCreditoDeFactura1.xml' = '3B677F2808BAB562'
        'Group2ExoneradoTest/notaDeCreditoDeFactura3.xml' = '5F558415A145BCEA'
        'Group2ExoneradoTest/notaDeCreditoDeFactura5.xml' = '4CEF3A0641ED2500'
        'Group2ExoneradoTest/notaDeDebitoDeFactura1.xml' = '371485B46BC80D0C'
        'Group2ExoneradoTest/notaDeDebitoDeFactura3.xml' = 'C1164520469BA852'
        'Group2ExoneradoTest/notaDeDebitoDeFactura5.xml' = 'C980E60ED1176865'
        'Group2InafectoTest/factura1Con1Items.xml' = 'A743744A72088151'
        'Group2InafectoTest/factura2Con4Items.xml' = '9C4BBDD93CCCE2E1'
        'Group2InafectoTest/factura3Con7Items.xml' = '6330EBF1052C685C'
        'Group2InafectoTest/factura4Con5Items.xml' = 'FE08876670C8DDFE'
        'Group2InafectoTest/factura5Con6Items.xml' = 'D6F6ECE332F3254E'
        'Group2InafectoTest/notaDeCreditoDeFactura1.xml' = 'F21B3693A2FFF994'
        'Group2InafectoTest/notaDeCreditoDeFactura3.xml' = '74647CFD32728670'
        'Group2InafectoTest/notaDeCreditoDeFactura5.xml' = '6DF95F691492F04C'
        'Group2InafectoTest/notaDeDebitoDeFactura1.xml' = '2E681ED1443CF1E3'
        'Group2InafectoTest/notaDeDebitoDeFactura3.xml' = '9B8AADA98C4000BB'
        'Group2InafectoTest/notaDeDebitoDeFactura5.xml' = 'BAE38A8FCA385FDB'
        'Group3Test/factura1Con7Items.xml' = '22BC97F83DCE8973'
        'Group3Test/factura2Con2Items.xml' = '9A800BB1BB576852'
        'Group3Test/factura3Con5Items.xml' = 'ACED3912C39D0BF0'
        'Group3Test/factura4Con4Items.xml' = '373DD5E849DC1676'
        'Group3Test/factura5Con3Items.xml' = '0F97C0628BCF587C'
        'Group4Test/factura1Con2Items.xml' = 'DE9D897B383693FC'
        'Group4Test/factura2Con2Items.xml' = 'BFB33EA8FE039244'
        'Group4Test/factura3Con4Items.xml' = '47558249E7F4C771'
        'Group4Test/factura4Con3Items.xml' = '2D85A5E2F4F1DC2E'
        'Group4Test/factura5Con5Items.xml' = '3C088C02C634737A'
        'Group4Test/notaDeCreditoDeFactura2.xml' = '8AFE9E6649F0FBC1'
        'Group4Test/notaDeCreditoDeFactura3.xml' = 'C9BC212837043005'
        'Group4Test/notaDeCreditoDeFactura5.xml' = 'A8945D2BFAF5FD8C'
        'Group4Test/notaDeDebitoDeFactura2.xml' = '3149728D39AD4D33'
        'Group4Test/notaDeDebitoDeFactura3.xml' = '5479BC463841AB9C'
        'Group4Test/notaDeDebitoDeFactura5.xml' = 'EBB53A01D3C83590'
        'Group5Test/factura1Con5Items.xml' = 'D041D400096CD633'
        'Group5Test/notaDeCreditoDeFactura1.xml' = '31E121C79F004F7C'
        'Group5Test/notaDeDebitoDeFactura2.xml' = '419F08A8D0005078'
        'Group6Test/factura1Con5Items.xml' = '79DCD07833FDE85C'
        'Group6Test/notaDeCreditoDeFactura1.xml' = 'B6AA1D813EE5794B'
        'Group6Test/notaDeDebitoDeFactura1.xml' = '100153BBD591D7E0'
        'Group7Test/factura1Con5Items.xml' = 'DDCE066EBADCC614'
        'Group7Test/notaDeCreditoDeFactura1.xml' = '36036FF140B8E99A'
        'Group7Test/notaDeDebitoDeFactura2.xml' = 'F7AE6835CF4A0D7D'
    }
    foreach ($relative in $files.Keys) {
        $target = Join-Path $sunat $relative
        New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
        Save-Pinned "$homologacion/$relative" $target $files[$relative]
        [void](Remove-EmptySigningSlot $target)
    }
    $filling = $null
    "deps/corpus/pe/sunat-homologacion: $($files.Count) SUNAT homologation cases (UBL 2.1, customization 2.0, test RUC 12345678912) from project-openubl xbuilder, unsigned; their empty signing slot (UBLExtensions) is dropped"
}
$sunatRules = Join-Path $deps 'corpus/pe/sunat-validaciones'
if (-not (Test-Path $sunatRules)) {
    $filling = $sunatRules
    $cpe = 'https://cpe.sunat.gob.pe/sites/default/files/inline-files/'
    New-Item -ItemType Directory -Force (Join-Path $sunatRules 'xsl'), (Join-Path $sunatRules 'xsd') | Out-Null
    Expand-Pinned "${cpe}XSL%20Actualizado%20al%2006092022%20%281%29.zip" '03A8DEC89D8BEB00' (Join-Path $sunatRules 'xsl')
    Expand-Pinned "${cpe}Archivos%20XSD%20%281%29.zip" '5CAC9D9353521340' (Join-Path $sunatRules 'xsd')
    $filling = $null
    "deps/corpus/pe/sunat-validaciones: SUNAT CPE validation rules (UBL 2.1 XSL, ValidaExprReg*-2.0.1, updated 2022-09-06) and the published XSD set"
}
$facturX = Join-Path $deps 'corpus/eu/factur-x'
$facturXZip = if ($env:FISCAL_FACTURX_ZIP) { $env:FISCAL_FACTURX_ZIP } else { Join-Path $HOME 'Downloads/ZUGFeRD_2.5.2_EN.zip' }
if (-not (Test-Path $facturX)) {
    if (Test-Path -LiteralPath $facturXZip) {
        $fingerprint = (Get-FileHash -LiteralPath $facturXZip -Algorithm SHA256).Hash
        if (-not $fingerprint.StartsWith('03C335F0B898A66A')) { throw "init.ps1 / $facturXZip changed (sha256 $fingerprint, pinned 03C335F0B898A66A)" }
        $filling = $facturX
        New-Item -ItemType Directory -Force $facturX | Out-Null
        Expand-Archive -LiteralPath $facturXZip -DestinationPath $facturX -Force
        $filling = $null
        "deps/corpus/eu/factur-x: ZUGFeRD 2.5.2 / Factur-X 1.09.2 package (5 profile schemas with schematron, CII D22B XSD, examples per profile)"
    } else {
        "deps/corpus/eu/factur-x: skipped (the ZUGFeRD 2.5.2 package sits behind FeRD's email form; set FISCAL_FACTURX_ZIP or put ZUGFeRD_2.5.2_EN.zip in Downloads)"
    }
}
$iso4217 = Join-Path $deps 'corpus/iso4217'
if (-not (Test-Path $iso4217)) {
    $filling = $iso4217
    New-Item -ItemType Directory -Force $iso4217 | Out-Null
    $six = 'https://www.six-group.com/dam/download/financial-information/data-center/iso-currrency/lists/'
    Save-Pinned "${six}list-one.xml" (Join-Path $iso4217 'list-one.xml') '33139B438657D1CE'
    Save-Pinned "${six}list-three.xml" (Join-Path $iso4217 'list-three.xml') '98FDE2423CDB916D'
    $filling = $null
    "deps/corpus/iso4217: ISO 4217 list one (2026-09-17, minor units) and list three (2026-01-01, withdrawn currencies with dates)"
}
$nfeFixtures = Join-Path $deps 'corpus/br/sped-nfe-fixtures'
if (-not (Test-Path $nfeFixtures)) {
    $filling = $nfeFixtures
    New-Item -ItemType Directory -Force $nfeFixtures | Out-Null
    $spedNfe = 'https://raw.githubusercontent.com/nfephp-org/sped-nfe/ff80086aa16576345a519629efdd9a05fc49226a/tests/fixtures/xml/'
    Save-Pinned "${spedNfe}2017protocoled.xml" (Join-Path $nfeFixtures '2017protocoled.xml') 'EE06EE4FB9437667'
    Save-Pinned "${spedNfe}nfe_layout4_com_prot.xml" (Join-Path $nfeFixtures 'nfe_layout4_com_prot.xml') '7BB040F311E64641'
    $filling = $null
    "deps/corpus/br/sped-nfe-fixtures: two authorized NF-e (3.10 from 2017 and 4.00) from the sped-nfe test fixtures at commit ff80086a"
}
$sunatSfs = Join-Path $deps 'corpus/pe/sunat-sfs'
if (-not (Test-Path $sunatSfs)) {
    $filling = $sunatSfs
    New-Item -ItemType Directory -Force $sunatSfs | Out-Null
    Save-Pinned 'https://www2.sunat.gob.pe/facturador/SFS_v-2.5.zip' (Join-Path $sunatSfs 'SFS_v-2.5.zip') '6F59BF9AC8646CC3'
    $filling = $null
    "deps/corpus/pe/sunat-sfs: SUNAT's Facturador SFS 2.5 (its VALI rule copies and the Saxon-HE 9.7 inside facturadorApp-2.5.jar run SUNAT's own validations)"
}
$peppol = Join-Path $deps 'corpus/eu/peppol-bis3'
if (-not (Test-Path $peppol)) {
    $filling = $peppol
    $release = 'https://raw.githubusercontent.com/OpenPeppol/peppol-bis-invoice-3/v3.0.20/rules/'
    New-Item -ItemType Directory -Force (Join-Path $peppol 'sch'), (Join-Path $peppol 'examples') | Out-Null
    foreach ($file in 'PEPPOL-EN16931-UBL.sch', 'CEN-EN16931-UBL.sch') {
        Invoke-WebRequest -Uri "${release}sch/$file" -OutFile (Join-Path $peppol "sch/$file") -TimeoutSec 120 -UseBasicParsing
    }
    foreach ($file in 'base-example', 'base-creditnote-correction', 'base-negative-inv-correction', 'Allowance-example', 'Vat-category-S', 'vat-category-E', 'vat-category-O', 'vat-category-Z') {
        Invoke-WebRequest -Uri "${release}examples/$file.xml" -OutFile (Join-Path $peppol "examples/$file.xml") -TimeoutSec 120 -UseBasicParsing
    }
    "deps/corpus/eu/peppol-bis3: BIS Billing 3.0.20 rules (2 schematron) and 8 official examples"
}
$peppolStructure = Join-Path $deps 'corpus/eu/peppol-bis3/structure'
if (-not (Test-Path (Join-Path $peppolStructure 'part'))) {
    $filling = $peppolStructure
    New-Item -ItemType Directory -Force $peppolStructure | Out-Null
    $syntax = 'https://raw.githubusercontent.com/OpenPeppol/peppol-bis-invoice-3/v3.0.20/structure/syntax/'
    $pending = [Collections.Generic.Queue[string]]::new([string[]]@('ubl-invoice.xml', 'ubl-creditnote.xml'))
    $fetched = [Collections.Generic.HashSet[string]]::new()
    while ($pending.Count) {
        $file = $pending.Dequeue()
        if (-not $fetched.Add($file)) { continue }
        $to = Join-Path $peppolStructure $file
        New-Item -ItemType Directory -Force (Split-Path $to) | Out-Null
        Invoke-WebRequest -Uri "$syntax$file" -OutFile $to -TimeoutSec 120 -UseBasicParsing
        $folder = Split-Path $file
        foreach ($m in [regex]::Matches([IO.File]::ReadAllText($to), '<Include>([^<]+)</Include>')) {
            $pending.Enqueue(([IO.Path]::Combine($folder, $m.Groups[1].Value) -replace '\\', '/'))
        }
    }
    "deps/corpus/eu/peppol-bis3/structure: BIS Billing 3.0.20 syntax bindings with their $($fetched.Count - 2) included parts (UBL element -> EN 16931 BT/BG term, per document)"
}
$pint = Join-Path $deps 'corpus/eu/peppol-pint'
if (-not (Test-Path $pint)) {
    $filling = $pint
    New-Item -ItemType Directory -Force $pint | Out-Null
    $zip = Join-Path $pint 'resources.zip'
    Invoke-WebRequest -Uri 'https://docs.peppol.eu/poac/pint/pint/resources.zip' -OutFile $zip -TimeoutSec 120 -UseBasicParsing
    $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
    if ($hash -ne '1C47F68D8EE9682862112A57C9FFE6B73C1AFE668A2DD4BD2B937B848C2408F6') { throw "init.ps1 / PINT resources.zip changed upstream (sha256 $hash); review the new release before re-pinning" }
    Expand-Archive -LiteralPath $zip -DestinationPath $pint -Force
    Remove-Item -LiteralPath $zip
    "deps/corpus/eu/peppol-pint: PINT Billing 1.1.3 resources ($(@(Get-ChildItem $pint -Recurse -Filter *.sch).Count) preprocessed schematron, $(@(Get-ChildItem $pint -Recurse -Filter *.gc).Count) genericode lists)"
}
$pintSyntax = Join-Path $pint 'syntax'
if (-not (Test-Path $pintSyntax)) {
    $filling = $pintSyntax
    New-Item -ItemType Directory -Force $pintSyntax | Out-Null
    $pages = [ordered]@{
        'trn-invoice' = '0B3DE3A675FBA9109E75A0174E866238A7FC68D49E7A88A84CF3C97E715BF309'
        'trn-creditnote' = '066108AB055879ED3A7D0911589098B0E4320AC75318CA56F8DD758DEF82E45E'
    }
    foreach ($page in $pages.Keys) {
        $to = Join-Path $pintSyntax "$page.html"
        Invoke-WebRequest -Uri "https://docs.peppol.eu/poac/pint/pint/$page/syntax/" -OutFile $to -TimeoutSec 120 -UseBasicParsing
        $hash = (Get-FileHash -LiteralPath $to -Algorithm SHA256).Hash
        if ($hash -ne $pages[$page]) { throw "init.ps1 / PINT $page syntax page changed upstream (sha256 $hash); review the new release before re-pinning" }
    }
    "deps/corpus/eu/peppol-pint/syntax: PINT Billing 1.1.3 syntax trees (IBT/IBG term -> UBL path and cardinality), $($pages.Count) transactions"
}
$pintRegions = [ordered]@{
    'my' = 'BCFA311FFCB082F535C911D12A6B8537115B55E630C71FA1CCF47272271DD3D8'
    'sg' = '584353B4FED58474D3EC7E32CC99D24EB8F50C812AC7D4A4AE72E6E0566B2670'
}
foreach ($region in $pintRegions.Keys) {
    $to = Join-Path $deps "corpus/$region/pint-$region"
    if (Test-Path $to) { continue }
    $filling = $to
    New-Item -ItemType Directory -Force $to | Out-Null
    $zip = Join-Path $to 'resources.zip'
    Invoke-WebRequest -Uri "https://docs.peppol.eu/poac/$region/pint-$region/resources.zip" -OutFile $zip -TimeoutSec 120 -UseBasicParsing
    $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
    if ($hash -ne $pintRegions[$region]) { throw "init.ps1 / PINT-$($region.ToUpper()) resources.zip changed upstream (sha256 $hash); review the new release before re-pinning" }
    Expand-Archive -LiteralPath $zip -DestinationPath $to -Force
    Remove-Item -LiteralPath $zip
    "deps/corpus/$region/pint-${region}: PINT-$($region.ToUpper()) resources ($(@(Get-ChildItem $to -Recurse -Filter *.sch).Count) schematron, $(@(Get-ChildItem $to -Recurse -Filter *.xml).Count) example documents)"
}
$ubl = Join-Path $deps 'corpus/eu/ubl21'
if (-not (Test-Path $ubl)) {
    $filling = $ubl
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
$navSamples = Join-Path $deps 'corpus/hu/nav-samples'
if (-not (Test-Path $navSamples)) {
    $filling = $navSamples
    New-Item -ItemType Directory -Force $navSamples | Out-Null
    $samples = [ordered]@{
        'Belfoldi devizas szamla.xml' = '7D95ED76E7390B50'
        'Belfoldi devizas vegszamla tobb eloleg tetel.xml' = 'A84820D0E3C25A24'
        'Belfoldi egyszerusitett szamla.xml' = '9F885D2B29D7AFFE'
        'Belfoldi elolegszamla egysegar nelkul .xml' = '92269A42139B862A'
        'Belfoldi elolegszamla.xml' = 'D2C0118F83532586'
        'Belfoldi ertekesites tobb AFA tipus.xml' = '315E105E281B0AF3'
        'Belfoldi termekertekesites AFA csoportok kozott.xml' = 'F7C4D29843CF9FB5'
        'Belfoldi termekertekesites maganszemelynek.xml' = 'BDD307786E4AC5D3'
        'Belfoldi termekertekesites tetelbol adott engedmennyel.xml' = '02AF0066FFFFE577'
        'Belfoldi termekertekesites.xml' = 'D9023DFB7405CC03'
        'Belfoldi vegszamla.xml' = '9A96FE789961BDC6'
        'Eredeti szamla modositasokhoz.xml' = '259B5996A4936621'
        'Gyujtoszamla 1.xml' = '0A751855C2A800C3'
        'Gyujtoszamla 2.xml' = '199207F00BB03218'
        'Harmadik orszagbeli devizas szamla.xml' = '3C42BFAABB2F9D59'
        'Modositas es ervenytelenites 1.xml' = 'DC2EF9704C99E11A'
        'Modositas es ervenytelenites 2.xml' = '1CEED3A18B0D2E72'
        'Tagorszagi devizas szamla.xml' = 'D3DBAE884C02F3C7'
        'Termekdijas szamla.xml' = 'F2DE3280DDC1DD9A'
        'Teteladatok modositasa.xml' = '0CCFE127EB3B10F5'
        'Teves termek helyesbitese 20.xml' = '6F6ED817F9AA1B70'
        'Teves termek helyesbitese 21.xml' = '026D40C6671B8B1F'
        'Teves termek helyesbitese.xml' = '78F69A82DF22ED07'
        'Tobb szamla modositasa egy okirattal alap 1.xml' = 'D9B463F8E16775DC'
        'Tobb szamla modositasa egy okirattal alap 2.xml' = 'E9BF4E22630CDECC'
        'Tobb szamla modositasa egy okirattal alap 3.xml' = 'B194F03232557F77'
        'Tobb szamla modositasa egy okirattal.xml' = '1298D5384F7ABD02'
        'Tobbszoros modositas 1.xml' = '9ADAE51C943DA800'
        'Tobbszoros modositas 2.xml' = '65174C13E8D68169'
        'Uj kozlekedesi eszkoz export.xml' = 'ED6213EBEAF840A6'
    }
    foreach ($name in $samples.Keys) {
        $uri = 'https://raw.githubusercontent.com/nav-gov-hu/Online-Invoice/cc7a775d6dce361311e409abb9934eb755f2749c/sample/Data%20sample/' + [uri]::EscapeDataString($name)
        Save-Pinned $uri (Join-Path $navSamples $name) $samples[$name]
    }
    $filling = $null
    "deps/corpus/hu/nav-samples: $($samples.Count) NAV invoiceData samples at cc7a775d"
}
$myDataDerived = Join-Path $deps 'corpus/gr/mydata-derived'
if (-not (Test-Path $myDataDerived)) {
    $filling = $myDataDerived
    New-Item -ItemType Directory -Force $myDataDerived | Out-Null
    $stubs = [ordered]@{
        'invoice-with-taxes-on-invoice-level.xml' = '8D592521F506C6EE'
        'request-doc-with-delivery-lifecycle.xml' = '83E7D00F0A6B02CC'
    }
    $myData = 'http://www.aade.gr/myDATA/invoice/v1.0'
    foreach ($name in $stubs.Keys) {
        $stub = Join-Path $myDataDerived $name
        Save-Pinned "https://raw.githubusercontent.com/firebed/aade-mydata/1244dd9296606f63f1390d88c2faeaf8049b5d09/stubs/$name" $stub $stubs[$name]
        $source = New-Object Xml.XmlDocument
        $source.XmlResolver = $null
        $source.Load($stub)
        $names = New-Object Xml.XmlNamespaceManager $source.NameTable
        $names.AddNamespace('m', $myData)
        $derived = New-Object Xml.XmlDocument
        [void]$derived.AppendChild($derived.CreateXmlDeclaration('1.0', 'UTF-8', $null))
        $root = $derived.AppendChild($derived.CreateElement('InvoicesDoc', $myData))
        foreach ($invoice in $source.SelectNodes('//m:invoicesDoc/m:invoice', $names)) { [void]$root.AppendChild($derived.ImportNode($invoice, $true)) }
        $derivedSettings = [System.Xml.XmlWriterSettings]::new()
        $derivedSettings.Encoding = [Text.UTF8Encoding]::new($false)
        $derivedWriter = [System.Xml.XmlWriter]::Create((Join-Path $myDataDerived ($name -replace '\.xml$', '.invoices.xml')), $derivedSettings)
        try { $derived.Save($derivedWriter) } finally { $derivedWriter.Dispose() }
        Remove-Item -LiteralPath $stub -Force
    }
    $filling = $null
    "deps/corpus/gr/mydata-derived: $($stubs.Count) InvoicesDoc documents re-rooted from firebed RequestedDoc stubs (schema-valid ones only)"
}
foreach ($derivedDocument in @(Get-ChildItem -LiteralPath $myDataDerived -Filter *.xml -ErrorAction SilentlyContinue)) {
    $bytes = [IO.File]::ReadAllBytes($derivedDocument.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        [IO.File]::WriteAllBytes($derivedDocument.FullName, $bytes[3..($bytes.Length - 1)])
        "deps/corpus/gr/mydata-derived: $($derivedDocument.Name) written without its byte order mark"
    }
}
$cfdiComplements = Join-Path $deps 'corpus/mx/complements'
if (-not (Test-Path $cfdiComplements)) {
    $filling = $cfdiComplements
    New-Item -ItemType Directory -Force $cfdiComplements | Out-Null
    $complements = [ordered]@{
        'http://www.sat.gob.mx/sitio_internet/cfd/TimbreFiscalDigital/TimbreFiscalDigitalv11.xsd' = 'FB3D061FE9914500'
        'http://www.sat.gob.mx/sitio_internet/cfd/Pagos/Pagos20.xsd' = 'F37DD303A490ECD1'
    }
    foreach ($url in $complements.Keys) { Save-Pinned $url (Join-Path $cfdiComplements (Split-Path $url -Leaf)) $complements[$url] }
    $filling = $null
    "deps/corpus/mx/complements: SAT TimbreFiscalDigital 1.1 and Pagos 2.0 (for typed CFDI complements)"
}
$catPagos = Join-Path $cfdiComplements 'catPagos.xsd'
if (-not (Test-Path $catPagos)) {
    $filling = $catPagos
    Save-Pinned 'http://www.sat.gob.mx/sitio_internet/cfd/catalogos/Pagos/catPagos.xsd' $catPagos '72DBAA6E3D6518AC'
    $filling = $null
    "deps/corpus/mx/complements: SAT catPagos.xsd (Pagos 2.0 imports it)"
}
$cfdiStamped = Join-Path $deps 'corpus/mx/stamped'
if (-not (Test-Path $cfdiStamped)) {
    $filling = $cfdiStamped
    New-Item -ItemType Directory -Force $cfdiStamped | Out-Null
    Save-Pinned 'https://raw.githubusercontent.com/eclipxe13/CfdiUtils/f2a03dc254348a8fb9e50374ecdbe49e7dd43f9b/tests/assets/cfdi40-valid.xml' (Join-Path $cfdiStamped 'cfdiutils-cfdi40-valid.xml') '66056C12F2FC9DB3'
    $filling = $null
    "deps/corpus/mx/stamped: CfdiUtils CFDI 4.0 fixture issued by SAT's test taxpayer EKU9003173C9 with a TimbreFiscalDigital 1.1 stamp"
}
$ublKinds = 'Invoice', 'CreditNote', 'DebitNote', 'ApplicationResponse', 'DespatchAdvice', 'ReceiptAdvice'
foreach ($kind in $ublKinds) {
    $maindoc = Join-Path $ubl "maindoc/UBL-$kind-2.1.xsd"
    if (-not (Test-Path $maindoc)) {
        $filling = $maindoc
        Invoke-WebRequest -Uri "https://docs.oasis-open.org/ubl/os-UBL-2.1/xsd/maindoc/UBL-$kind-2.1.xsd" -OutFile $maindoc -TimeoutSec 120 -UseBasicParsing
        "deps/corpus/eu/ubl21/maindoc: UBL-$kind-2.1.xsd"
    }
}
$filling = $null
$corpusRoot = Join-Path $deps 'corpus'
$roots = @{}
$regionalPint = @($pintRegions.Keys | ForEach-Object { "$_/pint-$_/" })
foreach ($file in Get-ChildItem $corpusRoot -Recurse -Filter *.xml) {
    $relative = $file.FullName.Substring($corpusRoot.Length + 1).Replace('\', '/')
    if (@($regionalPint | Where-Object { $relative.StartsWith($_) }).Count) { continue }
    $root = try { ([xml][IO.File]::ReadAllText($file.FullName)).DocumentElement } catch { $null }
    if ($root) { $roots[$relative] = "{$($root.NamespaceURI)}$($root.LocalName)" }
}
$jsonRoots = @{}
foreach ($file in Get-ChildItem $corpusRoot -Recurse -Filter *.json) {
    $text = [IO.File]::ReadAllText($file.FullName)
    if ($text -notmatch '"_D"\s*:') { continue }
    $parsed = try { $text | ConvertFrom-Json } catch { $null }
    $elements = @(if ($parsed) { $parsed.PSObject.Properties.Name | Where-Object { $_ -notmatch '^_' } })
    if ($elements.Count -eq 1) { $jsonRoots[$file.FullName.Substring($corpusRoot.Length + 1).Replace('\', '/')] = "{$($parsed._D)}$($elements[0])" }
}
foreach ($kind in $ublKinds) {
    $wanted = "{urn:oasis:names:specification:ubl:schema:xsd:$kind-2}$kind"
    $documents = @($roots.Keys | Where-Object { $roots[$_] -eq $wanted } | Sort-Object)
    [IO.File]::WriteAllText((Join-Path $corpusRoot "ubl-$($kind.ToLowerInvariant())-documents.txt"), ($documents -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
    $jsonDocuments = @($jsonRoots.Keys | Where-Object { $jsonRoots[$_] -eq $wanted } | Sort-Object)
    [IO.File]::WriteAllText((Join-Path $corpusRoot "ubl-$($kind.ToLowerInvariant())-json-documents.txt"), ($jsonDocuments -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
}
$manifests = [ordered]@{
    'hu-nav-invoicedata' = '{http://schemas.nav.gov.hu/OSA/3.0/data}InvoiceData'
    'gr-mydata-invoicesdoc' = '{http://www.aade.gr/myDATA/invoice/v1.0}InvoicesDoc'
    'mx-cfdi-comprobante' = '{http://www.sat.gob.mx/cfd/4}Comprobante'
}
foreach ($manifest in $manifests.Keys) {
    $documents = @($roots.Keys | Where-Object { $roots[$_] -eq $manifests[$manifest] } | Sort-Object)
    [IO.File]::WriteAllText((Join-Path $corpusRoot "$manifest-documents.txt"), ($documents -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
}
$embedded = [Collections.Generic.HashSet[string]]::new()
foreach ($unit in Get-ChildItem (Join-Path (Split-Path (Split-Path $corpusRoot)) 'generated') -Recurse -Filter *.spi -ErrorAction SilentlyContinue) {
    $unitText = [regex]::Replace([IO.File]::ReadAllText($unit.FullName), '"\s*\n\s*\^\^\s*"', '')
    foreach ($m in [regex]::Matches($unitText, '"deps/corpus/([^"]+)"')) { [void]$embedded.Add($m.Groups[1].Value) }
}
$manifestDrift = @(foreach ($listing in Get-ChildItem $corpusRoot -Filter '*-documents.txt' | Sort-Object Name) {
    $added = @([IO.File]::ReadAllLines($listing.FullName) | Where-Object { $_ -and -not $embedded.Contains($_) })
    if ($added.Count) { "$($listing.Name): $($added.Count) documents no committed generated unit embeds, first $($added[0])" }
})
if ($manifestDrift.Count) {
    $manifestDrift | ForEach-Object { "init.ps1 / manifest drift / $_" }
    if ($env:GITHUB_ACTIONS -eq 'true') { throw "init.ps1 / $($manifestDrift.Count) document manifests list documents the committed generated units do not embed: regenerate and commit generated/, or keep the new corpus folder out of the manifest scan" }
}
else { "init.ps1 / manifests: every listed document is embedded in a committed generated unit ($($embedded.Count) corpus paths)" }
$filling = $null
