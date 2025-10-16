`timescale 1ns/1ps
module fp_alu_tb;

  // ---------------- DUT I/O ----------------
  reg         clk = 0;
  reg         rst = 0;
  reg         start = 0;
  reg  [31:0] a, b;
  reg  [2:0]  op;
  reg         mode_fp;        // 0=half (16-bit), 1=single (por ahora solo half)
  reg  [1:0]  round_mode;     // ignorado por ahora
  wire [31:0] y;
  wire        valid;

  // DUT
  fp_alu DUT(
    .clk(clk), .rst(rst), .start(start),
    .op_code(op), .op_a(a), .op_b(b),
    .mode_fp(mode_fp), .round_mode(round_mode),
    .result(y), .valid_out(valid)
  );

  // ---------------- Clock ----------------
  always #5 clk = ~clk;  // 100 MHz

  // ---------------- Helpers ----------------
 task pulse_and_wait;
begin
  start = 1; @(posedge clk);   // ciclo 1: los wrappers cargan su registro
  start = 0; @(posedge clk);   // ciclo 2: la ALU registra el mux
  @(posedge clk);              // ciclo 3: la salida ya está estable para leer
end endtask 

  // Compara LSB16 (half) con esperado
  task check16(input [15:0] got, input [15:0] exp, input [127:0] msg);
  begin
    if (got !== exp) begin
      $display("ERROR %s: got=%h exp=%h", msg, got, exp);
      $fatal(1, "Mismatch");
    end else begin
      $display("OK    %s: %h", msg, got);
    end
  end endtask

  // ---- Operaciones como tareas ----
  task do_add(input [15:0] A, input [15:0] B, input [15:0] EXP);
  begin
    a = {16'h0000, A};
    b = {16'h0000, B};
    op = 3'b000; // ADD
    mode_fp = 1'b0;  // half
    round_mode = 2'b00;
    pulse_and_wait();
    $display("ADD %h + %h -> %h (valid=%0d)", A, B, y[15:0], valid);
    check16(y[15:0], EXP, "ADD");
  end endtask

  task do_sub(input [15:0] A, input [15:0] B, input [15:0] EXP);
  begin
    a = {16'h0000, A};
    b = {16'h0000, B};
    op = 3'b001; // SUB
    mode_fp = 1'b0;  // half
    round_mode = 2'b00;
    pulse_and_wait();
    $display("SUB %h - %h -> %h (valid=%0d)", A, B, y[15:0], valid);
    check16(y[15:0], EXP, "SUB");
  end endtask

  task do_mul(input [15:0] A, input [15:0] B, input [15:0] EXP);
  begin
    a = {16'h0000, A};
    b = {16'h0000, B};
    op = 3'b010; // MUL
    mode_fp = 1'b0;  // half
    round_mode = 2'b00;
    pulse_and_wait();
    $display("MUL %h * %h -> %h (valid=%0d)", A, B, y[15:0], valid);
    check16(y[15:0], EXP, "MUL");
  end endtask

  task do_div(input [15:0] A, input [15:0] B, input [15:0] EXP);
  begin
    a = {16'h0000, A};
    b = {16'h0000, B};
    op = 3'b011; // DIV
    mode_fp = 1'b0;  // half
    round_mode = 2'b00;
    pulse_and_wait();
    $display("DIV %h / %h -> %h (valid=%0d)", A, B, y[15:0], valid);
    check16(y[15:0], EXP, "DIV");
  end endtask
  task do_div_nc(input [15:0] A, input [15:0] B);
  begin
    a = {16'h0, A}; b = {16'h0, B};
    op = 3'b011; mode_fp = 1'b0; round_mode = 2'b00;
    start=1; #10; start=0; #10;
    $display("DIV_NC %h / %h -> %h (valid=%0d)", A,B,y[15:0],valid);
  end endtask

  // ---------------- Constantes HALF útiles ----------------
  // 0.5=0x3800, 1.0=0x3C00, 1.5=0x3E00, 2.0=0x4000, 3.0=0x4200,
  // 4.0=0x4400, 6.0=0x4600, 12.0=0x4A00, -1.0=0xBC00, -2.0=0xC000, -6.0=0xC600

  // ---------------- Estímulos ----------------
  initial begin
    // Reset
    rst = 1; repeat(3) @(posedge clk); rst = 0; @(posedge clk);

    // ---- ADD ----
    do_add(16'h3C00,16'h4000,16'h4200); // 1.0 + 2.0 = 3.0
    do_add(16'h4200,16'h4200,16'h4600);   // CORRECTO (6.0)
    do_add(16'hBC00,16'hC000,16'hC200); // -1.0 + (-2.0) = -3.0
    
    // ---- SUB ----
    do_sub(16'h4000,16'h3C00,16'h3C00); // 2.0 - 1.0 = 1.0  (0x3C00)
    do_sub(16'h4200,16'h4400,16'hBC00); // 3.0 - 4.0 = -1.0 (0xBC00)
    do_sub(16'hBC00,16'hC000,16'h3C00); // -1.0 - (-2.0) = 1.0 (0x3C00)
    
    // ---- MUL ----
    do_mul(16'h3C00,16'h4000,16'h4000); // 1.0 * 2.0 = 2.0
    do_mul(16'h4200,16'h4400,16'h4A00); // 3.0 * 4.0 = 12.0
    do_mul(16'hC000,16'h4200,16'hC600); // -2.0 * 3.0 = -6.0
    do_mul(16'h3C01,16'h3C01,16'h3C02); // caso RNE
    do_mul(16'h3C03,16'h3C03,16'h3C06); // caso RNE

    // ---- DIV ----
    do_div(16'h4200,16'h4000,16'h3E00); // 3.0 / 2.0 = 1.5
    do_div(16'h4000,16'h3C00,16'h4000); // 2.0 / 1.0 = 2.0
    do_div(16'hC000,16'h3C00,16'hC000); // -2.0 / 1.0 = -2.0
    do_div_nc(16'h3C01,16'h3C00); // ~1.0005 / 1.0
    do_div_nc(16'h4001,16'h3FFF); // ~2.0005 / ~1.9995
    
    do_add(16'h3C01,16'h0001,16'h3C01); // suma muy pequeña ? no cambia (guard=0)
    do_add(16'h3C01,16'h0002,16'h3C02); // guard=1, LSB=1 ? incrementa
    do_add(16'h3555,16'h3555,16'h36AB); // matching frac, posible carry en mantisa
    do_sub(16'h3C01,16'h0001,16'h3C00); // resta mínima ? puede requerir normalizar
    do_sub(16'h3E00,16'h3C00,16'h3800); // 1.5-1.0=0.5
    do_sub(16'h4000,16'h3FFF,16'h0001); // resultado muy pequeño (casi 0) normaliza
    $display("OK: todas las pruebas pasaron.");
    $finish;
  end

endmodule
