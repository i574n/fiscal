param([switch] $Write)
$root = Split-Path $PSScriptRoot
$d = Join-Path $root 'src'
$brazil = @(Get-Content "$d\corpus.txt" | ForEach-Object { Join-Path $root $_ })
$families = @(Get-ChildItem (Join-Path $root 'deps/corpus') -Directory | Where-Object Name -ne 'DFe.NET' |
    ForEach-Object { Get-ChildItem $_.FullName -Recurse -Filter *.xsd | Sort-Object FullName | ForEach-Object FullName })
$distinct = [Collections.Generic.HashSet[string]]::new()
$patterns = @(foreach ($schema in $brazil + $families) {
    ([xml](Get-Content $schema -Raw -Encoding utf8)).SelectNodes("//*[local-name()='pattern']") | ForEach-Object value |
        Where-Object { $_ -ne '' -and $_ -notmatch '[\r\n]' -and $distinct.Add($_) }
})
$generic = [Collections.Generic.List[string]]::new()
foreach ($n in 1..20) { $generic.Add(('1234567890' * 2).Substring(0, $n)); $generic.Add('0' * $n); $generic.Add('9' * $n) }
foreach ($s in @('', ' ', 'a', 'A', 'ABC', 'abc', 'Ação Ltda', ' leading', 'trailing ', 'two  spaces', ('x' * 61), 'Rua das Flores, 123',
        '0.00', '1.04', '2.00', '3.00', '4.00', '1.00', '1.10', '0.0001', '123.4567', '12345678901.1234', '-1.5', '-0.0001', '1.234567', '-23.550520', '-46.633308', '180.000000', '-90.000000',
        '2026-10-20', '2026-02-29', '2024-02-29', '2026-13-01', '20261020', '2026-10-20T10:20:30-03:00', '2026-10-20T10:20:30Z', '2026-10-20T10:20:30', '10:20:30',
        '12345678000195', '12345678901', '123456789012345678901234567890123456789012345678901234567890123', '35261012345678000195550010000000011000000015',
        'NFe35261012345678000195550010000000011000000015', 'ID123456789012345678901234567890123456789012', '0F1A2B3C-4D5E-6F70-8192-A3B4C5D6E7F8',
        'http://www.fazenda.sp.gov.br/nfce/qrcode?p=35261012345678000195650010000000011000000015|2|1|1|ABCDEF0123456789ABCDEF0123456789ABCDEF01',
        'https://www.sefaz.rs.gov.br/NFCE/NFCE-COM.aspx', 'abc@example.com', 'ab.c', 'a@b.c', 'SP', 'RS', 'XX', 'EX', 'BR', '35', '43', '99', 'ABC1234', 'ABC1D23', 'AAA0001', 'ZZZ9999',
        'V1.00', 'v1', '1', '01', '001', '1000', '01.01', 'S', 'N', 'true', 'false', '00', '0000')) { $generic.Add($s) }
$enumerations = Get-Content "$d\corpus.txt" | ForEach-Object { [xml](Get-Content (Join-Path $root $_) -Raw) } | ForEach-Object { $_.SelectNodes("//*[local-name()='enumeration']") | ForEach-Object value } | Where-Object { $_ -notmatch '[\r\n\t]' } | Sort-Object -Unique
. (Join-Path $PSScriptRoot 'pattern-examples.ps1')
$examples = [Collections.Generic.List[string]]::new()
foreach ($p in $patterns) {
    $anchored = [regex]::new('^(?:' + $p + ')$')
    foreach ($last in $false, $true) {
        $e = New-Example $p $last
        if ($anchored.IsMatch($e)) {
            $examples.Add($e)
            $examples.Add($e + 'x')
            if ($e.Length -gt 0) { $examples.Add($e.Substring(0, $e.Length - 1)) }
            if ($e.Length -gt 1) { $examples.Add('~' + $e.Substring(1)) }
        }
    }
}
$sampled = @(for ($k = 0; $k -lt $enumerations.Count; $k += 3) { $enumerations[$k] })
$probes = @(@($generic) + $sampled + $examples | Where-Object { $_ -notmatch '[\r\n]' } | Select-Object -Unique)
$compiled = foreach ($p in $patterns) { [regex]::new('^(?:' + $p + ')$', [Text.RegularExpressions.RegexOptions]::CultureInvariant) }
$rows = foreach ($r in $compiled) { -join ($probes | ForEach-Object { if ($r.IsMatch($_)) { '1' } else { '0' } }) }
$withPositive = @($rows | Where-Object { $_.Contains('1') }).Count
$withNegative = @($rows | Where-Object { $_.Contains('0') }).Count
$ones = ($rows | ForEach-Object { ($_.ToCharArray() | Where-Object { $_ -eq '1' }).Count } | Measure-Object -Sum).Sum
"patterns $($patterns.Count) ($($brazil.Count) Brazilian schemas, $($families.Count) other family schemas), probes $($probes.Count) ($($generic.Count) generic, $($sampled.Count) of $($enumerations.Count) enumeration values, $($examples.Count) generated examples and near misses), pairs $($patterns.Count * $probes.Count)"
"patterns with a positive probe $withPositive, with a negative probe $withNegative, positive pairs $ones"
if ($Write) {
    [IO.File]::WriteAllText("$d\patterns.txt", ($patterns -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText("$d\pattern_probes.txt", ($probes -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText("$d\pattern_expected.txt", ($rows -join "`n") + "`n")
    "wrote patterns.txt, pattern_probes.txt and pattern_expected.txt"
}
