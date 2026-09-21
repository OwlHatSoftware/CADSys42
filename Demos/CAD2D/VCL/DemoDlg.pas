{ : The handful of dialogs the demo needs, in one place.

  The VCL counterpart of Demos\CAD2D\FMX\DemoDlg.pas. Same interface,
  deliberately: the two MainFrm units are meant to be diffed against
  each other, and they can only be if everything around them presents
  the same face.

  Here the implementations are one-liners over Vcl.Dialogs. That is the
  point - the wrapper earns its keep on the FMX side, where the
  equivalents are spelled differently and have changed spelling more
  than once. Keeping it on both sides costs three short functions and
  removes a difference that would otherwise be noise in every diff. }
unit DemoDlg;

interface

uses
  System.SysUtils, System.UITypes;

{: Asks for one string. Returns False if the user cancelled. }
function AskString(const ACaption, APrompt: string;
  var AValue: string): Boolean;
{: Asks for two strings at once - a point, in practice. }
function AskTwoStrings(const ACaption, APrompt1, APrompt2: string;
  var AValue1, AValue2: string): Boolean;
{: Says something and waits for an acknowledgement. }
procedure Say(const AMessage: string);

implementation

uses
  Vcl.Dialogs;

function AskString(const ACaption, APrompt: string;
  var AValue: string): Boolean;
begin
  Result := InputQuery(ACaption, APrompt, AValue);
end;

function AskTwoStrings(const ACaption, APrompt1, APrompt2: string;
  var AValue1, AValue2: string): Boolean;
var
  TmpValues: array of string;
begin
  SetLength(TmpValues, 2);
  TmpValues[0] := AValue1;
  TmpValues[1] := AValue2;
  Result := InputQuery(ACaption, [APrompt1, APrompt2], TmpValues);
  if Result then
  begin
    AValue1 := TmpValues[0];
    AValue2 := TmpValues[1];
  end;
end;

procedure Say(const AMessage: string);
begin
  ShowMessage(AMessage);
end;

end.
