# fiscal

Typed e-invoice models generated from the official XML schemas, written in [Spiral](https://github.com/i574n/spiral).

Governments that mandate electronic invoicing publish their invoice formats as XSD schemas. `fiscal` reads those schemas
and generates, for every document family, a Spiral module with:

- the document as types: records for sequences, unions for choices and enumerations;
- a parser and a printer for each record (`*_of_xml`, `*_to_xml`);
- a validator for every facet-constrained value (`*_is_valid`), with patterns compiled to DFA tables;
- an example document builder (`*_example`), whose output is checked against the official XSD.

The XML reader, the XSD model, include/import resolution and the regex-to-DFA compiler live in Spiral's own library
(`lib/spiral`: `xml`, `xsd`, `xsd_resolve`, `xsd_regex`). This repository holds the generator, the corpus checks and the
schema families it targets.

## What it generates today

| Jurisdiction | Documents | Versions | Schema source | Status |
|---|---|---|---|---|
| Brazil | NF-e (goods; NFC-e, model 65, uses the same schema) | 2.00, 3.10, 4.00 | SEFAZ packages, as mirrored by [DFe.NET](https://github.com/ZeusAutomacao/DFe.NET) | generated |
| Brazil | CT-e (cargo transport), CT-e OS (other transport services), CT-e Simplificado | 2.00, 3.00, 4.00 | SEFAZ via DFe.NET | generated |
| Brazil | GTV-e (cash-in-transit), MDF-e (cargo manifest) | 3.00/4.00, 1.00/3.00 | SEFAZ via DFe.NET | generated |
| Mexico | CFDI | 4.0 | [SAT](http://www.sat.gob.mx/sitio_internet/cfd/4/cfdv40.xsd) (with its catalogs and data types) | generated |
| European Union | UBL 2.1 Invoice, the EN 16931 syntax used by Peppol BIS Billing 3.0 | 2.1 | [OASIS](https://docs.oasis-open.org/ubl/os-UBL-2.1/xsd/); EN16931-UBL schematron 1.3.16 from [CEN](https://github.com/ConnectingEurope/eInvoicing-EN16931) | generated |
| Poland | KSeF FA(3) | FA(3) | [Ministry of Finance (CRD)](http://crd.gov.pl/wzor/2025/06/25/13775/schemat.xsd) | generated |
| Italy | FatturaPA (SdI) | 1.2.3 | [fatturapa.gov.it](https://www.fatturapa.gov.it/) | schema read; generation does not finish yet |

That is 16 generated modules (13 Brazilian document versions, CFDI, UBL and KSeF). The largest Brazilian one,
`generated_nfe_v4.spi`, has 20,820 lines: 91 unions, 504 types, 252 validators and 198 parser/printer pairs.

## Reach today

Every number below comes from an official source unless it is marked otherwise; GDP and population are World Bank
2025 figures ([WDI API](https://api.worldbank.org/v2/country/BRA;MEX;ITA;POL;EUU;WLD/indicator/NY.GDP.MKTP.CD?date=2025&format=json);
world GDP US$118.35 tn, world population 8.215 bn).

### By jurisdiction

| Jurisdiction | Population | GDP (US$) | Share of world GDP | Platform and model | Volume |
|---|---|---|---|---|---|
| Brazil | 212.8 m | 2.28 tn | 1.93% | SEFAZ clearance: each invoice is authorized before the goods move | 62.4 bn NF-e authorized since 2006, about 9.0 bn a year now, from 2.99 m active issuers ([Portal NF-e](https://www.nfe.fazenda.gov.br/portal/infoEstatisticas.aspx), Oct 2026; the yearly rate is derived from archived counter snapshots) |
| Mexico | 132.0 m | 1.83 tn | 1.55% | SAT clearance through authorized certification providers (PAC) | 10.32 bn CFDI in 2023 ([SAT](https://www.gob.mx/sat/prensa/contribuyentes-emiten-mas-de-10-mil-millones-de-facturas-electronicas-en-2023-018-2024)); 11.40 bn in 2025 (IMCP citing SAT) |
| Italy | 58.9 m | 2.55 tn | 2.16% | SdI clearance (Agenzia delle Entrate) | about 2.4 bn invoice files in 2025 ([Agenzia Entrate, I risultati 2025](https://www.agenziaentrate.gov.it/portale/documents/d/guest/risultati_2025_25-03-26), via press reports) |
| Poland | 36.4 m | 1.04 tn | 0.87% | KSeF central repository | 657.4 m invoices from 2.37 m issuers between 1 Feb and 2 Sep 2026 ([Finance Ministry answer to the Sejm](https://api.sejm.gov.pl/sejm/term10/interpellations/attachment/ATTDXYJ6L/i19230-o1.pdf)) |
| European Union (27) | 451.1 m | 21.24 tn | 17.95% | EN 16931: public buyers must accept it ([Directive 2014/55/EU](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32014L0055)); Peppol for exchange | Peppol: 23 national authorities, documents exchanged in 65 countries ([OpenPeppol](https://peppol.org/openpeppol-welcomes-the-peppol-authority-for-france/), 2025) |

### In aggregate

| Set | Share of world GDP | Share of world population | What it means |
|---|---|---|---|
| Brazil + Mexico | 3.47% | 4.20% | complete national clearance coverage |
| Brazil + Mexico + Italy + Poland | 6.51% (US$7.70 tn) | 5.36% (440 m) | every national clearance schema targeted here |
| Brazil + Mexico + EU-27 | **21.42%** (US$25.36 tn) | **9.69%** (796 m) | upper bound of today's reach |

The four clearance platforms together handle roughly 24 billion documents a year (derived; their scopes differ: CFDI
also covers payroll and payment receipts, and KSeF is not universal until 2027).

Two limits on the EU row:

- **It is reach for sending to the public sector.** Every EU public buyer must accept EN 16931 in both of its syntaxes,
  so UBL output reaches all of them. National B2B mandates add their own profiles (XRechnung, CIUS-RO, HR-CIUS,
  CIUS-PT, Peppol BIS), and some accept only CII or Factur-X, which `fiscal` does not generate.
- **B2B arrives with ViDA.** Under [VAT in the Digital Age](https://taxation-customs.ec.europa.eu/taxation/vat/vat-digital-age-vida_en)
  (Directive (EU) 2025/516), member states may mandate domestic e-invoicing without a derogation since 14 April 2025,
  EN 16931 e-invoices with digital reporting become the default for intra-EU B2B on 1 July 2030, and national systems
  must align by 1 January 2035. The Commission estimates it cuts VAT fraud by up to EUR 11 bn a year, against an EU VAT
  gap of [EUR 128 bn (9.5%) in 2023](https://taxation-customs.ec.europa.eu/taxation/vat/fight-against-vat-fraud/vat-gap_en).

## Potential

Outside what is covered, 26 jurisdictions with live or announced mandates add **33.98% of world GDP and 48.79% of
world population** (derived from World Bank 2025). With today's reach that is **55.4% of world GDP and 58.5% of the
world's population** under some form of mandated e-invoicing or continuous transaction control. The United States
(26.0% of world GDP) has no federal mandate.

How much new work each one takes depends on its syntax. UBL 2.1 is already generated, so the countries that use it
need a profile (a CIUS, a PINT specialization or national code lists), not a new schema family:

| UBL 2.1 transfers, with a profile | UBL is one option among several | A new national schema is needed |
|---|---|---|
| Belgium, Croatia, Romania, Portugal (public sector), Serbia, Türkiye (UBL-TR), Saudi Arabia (ZATCA), UAE (PINT AE), Malaysia, Singapore (PINT SG), Australia and New Zealand (PINT A-NZ), Japan (JP PINT), Colombia (DIAN), Peru (SUNAT); probably Norway, Luxembourg, Latvia and the UK | France (UBL, CII or Factur-X), Germany (XRechnung in UBL or CII, ZUGFeRD), Spain (UBL, CII, EDIFACT or Facturae), Greece, Slovakia, Ireland, Estonia, Slovenia, the Netherlands | India, China, South Korea, Hungary, Egypt, Kenya, Chile, Argentina, Ecuador, Uruguay, Costa Rica, Guatemala, Dominican Republic, Paraguay, Bolivia, El Salvador |

### By region

| Region | Share of world GDP | Share of world population | Mandates (model, start) |
|---|---|---|---|
| Asia-Pacific (India, China, Japan, South Korea, Malaysia, Singapore, Australia, New Zealand, the Philippines) | 28.21% | 39.41% | China's fully digitalized e-fapiao is nationwide since Dec 2024 (clearance); India's GST invoice registration covers turnover above INR 5 crore since Aug 2023 (clearance, JSON); Malaysia's MyInvois phased in 2024-2026 (UBL 2.1); Singapore's InvoiceNow phases in 2028-2031 (Peppol) |
| Middle East and Africa (Türkiye, Saudi Arabia, UAE, Egypt, Kenya, Oman, Nigeria) | 3.66% | 6.73% | Saudi Arabia's FATOORA integrates taxpayers in waves since 2023, wave 25 by Feb 2027 (UBL 2.1); the UAE goes live in Jan 2027 for revenue above AED 50 m (Peppol PINT AE); Kenya's eTIMS is mandatory for all businesses since Sep 2023 |
| Latin America beyond Brazil and Mexico (Chile, Colombia, Peru, Argentina, Ecuador, Uruguay, Costa Rica, Guatemala, Dominican Republic) | 2.03% | 2.57% | clearance almost everywhere; Colombia (DIAN) and Peru (SUNAT) use UBL 2.1 profiles, the rest national XML; Costa Rica's v4.4 is mandatory from Nov 2026 |
| European Union (not yet profiled) | (inside the EU-27 row above) | | France receives from Sep 2026, issues by size from Sep 2026 and Sep 2027; Germany receives since Jan 2025, issues from 2027/2028; Belgium is on Peppol since Jan 2026; Croatia since Jan 2026; Romania clears since Jul 2024; Greece's second wave starts Nov 2026; Spain's B2B start awaits a ministerial order |

Country dates in this table come mostly from secondary compilations (VATupdate's July 2026 data cards, Big Four and
vendor alerts) where the official page was unreachable; several moved during 2026 (Greece, the UAE provider deadline,
Spain's Verifactu), so treat them as the state in October 2026.

### Market context

- B2B e-invoices worldwide: about 87 bn of roughly 300 bn B2B invoices in 2026 (29%), forecast at 107 bn by 2030
  ([Billentis](https://www.billentis.com/en/), a vendor-sponsored report).
- Commercial estimates put the e-invoicing software market at roughly US$18-25 bn in 2025
  ([IMARC](https://www.imarcgroup.com/global-e-invoicing-market), [TBRC](https://www.giiresearch.com/report/tbrc1808739-e-invoicing-global-market-report.html)).
- Brazil's consumption-tax reform ([LC 214/2025](https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp214.htm)) adds
  IBS/CBS groups to every Brazilian document from 2026 (test rates) through 2033, when ICMS and ISS end, so the NF-e
  family keeps gaining layout versions; regenerating from the published schema is how this project follows them.

## How it works

```
deps/corpus/*.xsd ──xml.read_xml──▶ xsd.read_schema ──xsd_resolve──▶ schema tree ──generator.spi──▶ src/generated_*.spi
                                                                                                        │
                                          samples/generated_*_example.xml ◀── each module's example test ┘
```

- `src/generator.spi` maps a resolved schema to Spiral: sequences become records (occurs become `option` or `list`),
  choices and enumerations become unions (shared by value set), facet-constrained strings get validators whose patterns
  are compiled to DFA tables by `xsd_regex`. Its tests write every generated module to `generated/<module>/`,
  each beside a one-module `package.spiproj`, so a test cell type-checks only its own module.
- Each generated module carries its own test, which builds the module's example document and writes it to `samples/`
  (the NF-e 4.00 module also parses an address back and checks the XML round trip). `scripts/family-gates.ps1`
  then validates every example against the official XSD with .NET's `XmlSchemaSet`.
- `src/corpus_checks.spi` pins the reader and the regex engine to independent oracles over the whole corpus: element
  and attribute counts against .NET's XML DOM, include resolution against `XmlSchemaSet` (`scripts/resolve-check.ps1`),
  and every distinct pattern of every corpus schema against .NET regex on generated probes: 271, of which 196 are
  Brazilian and 75 come from the other families (`scripts/pattern-oracle.ps1` derives the list into `src/patterns.txt`).

## Building

```powershell
pwsh scripts/init.ps1      # deps/spiral (a sibling spiral checkout, or a clone) and the schema corpus in deps/corpus
pwsh scripts/build.ps1     # pattern oracle, generator (writes generated/), then every test file through Cells
pwsh scripts/publish.ps1   # dist/: the source tree and the example documents as a browsable page
```

`build.ps1 -Files generator,corpus_checks` runs a subset. CI (`.github/workflows/gh-pages.yml`) runs the same three
steps on Ubuntu and Windows and publishes `dist` to GitHub Pages.

Generated modules, example documents and the pattern oracle's output are build products: they are ignored by git and
rebuilt by `build.ps1`, which regenerates everything before it tests.

## Layout

| Path | What |
|---|---|
| `src/generator.spi` | schema-to-Spiral generator and the family roots it writes |
| `generated/<module>/` | one generated module and its one-module package (a build product, ignored) |
| `src/corpus.spi`, `src/corpus_checks.spi` | corpus census and oracle checks |
| `src/fiscal_paths.spi` | repository root (`FISCAL_ROOT`, or the folder above that holds `src/generator.spi`) |
| `src/corpus.txt` | the Brazilian corpus file list |
| `scripts/` | init, build, publish, the example validator and the .NET oracles |

## Known limits

- EU coverage is UBL only. CII and its Factur-X / ZUGFeRD profiles (France's 2026 B2B mandate, Germany) are the next
  system, chosen because their five profiles are restricted XSDs of one document, a dimension the generic model does
  not express yet.
- Facet-constrained values are plain string aliases, and the generated readers do not call their validators, so an
  invalid value reads without error. Each constrained type is planned to become a nominal type built only through its
  validator, which makes a raw string where a validated value is expected a type error.
