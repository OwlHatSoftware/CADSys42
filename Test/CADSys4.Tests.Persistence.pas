{ : DUnitX tests for the CADSys 4.2 persistence layer.

  Two halves:

  1. Native stream persistence - TGraphicObject.SaveToStream /
  CreateFromStream, the TCADCmp2D whole-document round trip, TLayers
  streaming, source blocks, and the class registry that resolves a
  streamed class index back to a class reference.

  2. DXF text persistence - TDXFWrite / TDXFRead group round trips,
  the extended (1000+) group-code remap, the per-entity table clear,
  and locale independence of the float parser.

  Environment notes:
  - Console runner. VCL is linked but there is no form and no window
  handle, so no Draw* method is ever called and no TCADViewport* is
  ever instantiated.
  - CADSysRegister MUST stay in the uses clause: its initialization
  section populates GraphicObjectsRegistered (and _DefaultHandler2D).
  Without it every CreateFromStream raises ECADObjClassNotFound.
  - TGraphicObject descends from TInterfacedObject, so no graphic
  object is ever assigned to an interface variable here.
}
unit CADSys4.Tests.Persistence;

interface

uses
  DUnitX.TestFramework;

type
  { : Round trips of a single shape through a TMemoryStream. }
  [TestFixture]
  TShapeStreamRoundTripTests = class(TObject)
  public
    [Test]
    procedure Line2D_RoundTrip_PreservesEndpoints;
    [Test]
    procedure Polyline2D_RoundTrip_PreservesAllControlPoints;
    [Test]
    procedure Polygon2D_RoundTrip_PreservesClassAndPoints;
    [Test]
    procedure Rectangle2D_RoundTrip_PreservesCornersAndCurvePrecision;
    [Test]
    procedure Frame2D_RoundTrip_PreservesSavingType;
    [Test]
    procedure Ellipse2D_RoundTrip_PreservesCorners;
    [Test]
    procedure Arc2D_RoundTrip_PreservesControlPointsAndDirection;
    [Test]
    procedure BSpline2D_RoundTrip_PreservesOrderAndPoints;
    [Test]
    procedure GraphicObject_RoundTrip_PreservesIDLayerAndFlags;
    [Test]
    procedure Object2D_RoundTrip_PreservesModelTransform;
    [Test]
    procedure Container2D_RoundTrip_PreservesChildrenAndGeometry;
    [Test]
    procedure RoundTrip_ConsumesExactlyTheBytesThatWereWritten;
  end;

  { : The persistence class registry (CADSys4.pas ~13588-13640). }
  [TestFixture]
  TClassRegistryTests = class(TObject)
  public
    [Test]
    procedure FindClassIndex_ReturnsIndexUsedByCADSysRegister;
    [Test]
    procedure FindClassByName_ReturnsTheClassReference;
    [Test]
    procedure FindClassByIndex_RoundTripsWithFindClassIndex;
    [Test]
    procedure FindClassIndex_UnknownName_RaisesECADObjClassNotFound;
    [Test]
    procedure FindClassByIndex_UnregisteredSlot_RaisesECADObjClassNotFound;
    [Test]
    procedure FindClassByIndex_OutOfBound_RaisesECADOutOfBound;
  end;

  { : Whole-document round trips through TCADCmp2D. }
  [TestFixture]
  TDocumentRoundTripTests = class(TObject)
  private
    FTempFile: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure EmptyDocument_RoundTrip_LoadsWithNoObjects;
    [Test]
    procedure Document_RoundTrip_PreservesObjectCount;
    [Test]
    procedure Document_RoundTrip_PreservesGeometryInOrder;
    [Test]
    procedure Document_RoundTrip_PreservesLayerAssignment;
    [Test]
    procedure Document_RoundTrip_ReassignsSequentialIDs;
    [Test]
    procedure Document_RoundTrip_PreservesShapeClasses;
    [Test]
    procedure Document_RoundTrip_ViaFile_PreservesGeometry;
    [Test]
    procedure ModifiedLayer_RoundTrip_PreservesNameAndFlags;
    [Test]
    procedure UnmodifiedLayer_IsNotStreamed;
    [Test]
    procedure NonStreamableLayer_ObjectsAreNotSaved;
    [Test]
    procedure SourceBlockAndBlock_RoundTrip_RelinkByName;
    [Test]
    procedure LoadFromStream_ForeignVersionHeader_RaisesECADFileNotValid;
    [Test]
    procedure SavedHeader_IsTheCurrentLibraryVersion;
  end;

  { : Tests that PIN a known, unfixed defect rather than paper over it.

    Finding X3: TCADVersion = array[1..6] of Char and
    TSourceBlockName = array[0..12] of Char (CADSys4.pas:526, 529).
    Under Unicode Delphi SizeOf(Char) = 2, so both types silently
    doubled in size and the on-disk layout changed with no version
    gate. A CAD423 file written by a Unicode build is NOT readable by
    an ANSI build and vice versa.

    Finding X4: TText2D streams its AnsiString fText using
    TmpInt * SizeOf(Char) bytes (CS4Shapes.pas:751, 4511-4513,
    4538-4541). The writer therefore emits two bytes per one-byte
    character - reading N characters past the end of the string
    buffer - and the reader allocates an N-byte AnsiString and then
    reads 2*N bytes into it, overrunning the heap block.

    These tests assert the CURRENT behaviour exactly. When the
    version-gating fix lands they will fail, and the failure message
    is the specification of what changed.
  }
  [TestFixture]
  TUnicodeLayoutDefectPinTests = class(TObject)
  public
    [Test]
    procedure Pin_X3_SizeOfTCADVersion_IsDoubledUnderUnicode;
    [Test]
    procedure Pin_X3_SizeOfTSourceBlockName_IsDoubledUnderUnicode;
    [Test]
    procedure Pin_X3_EmptyDocumentHeaderIs26BytesNot20;
    [Test]
    procedure Pin_X3_VersionHeaderOccupiesSizeOfTCADVersionBytes;
    [Test]
    procedure Pin_X4_Text2D_WritesTwoBytesPerAnsiChar;
    [Test]
    procedure Pin_X4_Text2D_StreamSizeFollowsTheUnicodeFormula;
    [Test]
    procedure Pin_X4_Text2D_RoundTripStillYieldsTheOriginalText;
  end;

  { : TDXFWrite / TDXFRead group-level round trips (CS4DXFModule.pas). }
  [TestFixture]
  TDXFGroupRoundTripTests = class(TObject)
  private
    FTempFile: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure StringGroups_SurviveAWriteReadCycle;
    [Test]
    procedure FloatGroups_SurviveToSixDecimalPlaces;
    [Test]
    procedure IntegerGroups_SurviveAWriteReadCycle;
    [Test]
    procedure ExtendedGroupCodes_RemapTo256AndAbove;
    [Test]
    procedure ReadAnEntry_ClearsTheTableBetweenEntities;
    [Test]
    procedure ReadAnEntry_AcceptsCode1256AtTheTableUpperBound;
    [Test]
    procedure ReadAnEntry_IgnoresGroupCodesAbove1256;
    [Test]
    procedure ConsumeGroup_ParsesFloats_WhenGlobalDecimalSeparatorIsComma;
    [Test]
    procedure ConsumeGroup_DoesNotWriteTheGlobalFormatSettings;
    [Test]
    procedure Reader_IdentifiesTheEntitiesSection;
    [Test]
    procedure NextSection_AdvancesFromHeaderToEntities;
    [Test]
    procedure Rewind_RepositionsAtTheFirstSection;
  end;

  { : One end-to-end DXF import through TDXF2DImport. }
  [TestFixture]
  TDXFImportRoundTripTests = class(TObject)
  private
    FTempFile: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ImportedLineEntity_LandsInTheCADWithItsCoordinates;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Variants,
  System.IOUtils,
  Winapi.Windows,
  CS4BaseTypes,
  CADSys4,
  CS4Shapes,
  CS4DXFModule,
  { Required: its initialization section fills the persistence class
    registry. Removing it makes every CreateFromStream below raise
    ECADObjClassNotFound. }
  CADSysRegister;

const
  { Exact geometry must survive a Double round trip bit for bit; a
    tolerance is used only to keep the intent readable. }
  TOL_EXACT = 1E-9;
  { Values that have passed through an accumulation, or through the
    DXF '%.6f' text form, which cannot promise more than six decimals. }
  TOL_DXF = 1E-6;

  { --------------------------------------------------------------- }
  { Local assertion helpers.                                          }
  {                                                                   }
  { These exist purely to pin down DUnitX overload resolution: every  }
  { argument is already of the exact parameter type, so there is no   }
  { implicit widening for the compiler to choose between.             }
  { --------------------------------------------------------------- }

procedure AssertReal(const AExpected, AActual, ATolerance: Double;
  const AMessage: string);
begin
  Assert.AreEqual(AExpected, AActual, ATolerance, AMessage);
end;

