# CADSys 4.2 — DUnitX test suite

A console DUnitX suite for the library units in `..\Sources`. Built for **Delphi 11/12** using the DUnitX that ships with the IDE (`$(BDS)\source\DUnitX`).

> **This suite has never been compiled.** It was written by reading the sources, not by building against them. Every library symbol it calls was checked against a declaration in `..\Sources`, but the first build will still surface mistakes. Treat the first run as part of writing the suite, not as a verdict on the library.

## Building and running

Open `CADSys4Tests.dproj` in the IDE and build, or from the command line:

```
msbuild CADSys4Tests.dproj /p:Config=Debug /p:Platform=Win32
```

The project sets `..\Sources` as its unit search path, so the tests always compile against the real library units rather than a stale `.dcu`. No library unit is listed in the `.dpr`.

```
CADSys4Tests.exe                              full run, console output
CADSys4Tests.exe --exitbehavior:Continue      for CI — no "press Enter" pause
CADSys4Tests.exe --xmloutput:results.xml      NUnit XML for a CI report
```

The exit code is non-zero if anything failed, so it drops straight into the existing `.github/workflows` setup.

The Debug configuration does **not** turn on range or overflow checking. The library's own convention is range-checks-off — `CADSys4.pas` wraps only `DotProduct3D`/`CrossProd3D` in `{$R+}` (to catch an `Extended`→`Double` narrowing) and then does `{$R-}` for the rest of the unit — so `{$R+}` project-wide is not a baseline this code was written to satisfy.

It is still worth running that way deliberately. Range checking is how the `Word` capacity truncation (M2) and the draw-helper overruns (P3b) become visible at all. Tick **Range checking** and **Overflow checking** under Project → Options → Building → Delphi Compiler → Compiling, expect `ERangeError` to surface in places the library has always been sloppy about, and treat each one as a finding to triage rather than a build break.

## What is in here

| Unit | Covers |
|---|---|
| `CADSys4.Tests.Geometry` | `CS4BaseTypes` value types and every canvas-free geometry function in `CADSys4`: vector algebra, homogeneous coordinates, the 2D/3D transform algebra, box algebra, distance and clipping helpers. |
| `CADSys4.Tests.Structures` | `TPointsSet2D`/`3D`, `TGraphicObjList` and its iterators, `TIndexedObjectList`, `TLayer`/`TLayers`, `TCADPrgParam` ownership. |
| `CADSys4.Tests.Shapes` | Eight 2D shape families: construction, `Assign` round-trips and independence, bounding boxes, the `BeginUseProfilePoints` protocol, `OnMe` hit-testing, curve precision. |
| `CADSys4.Tests.Persistence` | Native `SaveToStream`/`LoadFromStream` round-trips, layer and document persistence, and DXF read/write round-trips against temp files. |
| `CADSys4.Tests.Regressions` | One test per defect from `docs/features/optimization-review.md`. These should fail on commit `a0ccd7a` and pass on the fix branch. |

## Two things to know before you read the results

**Some tests pin defects rather than correct behaviour.** The suite documents what the library *currently does*, including where that is wrong. The clearest case is the on-disk format: `TCADVersion` and `TSourceBlockName` are `array of Char`, so `SizeOf` doubled under Unicode Delphi and the format silently changed (findings X3/X4). `CADSys4.Tests.Persistence` asserts the *current* byte counts so that when the version gate lands, the diff on this suite states exactly what changed. Those tests are named and commented to make it obvious they are pinning a defect.

**Some findings cannot be reached from a console runner.** Anything behind the interaction FSM or a canvas — the pan double-free (M1), the draw-helper overruns (P3b), the GDI font churn (P4) — needs a live viewport. Rather than drop them, `CADSys4.Tests.Regressions` records them as `[Ignore]`d tests whose ignore message says why and how to verify them by hand. The same applies to findings deliberately left unfixed (M2, M5/M7/M8, X3/X4): the placeholder is there so the gap stays visible.

## Running it against a memory-leak check

Most of the review's findings are lifetime bugs, so the suite is most useful with FastMM4 in full-debug mode. Add `FastMM4` as the first unit in the `.dpr` uses clause, drop `FastMM_FullDebugMode.dll` beside the exe, and set:

```pascal
ReportMemoryLeaksOnShutdown := True;
```

Every fixture frees what it creates through `try/finally`, so a clean shutdown report is the expected result. A leak report naming a library class is a real finding.

## Adding to it

Fixtures self-register in each unit's `initialization` via `TDUnitX.RegisterTestFixture`, so a new fixture needs no change to the `.dpr` — only a new unit added to the project's `DCCReference` list if it lives in a new file.

When you add a test, the house rule that produced this suite is worth keeping: check the declaration in `..\Sources` before you call anything, and where a numeric result depends on flattening detail or accumulated floating point, assert the invariant (the box contains the points; the count grew by one) rather than a constant you computed by hand.
