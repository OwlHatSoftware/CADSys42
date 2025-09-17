program Project1;

uses
  Forms,
  Unit1 in 'Unit1.pas' {Form1},
  DefLayersFrm in 'DefLayersFrm.pas' {DefLayersForm};

{$R *.RES}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