procedure AssertInt(const AExpected, AActual: Integer;
  const AMessage: string);
begin
  Assert.AreEqual(AExpected, AActual, AMessage);
end;

procedure AssertStr(const AExpected, AActual: string;
  const AMessage: string);
begin
  Assert.AreEqual(AExpected, AActual, AMessage);
end;

{ --------------------------------------------------------------- }
{ Shared fixture helpers.                                           }
{ --------------------------------------------------------------- }

{ : Save Obj, rewind, and rebuild it through the registry using the
  object's own class name - exactly the path TCADCmp2D takes, minus
  the class-index word. The caller owns the result. }
function SaveAndReload(const AObj: TGraphicObject;
  const AStream: TMemoryStream): TGraphicObject;
var
  TmpClass: TGraphicObjectClass;
begin
  AStream.Clear;
  AObj.SaveToStream(AStream);
  AStream.Position := 0;
  TmpClass := CADSysFindClassByName(AObj.ClassName);
  Result := TmpClass.CreateFromStream(AStream, CADSysVersion);
end;

{ : Assert that two control points match to TOL_EXACT. }
procedure AssertPoint(const AExpected, AActual: TPoint2D;
  const AMessage: string);
begin
  AssertReal(AExpected.X, AActual.X, TOL_EXACT, AMessage + ' (X)');
  AssertReal(AExpected.Y, AActual.Y, TOL_EXACT, AMessage + ' (Y)');
  AssertReal(AExpected.W, AActual.W, TOL_EXACT, AMessage + ' (W)');
end;

{ : Write a DXF file line by line. ASCII has no byte-order mark, which
  matters because TDXFRead opens the file as a classic TextFile and the
  first ReadLn parses a Word. }
procedure WriteRawDXF(const AFileName: string;
  const ALines: array of string);
var
  TmpList: TStringList;
  Cont: Integer;
begin
  TmpList := TStringList.Create;
  try
    for Cont := Low(ALines) to High(ALines) do
      TmpList.Add(ALines[Cont]);
    TmpList.SaveToFile(AFileName, TEncoding.ASCII);
  finally
    TmpList.Free;
  end;
end;

{ : TDXFRead.ConsumeGroup reads both lines of a group and only then
  tests EOF, discarding the very last group in the file. Every fixture
  therefore appends two throwaway string groups so that the groups the
  test cares about are always parsed. Both are string-valued:
  NextSection compares GroupValue against 'SECTION', and comparing a
  float Variant with a string raises. }
procedure WriteDXFTail(const AWriter: TDXFWrite);
begin
  AWriter.WriteGroup(0, 'EOF');
  AWriter.WriteGroup(0, 'EOF');
end;

{ =================================================================== }
{ TShapeStreamRoundTripTests                                          }
{ =================================================================== }

procedure TShapeStreamRoundTripTests.Line2D_RoundTrip_PreservesEndpoints;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TLine2D;
begin
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TLine2D.Create(7, Point2D(1.5, -2.25), Point2D(30.125, 40.5));
    try
      TmpDst := TLine2D(SaveAndReload(TmpSrc, TmpStream));
      try
        Assert.IsTrue(TmpDst is TLine2D, 'Reloaded object is a TLine2D');
        AssertInt(2, Integer(TmpDst.Points.Count), 'Control point count');
        AssertPoint(Point2D(1.5, -2.25), TmpDst.Points[0], 'Start point');
        AssertPoint(Point2D(30.125, 40.5), TmpDst.Points[1], 'End point');
        AssertInt(7, TmpDst.ID, 'Object ID');
      finally
        TmpDst.Free;
      end;
    finally
      TmpSrc.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TShapeStreamRoundTripTests.
  Polyline2D_RoundTrip_PreservesAllControlPoints;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TPolyline2D;
begin
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TPolyline2D.Create(0, [Point2D(0, 0), Point2D(10, 0),
      Point2D(10, 10), Point2D(0, 10)]);
    try
      TmpDst := TPolyline2D(SaveAndReload(TmpSrc, TmpStream));
      try
        AssertInt(4, Integer(TmpDst.Points.Count), 'Control point count');
        AssertPoint(Point2D(0, 0), TmpDst.Points[0], 'Point 0');
        AssertPoint(Point2D(10, 0), TmpDst.Points[1], 'Point 1');
        AssertPoint(Point2D(10, 10), TmpDst.Points[2], 'Point 2');
        AssertPoint(Point2D(0, 10), TmpDst.Points[3], 'Point 3');
      finally
        TmpDst.Free;
      end;
    finally
      TmpSrc.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TShapeStreamRoundTripTests.
  Polygon2D_RoundTrip_PreservesClassAndPoints;
var
  TmpStream: TMemoryStream;
  TmpSrc: TPolygon2D;
  TmpDst: TGraphicObject;
begin
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TPolygon2D.Create(3, [Point2D(1, 1), Point2D(5, 1),
      Point2D(3, 4)]);
    try
      TmpDst := SaveAndReload(TmpSrc, TmpStream);
      try
        { TPolygon2D shares TPolyline2D's streaming, so the only thing
          that keeps a polygon a polygon is the registry lookup. }
        Assert.IsTrue(TmpDst is TPolygon2D, 'Reloaded object is a TPolygon2D');
        AssertInt(3, Integer(TPolygon2D(TmpDst).Points.Count),
          'Control point count');
        AssertPoint(Point2D(3, 4), TPolygon2D(TmpDst).Points[2], 'Apex');
      finally
        TmpDst.Free;
      end;
    finally
      TmpSrc.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TShapeStreamRoundTripTests.
  Rectangle2D_RoundTrip_PreservesCornersAndCurvePrecision;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TRectangle2D;
begin
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TRectangle2D.Create(0, Point2D(-1, -2), Point2D(3, 4));
    try
      TmpSrc.CurvePrecision := 12;
      TmpDst := TRectangle2D(SaveAndReload(TmpSrc, TmpStream));
      try
        AssertInt(2, Integer(TmpDst.Points.Count), 'Corner count');
        AssertPoint(Point2D(-1, -2), TmpDst.Points[0], 'Lower-left corner');
        AssertPoint(Point2D(3, 4), TmpDst.Points[1], 'Upper-right corner');
        AssertInt(12, Integer(TmpDst.CurvePrecision), 'Curve precision');
      finally
        TmpDst.Free;
      end;
    finally
      TmpSrc.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TShapeStreamRoundTripTests.Frame2D_RoundTrip_PreservesSavingType;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TFrame2D;
begin
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TFrame2D.Create(0, Point2D(0, 0), Point2D(100, 50));
    try
      TmpSrc.SavingType := stSpace;
      TmpDst := TFrame2D(SaveAndReload(TmpSrc, TmpStream));
      try
        Assert.IsTrue(TmpDst.SavingType = stSpace,
          'TCurve2D.SavingType survives the round trip');
        AssertPoint(Point2D(100, 50), TmpDst.Points[1], 'Second corner');
      finally
        TmpDst.Free;
      end;
    finally
      TmpSrc.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TShapeStreamRoundTripTests.Ellipse2D_RoundTrip_PreservesCorners;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TEllipse2D;
begin
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TEllipse2D.Create(0, Point2D(-5.5, -5.5), Point2D(5.5, 5.5));
    try
      TmpDst := TEllipse2D(SaveAndReload(TmpSrc, TmpStream));
      try
        AssertInt(2, Integer(TmpDst.Points.Count), 'Bounding point count');
        AssertPoint(Point2D(-5.5, -5.5), TmpDst.Points[0], 'First corner');
        AssertPoint(Point2D(5.5, 5.5), TmpDst.Points[1], 'Second corner');
      finally
        TmpDst.Free;
      end;
    finally
      TmpSrc.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TShapeStreamRoundTripTests.
  Arc2D_RoundTrip_PreservesControlPointsAndDirection;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TArc2D;
  TmpP2, TmpP3: TPoint2D;
begin
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TArc2D.Create(0, Point2D(-10, -10), Point2D(10, 10), 0.0,
      Pi / 2.0);
    try
      TmpSrc.Direction := adCounterClockwise;
      { TArc2D streams only its direction; the angles live in control
        points 2 and 3 and are re-derived by PopulateCurvePoints. The
        invariant that is actually persisted is therefore the four
        control points plus the direction - assert that, not the
        angles. }
      TmpP2 := TmpSrc.Points[2];
      TmpP3 := TmpSrc.Points[3];
      TmpDst := TArc2D(SaveAndReload(TmpSrc, TmpStream));
      try
        AssertInt(4, Integer(TmpDst.Points.Count), 'Control point count');
        AssertPoint(Point2D(-10, -10), TmpDst.Points[0], 'Box corner 0');
        AssertPoint(Point2D(10, 10), TmpDst.Points[1], 'Box corner 1');
        AssertPoint(TmpP2, TmpDst.Points[2], 'Start-angle control point');
        AssertPoint(TmpP3, TmpDst.Points[3], 'End-angle control point');
        Assert.IsTrue(TmpDst.Direction = adCounterClockwise,
          'Arc direction survives the round trip');
      finally
        TmpDst.Free;
      end;
    finally
      TmpSrc.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TShapeStreamRoundTripTests.
  BSpline2D_RoundTrip_PreservesOrderAndPoints;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TBSpline2D;
