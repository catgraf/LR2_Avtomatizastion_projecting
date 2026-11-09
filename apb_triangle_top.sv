`timescale 1ns/1ps //единица времени — 1 нс, точность — 1 пс

module apb_triangle_top (
    input               pclk,     // синхросигнал
    input               presetn,  // сигнал сброса (инверсный)
    // хост-интерфейс (управление мастером)
    input               req,      // запрос на транзакцию
    input               wr,       // 1 — запись, 0 — чтение
    input        [31:0] addr,     // адрес обращения
    input        [31:0] wdata,    // данные для записи
    output logic [31:0] rdata,    // прочитанные данные
    output logic        ready,    // транзакция завершена
    output logic        err       // признак ошибки (pslverr от треугольника)
);
    wire        psel;     // признак выбора устройства
    wire        penable;  // признак активной транзакции
    wire        pwrite;   // признак операции записи
    wire [31:0] paddr;    // адрес обращения
    wire [31:0] pwdata;   // данные для записи
    wire [31:0] prdata;   // прочитанные данные
    wire        pready;   // признак готовности от устройства
    wire        pslverr;  // признак ошибки при обращении

    apb_master MASTER (
        .pclk    (pclk),
        .presetn (presetn),
        .req     (req),
        .wr      (wr),
        .addr    (addr),
        .wdata   (wdata),
        .rdata   (rdata),
        .ready   (ready),
        .err     (err),
        .psel    (psel),
        .penable (penable),
        .pwrite  (pwrite),
        .paddr   (paddr),
        .pwdata  (pwdata),
        .prdata  (prdata),
        .pready  (pready),
        .pslverr (pslverr)
    );

    apb_triangle TRIANGLE (
        .pclk    (pclk),
        .presetn (presetn),
        .paddr   (paddr),
        .pwdata  (pwdata),
        .psel    (psel),
        .penable (penable),
        .pwrite  (pwrite),
        .pready  (pready),
        .pslverr (pslverr),
        .prdata  (prdata)
    );

endmodule
