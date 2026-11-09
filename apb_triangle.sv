`timescale 1ns/1ps //единица времени — 1 нс, точность — 1 пс

//выполняет роль слейва
module apb_triangle (
    input               pclk,     // синхросигнал
    input               presetn,  // сигнал сброса (инверсный)
    input        [31:0] paddr,    // адрес обращения
    input        [31:0] pwdata,   // данные для записи
    input               psel,     // признак выбора устройства
    input               penable,  // признак активной транзакции
    input               pwrite,   // признак операции записи
    output logic        pready,   // признак готовности
    output logic        pslverr,  // признак ошибки
    output logic [31:0] prdata    // прочитанные данные
);

    // Регистры сторон треугольника
    logic [31:0] side_a;
    logic [31:0] side_b;
    logic [31:0] side_c;

    enum logic [1:0] {
        APB_SETUP,    // фаза SETUP: psel=1, penable=0
        APB_W_ENABLE, // фаза ACCESS для записи
        APB_R_ENABLE  // фаза ACCESS для чтения
    } apb_st;

    always @(posedge pclk) begin
        if (!presetn) begin
            // синхронный сброс: все выходы и регистры в 0
            prdata  <= '0;
            pslverr <= 1'b0;
            pready  <= 1'b0;
            side_a  <= '0;
            side_b  <= '0;
            side_c  <= '0;
            apb_st  <= APB_SETUP;
        end else begin
            case (apb_st)

                APB_SETUP: begin: apb_setup_st
                    // очищаем prdata/pready/pslverr к началу новой транзакции, чтобы не было «залипших» значений с прошлой операции
                    prdata  <= '0;
                    pslverr <= 1'b0;
                    pready  <= 1'b0;
                    if (psel && !penable) begin
                        if (pwrite)
                            apb_st <= APB_W_ENABLE;
                        else
                            apb_st <= APB_R_ENABLE;
                    end
                end: apb_setup_st

                APB_W_ENABLE: begin: apb_w_en_st
                    if (psel && penable && pwrite) begin
                        pready <= 1'b1; // «готово» — один такт
                        case (paddr[7:0])
                            8'h0:    side_a <= pwdata;
                            8'h4:    side_b <= pwdata;
                            8'h8:    side_c <= pwdata;
                            8'hC:    pslverr <= 1'b1; // PERIM read-only, запись запрещена
                            default: pslverr <= 1'b1; // неверный адрес
                        endcase
                        apb_st <= APB_SETUP;
                    end
                end: apb_w_en_st

                APB_R_ENABLE: begin: apb_r_en_st
                    if (psel && penable && !pwrite) begin
                        pready <= 1'b1;
                        case (paddr[7:0])
                            8'h0:    prdata <= side_a;
                            8'h4:    prdata <= side_b;
                            8'h8:    prdata <= side_c;
                            8'hC:    prdata <= 32'h0; // заглушка
                            default: pslverr <= 1'b1; // неверный адрес
                        endcase
                        apb_st <= APB_SETUP;
                    end
                end: apb_r_en_st

                default: apb_st <= APB_SETUP;
            endcase
        end
    end

endmodule
