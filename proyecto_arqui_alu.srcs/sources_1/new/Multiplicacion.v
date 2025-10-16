`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.10.2025 12:37:37
// Design Name: 
// Module Name: Multiplicacion
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

//Si: Input que representa el bit del minuendo
//Ri: Input que representa el bit del sustraendo
//Din: Input que representa el borrow in (prestado del bit anterior)
//Debe: Borrow out que se genera para el siguiente bit
//Dout: Resultado de la resta bit a bit (Si-Ri-Din)
module FullSub(Si, Ri, Din, Debe, Dout);
  input Si, Ri, Din;
  output wire Debe, Dout;
  //Se pide prestado en casos: 
  //Si es 0 y Ri es 1 -> no se puede restar por lo que se pide prestado
  //Si es 0 y Din es 1 -> ya se pidi� prestado, se pide de nuevo
  //Ri y Din son 1 -> Dos cosas que restar tambi�n se pide prestado
  assign Debe = (~Si & Ri) | (~Si & Din) | (Ri & Din);
  assign Dout = Si ^ Ri ^ Din; //XOR que cambia el valor si hay una cantidad impar de 1's
endmodule

module RestaExp(S, R, F);
  input [4:0] S, R;
  output wire[4:0] F;
  //Debe[0] inicia en  porque arranca sin deuda
  wire [5:0] Debe; assign Debe[0] = 1'b0;
  genvar i;
  generate
    for(i = 0; i < 5; i = i + 1)
      FullSub sub_i(S[i], R[i], Debe[i], Debe[i+1], F[i]);
  endgenerate
endmodule

//Bajar un nivel en el exponente durante la normalizaci�n
//Resta 1 al exponente de 5 bits 
module restar_1_bit_expo(exp, F);
  input [4:0] exp; output [4:0] F;
  RestaExp sub_exp(exp, 5'b00001, F); //Llama a RestaExp con el n�mero 00001
endmodule

//--------------------------
//No se usa, se puede eliminar
//--------------------------
//Corrimiento a la derecha de la mantisa para alinear los n�meros flotantes
module right_shift_pf(mantisa, shifts, F);
  input [9:0] mantisa; //10 bits de la parte decimal del n�mero
  input [4:0] shifts; // Cuantas posiciones hay que desplazar (cu�nto difieren los exponentes)
  output [9:0] F; //Nueva mantisa desplazada
  wire [9:0] e1 = {1'b1, mantisa[9:1]}; //Agregar bit implicito del IEEE 754
  wire [4:0] aux_shifts;
  //Restar 1 al n�mero de corrimientos
  restar_1_bit_expo sub_shift(.exp(shifts), .F(aux_shifts));
  //Si shifts>0 e1 se mueve hacia la derecha auz_shift  posiciones
  //Si shifts = 0, no se toca la mantisa (ya esta alineado) 
  assign F = (shifts > 0) ? e1 >> aux_shifts : mantisa;
endmodule

module Prod(Sm, Rm, ExpIn, Fm, ExpOut);
  input [10:0] Sm, Rm;
  input signed [6:0]  ExpIn;
  output [9:0]  Fm;
  output signed [6:0]  ExpOut;

  wire [21:0] P = Sm * Rm;
  wire Debe = P[21];
  wire is_norm = P[20];
  wire need_left = !Debe && !is_norm;

  // Funci�n local: primera '1' en la ventana [20:0]
function [4:0] first_one_local;
    input [20:0] bits;
    integer idx;
    reg found;
    begin
      found = 1'b0;
      first_one_local = 5'd20;
      // buscamos desde 20->0 el primer '1'
      for (idx = 20; idx >= 0 && !found; idx = idx - 1) begin
        if (bits[idx]) begin
          // cantidad de desplazamientos para llevar ese '1' a la posici�n 20
          first_one_local = 20 - idx;
          found = 1'b1;
        end
      end
    end
  endfunction
  
  wire [4:0] shifts = need_left ? first_one_local(P[20:0]) : 5'd0;
  wire [21:0] N =
      Debe      ? (P >> 1) :
      is_norm   ?  P       :
                  (P << shifts);

  // Ajuste de exponente
  wire signed [6:0] e_adj =
      Debe      ?  7'sd1  :
      is_norm   ?  7'sd0  :
                  -$signed({2'b00,shifts}); // -(shifts)

  wire signed [6:0] exp_pre = ExpIn + e_adj;
  // Extraer mantisa y bits G/R/S desde N
  wire [9:0] mant_pre   = N[19:10];
  wire       guard_bit  = N[9];
  wire       round_bit  = N[8];
  wire       sticky_bit = |N[7:0];

  // Redondeo a lazos (RNE ties-to-even)
  wire [9:0] mant_rne;
  wire signed [6:0] exp_rne;
  wire       inexact_rne; // si quieres, �salo luego como flag

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

module ProductHP (S, R, F);
  input  [15:0] S, R;
  output [15:0] F;

  wire [9:0] m1 = S[9:0];
  wire [9:0] m2 = R[9:0];
  wire [4:0] e1 = S[14:10];
  wire [4:0] e2 = R[14:10];
  wire s1 = S[15];
  wire s2 = R[15];
  wire sign = s1 ^ s2;
  
  // Bit impl�cito SOLO si es normal (e != 0)
  wire [10:0] param_m1 = (e1==5'b0) ? {1'b0, m1} : {1'b1, m1};
  wire [10:0] param_m2 = (e2==5'b0) ? {1'b0, m2} : {1'b1, m2};

  // bias half = 15
  wire signed [6:0] e1_eff = (e1==5'd0) ? 7'sd1 : $signed({2'b00, e1});
  wire signed [6:0] e2_eff = (e2==5'd0) ? 7'sd1 : $signed({2'b00, e2});
  wire signed [6:0] exp_to_use = e1_eff + e2_eff - 7'sd15;

 
  wire [9:0] m_final;
  wire signed [6:0] exp_final;
  Prod product_mantisa(
    .Sm     (param_m1),
    .Rm     (param_m2),
    .ExpIn  (exp_to_use),
    .Fm     (m_final),
    .ExpOut (exp_final)
  );
  // Empaquetado m�nimo (clamp 0..31, sin especiales)
  wire [4:0] e_pack =
      (exp_final <= 7'sd0)  ? 5'd0  :
      (exp_final >= 7'sd31) ? 5'd31 : exp_final[4:0];

  assign F = {sign, e_pack, m_final};
endmodule