$root = Split-Path $PSScriptRoot
$validate = Join-Path $PSScriptRoot 'validate-example.ps1'
$table = Join-Path $root 'generated/family-gates.tsv'
if (-not (Test-Path -LiteralPath $table)) { throw "family-gates.ps1 / $table is missing: the generator writes it (test writes_the_family_gate_table)" }
foreach ($row in @(Import-Csv -LiteralPath $table -Delimiter "`t")) {
    $document = Join-Path $root "samples/$($row.example)"
    if (-not (Test-Path -LiteralPath $document)) { "== $($row.example) :: not written"; continue }
    "== $($row.example)"
    $schema = Join-Path $root $row.schema
    if ($row.kind -eq 'json') {
        $text = Get-Content -Raw -LiteralPath $document
        try {
            $null = Test-Json -Json $text -Schema (Get-Content -Raw -LiteralPath $schema) -ErrorAction Stop
            "document $($text.Length) bytes; validation messages 0"
        }
        catch { "document $($text.Length) bytes; validation messages 1"; "  $($_.Exception.Message)" }
        continue
    }
    $preload = @($row.preloads -split ';' | Where-Object { $_ } | ForEach-Object { Join-Path $root $_ })
    & $validate -Document $document -Schema $schema -Preload $preload -Resolve:($row.resolve -eq '1') -Show 8
}
