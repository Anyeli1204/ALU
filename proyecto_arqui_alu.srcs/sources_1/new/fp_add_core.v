`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.10.2025 13:51:36
// Design Name: 
// Module Name: fp_add_core
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

module FullAdder(input Si, input Ri, input Din, output Debe, output Dout);
  assign Debe = (Si & Ri) | (Ri & Din) | (Si & Din);
  assign Dout = Si ^ Ri ^ Din;
endmodule

module SumarExp(input [4:0] S, input [4:0] R, output [4:0] F);
  wire [5:0] c;
  assign c[0] = 1'b0;
  genvar i;
  generate
    for (i=0;i<5;i=i+1) begin : G
      FullAdder add_i(S[i], R[i], c[i], c[i+1], F[i]);
    end
  endgenerate
endmodule

module mas_1_bit_expo(input [4:0] exp, output [4:0] F);
  SumarExp add_exp(exp, 5'b00001, F);
endmodule

// -------- Resta de mantisas (usa FullSub y RestaExp ya existentes) --------
module RestaMantisa(
  input        is_same_exp,
  input  [9:0] S, R,
  input  [4:0] ExpIn,
  input        is_mayus_exp,  // 1 si e(S) > e(R)
  output [4:0] ExpOut,
  output [9:0] F
);
  // function local para evitar problemas de scope
  function [4:0] first_one_9bits;
    input [9:0] val;
    integer idx; reg found;
    begin
      found = 1'b0; first_one_9bits = 5'd0;
      for (idx=9; idx>=0; idx=idx-1) begin
        if (val[idx] && !found) begin
          first_one_9bits = (10 - idx);
          found = 1'b1;
        end
      end
    end
  endfunction

  wire [10:0] b_s, b_r;
  wire [9:0]  diff_sr, diff_rs;
  assign b_s[0] = 1'b0;
  assign b_r[0] = 1'b0;

  genvar i;
  generate
    for (i=0;i<10;i=i+1) begin : GR
      // F = S - R  y  F_e = R - S  (para decidir cu�l usar)
      FullSub sub_sr(S[i], R[i], b_s[i], b_s[i+1], diff_sr[i]);
      FullSub sub_rs(R[i], S[i], b_r[i], b_r[i+1], diff_rs[i]);
    end
  endgenerate

  wire [4:0] idx_sr = first_one_9bits(diff_sr);
  wire [4:0] idx_rs = first_one_9bits(diff_rs);

  // Elegimos �ndice y resultado seg�n cu�l �qued� negativo� tras la resta
  wire choose_rs    = (!is_mayus_exp && !is_same_exp) || (is_same_exp && b_s[10]);
  wire [4:0] idx    = choose_rs ? idx_rs    : idx_sr;
  wire [9:0] diff   = choose_rs ? diff_rs   : diff_sr;

  // �Debemos normalizar? (casos: mismos exponentes, o hubo pr�stamo final)
  wire need_shift = (!is_mayus_exp && b_r[10]) || is_same_exp || (is_mayus_exp && b_s[10]);

  wire [4:0] exp_adj;
  RestaExp sub_e(ExpIn, idx, exp_adj);

  assign ExpOut = need_shift ? exp_adj      : ExpIn;
  assign F      = need_shift ? (diff << idx) : diff;
endmodule

// -------- Suma de mantisas --------
module SumMantisa(
  input        is_same_exp,
  input  [9:0] S, R,
  input  [4:0] ExpIn,
  output [4:0] ExpOut,
  output [9:0] F
);
  wire [10:0] c;
  wire [9:0]  sum_raw;
  assign c[0] = 1'b0;

  genvar i;
  generate
    for (i=0;i<10;i=i+1) begin : GA
      FullAdder add_i(S[i], R[i], c[i], c[i+1], sum_raw[i]);
    end
  endgenerate

  // si hay carry (2.x) o si ven�an con el mismo exponente, sube exponente
  wire [4:0] exp_plus1;
  mas_1_bit_expo inc1(ExpIn, exp_plus1);

  assign ExpOut = (c[10] || is_same_exp) ? exp_plus1 : ExpIn;

  // si hay carry o mismo exp, corremos a la derecha 1 (para 1.x)
  wire [9:0] half_shift = {1'b1, sum_raw[9:1]};
  assign F = (c[10] && is_same_exp) ? half_shift :
             (c[10] || is_same_exp) ? (sum_raw >> 1) :
             sum_raw;
endmodule

// -------- Core de 16 bits (half) con RNE --------
module Suma16Bits (
  input  [15:0] S,   // A (half)
  input  [15:0] R,   // B (half)
  output [15:0] F    // Y = A (+/-) B  (para resta el wrapper invierte el signo de R)
);
  // ---- temporales para normalizaci�n (deben ir a nivel de m�dulo en Verilog) ----
  integer i;
  integer shl;
  reg [13:0] L;
  
  // Campos
  wire       sa = S[15];
  wire [4:0] ea = S[14:10];
  wire [9:0] fa = S[9:0];

  wire       sb = R[15];
  wire [4:0] eb = R[14:10];
  wire [9:0] fb = R[9:0];

  // Mantisas extendidas a 13b: [1_imp | 10 frac | GRS(3)=000]
  wire [12:0] ma0 = { (ea!=5'b0), fa, 3'b000 };  // bit impl�cito solo si normal
  wire [12:0] mb0 = { (eb!=5'b0), fb, 3'b000 };

  // Ordenar por exponente y magnitud
  wire a_ge_b = (ea > eb) || ((ea == eb) && (ma0 >= mb0));
  wire [4:0]   E_big  = a_ge_b ? ea  : eb;
  wire [4:0]   E_sml  = a_ge_b ? eb  : ea;
  wire [12:0]  M_big  = a_ge_b ? ma0 : mb0;
  wire [12:0]  M_sml  = a_ge_b ? mb0 : ma0;
  wire         S_big  = a_ge_b ? sa  : sb;
  wire         S_sml  = a_ge_b ? sb  : sa;

  // Desplazamiento derecha con sticky
  function [12:0] rshift13_sticky;
    input [12:0] x;
    input [4:0]  sh;
    reg   [12:0] t;
    reg          st;
    integer      k;
    begin
      if (sh == 0) begin
        rshift13_sticky = x;
      end else if (sh >= 13) begin
        st = |x;                 // todo se pierde ? solo sticky
        rshift13_sticky = 13'b0;
        rshift13_sticky[0] = st;
      end else begin
        t  = (x >> sh);
        st = 1'b0;
        for (k = 0; k < sh; k = k + 1) st = st | x[k]; // OR de bits perdidos
        t[0] = t[0] | st;           // pego sticky en el LSB
        rshift13_sticky = t;
      end
    end
  endfunction

  wire [4:0]  d         = E_big - E_sml;
  wire [12:0] M_sml_al  = rshift13_sticky(M_sml, d);
  wire [4:0]  E_al      = E_big;

  // �sumo o resto? (depende de los signos)
  wire do_sub = (S_big != S_sml);

  // Operaci�n en magnitud (14b por si carry)
  wire [13:0] sum_mag = {1'b0, M_big} + {1'b0, M_sml_al};
  wire [13:0] dif_mag = {1'b0, M_big} - {1'b0, M_sml_al};

  reg  [13:0] mag_raw;
  reg         s_res;
  reg  [4:0]  e_raw;

  always @* begin
    if (!do_sub) begin
      mag_raw = sum_mag;
      s_res   = S_big;
      e_raw   = E_al;
    end else begin
      mag_raw = dif_mag;   // M_big >= M_sml_al por construcci�n
      s_res   = S_big;
      e_raw   = E_al;
    end
  end

    // Normalizaci�n + extracci�n G/R/S
  reg  [9:0] mant_pre;
  reg        guard_bit, round_bit, sticky_bit;
  reg signed [6:0] eN;

  always @* begin
    if (mag_raw == 14'b0) begin
      mant_pre   = 10'b0;
      guard_bit  = 1'b0;
      round_bit  = 1'b0;
      sticky_bit = 1'b0;
      eN         = 7'sd0;
    end
    else if (mag_raw[13]) begin
      // 2.xxxxx... -> shift RIGHT 1 y exp+1
      mant_pre   = mag_raw[12:3];
      guard_bit  = mag_raw[2];
      round_bit  = mag_raw[1];
      sticky_bit = mag_raw[0];
      eN         = e_raw + 7'sd1;
    end
    else if (mag_raw[12]) begin
      // 1.xxxxx... -> ya normal
      mant_pre   = mag_raw[11:2];
      guard_bit  = mag_raw[1];
      round_bit  = mag_raw[0];
      sticky_bit = 1'b0;
      eN         = e_raw;
    end
    else begin
      // 0.xxxxx... -> shift LEFT hasta poner el 1 en [12]
      shl = 0;                    // <-- ya no se declara aqu�, solo se usa
      for (i = 12; i >= 0; i = i - 1)
        if (mag_raw[i] && (shl==0)) shl = (12 - i);

      L = mag_raw << shl;         // <-- L tambi�n es a nivel de m�dulo
      mant_pre   = L[11:2];
      guard_bit  = L[1];
      round_bit  = L[0];
      sticky_bit = 1'b0;
      eN = e_raw - $signed({2'b00, shl[4:0]}); // restar shl como signed
    end
  end

  // Sin redondeo - variables finales

  // Sin redondeo - usar directamente los valores pre-redondeo
  wire [9:0] mant_final = mant_pre;
  wire signed [6:0] exp_final = eN;

  // Empaquetado HALF (sin casos especiales aqu�)
  wire is_zero = (mant_final == 10'b0) && (exp_final <= 7'sd0);
  
  // Empaquetado: usar exponente de 5 bits, saturando en 0 si es negativo
  wire [4:0] exp_pack = (exp_final <= 7'sd0) ? 5'd0 : 
                       (exp_final >= 7'sd31) ? 5'd31 : exp_final[4:0];
  
  assign F = is_zero ? {s_res, 15'b0} : {s_res, exp_pack, mant_final};

endmodule

