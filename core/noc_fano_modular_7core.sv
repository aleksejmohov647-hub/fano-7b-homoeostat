// =================================================================
// PROJECT 7n: RIGOROUS MULTI-SCALE SU(3) TERNARY-TETRARY CORE
// FILE NAME: noc_fano_modular_core.sv
// SPECIFICATION: ZERO-WARNING SYNTHESIS MATCH (LATCH-FREE SPEC)
// =================================================================

module noc_fano_modular_core (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] traffic_tension, // Непрерывное комбинаторное натяжение
    output logic [2:0]  noc_route_mode,  // Тетрарный режим маршрутизации NoC
    output logic        entropy_clear,   // Сигнал полной аннигиляции (Тернарный 0)
    output logic        gate_active,     // Флаг удержания фазового затвора
    output logic        error_state      // Нарушение жесткого инварианта Чигера
);

    // Коды тетрарного каркаса контекстов NoC
    localparam logic [2:0] MODE_BOOT  = 3'b000; // Вычет 1  (Статический Базис)
    localparam logic [2:0] MODE_EQUIL = 3'b001; // Вычет 8, 12 (Инфинитное Плато)
    localparam logic [2:0] MODE_FLUSH = 3'b010; // Вычет 0  (Точка Аннигиляции)
    localparam logic [2:0] MODE_GATE  = 3'b011; // Вычет 10 (Фазовый Затвор)
    localparam logic [2:0] MODE_WARN  = 3'b100; // Вычеты 2-7, 9, 11 (Зона Джиттера)
    localparam logic [2:0] MODE_HALT  = 3'b111; // Математически запрещенный сбой

    // Сигналы внутренней тернарной фильтрации SU(3)
    logic [31:0] ternary_sign; 
    logic [31:0] ternary_abs;  

    // Сигналы дерева параллельной редукции (16^N mod 13)
    logic [11:0] sum_weight_1; 
    logic [11:0] sum_weight_3; 
    logic [11:0] sum_weight_9; 
    
    logic [11:0] step1_sum;    
    logic [7:0]  step2_sum;    
    logic [5:0]  step3_sum;    
    logic [5:0]  sub_res;      
    logic [3:0]  mod13_next;
    logic [3:0]  mod13_residue;

    // Комбинаторное тернарно-тетрарное ядро
    always_comb begin
        // Устранение Latches: явный сброс комбинаторных шин перед циклом
        ternary_sign = 32'd0;
        ternary_abs  = 32'd0;

        // Шаг 0: Дифференциальный SU(3) фильтр. 
        for (int i = 0; i < 32; i++) begin
            if (traffic_tension[i] == 1'b0) begin
                ternary_sign[i] = 1'b1; // Отрицательный баланс (Долг)
                ternary_abs[i]  = 1'b1;
            end else begin
                ternary_sign[i] = 1'b0; // Положительный баланс (Имущество)
                ternary_abs[i]  = 1'b1;
            end
        end

        // Безопасное приведение разрядов через валидный SystemVerilog-кастинг типов
        sum_weight_1 = (12'(ternary_sign[3:0]   ^ ternary_abs[15:12])) + 
                       (12'(ternary_sign[15:12] ^ ternary_abs[27:24])) + 
                       (12'(ternary_sign[27:24] ^ ternary_abs[3:0]));

        sum_weight_3 = (12'(ternary_sign[7:4]   ^ ternary_abs[19:16])) + 
                       (12'(ternary_sign[19:16] ^ ternary_abs[31:28])) + 
                       (12'(ternary_sign[31:28] ^ ternary_abs[7:4]));

        sum_weight_9 = (12'(ternary_sign[11:8]  ^ ternary_abs[23:20])) + 
                       (12'(ternary_sign[23:20] ^ ternary_abs[11:8]));

        // Взвешенное каноническое суммирование по модулю 13 (16 = 3, 256 = 9)
        step1_sum = sum_weight_1 + (sum_weight_3 * 12'd3) + (sum_weight_9 * 12'd9);

        // Исправленный синтаксис модулярного сжатия полинома
        step2_sum = 8'((8'(step1_sum[11:4]) * 8'd3) + 8'(step1_sum[3:0]));

        // Второе модулярное сжатие
        step3_sum = 6'((6'(step2_sum[7:4]) * 6'd3) + 6'(step2_sum[3:0]));

        // Финальное каскадное выравнивание (математически корректное для max_step3 = 38)
        if      (step3_sum >= 6'd26) sub_res = step3_sum - 6'd26;
        else if (step3_sum >= 6'd13) sub_res = step3_sum - 6'd13;
        else                         sub_res = step3_sum;

        mod13_next = sub_res[3:0];
    end

    // Конвейерный регистр фиксации хронотопа
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mod13_residue <= 4'd0;
        end else begin
            mod13_residue <= mod13_next;
        end
    end

    // Автомат удержания фазового затвора СИК-Логики
    always_comb begin
        // Дефолтные безопасные присвоения для исключения скрытых защелок
        noc_route_mode = MODE_WARN;
        entropy_clear  = 1'b0;
        gate_active    = 1'b0;
        error_state    = 1'b0;

        case (mod13_residue)
            4'd0: begin
                noc_route_mode = MODE_FLUSH;
                entropy_clear  = 1'b1; // Тернарный ноль (Аннигиляция)
            end
            4'd1: begin
                noc_route_mode = MODE_BOOT; 
            end
            4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7, 4'd9, 4'd11: begin
                noc_route_mode = MODE_WARN; 
            end
            4'd8: begin
                noc_route_mode = MODE_EQUIL; 
            end
            4'd10: begin
                noc_route_mode = MODE_GATE; 
                gate_active    = 1'b1; // Резонанс на широте 5pi/6
            end
            4'd12: begin
                noc_route_mode = MODE_EQUIL;
                gate_active    = 1'b1; // Инфинитное плато A12
            end
            default: begin
                noc_route_mode = MODE_HALT;
                error_state    = 1'b1; // Нарушение инварианта стабильности
            end
        endcase
    end

endmodule