begin
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TBSpline2D.Create(0, [Point2D(0, 0), Point2D(1, 5),
      Point2D(4, 5), Point2D(5, 0)]);
    try
      TmpSrc.Order := 4;
      TmpDst := TBSpline2D(SaveAndReload(TmpSrc, TmpStream));
      try
        AssertInt(4, Integer(TmpDst.Order), 'Spline order');
        AssertInt(4, Integer(TmpDst.Points.Count), 'Control point count');
        AssertPoint(Point2D(1, 5), TmpDst.Points[1], 'Control point 1');
        AssertPoint(Point2D(5, 0), TmpDst.Points[3], 'Control point 3');
      finally
        TmpDst.Free;
      end;
    finally
      TmpSrc.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TShapeStreamRoundTripTests.
  GraphicObject_RoundTrip_PreservesIDLayerAndFlags;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TLine2D;
begin
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TLine2D.Create(1234, Point2D(0, 0), Point2D(1, 1));
    try
      TmpSrc.Layer := 17;
      TmpSrc.Visible := False;
      TmpSrc.Enabled := True;
      TmpDst := TLine2D(SaveAndReload(TmpSrc, TmpStream));
      try
        AssertInt(1234, TmpDst.ID, 'ID');
        AssertInt(17, Integer(TmpDst.Layer), 'Layer');
        Assert.IsFalse(TmpDst.Visible, 'Visible flag');
        Assert.IsTrue(TmpDst.Enabled, 'Enabled flag');
        { TGraphicObject.SaveToStream stores ToBeSaved inverted for
          backward compatibility; the default True must survive. }
        Assert.IsTrue(TmpDst.ToBeSaved, 'ToBeSaved flag');
      finally
        TmpDst.Free;
      end;
    finally
      TmpSrc.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TShapeStreamRoundTripTests.
  Object2D_RoundTrip_PreservesModelTransform;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TLine2D;
  TmpT: TTransf2D;
begin
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TLine2D.Create(0, Point2D(0, 0), Point2D(1, 0));
    try
      TmpSrc.ModelTransform := Translate2D(12.5, -3.75);
      TmpDst := TLine2D(SaveAndReload(TmpSrc, TmpStream));
      try
        Assert.IsTrue(TmpDst.HasTransform,
          'The reloaded object still carries a transform');
        TmpT := TmpDst.ModelTransform;
        AssertReal(12.5, TmpT[3, 1], TOL_EXACT, 'Translation X');
        AssertReal(-3.75, TmpT[3, 2], TOL_EXACT, 'Translation Y');
        AssertReal(1.0, TmpT[1, 1], TOL_EXACT, 'Scale X');
        AssertReal(1.0, TmpT[2, 2], TOL_EXACT, 'Scale Y');
      finally
        TmpDst.Free;
      end;
    finally
      TmpSrc.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TShapeStreamRoundTripTests.
  Container2D_RoundTrip_PreservesChildrenAndGeometry;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TContainer2D;
  TmpIter: TGraphicObjIterator;
  TmpChild: TGraphicObject;
begin
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TContainer2D.Create(0,
      [TLine2D.Create(0, Point2D(0, 0), Point2D(1, 1)),
      TEllipse2D.Create(1, Point2D(2, 2), Point2D(6, 6))]);
    try
      TmpDst := TContainer2D(SaveAndReload(TmpSrc, TmpStream));
      try
        AssertInt(2, Integer(TmpDst.Objects.Count), 'Child count');
        TmpIter := TmpDst.Objects.GetIterator;
        try
          TmpChild := TmpIter.First;
          Assert.IsTrue(TmpChild is TLine2D, 'First child is a TLine2D');
          AssertPoint(Point2D(1, 1), TLine2D(TmpChild).Points[1],
            'First child end point');
          TmpChild := TmpIter.Next;
          Assert.IsTrue(TmpChild is TEllipse2D,
            'Second child is a TEllipse2D');
          AssertPoint(Point2D(2, 2), TEllipse2D(TmpChild).Points[0],
            'Second child first corner');
        finally
          TmpIter.Free;
        end;
      finally
        TmpDst.Free;
      end;
    finally
      TmpSrc.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TShapeStreamRoundTripTests.
  RoundTrip_ConsumesExactlyTheBytesThatWereWritten;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TPolyline2D;
  TmpWritten: Integer;
begin
  { A reader that stops short or overruns is the classic streaming bug.
    Position = Size after CreateFromStream is the invariant that says
    the writer and the reader agree on the record layout. }
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TPolyline2D.Create(0, [Point2D(0, 0), Point2D(1, 2),
      Point2D(3, 4)]);
    try
      TmpSrc.SaveToStream(TmpStream);
      TmpWritten := Integer(TmpStream.Size);
      TmpStream.Position := 0;
      TmpDst := TPolyline2D.CreateFromStream(TmpStream, CADSysVersion);
      try
        AssertInt(TmpWritten, Integer(TmpStream.Position),
          'CreateFromStream consumed exactly the bytes SaveToStream wrote');
        AssertInt(3, Integer(TmpDst.Points.Count), 'Control point count');
      finally
        TmpDst.Free;
      end;
    finally
      TmpSrc.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

{ =================================================================== }
{ TClassRegistryTests                                                 }
{ =================================================================== }

procedure TClassRegistryTests.FindClassIndex_ReturnsIndexUsedByCADSysRegister;
begin
  { These indices are the on-disk contract: a drawing stores the index,
    not the class name. Changing them silently breaks every saved file. }
  AssertInt(0, Integer(CADSysFindClassIndex('TContainer2D')),
    'TContainer2D registration index');
  AssertInt(1, Integer(CADSysFindClassIndex('TSourceBlock2D')),
    'TSourceBlock2D registration index');
  AssertInt(2, Integer(CADSysFindClassIndex('TBlock2D')),
    'TBlock2D registration index');
  AssertInt(3, Integer(CADSysFindClassIndex('TLine2D')),
    'TLine2D registration index');
  AssertInt(10, Integer(CADSysFindClassIndex('TText2D')),
    'TText2D registration index');
  AssertInt(13, Integer(CADSysFindClassIndex('TBSpline2D')),
    'TBSpline2D registration index');
end;

procedure TClassRegistryTests.FindClassByName_ReturnsTheClassReference;
begin
  Assert.IsTrue(CADSysFindClassByName('TLine2D') = TLine2D,
    'CADSysFindClassByName resolves TLine2D');
  Assert.IsTrue(CADSysFindClassByName('TRectangle2D') = TRectangle2D,
    'CADSysFindClassByName resolves TRectangle2D');
end;

procedure TClassRegistryTests.FindClassByIndex_RoundTripsWithFindClassIndex;
var
  TmpIdx: Word;
begin
  TmpIdx := CADSysFindClassIndex('TEllipse2D');
  Assert.IsTrue(CADSysFindClassByIndex(TmpIdx) = TEllipse2D,
    'Index -> class -> index is stable');
end;

procedure TClassRegistryTests.
  FindClassIndex_UnknownName_RaisesECADObjClassNotFound;
begin
  Assert.WillRaise(
    procedure
    begin
      CADSysFindClassIndex('TNotARegisteredShape2D');
    end, ECADObjClassNotFound,
    'An unregistered class name must not resolve silently');
end;

procedure TClassRegistryTests.
  FindClassByIndex_UnregisteredSlot_RaisesECADObjClassNotFound;
begin
  { CADSysRegister uses 0..14 and 50..70; 149 is free. A drawing file
    naming an empty slot must fail loudly. }
  Assert.WillRaise(
    procedure
    begin
      CADSysFindClassByIndex(149);
    end, ECADObjClassNotFound,
    'An empty registration slot must raise');
end;

procedure TClassRegistryTests.FindClassByIndex_OutOfBound_RaisesECADOutOfBound;
begin
  Assert.WillRaise(
    procedure
    begin
      CADSysFindClassByIndex(MAX_REGISTERED_CLASSES);
    end, ECADOutOfBound,
    'An index at or past MAX_REGISTERED_CLASSES must raise');
end;

{ =================================================================== }
{ TDocumentRoundTripTests                                             }
{ =================================================================== }

procedure TDocumentRoundTripTests.Setup;
begin
  FTempFile := TPath.GetTempFileName;
end;

procedure TDocumentRoundTripTests.TearDown;
begin
  if (FTempFile <> '') and TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
  FTempFile := '';
end;

