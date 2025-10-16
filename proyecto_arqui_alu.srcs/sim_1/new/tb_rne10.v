`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.10.2025 12:12:54
// Design Name: 
// Module Name: tb_rne10
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

module tb_rne10;
  reg  [9:0] mant_in;
  reg        guard, roundb, sticky;
  reg  [4:0] exp_in;
  wire [9:0] mant_out;
  wire [4:0] exp_out;
  wire       inexact;

  // DUT
  rne10 dut(
    .mant_in(mant_in),
    .guard(guard),
    .round(roundb),
    .sticky(sticky),
    .exp_in(exp_in),
    .mant_out(mant_out),
    .exp_out(exp_out),
    .inexact(inexact)
  );

  // helper de check
  task check(input [9:0] emant, input [4:0] eexp, input [127:0] name);
  begin
    if (mant_out !== emant || exp_out !== eexp) begin
      $display("ERROR %-12s  mant_out=%h exp_out=%h  (exp=%h %h)",
               name, mant_out, exp_out, emant, eexp);
      $fatal(1, "Mismatch");
    end else begin
      $display("OK    %-12s  mant=%h exp=%h  inexact=%0d",
               name, mant_out, exp_out, inexact);
    end
  end endtask

  initial begin
    // Caso A: tie exacto y LSB=0  -> NO incrementa (round-to-even)
    // inc = guard & (round|sticky|LSB) = 1 & (0|0|0) = 0
    mant_in = 10'h000; guard = 1; roundb = 0; sticky = 0; exp_in = 5'h0F;
    #1; check(10'h000, 5'h0F, "tie-even LSB=0");

    // Caso B: tie exacto y LSB=1  -> SÍ incrementa (para volverlo par)
    // inc = 1 & (0|0|1) = 1
    mant_in = 10'h001; guard = 1; roundb = 0; sticky = 0; exp_in = 5'h0F;
    #1; check(10'h002, 5'h0F, "tie-even LSB=1");

    // Caso C: guard=1 y (round|sticky)=1  -> SÍ incrementa
    // Además probamos overflow de mantisa: 0x3FF + 1 = 0x400 ? carry => exp+1
    mant_in = 10'h3FF; guard = 1; roundb = 1; sticky = 0; exp_in = 5'h0A;
    #1; check(10'h000, 5'h0B, "inc + carry->exp+1");

    // Caso D: guard=0 (aunque R/S=1) -> NO incrementa (pero inexact=1)
    mant_in = 10'h155; guard = 0; roundb = 1; sticky = 1; exp_in = 5'h04;
    #1; check(10'h155, 5'h04, "no-inc guard=0");

    // Caso E: incremento normal sin carry
    mant_in = 10'h2AA; guard = 1; roundb = 1; sticky = 0; exp_in = 5'h1C;
    #1; check(10'h2AB, 5'h1C, "inc sin carry");

    $display("OK: rne10 pasó todas las pruebas.");
    $finish;
  end
endmodule

