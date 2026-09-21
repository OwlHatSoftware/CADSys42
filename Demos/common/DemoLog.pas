{ : A step log for the demos, written next to the exe.

  Shared by both the VCL and the FMX CAD2D demo, and framework-free on
  purpose: the two demos are meant to be diffed against each other, so
  anything that can be common is common.

  It exists because a failure during construction arrives as a Windows
  "application error" with no indication of where it happened. Rather
  than guess from the outside, a demo says what it is about to do before
  it does it, so the last line in the file is the thing that failed.

  Deliberately crude: a text file opened, appended to and closed on
  every line. Nothing is buffered, so the log survives a hard crash that
  never unwinds the stack. }
unit DemoLog;

interface

uses
  System.SysUtils, System.Classes;

{: Appends one line. Never raises: a logger that can fail takes the
   blame for failures that are not its own. }
procedure Log(const AMessage: string);
{: Starts a fresh file and records where and when. }
procedure LogStart;
{: Records an exception with its class and message. }
procedure LogError(const AWhere: string; const E: Exception);
{: The log's full path, for telling the user where to look. }
function LogFileName: string;

implementation

function LogFileName: string;
begin
  Result := ChangeFileExt(ParamStr(0), '.log');
end;

procedure Log(const AMessage: string);
var
  TmpFile: TextFile;
begin
  try
    AssignFile(TmpFile, LogFileName);
    if FileExists(LogFileName) then
      Append(TmpFile)
    else
      Rewrite(TmpFile);
    try
      Writeln(TmpFile, FormatDateTime('hh:nn:ss.zzz', Now), '  ', AMessage);
    finally
      CloseFile(TmpFile);
    end;
  except
    { A failing logger must not become the failure being investigated. }
  end;
end;

procedure LogStart;
begin
  try
    if FileExists(LogFileName) then
      DeleteFile(LogFileName);
  except
  end;
  Log('CADSysFMXDemo starting');
  Log('  exe: ' + ParamStr(0));
end;

procedure LogError(const AWhere: string; const E: Exception);
begin
  if E = nil then
    Log('FAILED in ' + AWhere + ': unknown error')
  else
    Log('FAILED in ' + AWhere + ': ' + E.ClassName + ' - ' + E.Message);
end;

end.
