`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.10.2025
// Design Name: Floating Point RNE (Round to Nearest Even)
// Module Name: rne10
// Project Name: FP_ALU
// Target Devices: Basys3 / NexysA7
// Tool Versions: Vivado 2023.x+
// Description: 
//   Implementa el redondeo Round-to-Nearest-Even (RNE) para números 
//   en formato de punto flotante de 16 bits (half precision).
//   Entrada: mantisa normalizada (10 bits), bits de guard, round, sticky y exponente.
//   Salida: mantisa redondeada, exponente ajustado e indicador de inexactitud.
// 
// IEEE-754: 
//   Si guard=1 y (round|sticky|LSB=1) ? se incrementa la mantisa.
//   Si hay carry ? el exponente aumenta en +1.
//   inexact = guard | round | sticky.
// 
// Dependencies: None
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//   Este módulo puede adaptarse fácilmente a single precision (mantisa de 23 bits).
//////////////////////////////////////////////////////////////////////////////////

module rne10 (
  input  [9:0]        mant_in,
  input               guard,
  input               round,
  input               sticky,
  input  signed [6:0] exp_in,     // signed
  output [9:0]        mant_out,
  output signed [6:0] exp_out,    // signed
  output              inexact
);
  wire lsb = mant_in[0];
  wire inc = guard & (round | sticky | lsb);
  wire [10:0] sum = {1'b0, mant_in} + (inc ? 11'd1 : 11'd0);

  wire carry = sum[10];
  assign mant_out = carry ? sum[10:1] : sum[9:0];   // renormaliza si hay carry
  assign exp_out  = exp_in + (carry ? 7'sd1 : 7'sd0);
  assign inexact  = guard | round | sticky;
endmodule
