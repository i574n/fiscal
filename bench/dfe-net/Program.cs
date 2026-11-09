using System.Diagnostics;
using System.Xml.Linq;
using DFe.Classes.Flags;
using DFe.Utils;
using NFe.Classes.Servicos.Tipos;
using CteVersion = CTe.Classes.Servicos.Tipos.versao;
using MdfeVersion = MDFe.Utils.Flags.VersaoServico;

const int WarmUps = 5;
const int Measured = 31;

if (args.Length < 3)
{
    Console.Error.WriteLine("usage: Bench <corpus folder> <out.tsv> <document.xml>...");
    return 2;
}

var corpus = Path.GetFullPath(args[0]);
var output = Path.GetDirectoryName(Path.GetFullPath(args[1]))!;
var rows = new List<string> { "library\tdocument\toperation\tmedian_us\truns\tverdict" };

foreach (var path in args.Skip(2))
{
    var document = Path.GetFileName(path);
    var xml = File.ReadAllText(path);
    var parsedDocument = XDocument.Parse(xml);
    var root = parsedDocument.Root!.Name.LocalName;
    var version = LayoutVersion(parsedDocument);
    switch (root)
    {
        case "NFe":
            Bench<NFe.Classes.NFe>(document, xml, NFeValidation(xml, version, Path.Combine(corpus, "NFe.AppTeste", "Schemas")));
            break;
        case "CTe":
            Bench<CTe.Classes.CTe>(document, xml, CteValidation(xml, $"cte_v{version}.xsd", version));
            break;
        case "CTeOS":
            Bench<CTe.CTeOSClasses.CTeOS>(document, xml, CteValidation(xml, $"cteOS_v{version}.xsd", version));
            break;
        case "CTeSimp":
            Bench<CTe.Classes.Simplificado.cteSimp>(document, xml, CteValidation(xml, $"cteSimp_v{version}.xsd", version));
            break;
        case "MDFe":
            var layout = version switch { "1.00" => MdfeVersion.Versao100, "3.00" => MdfeVersion.Versao300, _ => (MdfeVersion?)null };
            if (layout is null) { Unsupported(document, $"MDFe {version}"); break; }
            MDFe.Utils.Configuracoes.MDFeConfiguracao.Instancia.VersaoWebService.VersaoLayout = layout.Value;
            Bench<MDFe.Classes.Informacoes.MDFe>(document, xml, MdfeValidation(xml, $"mdfe_v{version}.xsd"));
            break;
        default:
            Unsupported(document, root);
            break;
    }
}

File.WriteAllLines(args[1], rows);
Console.WriteLine($"wrote {rows.Count - 1} rows to {args[1]}");
return 0;

void Bench<T>(string document, string xml, Func<string>? validate) where T : class
{
    T? parsed = null;
    double[] parse;
    try { parse = Measure(() => parsed = FuncoesXml.XmlStringParaClasse<T>(xml)); }
    catch (Exception failure)
    {
        rows.Add($"dfe.net\t{document}\tparse\t\t0\tfailed:{Reason(failure)}");
        return;
    }
    rows.Add(Row(document, "parse", parse, parsed is null ? "failed" : "ok"));
    if (parsed is null) return;
    var written = "";
    double[] serialize;
    try { serialize = Measure(() => written = FuncoesXml.ClasseParaXmlString(parsed)); }
    catch (Exception failure)
    {
        rows.Add($"dfe.net\t{document}\tserialize\t\t0\tfailed:{Reason(failure)}");
        return;
    }
    File.WriteAllText(Path.Combine(output, "dfe.net-" + document), written);
    rows.Add(Row(document, "serialize", serialize, "written"));
    if (validate is null)
    {
        rows.Add($"dfe.net\t{document}\tvalidate\t\t0\tunsupported");
        return;
    }
    var verdict = "";
    var validation = Measure(() => verdict = validate());
    rows.Add(Row(document, "validate", validation, verdict));
}

void Unsupported(string document, string what)
{
    foreach (var operation in new[] { "parse", "serialize", "validate" })
        rows.Add($"dfe.net\t{document}\t{operation}\t\t0\tunsupported:{what}");
}

Func<string>? NFeValidation(string xml, string? version, string schemas)
{
    VersaoServico? service = version switch { "4.00" => VersaoServico.Versao400, "3.10" => VersaoServico.Versao310, _ => null };
    if (service is null) return null;
    return () =>
    {
        var messages = NFe.Utils.Validacao.Validador.Valida(ServicoNFe.NFeAutorizacao, service.Value, xml, false, schemas);
        return messages.Length == 0 ? "valid" : $"invalid:{messages.Length}";
    };
}

Func<string>? CteValidation(string xml, string schema, string? version)
{
    CteVersion? layout = version switch { "2.00" => CteVersion.ve200, "3.00" => CteVersion.ve300, "4.00" => CteVersion.ve400, _ => null };
    if (layout is null) return null;
    var configuration = new CTe.Classes.ConfiguracaoServico
    {
        DiretorioSchemas = Path.Combine(corpus, "CTe.AppTeste", "schemas"),
        VersaoLayout = layout.Value,
    };
    return () => Throwing(() => CTe.Utils.Validacao.Validador.Valida(xml, schema, configuration));
}

Func<string> MdfeValidation(string xml, string schema)
{
    var configuration = new MDFe.Utils.Configuracoes.MDFeConfiguracao { CaminhoSchemas = Path.Combine(corpus, "MDFe.AppTeste", "Schemas") };
    configuration.VersaoWebService.VersaoLayout = MDFe.Utils.Configuracoes.MDFeConfiguracao.Instancia.VersaoWebService.VersaoLayout;
    return () => Throwing(() => MDFe.Utils.Validacao.Validador.Valida(xml, schema, configuration));
}

static string Throwing(Action validate)
{
    try
    {
        validate();
        return "valid";
    }
    catch (Exception failure)
    {
        return "invalid:" + failure.Message.Split('\n').Last().Trim().Replace('\t', ' ');
    }
}

static string Reason(Exception failure)
{
    var innermost = failure;
    while (innermost.InnerException is not null) innermost = innermost.InnerException;
    return innermost.Message.Replace('\t', ' ').Replace('\r', ' ').Replace('\n', ' ');
}

static string? LayoutVersion(XDocument document) =>
    document.Descendants().FirstOrDefault(e => e.Name.LocalName.StartsWith("inf") && e.Attribute("versao") is not null)?.Attribute("versao")?.Value;

static double[] Measure(Action operation)
{
    for (var i = 0; i < WarmUps; i++) operation();
    var samples = new double[Measured];
    var clock = new Stopwatch();
    for (var i = 0; i < Measured; i++)
    {
        clock.Restart();
        operation();
        samples[i] = clock.Elapsed.TotalMicroseconds;
    }
    Array.Sort(samples);
    return samples;
}

static string Row(string document, string operation, double[] samples, string verdict) =>
    $"dfe.net\t{document}\t{operation}\t{samples[samples.Length / 2]:F1}\t{samples.Length}\t{verdict}";
