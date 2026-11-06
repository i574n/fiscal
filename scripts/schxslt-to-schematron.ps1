param(
    [Parameter(Mandatory)] [string] $Compiled,
    [Parameter(Mandatory)] [string] $Output
)
$ErrorActionPreference = 'Stop'
$xslNs = 'http://www.w3.org/1999/XSL/Transform'
$schNs = 'http://purl.oclc.org/dsdl/schematron'
$svrlNs = 'http://purl.oclc.org/dsdl/svrl'
$schxsltNs = 'https://doi.org/10.5281/zenodo.1495494'
$compiledDocument = [xml][IO.File]::ReadAllText((Resolve-Path -LiteralPath $Compiled).Path)
$names = [Xml.XmlNamespaceManager]::new($compiledDocument.NameTable)
$names.AddNamespace('xsl', $xslNs)
$names.AddNamespace('svrl', $svrlNs)
$names.AddNamespace('schxslt', $schxsltNs)
$stylesheet = $compiledDocument.DocumentElement
$toolingNamespaces = @($xslNs, $schNs, $svrlNs, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#')
$schema = [Xml.XmlDocument]::new()
$root = $schema.AppendChild($schema.CreateElement('sch', 'schema', $schNs))
$root.SetAttribute('queryBinding', 'xslt2')
foreach ($declaration in @($stylesheet.Attributes | Where-Object { $_.Prefix -eq 'xmlns' })) {
    if ($declaration.Value -in $toolingNamespaces -or $declaration.Value.StartsWith($schxsltNs)) { continue }
    $ns = $root.AppendChild($schema.CreateElement('sch', 'ns', $schNs))
    $ns.SetAttribute('prefix', $declaration.LocalName)
    $ns.SetAttribute('uri', $declaration.Value)
}
$rules = foreach ($template in @($stylesheet.SelectNodes('xsl:template[@match and @mode]', $names))) {
    $fired = $template.SelectSingleNode('xsl:choose/xsl:otherwise/schxslt:rule[.//svrl:fired-rule]', $names)
    if (-not $fired) { $fired = $template.SelectSingleNode('schxslt:rule[.//svrl:fired-rule]', $names) }
    if (-not $fired) { continue }
    [pscustomobject]@{
        Pattern = $fired.GetAttribute('pattern')
        Context = $template.GetAttribute('match')
        Priority = [double]$template.GetAttribute('priority')
        Body = $fired
    }
}
function Join-Guards([string[]] $guards) { if ($guards.Count) { ($guards | ForEach-Object { "($_)" }) -join ' and ' } else { 'true()' } }
function Add-Guarded($branch, $ruleElement, [string[]] $ruleGuards, [string] $itemsSelect, [string[]] $itemGuards, [string] $guard) {
    if ($itemsSelect) { Add-Steps $branch $ruleElement $ruleGuards $itemsSelect ($itemGuards + $guard) }
    else { Add-Steps $branch $ruleElement ($ruleGuards + $guard) $null @() }
}
function Add-Steps($parent, $ruleElement, [string[]] $ruleGuards, [string] $itemsSelect, [string[]] $itemGuards) {
    $context = $ruleElement.GetAttribute('context')
    foreach ($step in @($parent.ChildNodes | Where-Object { $_ -is [Xml.XmlElement] })) {
        if ($step.NamespaceURI -eq $svrlNs -and $step.LocalName -eq 'failed-assert') {
            $fails = if ($itemsSelect) { "exists(($itemsSelect)[$(Join-Guards $itemGuards)])" } else { 'true()' }
            $assert = $ruleElement.AppendChild($schema.CreateElement('sch', 'assert', $schNs))
            foreach ($attribute in 'id', 'flag', 'role') { if ($step.HasAttribute($attribute)) { $assert.SetAttribute($attribute, $step.GetAttribute($attribute)) } }
            $assert.SetAttribute('test', "not($(Join-Guards (@($ruleGuards) + $fails | Where-Object { $_ -ne 'true()' })))")
            $text = $step.SelectSingleNode('svrl:text', $names)
            [void]$assert.AppendChild($schema.CreateTextNode($(if ($text) { $text.InnerText.Trim() } else { '' })))
            $script:assertCount++
            continue
        }
        if ($step.NamespaceURI -ne $xslNs) { continue }
        if ($step.LocalName -eq 'variable') {
            if ($ruleGuards.Count -or $itemsSelect) { throw "$Compiled : a variable under a guard or for-each in rule '$context'" }
            $let = $ruleElement.AppendChild($schema.CreateElement('sch', 'let', $schNs))
            $let.SetAttribute('name', $step.GetAttribute('name'))
            $let.SetAttribute('value', $step.GetAttribute('select'))
        } elseif ($step.LocalName -eq 'for-each') {
            if ($itemsSelect) { throw "$Compiled : nested for-each in rule '$context'" }
            Add-Steps $step $ruleElement $ruleGuards $step.GetAttribute('select') @()
        } elseif ($step.LocalName -eq 'if') {
            Add-Guarded $step $ruleElement $ruleGuards $itemsSelect $itemGuards $step.GetAttribute('test')
        } elseif ($step.LocalName -eq 'choose') {
            $earlier = [Collections.Generic.List[string]]::new()
            foreach ($branch in @($step.ChildNodes | Where-Object { $_ -is [Xml.XmlElement] -and $_.NamespaceURI -eq $xslNs })) {
                $excluded = @($earlier | ForEach-Object { "not($_)" })
                if ($branch.LocalName -eq 'when') {
                    Add-Guarded $branch $ruleElement $ruleGuards $itemsSelect $itemGuards (Join-Guards ($excluded + $branch.GetAttribute('test')))
                    $earlier.Add($branch.GetAttribute('test'))
                } elseif ($branch.LocalName -eq 'otherwise') {
                    Add-Guarded $branch $ruleElement $ruleGuards $itemsSelect $itemGuards (Join-Guards $excluded)
                }
            }
        }
    }
}
$patternOrder = [Collections.Generic.List[string]]::new()
foreach ($rule in $rules) { if (-not $patternOrder.Contains($rule.Pattern)) { $patternOrder.Add($rule.Pattern) } }
$assertCount = 0
foreach ($patternId in $patternOrder) {
    $pattern = $root.AppendChild($schema.CreateElement('sch', 'pattern', $schNs))
    $pattern.SetAttribute('id', $patternId)
    foreach ($rule in @($rules | Where-Object Pattern -eq $patternId | Sort-Object Priority -Descending -Stable)) {
        $ruleElement = $pattern.AppendChild($schema.CreateElement('sch', 'rule', $schNs))
        $ruleElement.SetAttribute('context', $rule.Context)
        Add-Steps $rule.Body $ruleElement @() $null @()
    }
}
$compiledAsserts = $compiledDocument.SelectNodes('//svrl:failed-assert', $names).Count
if ($assertCount -ne $compiledAsserts) { throw "$Compiled : rebuilt $assertCount asserts of $compiledAsserts compiled" }
$settings = [Xml.XmlWriterSettings]::new()
$settings.Indent = $true
$settings.Encoding = [Text.UTF8Encoding]::new($false)
$writer = [Xml.XmlWriter]::Create($Output, $settings)
try { $schema.Save($writer) } finally { $writer.Dispose() }
"$(Split-Path $Output -Leaf): $($patternOrder.Count) patterns, $(@($rules).Count) rules, $assertCount asserts (all compiled asserts), $(@($schema.GetElementsByTagName('let', $schNs)).Count) lets"
