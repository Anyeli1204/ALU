`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.10.2025 13:43:04
// Design Name: 
// Module Name: fp_sub_wrapper
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


module fp_sub_wrapper (
  input  wire        clk, rst, start,
  input  wire [31:0] op_a, op_b,
  input  wire        mode_fp,
  input  wire [1:0]  round_mode,
  output reg  [31:0] result,
  output reg         valid_out
);
  wire [15:0] a16 = op_a[15:0];
  // A - B  ==  A + (-B)  -> invierte el signo de B
  wire [15:0] b16_neg = {~op_b[15], op_b[14:0]};
  wire [15:0] y16;

  Suma16Bits u_sub_as_add (.S(a16), .R(b16_neg), .F(y16));

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      valid_out <= 1'b0;
      result    <= 32'b0;
    end else begin
      valid_out <= start;
      result    <= {16'b0, y16};
    end
  end
endmodule

