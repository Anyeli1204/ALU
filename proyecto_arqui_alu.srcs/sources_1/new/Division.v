`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.10.2025 13:25:50
// Design Name: 
// Module Name: Division
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// -------- Division.v (FP16) --------
module Division(
  input  [10:0]       Sm, Rm,     // mantisas con bit implícito (o 0 si subnormal)
  input  signed [6:0] ExpIn,      // exponente efectivo (e1_eff - e2_eff + bias)
  output       [9:0]  Fm,         // mantisa normalizada (10 bits)
  output signed [6:0] ExpOut      // exponente tras normalizar/round
);
  // Escalamos el dividendo para tener "fracción" suficiente
  wire [21:0] num  = {Sm, 11'b0};     // Sm * 2^11
  wire [21:0] Quot = num / Rm;        // cociente
  wire [21:0] Rem  = num % Rm;        // residuo (para sticky)

  // Ventana de 13 bits para decidir normalización
  wire [12:0] Qw = Quot[12:0];
  wire Debe        = Qw[12];          // 1x.xxxxx...
  wire AlreadyNorm = (!Debe) && Qw[11]; // 1.xxxxx...
  wire NeedLeft    = (!Debe) && (!Qw[11]); // 0.xxxxx...

  // Busca cuántos shifts a la IZQ para llevar el primer '1' a bit 11
  function [4:0] first_one_local;
  input [11:0] bits;
  integer idx;
  reg found;
  begin
    found = 1'b0;
    first_one_local = 5'd11; // valor por defecto
    for (idx = 11; idx >= 0 && !found; idx = idx - 1) begin
      if (bits[idx]) begin
        first_one_local = 11 - idx;
        found = 1'b1; // esto rompe el bucle sin usar disable
      end
    end
  end
endfunction


  wire [4:0] lsh = NeedLeft ? first_one_local(Qw[11:0]) : 5'd0;

  // Exponente previo al redondeo
  // - Si 0.x ? normalizamos a la IZQ (equivale a dividir por 2^{-lsh} => exponente - lsh)
  // - Si 1x.x ? normalizamos a la DER (>>1) => exponente +1
  wire signed [6:0] e_adj =
      Debe      ?  7'sd1  :
      AlreadyNorm? 7'sd0  :
                   -$signed({2'b00, lsh});

  wire signed [6:0] exp_pre = ExpIn + e_adj;

  // Construimos una "cola" desplazada para extraer mantisa y G/R/S coherentes
  // Casos:
  //  - Debe:     usar Qw tal cual (equivale a >>1 de la real), ya está 1x.x...
  //  - 1.x:      usar Qw tal cual
  //  - 0.x:      usar (Qw << lsh)
  wire [12:0] Qnorm =
      Debe       ? Qw :
      AlreadyNorm? Qw :
                   (Qw << lsh);

  // Mantisa preliminar y G/R/S desde la Qnorm
  // Qnorm[12] = bit entero (1), Qnorm[11:2] = 10 bits mantisa, Qnorm[1]=G, Qnorm[0]=R
  wire [9:0] mant_pre  = Qnorm[11:2];
  wire       guard_bit = Qnorm[1];
  wire       round_bit = Qnorm[0];
  wire       sticky_bit= |Rem;   // hubo residuo => hubo info descartada

  // RNE ties-to-even
  wire [9:0]        mant_rne;
  wire signed [6:0] exp_rne;
  wire              inexact_rne;

  rne10 u_rne (
    .mant_in (mant_pre),
    .guard   (guard_bit),
    .round   (round_bit),
    .sticky  (sticky_bit),
    .exp_in  (exp_pre),
    .mant_out(mant_rne),
    .exp_out (exp_rne),
    .inexact (inexact_rne)
  );

  assign Fm     = mant_rne;
  assign ExpOut = exp_rne;
endmodule

// -------- DivHP (wrapper FP16) --------

module DivHP (input [15:0] S, input [15:0] R, output [15:0] F);
  wire s1 = S[15], s2 = R[15];
  wire [4:0] e1 = S[14:10], e2 = R[14:10];
  wire [9:0] f1 = S[9:0],   f2 = R[9:0];
  wire sign = s1 ^ s2;

  // Bit implícito y exponente efectivo (subnormal: imp=0, e_eff=1)
  wire [10:0] Sm = (e1==5'd0) ? {1'b0, f1} : {1'b1, f1};
  wire [10:0] Rm = (e2==5'd0) ? {1'b0, f2} : {1'b1, f2};

  wire signed [6:0] e1_eff = (e1==5'd0) ? 7'sd1 : $signed({2'b00,e1});
  wire signed [6:0] e2_eff = (e2==5'd0) ? 7'sd1 : $signed({2'b00,e2});

  // División: e = e1 - e2 + bias(15)
  wire signed [6:0] exp_in = e1_eff - e2_eff + 7'sd15;

  wire [9:0]        mant_out;
  wire signed [6:0] exp_out_s;

  Division u_div(
    .Sm    (Sm),
    .Rm    (Rm),
    .ExpIn (exp_in),
    .Fm    (mant_out),
    .ExpOut(exp_out_s)
  );

  // Empaquetado mínimo (clamp 0..31) - sin casos especiales aún
  wire [4:0] e_pack =
      (exp_out_s <= 7'sd0)  ? 5'd0  :
      (exp_out_s >= 7'sd31) ? 5'd31 :
                              exp_out_s[4:0];

  assign F = {sign, e_pack, mant_out};
endmodule
