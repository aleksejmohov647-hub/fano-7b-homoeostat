// =================================================================
// PROJECT 7n: RIGOROUS MODULAR NOC PHASE-LOCK AND STATE GATEWAY
// ELITE PRODUCTION EDITION (ZERO-WARNING SYNTHESIS MATCH)
// =================================================================

module noc_fano_modular_core (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] traffic_tension, // Входная мера комбинаторного натяжения
    output logic [2:0]  noc_route_mode,  // Режим маршрутизации пакетов
    output logic        entropy_clear,   // Сигнал полной аннигиляции хаоса
    output logic        gate_active,     // Флаг удержания фазового затвора
    output logic        error_state      // Нарушение жесткого инварианта вычетов
);

    // Коды режимов NoC-маршрутизации (Спектральный зазор)
    localparam logic [2:0] MODE_BOOT  = 3'b000; 
    localparam logic [2:0] MODE_EQUIL = 3'b001; 
    localparam logic [2:0] MODE_FLUSH = 3'b010; 
    localparam logic [2:0] MODE_GATE  = 3'b011; 
    localparam logic [2:0] MODE_WARN  = 3'b100; 
    localparam logic [2:0] MODE_HALT  = 3'b111; 

    // Сигналы дерева параллельной редукции (16^N mod 13)
    logic [11:0] sum_weight_1; 
    logic [11:0] sum_weight_3; 
    logic [11:0] sum_weight_9; 
    
    logic [11:0] step1_sum;    // Теоретический максимум: 450
    logic [7:0]  step2_sum;    // Теоретический максимум: 86
    logic [5:0]  step3_sum;    // Скорректированный максимум: 27 (требует 6 бит во избежание переполнения)
    logic [5:0]  sub_res;      // Расширенная шина безопасного выравнивания
    logic [3:0]  mod13_next;
    logic [3:0]  mod13_residue;

    // Комбинаторное дерево быстрой параллельной редукции
    always_comb begin
        // Шаг 1: Распределение тетрад по циклу весов (1, 3, 9) основания 16 по модулю 13
        sum_weight_1 = 12'(traffic_tension[3:0])   + 12'(traffic_tension[15:12]) + 12'(traffic_tension[27:24]);
        sum_weight_3 = 12'(traffic_tension[7:4])   + 12'(traffic_tension[19:16]) + 12'(traffic_tension[31:28]);
        sum_weight_9 = 12'(traffic_tension[11:8])  + 12'(traffic_tension[23:20]);

        // Взвешенное суммирование. Максимум: 15*3*1 + 15*3*3 + 15*2*9 = 450
        step1_sum = sum_weight_1 + (sum_weight_3 * 12'd3) + (sum_weight_9 * 12'd9);

        // Шаг 2: Первое модулярное сжатие (основание 16 -> вес 3)
        // Максимум: (450 >> 4) * 3 + (450 & 15) = 28 * 3 + 2 = 86
        step2_sum = 8'((step1_sum[11:4] * 4'd3) + step1_sum[3:0]);

        // Шаг 3: Второе модулярное сжатие полинома
        // Истинный максимум при step2_sum = 79 (0x4F): 4 * 3 + 15 = 27
        step3_sum = 6'((6'(step2_sum[7:4]) * 6'd3) + 6'(step2_sum[3:0]));

        // Шаг 4: Финальное каскадное выравнивание остатка (устранение утечки для диапазона [0..27])
        if      (step3_sum >= 6'd26) sub_res = step3_sum - 6'd26;
        else if (step3_sum >= 6'd13) sub_res = step3_sum - 6'd13;
        else                         sub_res = step3_sum;

        // Абсолютно безопасное сужение шины до диапазона [0...12]
        mod13_next = sub_res[3:0];
    end

    // Конвейерный регистр остатка 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mod13_residue <= 4'd0;
        end else begin
            mod13_residue <= mod13_next;
        end
    end

    // Автомат управления топологической упругостью NoC (Все 16 состояний закрыты)
    always_comb begin
        noc_route_mode = MODE_WARN;
        entropy_clear  = 1'b0;
        gate_active    = 1'b0;
        error_state    = 1'b0;

        case (mod13_residue)
            4'd0: begin
                noc_route_mode = MODE_FLUSH;
                entropy_clear  = 1'b1;
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
                gate_active    = 1'b1;
            end
            4'd12: begin
                noc_route_mode = MODE_EQUIL;
                gate_active    = 1'b1;
            end
            // Дефолтный кейс теперь математически недостижим, но необходим для full_case синтеза
            default: begin
                noc_route_mode = MODE_HALT;
                error_state    = 1'b1;
            end
        endcase
    end

endmodule
