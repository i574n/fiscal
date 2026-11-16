param(
    [string] $Document = (Join-Path $PSScriptRoot '..\samples\generated_nfe_v4_example.xml'),
    [string] $Schema = (Join-Path $PSScriptRoot '..\deps\corpus\DFe.NET\NFe.AppTeste\Schemas\nfe_v4.00.xsd'),
    [int] $Show = 12,
    [string[]] $Preload = @(),
    [switch] $Resolve
)
$xs = 'http://www.w3.org/2001/XMLSchema'
$errors = [Collections.Generic.List[string]]::new()
$repairs = [Collections.Generic.List[string]]::new()
$ignoreDtd = [System.Xml.XmlReaderSettings]::new()
$ignoreDtd.DtdProcessing = [System.Xml.DtdProcessing]::Ignore

function New-SchemaSet([string] $schemaPath) {
    $set = [System.Xml.Schema.XmlSchemaSet]::new()
    $set.XmlResolver = if ($Preload.Count -and -not $Resolve) { $null } else { [System.Xml.XmlUrlResolver]::new() }
    foreach ($path in $Preload) {
        $preloaded = [System.Xml.XmlReader]::Create((Resolve-Path $path).Path, $ignoreDtd)
        try { $null = $set.Add([NullString]::Value, $preloaded) } finally { $preloaded.Close() }
    }
    $reader = [System.Xml.XmlReader]::Create($schemaPath)
    try { $null = $set.Add([NullString]::Value, $reader) } finally { $reader.Close() }
    $set.Compile()
    $set
}

function Get-TopLevelNames([xml] $doc) {
    @($doc.DocumentElement.ChildNodes | Where-Object { $_.NamespaceURI -eq $xs -and $_.LocalName -in 'simpleType', 'complexType' } | ForEach-Object { $_.GetAttribute('name') })
}

function Get-Closure([string] $folder, [string] $start) {
    $docs = [ordered]@{}
    $queue = [Collections.Generic.Queue[string]]::new()
    $queue.Enqueue($start)
    while ($queue.Count) {
        $fileName = $queue.Dequeue()
        $path = Join-Path $folder $fileName
        if ($docs.Contains($fileName) -or -not (Test-Path -LiteralPath $path)) { continue }
        $docs[$fileName] = [xml](Get-Content -LiteralPath $path -Raw -Encoding utf8)
        $docs[$fileName].DocumentElement.ChildNodes | Where-Object { $_.NamespaceURI -eq $xs -and $_.LocalName -in 'include', 'import' -and $_.GetAttribute('schemaLocation') } |
            ForEach-Object { $queue.Enqueue((Split-Path $_.GetAttribute('schemaLocation') -Leaf)) }
    }
    $docs
}

function Repair-LocalDuplicate([string] $folder, [string] $start, [string] $name) {
    $docs = Get-Closure $folder $start
    $repaired = 0
    foreach ($fileName in @($docs.Keys)) {
        $doc = $docs[$fileName]
        if ((Get-TopLevelNames $doc) -notcontains $name) { continue }
        $included = @($doc.DocumentElement.ChildNodes | Where-Object { $_.NamespaceURI -eq $xs -and $_.LocalName -eq 'include' } | ForEach-Object { Split-Path $_.GetAttribute('schemaLocation') -Leaf })
        $owner = $included | Where-Object { $docs.Contains($_) -and (Get-TopLevelNames $docs[$_]) -contains $name } | Select-Object -First 1
        if (-not $owner) { continue }
        $local = $doc.DocumentElement.ChildNodes | Where-Object { $_.NamespaceURI -eq $xs -and $_.LocalName -in 'simpleType', 'complexType' -and $_.GetAttribute('name') -eq $name } | Select-Object -First 1
        $null = $doc.DocumentElement.RemoveChild($local)
        $doc.Save((Join-Path $folder $fileName))
        $repairs.Add("schema repair: dropped local $name from $fileName (also declared in $owner, which wins)")
        $repaired++
    }
    $repaired
}

$schemaPath = (Resolve-Path $Schema).Path
$set = $null
try { $set = New-SchemaSet $schemaPath }
catch {
    $message = $_.Exception.InnerException.Message ?? $_.Exception.Message
    if ($message -match "The (simpleType|complexType) '[^']*:([^':]+)' has already been declared") {
        $copy = Join-Path ([IO.Path]::GetTempPath()) "validate-example-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
        Copy-Item -LiteralPath (Split-Path $schemaPath) -Destination $copy -Recurse
        $copiedSchema = Join-Path $copy (Split-Path $schemaPath -Leaf)
        foreach ($attempt in 1..8) {
            if (-not (Repair-LocalDuplicate $copy (Split-Path $schemaPath -Leaf) $Matches[2])) { $errors.Add("schema: $message"); break }
            try { $set = New-SchemaSet $copiedSchema; break }
            catch {
                $message = $_.Exception.InnerException.Message ?? $_.Exception.Message
                if ($message -notmatch "The (simpleType|complexType) '[^']*:([^':]+)' has already been declared") { $errors.Add("schema: $message"); break }
            }
        }
        Remove-Item -LiteralPath $copy -Recurse -Force -ErrorAction Ignore
    } else { $errors.Add("schema: $message") }
}

$rootReader = [System.Xml.XmlReader]::Create((Resolve-Path -LiteralPath $Document).Path, $ignoreDtd)
try { $null = $rootReader.MoveToContent(); $root = [System.Xml.XmlQualifiedName]::new($rootReader.LocalName, $rootReader.NamespaceURI) } finally { $rootReader.Close() }
if (-not $set -or -not $set.GlobalElements.Contains($root)) { $errors.Add("schema: no loaded schema declares the document root {$($root.Namespace)}$($root.Name)") }

if ($set) {
    $settings = [System.Xml.XmlReaderSettings]::new()
    $settings.ValidationType = [System.Xml.ValidationType]::Schema
    $settings.Schemas = $set
    $settings.add_ValidationEventHandler({ param($s, $e) $errors.Add("$($e.Severity) line $($e.Exception.LineNumber): $($e.Message)") })
    $documentStream = [IO.File]::OpenRead((Resolve-Path -LiteralPath $Document).Path)
    $validating = [System.Xml.XmlReader]::Create($documentStream, $settings)
    try { while ($validating.Read()) { } } catch { $errors.Add("fatal: $($_.Exception.Message) (at $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber))") } finally { $validating.Close(); $documentStream.Dispose() }
}
$pending = @($errors | Where-Object { $_ -match "incomplete content\. List of possible elements expected: .*'Signature' in namespace 'http://www\.w3\.org/2000/09/xmldsig#'" })
$errors = @($errors | Where-Object { $_ -notin $pending })
"document $((Get-Item -LiteralPath $Document).Length) bytes; validation messages $($errors.Count); signature pending $($pending.Count)"
$repairs | ForEach-Object { "  $_" }
$errors | Group-Object { ($_ -replace "'[^']*'", "'x'") -replace 'line \d+', 'line n' } | Sort-Object Count -Descending | Select-Object -First $Show | ForEach-Object { "  x$($_.Count): $($_.Group[0].Substring(0, [Math]::Min(220, $_.Group[0].Length)))" }
