`timescale 1ns/1ps
//======================================================================
// sccb_if : SCCB bus (monitoring only).
//   Uses tri1 for open-drain behavior (defaults to 1 when undriven, pulled low to drive 0).
//======================================================================
interface sccb_if ();
  tri1 sioc;
  tri1 siod;
endinterface
