`timescale 1ns/1ps //единица времени — 1 нс, точность — 1 пс

module apb_master (
    input               pclk,     // синхросигнал
    input               presetn,  // сигнал сброса (инверсный)
    // управляющий интерфейс (сторона хоста)
    input               req,      // запрос на транзакцию
    input               wr,       // 1 — запись, 0 — чтение
    input        [31:0] addr,     // адрес обращения
    input        [31:0] wdata,    // данные для записи
    output logic [31:0] rdata,    // прочитанные данные
    output logic        ready,    // транзакция завершена (уровень)
    output logic        err,      // признак ошибки (pslverr)
    // интерфейс APB (сторона шины)
    output logic        psel,     // признак выбора устройства
    output logic        penable,  // признак активной транзакции
    output logic        pwrite,   // признак операции записи
    output logic [31:0] paddr,    // адрес обращения
    output logic [31:0] pwdata,   // данные для записи
    input        [31:0] prdata,   // прочитанные данные
    input               pready,   // признак готовности от устройства
    input               pslverr   // признак ошибки при обращении
);

    // FSM мастера
    enum logic [1:0] {
        MASTER_IDLE,   //   IDLE   — ждём req, выходы APB в 0;
        MASTER_SETUP,  //   SETUP  — фаза SETUP по APB: psel=1, penable=0 (один такт);
        MASTER_ACCESS, //   ACCESS — фаза ACCESS по APB: psel=1, penable=1, ждём pready=1;
        MASTER_DONE    //   DONE   — ready=1, ждём req=0 (защита от повторного запуска).
    } master_st;

    //сброс и выставление дефолтных значений
    always @(posedge pclk) begin
        if (!presetn) begin
            psel      <= 1'b0;
            penable   <= 1'b0;
            pwrite    <= 1'b0;
            paddr     <= '0;
            pwdata    <= '0;
            rdata     <= '0;
            ready     <= 1'b0;
            err       <= 1'b0;
            master_st <= MASTER_IDLE;
        end else begin
            case (master_st)

                MASTER_IDLE: begin: master_idle_st
                    ready <= 1'b0;
                    err   <= 1'b0;
                    if (req) begin
                        psel      <= 1'b1;
                        pwrite    <= wr;
                        paddr     <= addr;
                        pwdata    <= wdata;
                        master_st <= MASTER_SETUP;
                    end
                end: master_idle_st

                MASTER_SETUP: begin: master_setup_st
                    // фаза SETUP по APB: psel=1, penable=0
                    penable   <= 1'b1;
                    master_st <= MASTER_ACCESS;
                end: master_setup_st

                MASTER_ACCESS: begin: master_access_st
                    // фаза ACCESS: ждём pready от слейва
                    if (pready) begin
                        ready <= 1'b1;
                        err   <= pslverr;
                        if (!pwrite)
                            rdata <= prdata;
                        if (pslverr)
                            $display("[MASTER] ERROR: addr=0x%08h", paddr);
                        else if (pwrite)
                            $display("[MASTER] WRITE 0x%08h: data=0x%08h", paddr, pwdata);
                        else
                            $display("[MASTER] READ 0x%08h: data=0x%08h", paddr, prdata);
                        psel      <= 1'b0;
                        penable   <= 1'b0;
                        pwrite    <= 1'b0;
                        master_st <= MASTER_DONE;
                    end
                end: master_access_st

                MASTER_DONE: begin: master_done_st
                    // ждём снятия req, чтобы не запустить лишнюю транзакцию
                    if (!req) begin
                        ready     <= 1'b0;
                        err       <= 1'b0;
                        master_st <= MASTER_IDLE;
                    end
                end: master_done_st

                default: master_st <= MASTER_IDLE;
            endcase
        end
    end

endmodule
