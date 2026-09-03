// ============================================================================
// File Name:    fano_multiscale_f1_core_v2.v
// Version:      2.0 (v2.0-macro Generate)
// Architecture: Multiscale Gauge Fano Automaton (Conditional Elaboration)
// ============================================================================

module fano_multiscale_f1_core_v2 #(
    parameter WIDTH = 8
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire [WIDTH-1:0]     s,
    input  wire [WIDTH-1:0]     f,
    input  wire [3:0]           q_env,
    output reg  [WIDTH-1:0]     s_next,
    output reg  [WIDTH-1:0]     f_next,
    output reg                  macro_f1
);

    // --- 1. Локальные весы Хэмминга (Плотность Поля) ---
    wire [2:0] h_weight = {2'b0, f[0]} + {2'b0, f[1]} + {2'b0, f[2]} + {2'b0, f[3]};
    wire scale_trigger = (h_weight >= 3'd3);
    
    // --- 2. Третья сторона (Уравнитель Перекосов) ---
    wire [2:0] idx_a = scale_trigger ? 3'd4 : 3'd3;
    wire [2:0] idx_b = scale_trigger ? 3'd3 : 3'd4;

    // --- 3. Вычислительное ядро плоскости F1 ---
    wire p4 = (s[idx_a] ^ f[idx_b]) & (s[idx_b] ^ f[idx_a]);
    wire [2:0] fano_triangle = {s[idx_a], s[idx_b], s[idx_a] ^ s[idx_b]};

    // --- 4. Чистый аппаратный макро-транзит (Без опасных срезов шины) ---
    wire [WIDTH-1:0] s_tmp;
    assign s_tmp[3:0] = s[3:0]; // Младший масштаб стабилен

    // Условная компиляция макро-надстройки: 0 затрат железа, чистая разводка дорожек
    generate
        if (WIDTH == 6) begin : gen_width_6
            // Сворачиваем 3-ю сторону (баланс) во 2-й бит транзита, сохраняя обе базовые координаты
            assign s_tmp[4] = s[4] ^ fano_triangle[0];
            assign s_tmp[5] = s[5] ^ (fano_triangle[1] ^ fano_triangle[2]);
        end 
        else if (WIDTH == 7) begin : gen_width_7
            // Прямой транзит всех трех узлов треугольника на макроуровень [6:4]
            assign s_tmp[6:4] = s[6:4] ^ fano_triangle[2:0];
        end 
        else begin : gen_width_8
            // Для 8-битной топологии: треугольник транслируется в [6:4], старший 7-й бит чист
            assign s_tmp[6:4] = s[6:4] ^ fano_triangle[2:0];
            assign s_tmp[7]   = s[7];
        end
    endgenerate

    // Эволюционные операторы поля
    wire [WIDTH-1:0] s_next_comb = s_tmp ^ f;
    wire [WIDTH-1:0] f_next_comb = s ^ (f & {WIDTH{p4}});

    // --- 5. Синхронный барьер фиксации минимального энергоемкого положения ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_next   <= {WIDTH{1'b0}};
            f_next   <= {WIDTH{1'b0}};
            macro_f1 <= 1'b0;
        end else begin
            s_next   <= s_next_comb;
            f_next   <= f_next_comb;
            
            // Адаптивные макро-аттракторы деранжирования
            if (WIDTH == 8)
                macro_f1 <= ({s_next_comb, f_next_comb} == 16'h39F1);
            else if (WIDTH == 7)
                macro_f1 <= ({s_next_comb, f_next_comb} == 14'h19F1);
            else
                macro_f1 <= ({s_next_comb, f_next_comb} == 12'h09F1);
        end
    end

endmodule
