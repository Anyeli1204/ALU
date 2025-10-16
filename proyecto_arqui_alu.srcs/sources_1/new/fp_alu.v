`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.10.2025 12:38:28
// Design Name: 
// Module Name: fp_alu
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

module fp_alu (
  input  wire        clk, rst, start,
  input  wire [2:0]  op_code,         // 000:add,001:sub,010:mul,011:div
  input  wire [31:0] op_a, op_b,
  input  wire        mode_fp,         // 0=half, 1=single
  input  wire [1:0]  round_mode,
  output reg  [31:0] result,
  output reg         valid_out
);

  wire [31:0] y_add, y_sub, y_mul, y_div;
  wire        v_add, v_sub, v_mul, v_div;
  
  fp_mul_wrapper u_mul(
    .clk(clk), .rst(rst), .start(start),
    .op_a(op_a), .op_b(op_b),
    .mode_fp(mode_fp), .round_mode(round_mode),
    .result(y_mul), .valid_out(v_mul)
  );
  fp_div_wrapper u_div(
  .clk(clk), .rst(rst), .start(start),
  .op_a(op_a), .op_b(op_b),
  .mode_fp(mode_fp), .round_mode(round_mode),
  .result(y_div), .valid_out(v_div)
  );
  fp_add_wrapper u_add(
  .clk(clk), .rst(rst), .start(start),
  .op_a(op_a), .op_b(op_b),
  .mode_fp(mode_fp), .round_mode(round_mode),
  .result(y_add), .valid_out(v_add)
  );

  fp_sub_wrapper u_sub(
  .clk(clk), .rst(rst), .start(start),
  .op_a(op_a), .op_b(op_b),
  .mode_fp(mode_fp), .round_mode(round_mode),
  .result(y_sub), .valid_out(v_sub)
  );

 reg [31:0] result_next;
reg        valid_next;

always @* begin
  result_next = 32'b0;
  valid_next  = 1'b0;
  case (op_code)
    3'b000: begin result_next = y_add; valid_next = v_add; end
    3'b001: begin result_next = y_sub; valid_next = v_sub; end
    3'b010: begin result_next = y_mul; valid_next = v_mul; end
    3'b011: begin result_next = y_div; valid_next = v_div; end
    default: ;
  endcase
end

always @(posedge clk or posedge rst) begin
  if (rst) begin
    result    <= 32'b0;
    valid_out <= 1'b0;
  end else begin
    result    <= result_next;
    valid_out <= valid_next;
  end
end

  
endmodule