procedure TDocumentRoundTripTests.EmptyDocument_RoundTrip_LoadsWithNoObjects;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TCADCmp2D;
begin
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TCADCmp2D.Create(nil);
    try
      TmpSrc.SaveToStream(TmpStream);
    finally
      TmpSrc.Free;
    end;
    TmpStream.Position := 0;
    TmpDst := TCADCmp2D.Create(nil);
    try
      TmpDst.LoadFromStream(TmpStream);
      AssertInt(0, TmpDst.ObjectsCount, 'Object count');
      AssertInt(0, TmpDst.SourceBlocksCount, 'Source block count');
    finally
      TmpDst.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TDocumentRoundTripTests.Document_RoundTrip_PreservesObjectCount;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TCADCmp2D;
begin
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TCADCmp2D.Create(nil);
    try
      TmpSrc.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
      TmpSrc.AddObject(-1, TEllipse2D.Create(-1, Point2D(2, 2),
        Point2D(4, 4)));
      TmpSrc.AddObject(-1, TRectangle2D.Create(-1, Point2D(5, 5),
        Point2D(9, 7)));
      TmpSrc.AddObject(-1, TPolyline2D.Create(-1, [Point2D(0, 0),
        Point2D(1, 0), Point2D(1, 1)]));
      AssertInt(4, TmpSrc.ObjectsCount, 'Objects present before saving');
      TmpSrc.SaveToStream(TmpStream);
    finally
      TmpSrc.Free;
    end;
    TmpStream.Position := 0;
    TmpDst := TCADCmp2D.Create(nil);
    try
      TmpDst.LoadFromStream(TmpStream);
      AssertInt(4, TmpDst.ObjectsCount, 'Objects present after loading');
    finally
      TmpDst.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TDocumentRoundTripTests.Document_RoundTrip_PreservesGeometryInOrder;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TCADCmp2D;
  TmpIter: TGraphicObjIterator;
  TmpObj: TGraphicObject;
begin
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TCADCmp2D.Create(nil);
    try
      TmpSrc.AddObject(-1, TLine2D.Create(-1, Point2D(1.25, 2.5),
        Point2D(3.75, 4.0)));
      TmpSrc.AddObject(-1, TEllipse2D.Create(-1, Point2D(-8, -8),
        Point2D(8, 8)));
      TmpSrc.SaveToStream(TmpStream);
    finally
      TmpSrc.Free;
    end;
    TmpStream.Position := 0;
    TmpDst := TCADCmp2D.Create(nil);
    try
      TmpDst.LoadFromStream(TmpStream);
      TmpIter := TmpDst.ObjectsIterator;
      try
        TmpObj := TmpIter.First;
        Assert.IsTrue(TmpObj is TLine2D, 'First object is the TLine2D');
        AssertPoint(Point2D(1.25, 2.5), TLine2D(TmpObj).Points[0],
          'Line start point');
        AssertPoint(Point2D(3.75, 4.0), TLine2D(TmpObj).Points[1],
          'Line end point');
        TmpObj := TmpIter.Next;
        Assert.IsTrue(TmpObj is TEllipse2D,
          'Second object is the TEllipse2D');
        AssertPoint(Point2D(-8, -8), TEllipse2D(TmpObj).Points[0],
          'Ellipse first corner');
        AssertPoint(Point2D(8, 8), TEllipse2D(TmpObj).Points[1],
          'Ellipse second corner');
      finally
        TmpIter.Free;
      end;
    finally
      TmpDst.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TDocumentRoundTripTests.Document_RoundTrip_PreservesLayerAssignment;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TCADCmp2D;
  TmpObj: TObject2D;
begin
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TCADCmp2D.Create(nil);
    try
      { TCADCmp.AddObject stamps CurrentLayer onto the object, so the
        layer must be chosen before the add, not after. }
      TmpSrc.CurrentLayer := 0;
      TmpSrc.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
      TmpSrc.CurrentLayer := 5;
      TmpSrc.AddObject(-1, TLine2D.Create(-1, Point2D(2, 2), Point2D(3, 3)));
      TmpSrc.CurrentLayer := 200;
      TmpSrc.AddObject(-1, TLine2D.Create(-1, Point2D(4, 4), Point2D(5, 5)));
      TmpSrc.SaveToStream(TmpStream);
    finally
      TmpSrc.Free;
    end;
    TmpStream.Position := 0;
    TmpDst := TCADCmp2D.Create(nil);
    try
      TmpDst.LoadFromStream(TmpStream);
      TmpObj := TmpDst.GetObject(0);
      AssertInt(0, Integer(TmpObj.Layer), 'Layer of object 0');
      TmpObj := TmpDst.GetObject(1);
      AssertInt(5, Integer(TmpObj.Layer), 'Layer of object 1');
      TmpObj := TmpDst.GetObject(2);
      AssertInt(200, Integer(TmpObj.Layer), 'Layer of object 2');
    finally
      TmpDst.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TDocumentRoundTripTests.Document_RoundTrip_ReassignsSequentialIDs;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TCADCmp2D;
