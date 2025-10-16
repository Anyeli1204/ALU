`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.10.2025 13:06:55
// Design Name: 
// Module Name: fp_alu_tb
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

`timescale 1ns/1ps
module fp_alu_tb;
  reg clk=0, rst=0, start=0;
  reg [31:0] a, b;
  reg [2:0]  op;
  reg        mode_fp;      // 0=half
  reg [1:0]  round_mode;   // ignorado
  wire [31:0] y;
  wire valid;

  fp_alu DUT(
    .clk(clk), .rst(rst), .start(start),
    .op_code(op), .op_a(a), .op_b(b),
    .mode_fp(mode_fp), .round_mode(round_mode),
    .result(y), .valid_out(valid)
  );

  always #5 clk = ~clk;

  task do_mul(input [15:0] A, input [15:0] B);
  begin
    a = {16'h0, A};
    b = {16'h0, B};
    op = 3'b010; mode_fp = 1'b0; round_mode = 2'b00;
    start = 1; #10; start = 0; #10;
    $display("MUL half A=%h B=%h -> Y=%h (valid=%0d)", A,B,y[15:0],valid);
  end endtask

  initial begin
    rst=1; #20; rst=0;
    do_mul(16'h3C00, 16'h4000); // 1.0 * 2.0 ? 2.0 (0x4000)
    do_mul(16'h4200, 16'h4400); // 3.0 * 4.0 ? 12.0
    do_mul(16'hC000, 16'h4200); // -2.0 * 3.0 ? -6.0
    $finish;
  end
endmodule

