function New-Example([string] $Pattern, [bool] $Last) {
    $script:p = $Pattern
    $script:i = 0
    $script:last = $Last
    Read-Alternation
}

function Read-Alternation {
    $branches = [Collections.Generic.List[string]]::new()
    $branches.Add((Read-Sequence))
    while ($script:i -lt $script:p.Length -and $script:p[$script:i] -eq '|') {
        $script:i++
        $branches.Add((Read-Sequence))
    }
    if ($script:last) { $branches[$branches.Count - 1] } else { $branches[0] }
}

function Read-Sequence {
    $sb = [Text.StringBuilder]::new()
    while ($script:i -lt $script:p.Length -and $script:p[$script:i] -ne '|' -and $script:p[$script:i] -ne ')') {
        $atom = Read-Atom
        $count = Read-Count
        for ($k = 0; $k -lt $count; $k++) { $null = $sb.Append($atom) }
    }
    $sb.ToString()
}

$script:blockExamples = @{
    'IsBasicLatin' = @('A', '~')
    'IsLatin-1Supplement' = @('À', 'ÿ')
    'IsLatinExtended-A' = @('Ā', 'ſ')
    'IsLatinExtended-B' = @('ƀ', 'ɏ')
}

function Test-Property {
    $script:p[$script:i] -eq '\' -and $script:p[$script:i + 1] -cin 'p', 'P' -and $script:p[$script:i + 2] -eq '{'
}

function Read-Property {
    $negated = $script:p[$script:i + 1] -ceq 'P'
    $close = $script:p.IndexOf('}', $script:i)
    $name = $script:p.Substring($script:i + 3, $close - $script:i - 3)
    $script:i = $close + 1
    if ($negated) { return @('Ж', 'Ж') }
    $range = $script:blockExamples[$name]
    if (-not $range) { throw "no example characters for the block $name" }
    $range
}

function Read-Atom {
    $c = $script:p[$script:i]
    if (Test-Property) {
        $range = Read-Property
        if ($script:last) { return [string]$range[1] } else { return [string]$range[0] }
    }
    if ($c -eq '(') {
        $script:i++
        $inner = Read-Alternation
        $script:i++
        return $inner
    }
    if ($c -eq '[') {
        $script:i++
        $negated = $false
        if ($script:p[$script:i] -eq '^') { $negated = $true; $script:i++ }
        $ranges = [Collections.Generic.List[object]]::new()
        while ($script:p[$script:i] -ne ']') {
            if (Test-Property) { $ranges.Add((Read-Property)); continue }
            $low = $script:p[$script:i]
            if ($low -eq '\') {
                $script:i++
                $e = $script:p[$script:i]
                $script:i++
                if ($e -eq 'd') { $ranges.Add(@('0', '9')) } elseif ($e -eq 's') { $ranges.Add(@(' ', ' ')) } elseif ($e -eq 'w') { $ranges.Add(@('a', 'z')) } else { $ranges.Add(@($e, $e)) }
                continue
            }
            $script:i++
            if ($script:p[$script:i] -eq '-' -and $script:p[$script:i + 1] -ne ']') {
                $high = $script:p[$script:i + 1]
                $script:i += 2
                $ranges.Add(@($low, $high))
            } else { $ranges.Add(@($low, $low)) }
        }
        $script:i++
        if ($negated) { return 'q' }
        $r = if ($script:last) { $ranges[$ranges.Count - 1] } else { $ranges[0] }
        if ($script:last) { return [string]$r[1] } else { return [string]$r[0] }
    }
    if ($c -eq '\') {
        $e = $script:p[$script:i + 1]
        $script:i += 2
        if ($e -eq 'd') { return '7' } elseif ($e -eq 's') { return ' ' } elseif ($e -eq 'w') { return 'w' } else { return [string]$e }
    }
    if ($c -eq '.') { $script:i++; return 'z' }
    $script:i++
    [string]$c
}

function Read-Count {
    if ($script:i -ge $script:p.Length) { return 1 }
    $c = $script:p[$script:i]
    if ($c -eq '?') { $script:i++; return $(if ($script:last) { 1 } else { 0 }) }
    if ($c -eq '*') { $script:i++; return $(if ($script:last) { 2 } else { 0 }) }
    if ($c -eq '+') { $script:i++; return $(if ($script:last) { 2 } else { 1 }) }
    if ($c -eq '{') {
        $close = $script:p.IndexOf('}', $script:i)
        $body = $script:p.Substring($script:i + 1, $close - $script:i - 1)
        $script:i = $close + 1
        $parts = $body.Split(',')
        $min = [int]$parts[0]
        if ($parts.Count -eq 1) { return $min }
        if ($parts[1] -eq '') { return $(if ($script:last) { $min + 1 } else { $min }) }
        $max = [int]$parts[1]
        return $(if ($script:last) { $max } else { $min })
    }
    1
}