begin
  { Documented behaviour, not an accident: TCADCmp2D.LoadObjectsFromStream
    calls AddObject(-1, ...) after DeleteAllObjects has reset fNextID, so
    the loaded objects are renumbered 0..N-1 in stream order. The saved
    IDs are written but are not what a loaded object ends up with. }
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TCADCmp2D.Create(nil);
    try
      TmpSrc.AddObject(100, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
      TmpSrc.AddObject(200, TLine2D.Create(-1, Point2D(2, 2), Point2D(3, 3)));
      AssertInt(100, TmpSrc.GetObject(100).ID, 'Explicit ID before saving');
      TmpSrc.SaveToStream(TmpStream);
    finally
      TmpSrc.Free;
    end;
    TmpStream.Position := 0;
    TmpDst := TCADCmp2D.Create(nil);
    try
      TmpDst.LoadFromStream(TmpStream);
      AssertInt(2, TmpDst.ObjectsCount, 'Object count');
      Assert.IsTrue(TmpDst.GetObject(0) <> nil,
        'Object 0 exists after loading');
      Assert.IsTrue(TmpDst.GetObject(1) <> nil,
        'Object 1 exists after loading');
      AssertInt(0, TmpDst.GetObject(0).ID, 'First object renumbered to 0');
      AssertInt(1, TmpDst.GetObject(1).ID, 'Second object renumbered to 1');
    finally
      TmpDst.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TDocumentRoundTripTests.Document_RoundTrip_PreservesShapeClasses;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TCADCmp2D;
begin
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TCADCmp2D.Create(nil);
    try
      TmpSrc.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
      TmpSrc.AddObject(-1, TPolygon2D.Create(-1, [Point2D(0, 0),
        Point2D(1, 0), Point2D(0, 1)]));
      TmpSrc.AddObject(-1, TFilledEllipse2D.Create(-1, Point2D(0, 0),
        Point2D(2, 2)));
      TmpSrc.AddObject(-1, TBSpline2D.Create(-1, [Point2D(0, 0),
        Point2D(1, 1), Point2D(2, 0)]));
      TmpSrc.SaveToStream(TmpStream);
    finally
      TmpSrc.Free;
    end;
    TmpStream.Position := 0;
    TmpDst := TCADCmp2D.Create(nil);
    try
      TmpDst.LoadFromStream(TmpStream);
      Assert.IsTrue(TmpDst.GetObject(0) is TLine2D, 'Object 0 class');
      Assert.IsTrue(TmpDst.GetObject(1) is TPolygon2D, 'Object 1 class');
      Assert.IsTrue(TmpDst.GetObject(2) is TFilledEllipse2D,
        'Object 2 class');
      Assert.IsTrue(TmpDst.GetObject(3) is TBSpline2D, 'Object 3 class');
    finally
      TmpDst.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TDocumentRoundTripTests.Document_RoundTrip_ViaFile_PreservesGeometry;
var
  TmpSrc, TmpDst: TCADCmp2D;
  TmpLine: TLine2D;
begin
  TmpSrc := TCADCmp2D.Create(nil);
  try
    TmpSrc.AddObject(-1, TLine2D.Create(-1, Point2D(-11.5, 22.25),
      Point2D(33.125, -44.0625)));
    TmpSrc.SaveToFile(FTempFile);
  finally
    TmpSrc.Free;
  end;
  Assert.IsTrue(TFile.Exists(FTempFile), 'SaveToFile produced a file');
  TmpDst := TCADCmp2D.Create(nil);
  try
    { LoadFromFile also calls RepaintViewports, which is a no-op here
      because no TCADViewport is ever linked to the component. }
    TmpDst.LoadFromFile(FTempFile);
    AssertInt(1, TmpDst.ObjectsCount, 'Object count');
    TmpLine := TmpDst.GetObject(0) as TLine2D;
    AssertPoint(Point2D(-11.5, 22.25), TmpLine.Points[0], 'Start point');
    AssertPoint(Point2D(33.125, -44.0625), TmpLine.Points[1], 'End point');
  finally
    TmpDst.Free;
  end;
end;

procedure TDocumentRoundTripTests.ModifiedLayer_RoundTrip_PreservesNameAndFlags;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TCADCmp2D;
  TmpName: string;
begin
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TCADCmp2D.Create(nil);
    try
      { TLayer.SetName sets fModified, which is what makes TLayers
        stream this layer at all. }
      TmpSrc.Layers[7].Name := 'WALLS';
      TmpSrc.Layers[7].Visible := False;
      TmpSrc.Layers[7].Opaque := True;
      TmpSrc.SaveToStream(TmpStream);
    finally
      TmpSrc.Free;
    end;
    TmpStream.Position := 0;
    TmpDst := TCADCmp2D.Create(nil);
    try
      TmpDst.LoadFromStream(TmpStream);
      { TLayerName is String[31]; the assignment converts it. }
      TmpName := TmpDst.Layers[7].Name;
      AssertStr('WALLS', TmpName, 'Layer 7 name');
      Assert.IsFalse(TmpDst.Layers[7].Visible, 'Layer 7 Visible flag');
      Assert.IsTrue(TmpDst.Layers[7].Opaque, 'Layer 7 Opaque flag');
      Assert.IsTrue(TmpDst.Layers[7].Streamable, 'Layer 7 Streamable flag');
      Assert.IsTrue(TmpDst.Layers[7].Modified,
        'A layer read from a stream is marked modified');
    finally
      TmpDst.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TDocumentRoundTripTests.UnmodifiedLayer_IsNotStreamed;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TCADCmp2D;
begin
  { TLayers.SaveToStream only writes layers whose fModified is set, and
    Visible/Active/Opaque/Streamable are plain field writes that do NOT
    set it. Toggling only Visible therefore silently fails to persist.
    This is current, documented behaviour - pin it so a future change
    to the setters is visible here. }
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TCADCmp2D.Create(nil);
    try
      TmpSrc.Layers[9].Visible := False;
      Assert.IsFalse(TmpSrc.Layers[9].Modified,
        'Writing Visible does not mark the layer modified');
      TmpSrc.SaveToStream(TmpStream);
    finally
      TmpSrc.Free;
    end;
    TmpStream.Position := 0;
    TmpDst := TCADCmp2D.Create(nil);
    try
      TmpDst.LoadFromStream(TmpStream);
      Assert.IsTrue(TmpDst.Layers[9].Visible,
        'Layer 9 came back at its default because it was never streamed');
    finally
      TmpDst.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TDocumentRoundTripTests.NonStreamableLayer_ObjectsAreNotSaved;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TCADCmp2D;
begin
  { TCADCmp2D.SaveObjectsToStream skips objects whose layer is not
    Streamable, then writes the 65535 sentinel so the reader stops
    early. Both halves of that mechanism are exercised here. }
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TCADCmp2D.Create(nil);
    try
      TmpSrc.Layers[4].Streamable := False;
      TmpSrc.CurrentLayer := 0;
      TmpSrc.AddObject(-1, TLine2D.Create(-1, Point2D(0, 0), Point2D(1, 1)));
      TmpSrc.CurrentLayer := 4;
      TmpSrc.AddObject(-1, TLine2D.Create(-1, Point2D(2, 2), Point2D(3, 3)));
      AssertInt(2, TmpSrc.ObjectsCount, 'Objects present before saving');
      TmpSrc.SaveToStream(TmpStream);
    finally
      TmpSrc.Free;
    end;
    TmpStream.Position := 0;
    TmpDst := TCADCmp2D.Create(nil);
    try
      TmpDst.LoadFromStream(TmpStream);
      AssertInt(1, TmpDst.ObjectsCount,
        'Only the object on the streamable layer was saved');
      AssertInt(0, Integer(TmpDst.GetObject(0).Layer),
        'The surviving object is the one from layer 0');
    finally
      TmpDst.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TDocumentRoundTripTests.SourceBlockAndBlock_RoundTrip_RelinkByName;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TCADCmp2D;
  TmpSource: TSourceBlock2D;
  TmpBlock: TBlock2D;
begin
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TCADCmp2D.Create(nil);
    try
      TmpSource := TSourceBlock2D.Create(-1, StringToBlockName('DOOR'),
        [TLine2D.Create(0, Point2D(0, 0), Point2D(0, 2)),
        TLine2D.Create(1, Point2D(0, 2), Point2D(1, 2))]);
      TmpSrc.AddSourceBlock(TmpSource);
      TmpBlock := TBlock2D.Create(-1, TmpSource);
      TmpSrc.AddObject(-1, TmpBlock);
      AssertInt(1, TmpSrc.SourceBlocksCount, 'Source blocks before saving');
      AssertInt(1, TmpSrc.ObjectsCount, 'Objects before saving');
      TmpSrc.SaveToStream(TmpStream);
    finally
      TmpSrc.Free;
    end;
    TmpStream.Position := 0;
    TmpDst := TCADCmp2D.Create(nil);
    try
      TmpDst.LoadFromStream(TmpStream);
      AssertInt(1, TmpDst.SourceBlocksCount, 'Source blocks after loading');
      AssertInt(1, TmpDst.ObjectsCount, 'Objects after loading');
      TmpBlock := TmpDst.GetObject(0) as TBlock2D;
      Assert.IsTrue(TmpBlock.SourceBlock <> nil,
        'TBlock2D.UpdateReference relinked the block to its source');
      { The same array-of-Char comparison TBlock2D.UpdateReference uses. }
      Assert.IsTrue(TmpBlock.SourceBlock.Name = StringToBlockName('DOOR'),
        'The block was relinked by source block name');
      AssertInt(2, Integer(TmpBlock.SourceBlock.Objects.Count),
        'The source block kept both of its children');
    finally
      TmpDst.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TDocumentRoundTripTests.
  LoadFromStream_ForeignVersionHeader_RaisesECADFileNotValid;
var
  TmpStream: TMemoryStream;
  TmpCad: TCADCmp2D;
  TmpBogus: TCADVersion;
begin
  { TCADCmp.MergeFromStream accepts anything starting with 'CAD' and
    rejects everything else. 'XXX423' is neither the current version
    nor a plausible older one. }
  TmpBogus := 'XXX423';
  TmpStream := TMemoryStream.Create;
  try
    TmpStream.Write(TmpBogus, SizeOf(TmpBogus));
    TmpStream.Position := 0;
    TmpCad := TCADCmp2D.Create(nil);
    try
      Assert.WillRaise(
        procedure
        begin
          TmpCad.LoadFromStream(TmpStream);
        end, ECADFileNotValid,
        'A stream with a foreign version signature must be rejected');
    finally
      TmpCad.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

procedure TDocumentRoundTripTests.SavedHeader_IsTheCurrentLibraryVersion;
var
  TmpStream: TMemoryStream;
  TmpCad: TCADCmp2D;
  TmpRead: TCADVersion;
begin
  TmpStream := TMemoryStream.Create;
  try
    TmpCad := TCADCmp2D.Create(nil);
    try
      Assert.IsTrue(TmpCad.Version = CADSysVersion,
        'A fresh TCADCmp2D carries the current library version');
      TmpCad.SaveToStream(TmpStream);
    finally
      TmpCad.Free;
    end;
    TmpStream.Position := 0;
    TmpStream.Read(TmpRead, SizeOf(TmpRead));
    { Same comparison TCADCmp.MergeFromStream performs at CADSys4:14829. }
    Assert.IsTrue(TmpRead = CADSysVersion,
      'The first field on the stream is the CADSysVersion signature');
  finally
    TmpStream.Free;
  end;
end;

{ =================================================================== }
{ TUnicodeLayoutDefectPinTests                                        }
{ =================================================================== }

procedure TUnicodeLayoutDefectPinTests.
  Pin_X3_SizeOfTCADVersion_IsDoubledUnderUnicode;
begin
  { X3: CADSys4.pas:526 - TCADVersion = array[1..6] of Char.
    Pre-Unicode this occupied 6 bytes on disk; under Delphi 12 it is
    12. Nothing in TCADCmp.SaveToStream or MergeFromStream gates on
    this, so 'CAD423' means two different file layouts depending on
    which compiler produced the file. }
  AssertInt(2, SizeOf(Char), 'Char is two bytes under Unicode Delphi');
  AssertInt(12, SizeOf(TCADVersion),
    'X3: TCADVersion occupies 12 bytes, not the 6 the format assumes');
end;

procedure TUnicodeLayoutDefectPinTests.
  Pin_X3_SizeOfTSourceBlockName_IsDoubledUnderUnicode;
begin
  { X3: CADSys4.pas:529 - TSourceBlockName = array[0..12] of Char.
    TSourceBlock2D.SaveToStream and TBlock2D.SaveToStream both write
    SizeOf(fName)/SizeOf(fSourceName) raw bytes, so every block name
    in the file is 26 bytes instead of 13. }
  AssertInt(26, SizeOf(TSourceBlockName),
    'X3: TSourceBlockName occupies 26 bytes, not the 13 the format assumes');
end;

procedure TUnicodeLayoutDefectPinTests.Pin_X3_EmptyDocumentHeaderIs26BytesNot20;
var
  TmpStream: TMemoryStream;
  TmpCad: TCADCmp2D;
begin
  { The complete byte budget of an empty drawing:

    SizeOf(TCADVersion)      12   (was 6 before Unicode)
    TLayers open marker       2   Word = 1
    TLayers end marker        2   Word = 256, no modified layers
    block section marker      1   Byte = 2
    source block count        4   LongInt = 0
    object section marker     1   Byte = 3
    object count              4   LongInt = 0
    ------------------------------
    total                    26   (would be 20 with a 6-byte version)

    X3: when the version gate lands, this becomes 20 for a legacy
    layout or stays 26 for a new one - either way the change shows up
    here first. }
  TmpStream := TMemoryStream.Create;
  try
    TmpCad := TCADCmp2D.Create(nil);
    try
      TmpCad.SaveToStream(TmpStream);
    finally
      TmpCad.Free;
    end;
    AssertInt(26, Integer(TmpStream.Size),
      'X3: an empty drawing header is 26 bytes under Unicode');
    AssertInt(SizeOf(TCADVersion) + 14, Integer(TmpStream.Size),
      'X3: the whole overshoot is the doubled TCADVersion');
  finally
    TmpStream.Free;
  end;
end;

procedure TUnicodeLayoutDefectPinTests.
  Pin_X3_VersionHeaderOccupiesSizeOfTCADVersionBytes;
var
  TmpStream: TMemoryStream;
  TmpCad: TCADCmp2D;
  TmpMarker: Word;
begin
  { The layer table opens with a Word = 1 immediately after the
    version. Finding it at offset SizeOf(TCADVersion) proves the
    header length is driven by SizeOf(Char). }
  TmpStream := TMemoryStream.Create;
  try
    TmpCad := TCADCmp2D.Create(nil);
    try
      TmpCad.SaveToStream(TmpStream);
    finally
      TmpCad.Free;
    end;
    TmpStream.Position := SizeOf(TCADVersion);
    TmpMarker := 0;
    TmpStream.Read(TmpMarker, SizeOf(TmpMarker));
    AssertInt(1, Integer(TmpMarker),
      'X3: the layer-table marker sits at byte 12, not byte 6');
  finally
    TmpStream.Free;
  end;
end;

procedure TUnicodeLayoutDefectPinTests.Pin_X4_Text2D_WritesTwoBytesPerAnsiChar;
var
  TmpShort, TmpLong: TText2D;
  TmpStreamA, TmpStreamB: TMemoryStream;
  TmpDelta: Integer;
begin
  { X4: CS4Shapes.pas:4511-4513 and 4538-4541.

    fText is an AnsiString (CS4Shapes.pas:751) but both the writer and
    the reader move TmpInt * SizeOf(Char) bytes. Two texts differing by
    two characters must therefore differ by FOUR bytes on the stream,
    where a byte-correct AnsiString writer would differ by two.

    The writer is also reading two bytes for every one it owns, so the
    trailing half of the record is whatever followed the string on the
    heap. }
  TmpStreamA := TMemoryStream.Create;
  try
    TmpStreamB := TMemoryStream.Create;
    try
      TmpShort := TText2D.Create(0, Rect2D(0, 0, 10, 10), 5.0,
        AnsiString('AB'));
      try
        TmpLong := TText2D.Create(0, Rect2D(0, 0, 10, 10), 5.0,
          AnsiString('ABCD'));
        try
          TmpShort.SaveToStream(TmpStreamA);
          TmpLong.SaveToStream(TmpStreamB);
        finally
          TmpLong.Free;
        end;
      finally
        TmpShort.Free;
      end;
      TmpDelta := Integer(TmpStreamB.Size) - Integer(TmpStreamA.Size);
      AssertInt(4, TmpDelta,
        'X4: two extra AnsiChars cost four bytes on the stream');
      Assert.IsFalse(TmpDelta = 2,
        'X4: a byte-correct AnsiString writer would have cost two bytes');
    finally
      TmpStreamB.Free;
    end;
  finally
    TmpStreamA.Free;
  end;
end;

procedure TUnicodeLayoutDefectPinTests.
  Pin_X4_Text2D_StreamSizeFollowsTheUnicodeFormula;
const
  TEXT_LEN = 6;
var
  TmpText: TText2D;
  TmpStream: TMemoryStream;
  TmpExpected: Integer;
begin
  { The exact record a TText2D writes today, term by term. Every term
    except the text length is correct; the text term is the defect. }
  TmpExpected :=
  { TGraphicObject: fID, fLayer, flag bitmask }
    SizeOf(LongInt) + SizeOf(Byte) + SizeOf(Byte)
  { TObject2D: the model transform }
    + SizeOf(TTransf2D)
  { TPrimitive2D: point count, two control points, GrowingEnabled }
    + SizeOf(Word) + 2 * SizeOf(TPoint2D) + SizeOf(Boolean)
  { TText2D: the length prefix, then X4 - two bytes per AnsiChar }
    + SizeOf(Integer) + TEXT_LEN * SizeOf(Char)
  { TExtendedFont.SaveToStream writes a raw TLogFont }
    + SizeOf(TLogFont)
  { TText2D: clipping flags, DrawBox, height }
    + SizeOf(Integer) + SizeOf(Boolean) + SizeOf(TRealType);

  TmpStream := TMemoryStream.Create;
  try
    TmpText := TText2D.Create(0, Rect2D(0, 0, 20, 8), 4.0,
      AnsiString('ABCDEF'));
    try
      TmpText.SaveToStream(TmpStream);
    finally
      TmpText.Free;
    end;
    AssertInt(TmpExpected, Integer(TmpStream.Size),
      'X4: the on-stream TText2D record matches the SizeOf(Char) formula');
  finally
    TmpStream.Free;
  end;
end;

procedure TUnicodeLayoutDefectPinTests.
  Pin_X4_Text2D_RoundTripStillYieldsTheOriginalText;
var
  TmpStream: TMemoryStream;
  TmpSrc, TmpDst: TText2D;
  TmpBackText: string;
begin
  { X4, load side: CreateFromStream does SetLength(fText, TmpInt) - an
    N-byte AnsiString buffer - and then reads 2*N bytes into it. The
    first N bytes land correctly, which is why the text still compares
    equal; the second N bytes are written past the end of the string
    block. The round trip therefore APPEARS to work and quietly
    corrupts the heap.

    A short string is used deliberately so the overrun stays inside the
    allocator's rounding slack. Pinning the observable behaviour is the
    point; when the fix lands, this test should keep passing while the
    two byte-count pins above change. }
  TmpStream := TMemoryStream.Create;
  try
    TmpSrc := TText2D.Create(42, Rect2D(1, 2, 11, 6), 3.5,
      AnsiString('ABCD'));
    try
      TmpSrc.SaveToStream(TmpStream);
    finally
      TmpSrc.Free;
    end;
    TmpStream.Position := 0;
    TmpDst := TText2D.CreateFromStream(TmpStream, CADSysVersion);
    try
      TmpBackText := TmpDst.Text;
      AssertStr('ABCD', TmpBackText, 'X4: the text still reads back');
      AssertInt(42, TmpDst.ID, 'ID survives');
      AssertReal(3.5, TmpDst.Height, TOL_EXACT, 'Height survives');
      AssertPoint(Point2D(1, 2), TmpDst.Points[0], 'First corner');
      AssertPoint(Point2D(11, 6), TmpDst.Points[1], 'Second corner');
      AssertInt(Integer(TmpStream.Size), Integer(TmpStream.Position),
        'X4: reader and writer agree on the record length');
    finally
      TmpDst.Free;
    end;
  finally
    TmpStream.Free;
  end;
end;

{ =================================================================== }
{ TDXFGroupRoundTripTests                                             }
{ =================================================================== }

procedure TDXFGroupRoundTripTests.Setup;
begin
  FTempFile := TPath.GetTempFileName;
end;

procedure TDXFGroupRoundTripTests.TearDown;
begin
  if (FTempFile <> '') and TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
  FTempFile := '';
end;

procedure TDXFGroupRoundTripTests.StringGroups_SurviveAWriteReadCycle;
var
  TmpWrite: TDXFWrite;
  TmpRead: TDXFRead;
  TmpOut, TmpIn: TGroupTable;
begin
  TmpWrite := TDXFWrite.Create(FTempFile);
  try
    TmpOut[0] := 'LINE';
    TmpOut[8] := 'WALLS';
    TmpWrite.BeginSection(scEntities);
    TmpWrite.WriteAnEntry({%H-}TmpOut);
    TmpWrite.EndSection(scEntities);
    WriteDXFTail(TmpWrite);
  finally
    TmpWrite.Free;
  end;

  TmpRead := TDXFRead.Create(FTempFile);
  try
    TmpRead.ReadAnEntry(0, {%H-}TmpIn);
    AssertStr('LINE', VarToStr(TmpIn[0]), 'Group 0 (entity type)');
    AssertStr('WALLS', VarToStr(TmpIn[8]), 'Group 8 (layer name)');
  finally
    TmpRead.Free;
  end;
end;

procedure TDXFGroupRoundTripTests.FloatGroups_SurviveToSixDecimalPlaces;
var
  TmpWrite: TDXFWrite;
  TmpRead: TDXFRead;
  TmpOut, TmpIn: TGroupTable;
begin
  TmpWrite := TDXFWrite.Create(FTempFile);
  try
    TmpOut[0] := 'LINE';
    TmpOut[10] := 12.345678;
    TmpOut[20] := -98.765432;
    TmpOut[40] := 0.5;
    TmpWrite.BeginSection(scEntities);
    TmpWrite.WriteAnEntry({%H-}TmpOut);
    TmpWrite.EndSection(scEntities);
    WriteDXFTail(TmpWrite);
  finally
    TmpWrite.Free;
  end;

  TmpRead := TDXFRead.Create(FTempFile);
  try
    TmpRead.ReadAnEntry(0, {%H-}TmpIn);
    { TDXFWrite formats floats with '%.6f', so six decimals is the
      best the text form can promise. }
    AssertReal(12.345678, Double(TmpIn[10]), TOL_DXF, 'Group 10');
    AssertReal(-98.765432, Double(TmpIn[20]), TOL_DXF, 'Group 20');
    AssertReal(0.5, Double(TmpIn[40]), TOL_DXF, 'Group 40');
  finally
    TmpRead.Free;
  end;
end;

procedure TDXFGroupRoundTripTests.IntegerGroups_SurviveAWriteReadCycle;
var
  TmpWrite: TDXFWrite;
  TmpRead: TDXFRead;
  TmpOut, TmpIn: TGroupTable;
begin
  TmpWrite := TDXFWrite.Create(FTempFile);
  try
    TmpOut[0] := 'LINE';
    TmpOut[62] := 7;
    TmpOut[70] := -3;
    TmpWrite.BeginSection(scEntities);
    TmpWrite.WriteAnEntry({%H-}TmpOut);
    TmpWrite.EndSection(scEntities);
    WriteDXFTail(TmpWrite);
  finally
    TmpWrite.Free;
  end;

  TmpRead := TDXFRead.Create(FTempFile);
  try
    TmpRead.ReadAnEntry(0, {%H-}TmpIn);
    AssertInt(7, Integer(TmpIn[62]), 'Group 62 (colour)');
    AssertInt(-3, Integer(TmpIn[70]), 'Group 70');
  finally
    TmpRead.Free;
  end;
end;

procedure TDXFGroupRoundTripTests.ExtendedGroupCodes_RemapTo256AndAbove;
var
  TmpWrite: TDXFWrite;
  TmpRead: TDXFRead;
  TmpOut, TmpIn: TGroupTable;
begin
  { TGroupTable is only 513 slots wide, so the extended DXF codes are
    folded down by 744: 1000 -> 256, 1010 -> 266, 1060 -> 316. Both
    TDXFWrite.WriteAnEntry and TDXFRead.ReadAnEntry must agree on that
    offset or extended data silently lands in the wrong slot. }
  TmpWrite := TDXFWrite.Create(FTempFile);
  try
    TmpOut[0] := 'LINE';
    TmpOut[256] := 'XDATA';
    TmpOut[266] := 3.25;
    TmpOut[316] := 4242;
    TmpWrite.BeginSection(scEntities);
    TmpWrite.WriteAnEntry({%H-}TmpOut);
    TmpWrite.EndSection(scEntities);
    WriteDXFTail(TmpWrite);
  finally
    TmpWrite.Free;
  end;

  TmpRead := TDXFRead.Create(FTempFile);
  try
    TmpRead.ReadAnEntry(0, {%H-}TmpIn);
    AssertStr('XDATA', VarToStr(TmpIn[256]),
      'Code 1000 came back at slot 256');
    AssertReal(3.25, Double(TmpIn[266]), TOL_DXF,
      'Code 1010 came back at slot 266');
    AssertInt(4242, Integer(TmpIn[316]),
      'Code 1060 came back at slot 316');
    AssertStr('LINE', VarToStr(TmpIn[0]),
      'The ordinary groups were not disturbed');
  finally
    TmpRead.Free;
  end;
end;

procedure TDXFGroupRoundTripTests.ReadAnEntry_ClearsTheTableBetweenEntities;
var
  TmpWrite: TDXFWrite;
  TmpRead: TDXFRead;
  TmpFirst, TmpSecond, TmpIn: TGroupTable;
begin
  { CS4-FIX: ReadAnEntry now VarClears every slot before filling the
    table. Before the fix a group the second entity omitted kept the
    FIRST entity's value, so every 'VarType(...) <> varEmpty' guard in
    the importer read stale data instead of detecting an absent group. }
  TmpWrite := TDXFWrite.Create(FTempFile);
  try
    TmpFirst[0] := 'LINE';
    TmpFirst[8] := 'WALLS';
    TmpFirst[10] := 1.0;
    TmpFirst[20] := 2.0;
    TmpFirst[62] := 7;

    TmpSecond[0] := 'POINT';
    TmpSecond[10] := 9.0;

    TmpWrite.BeginSection(scEntities);
    TmpWrite.WriteAnEntry({%H-}TmpFirst);
    TmpWrite.WriteAnEntry({%H-}TmpSecond);
    TmpWrite.EndSection(scEntities);
    WriteDXFTail(TmpWrite);
  finally
    TmpWrite.Free;
  end;

  TmpRead := TDXFRead.Create(FTempFile);
  try
    TmpRead.ReadAnEntry(0, {%H-}TmpIn);
    AssertStr('LINE', VarToStr(TmpIn[0]), 'First entity type');
    AssertInt(7, Integer(TmpIn[62]), 'First entity colour');

    TmpRead.ReadAnEntry(0, TmpIn);
    AssertStr('POINT', VarToStr(TmpIn[0]), 'Second entity type');
    AssertReal(9.0, Double(TmpIn[10]), TOL_DXF, 'Second entity group 10');
    Assert.IsTrue(VarType(TmpIn[20]) = varEmpty,
      'Group 20 was omitted by the second entity and reads Unassigned');
    Assert.IsTrue(VarType(TmpIn[62]) = varEmpty,
      'Group 62 was omitted by the second entity and reads Unassigned');
    Assert.IsTrue(VarType(TmpIn[8]) = varEmpty,
      'Group 8 was omitted by the second entity and reads Unassigned');
  finally
    TmpRead.Free;
  end;
end;

procedure TDXFGroupRoundTripTests.
  ReadAnEntry_AcceptsCode1256AtTheTableUpperBound;
var
  TmpRead: TDXFRead;
  TmpIn: TGroupTable;
begin
  { 1256 - 744 = 512 = High(TGroupTable), the last legal slot. It is
    written by hand because TDXFWrite.WriteGroup has no formatting rule
    for 1256 and would emit an empty value line. Codes outside the
    numeric ranges fall through to the untrimmed raw-text branch of
    ConsumeGroup, so the value is written with no leading spaces. }
  WriteRawDXF(FTempFile, ['0', 'SECTION', '2', 'ENTITIES', '0', 'LINE',
    '1256', 'EDGE', '10', '1.000000', '0', 'ENDSEC', '0', 'EOF', '0',
    'EOF']);

  TmpRead := TDXFRead.Create(FTempFile);
  try
    TmpRead.ReadAnEntry(0, {%H-}TmpIn);
    AssertStr('EDGE', VarToStr(TmpIn[512]),
      'Code 1256 lands at the last table slot');
    AssertStr('LINE', VarToStr(TmpIn[0]), 'Entity type');
    AssertReal(1.0, Double(TmpIn[10]), TOL_DXF, 'Group 10');
  finally
    TmpRead.Free;
  end;
end;

procedure TDXFGroupRoundTripTests.ReadAnEntry_IgnoresGroupCodesAbove1256;
var
  TmpRead: TDXFRead;
  TmpIn: TGroupTable;
begin
  { CS4-FIX: the upper bound on the extended-code branch was missing,
    so a code above 1256 wrote a Variant past the end of TGroupTable -
    and every caller in CS4DXFModule declares that table as a stack
    local. 1300 must now be dropped entirely: neither stored nor
    allowed to disturb the surrounding groups. }
  WriteRawDXF(FTempFile, ['0', 'SECTION', '2', 'ENTITIES', '0', 'LINE',
    '10', '1.000000', '1300', 'OUTOFRANGE', '20', '2.000000', '0',
    'ENDSEC', '0', 'EOF', '0', 'EOF']);

  TmpRead := TDXFRead.Create(FTempFile);
  try
    TmpRead.ReadAnEntry(0, {%H-}TmpIn);
    AssertStr('LINE', VarToStr(TmpIn[0]), 'Entity type');
    AssertReal(1.0, Double(TmpIn[10]), TOL_DXF,
      'The group before the bad code');
    AssertReal(2.0, Double(TmpIn[20]), TOL_DXF,
      'The group after the bad code');
    Assert.IsTrue(VarType(TmpIn[512]) = varEmpty,
      'The out-of-range code did not land at the top of the table');
    Assert.IsTrue(VarType(TmpIn[256]) = varEmpty,
      'The out-of-range code did not land in the extended block');
  finally
    TmpRead.Free;
  end;
end;

procedure TDXFGroupRoundTripTests.
  ConsumeGroup_ParsesFloats_WhenGlobalDecimalSeparatorIsComma;
var
  TmpRead: TDXFRead;
  TmpIn: TGroupTable;
  TmpSaved: Char;
begin
  { X2: TDXFRead.ConsumeGroup used to save, overwrite and restore
    FormatSettings.DecimalSeparator - a process global - around every
    parsed group. It now carries its own TFormatSettings pinned to '.',
    so a '.'-decimal DXF must parse correctly even while the global
    separator says ','. }
  WriteRawDXF(FTempFile, ['0', 'SECTION', '2', 'ENTITIES', '0', 'LINE',
    '10', '12.500000', '20', '-0.250000', '0', 'ENDSEC', '0', 'EOF',
    '0', 'EOF']);

  TmpSaved := FormatSettings.DecimalSeparator;
  try
    FormatSettings.DecimalSeparator := ',';
    TmpRead := TDXFRead.Create(FTempFile);
    try
      TmpRead.ReadAnEntry(0, {%H-}TmpIn);
      AssertReal(12.5, Double(TmpIn[10]), TOL_DXF,
        'X2: group 10 parsed with a comma decimal separator in force');
      AssertReal(-0.25, Double(TmpIn[20]), TOL_DXF,
        'X2: group 20 parsed with a comma decimal separator in force');
    finally
      TmpRead.Free;
    end;
  finally
    FormatSettings.DecimalSeparator := TmpSaved;
  end;
end;

procedure TDXFGroupRoundTripTests.
  ConsumeGroup_DoesNotWriteTheGlobalFormatSettings;
var
  TmpRead: TDXFRead;
  TmpIn: TGroupTable;
  TmpSaved: Char;
  TmpAfter: Char;
begin
  { The other half of X2: parsing must leave the process-wide
    FormatSettings exactly as it found them. }
  WriteRawDXF(FTempFile, ['0', 'SECTION', '2', 'ENTITIES', '0', 'LINE',
    '10', '3.750000', '0', 'ENDSEC', '0', 'EOF', '0', 'EOF']);

  TmpSaved := FormatSettings.DecimalSeparator;
  try
    FormatSettings.DecimalSeparator := ',';
    TmpRead := TDXFRead.Create(FTempFile);
    try
      TmpRead.ReadAnEntry(0, {%H-}TmpIn);
      AssertReal(3.75, Double(TmpIn[10]), TOL_DXF, 'Group 10');
    finally
      TmpRead.Free;
    end;
    TmpAfter := FormatSettings.DecimalSeparator;
    Assert.IsTrue(TmpAfter = ',',
      'X2: the DXF parser left the global decimal separator untouched');
  finally
    FormatSettings.DecimalSeparator := TmpSaved;
  end;
end;

procedure TDXFGroupRoundTripTests.Reader_IdentifiesTheEntitiesSection;
var
  TmpWrite: TDXFWrite;
  TmpRead: TDXFRead;
begin
  TmpWrite := TDXFWrite.Create(FTempFile);
  try
    TmpWrite.BeginSection(scEntities);
    TmpWrite.EndSection(scEntities);
    WriteDXFTail(TmpWrite);
  finally
    TmpWrite.Free;
  end;

  TmpRead := TDXFRead.Create(FTempFile);
  try
    { TDXFRead.Create already consumes the first group and positions on
      the first section. }
    Assert.IsTrue(TmpRead.CurrentSection = scEntities,
      'BeginSection(scEntities) is read back as scEntities');
  finally
    TmpRead.Free;
  end;
end;

procedure TDXFGroupRoundTripTests.NextSection_AdvancesFromHeaderToEntities;
var
  TmpRead: TDXFRead;
begin
  WriteRawDXF(FTempFile, ['0', 'SECTION', '2', 'HEADER', '0', 'ENDSEC',
    '0', 'SECTION', '2', 'ENTITIES', '0', 'ENDSEC', '0', 'EOF']);

  TmpRead := TDXFRead.Create(FTempFile);
  try
    Assert.IsTrue(TmpRead.CurrentSection = scHeader,
      'The reader starts on the HEADER section');
    TmpRead.NextSection;
    Assert.IsTrue(TmpRead.CurrentSection = scEntities,
      'NextSection advances to the ENTITIES section');
  finally
    TmpRead.Free;
  end;
end;

procedure TDXFGroupRoundTripTests.Rewind_RepositionsAtTheFirstSection;
var
  TmpRead: TDXFRead;
begin
  WriteRawDXF(FTempFile, ['0', 'SECTION', '2', 'HEADER', '0', 'ENDSEC',
    '0', 'SECTION', '2', 'ENTITIES', '0', 'ENDSEC', '0', 'EOF']);

  TmpRead := TDXFRead.Create(FTempFile);
  try
    TmpRead.NextSection;
    Assert.IsTrue(TmpRead.CurrentSection = scEntities,
      'Advanced to ENTITIES');
    TmpRead.Rewind;
    Assert.IsTrue(TmpRead.CurrentSection = scHeader,
      'Rewind puts the reader back on the first section');
  finally
    TmpRead.Free;
  end;
end;

{ =================================================================== }
{ TDXFImportRoundTripTests                                            }
{ =================================================================== }

procedure TDXFImportRoundTripTests.Setup;
begin
  FTempFile := TPath.GetTempFileName;
end;

procedure TDXFImportRoundTripTests.TearDown;
begin
  if (FTempFile <> '') and TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
  FTempFile := '';
end;

procedure TDXFImportRoundTripTests.
  ImportedLineEntity_LandsInTheCADWithItsCoordinates;
var
  TmpWrite: TDXFWrite;
  TmpOut: TGroupTable;
  TmpImport: TDXF2DImport;
  TmpCad: TCADCmp2D;
  TmpLine: TLine2D;
begin
  { End to end: TDXFWrite produces the file, TDXF2DImport consumes it
    and materialises a TLine2D in a TCADCmp2D. Only LINE is covered -
    it is the one entity whose importer needs neither a vector font nor
    a source-block table. }
  TmpWrite := TDXFWrite.Create(FTempFile);
  try
    TmpOut[0] := 'LINE';
    TmpOut[8] := '0';
    TmpOut[10] := 1.5;
    TmpOut[20] := 2.5;
    TmpOut[11] := 3.5;
    TmpOut[21] := 4.5;
    TmpWrite.BeginSection(scEntities);
    TmpWrite.WriteAnEntry({%H-}TmpOut);
    TmpWrite.EndSection(scEntities);
    WriteDXFTail(TmpWrite);
  finally
    TmpWrite.Free;
  end;

  TmpCad := TCADCmp2D.Create(nil);
  try
    TmpImport := TDXF2DImport.Create(FTempFile, TmpCad);
    try
      TmpImport.Scale := 1.0;
      TmpImport.Verbose := False;
      TmpImport.ReadDXF;
      Assert.IsFalse(TmpImport.UnableToReadAllTheFile,
        'The whole DXF was consumed');
    finally
      { Frees the TDXFRead and so closes the file before TearDown
        deletes it. }
      TmpImport.Free;
    end;
    AssertInt(1, TmpCad.ObjectsCount, 'One entity was imported');
    TmpLine := TmpCad.GetObject(0) as TLine2D;
    AssertReal(1.5, TmpLine.Points[0].X, TOL_DXF, 'Start X');
    AssertReal(2.5, TmpLine.Points[0].Y, TOL_DXF, 'Start Y');
    AssertReal(3.5, TmpLine.Points[1].X, TOL_DXF, 'End X');
    AssertReal(4.5, TmpLine.Points[1].Y, TOL_DXF, 'End Y');
  finally
    TmpCad.Free;
  end;
end;

initialization

TDUnitX.RegisterTestFixture(TShapeStreamRoundTripTests);
TDUnitX.RegisterTestFixture(TClassRegistryTests);
TDUnitX.RegisterTestFixture(TDocumentRoundTripTests);
TDUnitX.RegisterTestFixture(TUnicodeLayoutDefectPinTests);
TDUnitX.RegisterTestFixture(TDXFGroupRoundTripTests);
TDUnitX.RegisterTestFixture(TDXFImportRoundTripTests);

end.
