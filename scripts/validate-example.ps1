param(
    [string] $Document = (Join-Path $PSScriptRoot '..\samples\nfe_v4_example.xml'),
    [string] $Schema = (Join-Path $PSScriptRoot '..\deps\corpus\DFe.NET\NFe.AppTeste\Schemas\nfe_v4.00.xsd'),
    [int] $Show = 12,
    [string[]] $Preload = @(),
    [switch] $Resolve
)
$set = [System.Xml.Schema.XmlSchemaSet]::new()
$set.XmlResolver = if ($Preload.Count -and -not $Resolve) { $null } else { [System.Xml.XmlUrlResolver]::new() }
$ignoreDtd = [System.Xml.XmlReaderSettings]::new()
$ignoreDtd.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
foreach ($path in $Preload) {
    $preloaded = [System.Xml.XmlReader]::Create((Resolve-Path $path).Path, $ignoreDtd)
    $null = $set.Add([NullString]::Value, $preloaded)
    $preloaded.Close()
}
$reader = [System.Xml.XmlReader]::Create((Resolve-Path $Schema).Path)
$null = $set.Add([NullString]::Value, $reader)
$reader.Close()
$set.Compile()
$settings = [System.Xml.XmlReaderSettings]::new()
$settings.ValidationType = [System.Xml.ValidationType]::Schema
$settings.Schemas = $set
$errors = [Collections.Generic.List[string]]::new()
$settings.add_ValidationEventHandler({ param($s, $e) $errors.Add("$($e.Severity) line $($e.Exception.LineNumber): $($e.Message)") })
$documentStream = [IO.File]::OpenRead((Resolve-Path -LiteralPath $Document).Path)
$validating = [System.Xml.XmlReader]::Create($documentStream, $settings)
try { while ($validating.Read()) { } } catch { $errors.Add("fatal: $($_.Exception.Message) (at $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber))") } finally { $validating.Close(); $documentStream.Dispose() }
"document $((Get-Item -LiteralPath $Document).Length) bytes; validation messages $($errors.Count)"
$errors | Group-Object { ($_ -replace "'[^']*'", "'x'") -replace 'line \d+', 'line n' } | Sort-Object Count -Descending | Select-Object -First $Show | ForEach-Object { "  x$($_.Count): $($_.Group[0].Substring(0, [Math]::Min(220, $_.Group[0].Length)))" }
