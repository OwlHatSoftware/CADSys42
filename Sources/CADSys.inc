{ ============================================================================
  CADSys.inc - which UI framework this build targets.

  Include this at the top of every unit that mentions a framework. Exactly
  one of CADSYS_VCL, CADSYS_FMX and CADSYS_LCL ends up defined, and the
  units switch their uses clauses (and the few genuinely divergent bits of
  code) on that.

  How it decides:

  - FPC/Lazarus is always LCL. There is no FMX there, and the VCL does
    not exist at all.
  - On Delphi the default is VCL, because that is what the packages,
    demos and tests build. An FMX build says so by defining CADSYS_FMX -
    or TMS FNC's own FMXLIB - in the project or package options, which is
    exactly how TMS FNC itself is configured.

  So nothing has to change for an existing VCL project: not defining
  anything keeps today's behaviour.

  Three rules for the units that include this:

  - Never test FMXLIB/VCLLIB/LCLLIB directly. Those belong to TMS FNC and
    are not guaranteed to be set in a project that only uses CADSys.
  - RTL units are spelled with their scope on Delphi (System.SysUtils) and
    without it on FPC (SysUtils), under IFDEF CADSYS_LCL. Writing them
    bare everywhere and leaning on Delphi's unit scope names - which is
    what TMS FNC does - works, but it makes 'Graphics' mean whichever of
    Vcl and FMX the project happens to list first. These units carry all
    three frameworks in one copy, so they cannot afford that ambiguity.
  - Prefer IFDEF CADSYS_VCL ... ELSE over listing FMX and LCL separately
    when the two agree, which is most of the time: the VCL is the odd one
    out because it is the only target with a GDI backend.

  The directives named in this comment are written without their braces
  on purpose. A brace comment does not nest, so a real directive in this
  prose would end the comment at its own closing brace and quietly turn
  everything after it into code.
  - A framework-free unit still includes this file - FPC needs the mode
    and string dialect set before anything else - but must never test
    CADSYS_*. If one starts wanting to, it is no longer framework-free,
    and that is worth noticing rather than papering over.
  ============================================================================ }

{$IFDEF FPC}
  {$DEFINE CADSYS_LCL}
  { Delphi dialect, long strings, records with methods - the same three
    settings TMS FNC's own LCLTMSFNCDefines.inc turns on, because this is
    Delphi source being compiled by FPC. }
  {$MODE DELPHI}
  {$H+}
  {$MODESWITCH ADVANCEDRECORDS}
{$ENDIF}

{$IFNDEF CADSYS_LCL}
  {$IFDEF FMXLIB}
    {$DEFINE CADSYS_FMX}
  {$ENDIF}
  {$IFNDEF CADSYS_FMX}
    {$DEFINE CADSYS_VCL}
  {$ENDIF}
{$ENDIF}

{ Two frameworks at once is always a configuration mistake, and it is far
  cheaper to say so here than to let it surface as a puzzling error in a
  uses clause several thousand lines away. }
{$IFDEF CADSYS_VCL}
  {$IFDEF CADSYS_FMX}
    {$MESSAGE Fatal 'CADSys: CADSYS_VCL and CADSYS_FMX are both defined.'}
  {$ENDIF}
  {$IFDEF CADSYS_LCL}
    {$MESSAGE Fatal 'CADSys: CADSYS_VCL and CADSYS_LCL are both defined.'}
  {$ENDIF}
{$ENDIF}
{$IFDEF CADSYS_FMX}
  {$IFDEF CADSYS_LCL}
    {$MESSAGE Fatal 'CADSys: CADSYS_FMX and CADSYS_LCL are both defined.'}
  {$ENDIF}
{$ENDIF}
