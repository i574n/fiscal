program bench_acbr;

{$mode delphi}{$H+}
{$modeswitch functionreferences}
{$modeswitch anonymousfunctions}

uses
  Windows, SysUtils, Classes, StrUtils,
  ACBrDFe, ACBrNFe, pcnConversaoNFe, ACBrDFeSSL,
  ACBrCTe, pcteConversaoCTe,
  ACBrMDFe, ACBrMDFe.Conversao;

const
  WarmUps = 5;
  Measured = 31;

type
  TOperation = reference to procedure;
  TLoad = reference to function: Boolean;
  TWrite = reference to function: String;

var
  Frequency: Int64;
  NFe: TACBrNFe;
  CTe: TACBrCTe;
  MDFe: TACBrMDFe;
  Rows: TStringList;
  Corpus, Xml, Written, Verdict: String;
  Index: Integer;

function Median(Operation: TOperation): Double;
var
  Samples: array of Double;
  Start, Stop: Int64;
  I, J: Integer;
  Held: Double;
begin
  for I := 1 to WarmUps do Operation();
  SetLength(Samples, Measured);
  for I := 0 to Measured - 1 do
  begin
    QueryPerformanceCounter(Start);
    Operation();
    QueryPerformanceCounter(Stop);
    Samples[I] := (Stop - Start) * 1000000.0 / Frequency;
  end;
  for I := 1 to Measured - 1 do
  begin
    Held := Samples[I];
    J := I - 1;
    while (J >= 0) and (Samples[J] > Held) do
    begin
      Samples[J + 1] := Samples[J];
      Dec(J);
    end;
    Samples[J + 1] := Held;
  end;
  Result := Samples[Measured div 2];
end;

function Has(const Version: String): Boolean;
begin
  Result := Pos('versao="' + Version + '"', Xml) > 0;
end;

function Row(const Document, Operation: String; MedianMicros: Double; Runs: Integer; const Verdict: String): String;
begin
  Result := Format('acbr'#9'%s'#9'%s'#9'%.1f'#9'%d'#9'%s',
    [Document, Operation, MedianMicros, Runs, Verdict], DefaultFormatSettings);
end;

