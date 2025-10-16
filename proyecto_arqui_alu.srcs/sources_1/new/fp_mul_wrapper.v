`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.10.2025 12:37:57
// Design Name: 
// Module Name: fp_mul_wrapper
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


module fp_mul_wrapper (
  input  wire        clk, rst, start,
  input  wire [31:0] op_a, op_b,   // usamos [15:0]
  input  wire        mode_fp,      // 0=half, 1=single (por ahora solo half)
  input  wire [1:0]  round_mode,   // ignorado por ahora
  output reg  [31:0] result,       // salida en 16 LSB
  output reg         valid_out
);
  wire [15:0] a16 = op_a[15:0];
  wire [15:0] b16 = op_b[15:0];
  wire [15:0] y16;

  ProductHP u_mul (.S(a16), .R(b16), .F(y16));

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      valid_out <= 1'b0;
      result    <= 32'b0;
    end else begin
      valid_out <= start;          // pulso de 1 ciclo
      result    <= {16'b0, y16};   // 16 LSB válidos
    end
  end
endmodule
