`timescale 1ns/1ps //единица времени — 1 нс, точность — 1 пс

module tb_triangle_top;

  // Сигналы хоста
  logic        pclk;
  logic        presetn;
  logic        req;
  logic        wr;
  logic [31:0] addr;
  logic [31:0] wdata;
  wire  [31:0] rdata;
  wire         ready;
  wire         err;

  // Параметры
  parameter bit [31:0] p_device_offset = 32'h7000_0000;

  // Внутренние переменные тестбенча
  logic [31:0] address;
  logic [31:0] data_to_device;
  logic [31:0] data_from_device;
  logic        err_seen; // захват err: сбрасывается в MASTER_DONE, проверяем через монитор

  apb_triangle_top TOP (
    .pclk    (pclk),
    .presetn (presetn),
    .req     (req),
    .wr      (wr),
    .addr    (addr),
    .wdata   (wdata),
    .rdata   (rdata),
    .ready   (ready),
    .err     (err)
  );

  // Монитор факта ошибки, т.к err живёт один такт
  always @(posedge pclk)
    if (err) err_seen <= 1'b1;

  // Запись через мастера
  task apb_write(input [31:0] a, input [31:0] d);
    wait (ready == 1'b0);
    @(posedge pclk);
    req   <= 1'b1;
    wr    <= 1'b1;
    addr  <= a;
    wdata <= d;
    wait (ready == 1'b1);
    req   <= 1'b0;
    wait (ready == 1'b0);
  endtask

  // Чтение через мастера
  task apb_read(input [31:0] a, output logic [31:0] d);
    wait (ready == 1'b0);
    @(posedge pclk);
    req   <= 1'b1;
    wr    <= 1'b0;
    addr  <= a;
    wait (ready == 1'b1);
    d = rdata;
    req   <= 1'b0;
    wait (ready == 1'b0);
  endtask

  // Генератор тактового сигнала (период 20 нс)
  always #10 pclk = ~pclk;

  initial begin
    pclk    = 1'b0;
    presetn = 1'b1;
    req     = 1'b0;
    wr      = 1'b0;
    addr    = '0;
    wdata   = '0;
    err_seen = 1'b0;

    repeat (5) @(posedge pclk);
        presetn = 1'b0;
    repeat (5) @(posedge pclk);
        presetn = 1'b1;
    repeat (5) @(posedge pclk);

    // T1: запись/чтение регистров A, B, C
    apb_write(p_device_offset + 0, 32'd3);
    apb_read (p_device_offset + 0, data_from_device);
    if (data_from_device !== 32'd3) $error("[TB] FAIL T1: A=0x%08h", data_from_device);
    apb_write(p_device_offset + 4, 32'd4);
    apb_read (p_device_offset + 4, data_from_device);
    if (data_from_device !== 32'd4) $error("[TB] FAIL T1: B=0x%08h", data_from_device);
    apb_write(p_device_offset + 8, 32'd5);
    apb_read (p_device_offset + 8, data_from_device);
    if (data_from_device !== 32'd5) $error("[TB] FAIL T1: C=0x%08h", data_from_device);
    $display("[TB] PASS T1: register read/write");

    // T2: валидный треугольник 3,4,5 -> 12
    apb_write(p_device_offset + 0, 32'd3);
    apb_write(p_device_offset + 4, 32'd4);
    apb_write(p_device_offset + 8, 32'd5);
    err_seen = 1'b0;
    apb_read (p_device_offset + 12, data_from_device);
    if (data_from_device !== 32'd12 || err_seen !== 1'b0)
        $error("[TB] FAIL T2: got 0x%08h, err=%b", data_from_device, err_seen);
    else
        $display("[TB] PASS T2: 3,4,5 -> 12");

    // T3: невалидный треугольник 1,1,100 -> err, prdata=0
    apb_write(p_device_offset + 0, 32'd1);
    apb_write(p_device_offset + 4, 32'd1);
    apb_write(p_device_offset + 8, 32'd100);
    err_seen = 1'b0;
    apb_read (p_device_offset + 12, data_from_device);
    if (err_seen !== 1'b1 || data_from_device !== 32'd0)
        $error("[TB] FAIL T3: err=%b, prdata=0x%08h", err_seen, data_from_device);
    else
        $display("[TB] PASS T3: 1,1,100 -> err");

    // T4: вырожденный 1,2,3 (1+2=3, не > 3) -> err
    apb_write(p_device_offset + 0, 32'd1);
    apb_write(p_device_offset + 4, 32'd2);
    apb_write(p_device_offset + 8, 32'd3);
    err_seen = 1'b0;
    apb_read (p_device_offset + 12, data_from_device);
    if (err_seen !== 1'b1)
        $error("[TB] FAIL T4: expected err");
    else
        $display("[TB] PASS T4: 1,2,3 -> err");

    // T5: переполнение суммы 0xFFFFFFFF*3 (треугольник валиден, но сумма не влезает в 32 бита)
    apb_write(p_device_offset + 0, 32'hFFFFFFFF);
    apb_write(p_device_offset + 4, 32'hFFFFFFFF);
    apb_write(p_device_offset + 8, 32'hFFFFFFFF);
    err_seen = 1'b0;
    apb_read (p_device_offset + 12, data_from_device);
    if (err_seen !== 1'b1 || data_from_device !== 32'd0)
        $error("[TB] FAIL T5: err=%b, prdata=0x%08h", err_seen, data_from_device);
    else
        $display("[TB] PASS T5: overflow -> err");

    // T6: максимальный валидный треугольник 0x55555555*3 -> 0xFFFFFFFF
    apb_write(p_device_offset + 0, 32'h55555555);
    apb_write(p_device_offset + 4, 32'h55555555);
    apb_write(p_device_offset + 8, 32'h55555555);
    err_seen = 1'b0;
    apb_read (p_device_offset + 12, data_from_device);
    if (data_from_device !== 32'hFFFFFFFF || err_seen !== 1'b0)
        $error("[TB] FAIL T6: got 0x%08h, err=%b", data_from_device, err_seen);
    else
        $display("[TB] PASS T6: max valid -> 0xFFFFFFFF");

    // T7: запись в read-only PERIM -> err
    err_seen = 1'b0;
    apb_write(p_device_offset + 12, 32'hDEADBEEF);
    if (err_seen !== 1'b1)
        $error("[TB] FAIL T7: expected err on write to PERIM");
    else
        $display("[TB] PASS T7: write to PERIM -> err");

    // T8: чтение по невалидному адресу -> err
    err_seen = 1'b0;
    apb_read (p_device_offset + 16, data_from_device);
    if (err_seen !== 1'b1)
        $error("[TB] FAIL T8: expected err on invalid read addr");
    else
        $display("[TB] PASS T8: read invalid addr -> err");

    // T9: 0,0,0 -> err (граница: сумма = 0)
    apb_write(p_device_offset + 0, 32'd0);
    apb_write(p_device_offset + 4, 32'd0);
    apb_write(p_device_offset + 8, 32'd0);
    err_seen = 1'b0;
    apb_read (p_device_offset + 12, data_from_device);
    if (err_seen !== 1'b1)
        $error("[TB] FAIL T9: expected err for 0,0,0");
    else
        $display("[TB] PASS T9: 0,0,0 -> err");

    repeat (10) @(posedge pclk);
    $finish();
  end

endmodule
