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
    // 64-битные промежуточные сигналы для отлова переполнения
    logic [63:0] sum64;                   // A + B + C в 64 битах
    logic [63:0] sum_ab, sum_ac, sum_bc;  // попарные суммы для проверки неравенства
    logic        sum_overflow;            // 1 — сумма не влезла в 32 бита
    logic        triangle_valid;          // 1 — треугольник существует

    enum logic [1:0] {
        APB_SETUP,    // фаза SETUP: psel=1, penable=0
        APB_W_ENABLE, // фаза ACCESS для записи
        APB_R_ENABLE  // фаза ACCESS для чтения
    } apb_st;


    // Комбинационный расчёт периметра и флагов
    always @(*) begin
        sum64  = {32'h0, side_a} + {32'h0, side_b} + {32'h0, side_c};
        sum_ab = {32'h0, side_a} + {32'h0, side_b};
        sum_ac = {32'h0, side_a} + {32'h0, side_c};
        sum_bc = {32'h0, side_b} + {32'h0, side_c};
        sum_overflow   = (sum64[63:32] != 32'h0);
        triangle_valid = (sum_ab > {32'h0, side_c}) &&
                         (sum_ac > {32'h0, side_b}) &&
                         (sum_bc > {32'h0, side_a});
    end

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
                    // очищение prdata/pready/pslverr к началу новой транзакции, чтобы не было «залипших» значений с прошлой операции
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
                            8'hC: begin
                                if (sum_overflow) begin
                                    prdata  <= 32'h0;
                                    pslverr <= 1'b1;
                                    $display("[TRIANGLE] ERROR: sum overflow (A=0x%08h, B=0x%08h, C=0x%08h)",
                                             side_a, side_b, side_c);
                                end else if (!triangle_valid) begin
                                    prdata  <= 32'h0;
                                    pslverr <= 1'b1;
                                    $display("[TRIANGLE] ERROR: triangle inequality violated (A=0x%08h, B=0x%08h, C=0x%08h)",
                                             side_a, side_b, side_c);
                                end else begin
                                    prdata <= sum64[31:0];
                                    $display("[TRIANGLE] READ 0xC: perimeter=0x%08h (A=0x%08h, B=0x%08h, C=0x%08h)",
                                             sum64[31:0], side_a, side_b, side_c);
                                end
                            end
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
