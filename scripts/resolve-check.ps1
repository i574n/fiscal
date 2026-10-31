$xs = 'http://www.w3.org/2001/XMLSchema'
$cache = @{}
function Get-Doc([string] $Path) {
    if (-not $cache.ContainsKey($Path)) { $doc = [xml]::new(); $doc.Load($Path); $cache[$Path] = $doc }
    $cache[$Path]
}
function Get-Tree([string] $Path, [hashtable] $Seen, [Collections.Generic.List[string]] $Missing) {
    if ($Seen.ContainsKey($Path)) { return }
    if (-not (Test-Path -LiteralPath $Path)) { $Missing.Add($Path); return }
    $Seen[$Path] = $true
    $doc = Get-Doc $Path
    $dir = Split-Path $Path
    foreach ($inc in $doc.SelectNodes("/*/*[local-name()='include' or local-name()='import']")) {
        $loc = $inc.GetAttribute('schemaLocation')
        if ($loc) { Get-Tree ([IO.Path]::GetFullPath((Join-Path $dir $loc))) $Seen $Missing }
    }
}
$root = Split-Path $PSScriptRoot
$files = @(Get-Content (Join-Path $root 'src\corpus.txt') | Where-Object { $_ } | ForEach-Object { Join-Path $root $_ })
$withMissing = 0; $danglingComplete = 0; $danglingWithMissing = 0
$examples = [Collections.Generic.List[string]]::new()
foreach ($f in $files) {
    $seen = @{}; $missing = [Collections.Generic.List[string]]::new()
    Get-Tree ([IO.Path]::GetFullPath($f)) $seen $missing
    $names = @{}
    $refs = [Collections.Generic.List[string]]::new()
    foreach ($p in $seen.Keys) {
        $doc = Get-Doc $p
        foreach ($n in $doc.SelectNodes("//*[(local-name()='simpleType' or local-name()='complexType') and @name]")) { $names[$n.GetAttribute('name')] = $true }
        foreach ($n in $doc.SelectNodes("//*[@type or @base]")) {
            foreach ($attr in 'type', 'base') {
                $v = $n.GetAttribute($attr)
                if (-not $v) { continue }
                $prefix = if ($v.Contains(':')) { $v.Split(':')[0] } else { '' }
                $ns = $n.GetNamespaceOfPrefix($prefix)
                if ($ns -eq $xs) { continue }
                $refs.Add($v.Split(':')[-1])
            }
        }
    }
    $dangling = @($refs | Where-Object { -not $names.ContainsKey($_) })
    if ($missing.Count -gt 0) { $withMissing++; if ($dangling.Count -gt 0) { $danglingWithMissing++ } }
    elseif ($dangling.Count -gt 0) { $danglingComplete++; if ($examples.Count -lt 5) { $examples.Add("$(Split-Path $f -Leaf): $($dangling | Select-Object -First 3)") } }
}
"files $($files.Count); with a missing include $withMissing (dangling there $danglingWithMissing); complete trees with dangling references $danglingComplete"
$examples