procedure Unsupported(const Document, What: String);
begin
  Rows.Add('acbr'#9 + Document + #9'parse'#9#9'0'#9'unsupported:' + What);
  Rows.Add('acbr'#9 + Document + #9'serialize'#9#9'0'#9'unsupported:' + What);
  Rows.Add('acbr'#9 + Document + #9'validate'#9#9'0'#9'unsupported:' + What);
end;

procedure Measure(const Document: String; Load: TLoad; Write: TWrite; Check: TOperation);
var
  Loaded: Boolean;
  Seconds: Double;
begin
  Loaded := False;
  Seconds := Median(procedure begin Loaded := Load(); end);
  Rows.Add(Row(Document, 'parse', Seconds, Measured, IfThen(Loaded, 'ok', 'failed')));
  if not Loaded then Exit;

  Seconds := Median(procedure begin Written := Write(); end);
  with TStringList.Create do
  try
    Text := Written;
    SaveToFile(ExtractFilePath(ExpandFileName(ParamStr(2))) + 'acbr-' + Document);
  finally
    Free;
  end;
  Rows.Add(Row(Document, 'serialize', Seconds, Measured, 'written'));

  Verdict := 'valid';
  Seconds := Median(procedure
    begin
      try
        Check();
      except
        on E: Exception do Verdict := 'invalid';
      end;
    end);
  Rows.Add(Row(Document, 'validate', Seconds, Measured, Verdict));
end;

procedure BenchNFe(const Document: String);
begin
  if Has('4.00') then NFe.Configuracoes.Geral.VersaoDF := TpcnVersaoDF.ve400
  else if Has('3.10') then NFe.Configuracoes.Geral.VersaoDF := TpcnVersaoDF.ve310
  else if Has('2.00') then NFe.Configuracoes.Geral.VersaoDF := TpcnVersaoDF.ve200
  else begin Unsupported(Document, 'NFe version'); Exit; end;
  Measure(Document,
    function: Boolean begin NFe.NotasFiscais.Clear; Result := NFe.NotasFiscais.LoadFromString(Xml); end,
    function: String begin Result := NFe.NotasFiscais[0].GerarXML; end,
    procedure begin NFe.NotasFiscais[0].Validar; end);
end;

procedure BenchCTe(const Document: String; Model: TModeloCTe);
begin
  if Has('4.00') then CTe.Configuracoes.Geral.VersaoDF := TVersaoCTe.ve400
  else if Has('3.00') then CTe.Configuracoes.Geral.VersaoDF := TVersaoCTe.ve300
  else if Has('2.00') then CTe.Configuracoes.Geral.VersaoDF := TVersaoCTe.ve200
  else begin Unsupported(Document, 'CTe version'); Exit; end;
  CTe.Configuracoes.Geral.ModeloDF := Model;
  Measure(Document,
    function: Boolean begin CTe.Conhecimentos.Clear; Result := CTe.Conhecimentos.LoadFromString(Xml); end,
    function: String begin Result := CTe.Conhecimentos[0].GerarXML; end,
    procedure begin CTe.Conhecimentos[0].Validar; end);
end;

procedure BenchMDFe(const Document: String);
begin
  if Has('3.00') then MDFe.Configuracoes.Geral.VersaoDF := TVersaoMDFe.ve300
  else if Has('1.00') then MDFe.Configuracoes.Geral.VersaoDF := TVersaoMDFe.ve100
  else begin Unsupported(Document, 'MDFe version'); Exit; end;
  Measure(Document,
    function: Boolean begin MDFe.Manifestos.Clear; Result := MDFe.Manifestos.LoadFromString(Xml); end,
    function: String begin Result := MDFe.Manifestos[0].GerarXML; end,
    procedure begin MDFe.Manifestos[0].Validar; end);
end;

procedure Bench(const Path: String);
var
  Document: String;
begin
  Document := ExtractFileName(Path);
  with TStringList.Create do
  try
    LoadFromFile(Path);
    Xml := Text;
  finally
    Free;
  end;
  if Pos('</NFe>', Xml) > 0 then BenchNFe(Document)
  else if Pos('</CTeOS>', Xml) > 0 then BenchCTe(Document, TModeloCTe.moCTeOS)
  else if Pos('</GTVe>', Xml) > 0 then BenchCTe(Document, TModeloCTe.moGTVe)
  else if Pos('</CTeSimp>', Xml) > 0 then BenchCTe(Document, TModeloCTe.moCTeSimp)
  else if Pos('</CTe>', Xml) > 0 then BenchCTe(Document, TModeloCTe.moCTe)
  else if Pos('</MDFe>', Xml) > 0 then BenchMDFe(Document)
  else Unsupported(Document, 'root');
end;

procedure UseOpenSsl(Component: TACBrDFe; const Schemas: String);
begin
  Component.Configuracoes.Geral.SSLLib := libOpenSSL;
  Component.Configuracoes.Geral.SSLXmlSignLib := xsLibXml2;
  Component.Configuracoes.Arquivos.PathSchemas := Schemas;
end;

begin
  if ParamCount < 3 then
  begin
    WriteLn(ErrOutput, 'usage: bench_acbr <corpus folder> <out.tsv> <document.xml>...');
    Halt(2);
  end;
  QueryPerformanceFrequency(Frequency);
  Corpus := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
  NFe := TACBrNFe.Create(nil);
  CTe := TACBrCTe.Create(nil);
  MDFe := TACBrMDFe.Create(nil);
  Rows := TStringList.Create;
  try
    UseOpenSsl(NFe, Corpus + 'NFe.AppTeste\Schemas');
    UseOpenSsl(CTe, Corpus + 'CTe.AppTeste\schemas');
    UseOpenSsl(MDFe, Corpus + 'MDFe.AppTeste\Schemas');
    Rows.Add('library'#9'document'#9'operation'#9'median_us'#9'runs'#9'verdict');
    for Index := 3 to ParamCount do Bench(ParamStr(Index));
    Rows.SaveToFile(ParamStr(2));
    WriteLn('wrote ', Rows.Count - 1, ' rows to ', ParamStr(2));
  finally
    Rows.Free;
    MDFe.Free;
    CTe.Free;
    NFe.Free;
  end;
end.
