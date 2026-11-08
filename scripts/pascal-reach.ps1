param(
    [Parameter(Mandatory)] [string] $Module,
    [string] $Lib = (Join-Path $PSScriptRoot '..\deps\spiral\lib\spiral'),
    [string] $Mounts = (Join-Path ($env:SPIRAL_CELLS_ROOT ? $env:SPIRAL_CELLS_ROOT : (Join-Path $PSScriptRoot '..\deps\spiral\apps\cells')) 'lib\spiral\cells')
)
$sources = @(Get-ChildItem $Lib -Filter *.spi -File) + @(if ($Mounts -and (Test-Path $Mounts)) { Get-ChildItem $Mounts -Filter *.spi -File })
$definitions = @{}
foreach ($file in $sources) {
    $moduleName = [IO.Path]::GetFileNameWithoutExtension($file.Name)
    $lines = [IO.File]::ReadAllLines($file.FullName)
    $current = $null; $body = [Text.StringBuilder]::new()
    foreach ($line in $lines + @(':= __end__')) {
        if ($line -match '^(?::=|:~ \^|:& :~|:~|inl) +([A-Za-z_][\w'']*)') {
            if ($current) { $definitions["$moduleName.$current"] = $body.ToString() }
            $current = $Matches[1]; $body = [Text.StringBuilder]::new(); [void]$body.AppendLine($line)
        } elseif ($line -match '^(test |:# |///)') {
            if ($current) { $definitions["$moduleName.$current"] = $body.ToString() }
            $current = $null
        } elseif ($current) { [void]$body.AppendLine($line) }
    }
}
$imports = @{}
foreach ($file in $sources) {
    $moduleName = [IO.Path]::GetFileNameWithoutExtension($file.Name)
    $imports[$moduleName] = @(Select-String -LiteralPath $file.FullName -Pattern '^:< ([\w'']+)' | ForEach-Object { $_.Matches[0].Groups[1].Value })
}
function Get-Calls([string] $text, [string] $origin) {
    $calls = [Collections.Generic.HashSet[string]]::new()
    foreach ($m in [regex]::Matches($text, "\b([a-z][\w']*)(?:\.|::)([a-z_][\w']*)")) { [void]$calls.Add("$($m.Groups[1].Value).$($m.Groups[2].Value)") }
    if ($origin) {
        $locals = [Collections.Generic.HashSet[string]]::new()
        foreach ($m in [regex]::Matches($text, "(?m)^\s*:=\s+([a-z_][\w']*)\s*[:=]|\(([a-z_][\w']*)\s*:")) { [void]$locals.Add($m.Groups[1].Value + $m.Groups[2].Value) }
        foreach ($m in [regex]::Matches($text, "(?<![\w'.])([a-z_][\w']*)\b")) {
            if ($locals.Contains($m.Groups[1].Value) -and $text.Substring(0, $m.Index).TrimEnd() -notmatch '(?<![|:]):$') { continue }
            foreach ($scope in @($origin) + $imports[$origin]) { $key = "$scope.$($m.Groups[1].Value)"; if ($definitions.ContainsKey($key)) { [void]$calls.Add($key); break } }
        }
    }
    $calls
}
function Select-PascalText([string] $body) {
    $hasPascal = $body -match '\|\s*Pascal\s*=>|\bPascal\s*=\s*\\'
    $out = [Collections.Generic.List[string]]::new(); $skip = -1
    foreach ($line in $body -split "`n") {
        $indent = $line.Length - $line.TrimStart().Length
        if ($skip -ge 0) { if ($line.Trim() -eq '' -or $indent -gt $skip) { continue } else { $skip = -1 } }
        $arm = $null
        if ($line -match '^\s*\|\s*([A-Za-z_]+)(?:\s+[a-z_]\w*)?\s*=>') { $arm = $Matches[1]; if ($arm -cmatch '^[a-z]') { $arm = '_' } } elseif ($line -match '^\s*([A-Z][A-Za-z]*)\s*=\s*\\') { $arm = $Matches[1] }
        if ($arm -and -not ($arm -eq 'Pascal' -or ($arm -eq '_' -and -not $hasPascal))) { $skip = $indent; continue }
        $out.Add($line)
    }
    $out -join "`n"
}
$moduleText = [IO.File]::ReadAllText($Module)
$queue = [Collections.Generic.Queue[string]]::new(); $seen = [Collections.Generic.HashSet[string]]::new(); $parent = @{}
foreach ($c in Get-Calls $moduleText $null) { if ($definitions.ContainsKey($c) -and $seen.Add($c)) { $queue.Enqueue($c) } }
$gaps = [Collections.Generic.List[object]]::new()
$primitives = @{}
$rustEmits = [Collections.Generic.List[string]]::new()
while ($queue.Count) {
    $name = $queue.Dequeue(); $body = $definitions[$name]; $origin = $name.Split('.')[0]
    $switchy = $body -match 'run_target|backend_switch'
    if ($switchy -and $body -notmatch '\bPascal\b' -and $body -notmatch '\|\s*_\s*=>') { $gaps.Add([pscustomobject]@{ function = $name; kind = $(if ($body -match 'backend_switch') { 'backend_switch, no Pascal key' } else { 'run_target, no Pascal or _ arm' }) }) }
    elseif ($switchy -and $body -notmatch '\bPascal\b' -and $body -match '\|\s*_\s*=>\s*\\\s*\(\)\s*=>\s*failwith') { $gaps.Add([pscustomobject]@{ function = $name; kind = 'run_target, _ arm fails' }) }
    elseif ($body -match 'Pascal\s*=.*has_no_Pascal_arm') { $gaps.Add([pscustomobject]@{ function = $name; kind = 'placeholder Pascal arm' }) }
    $pascalText = Select-PascalText $body
    if ($pascalText -match '!\\{1,2}\(') { $rustEmits.Add($name) }
    foreach ($m in [regex]::Matches($pascalText, '!!!!(?!BackendSwitch\b)(\w+)')) { $primitives["$($m.Groups[1].Value)"] = @($primitives["$($m.Groups[1].Value)"]) + $name | Select-Object -Unique }
    foreach ($c in Get-Calls $pascalText $origin) { if ($c -ne $name -and $definitions.ContainsKey($c) -and $seen.Add($c)) { $parent[$c] = $name; $queue.Enqueue($c) } }
}
"reached lib definitions: $($seen.Count)"
"Pascal gaps: $($gaps.Count)"
"primitives on Pascal paths: $($primitives.Count)"
$primitives.Keys | Sort-Object | ForEach-Object { '  {0,-24} in {1}' -f $_, (($primitives[$_] | Where-Object { $_ }) -join ', ') }
"Rust emit macros on Pascal paths: $($rustEmits.Count)"
$rustEmits | Sort-Object | ForEach-Object { $chain = @($_); $p = $_; while ($parent.ContainsKey($p)) { $p = $parent[$p]; $chain += $p }; '  {0,-30} via {1}' -f $_, (($chain | Select-Object -Skip 1) -join ' <- ') }
$gaps | Sort-Object function | ForEach-Object { $chain = @($_.function); $p = $_.function; while ($parent.ContainsKey($p)) { $p = $parent[$p]; $chain += $p }; '  {0,-30} {1,-30} via {2}' -f $_.function, $_.kind, (($chain | Select-Object -Skip 1) -join ' <- ') }
