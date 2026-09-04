`timescale 1ns / 1ps
`default_nettype none // Строгая защита от скрытых опечаток в проводах

module fano_gauge_atom_minimax #(
    parameter int WIDTH = 8                     // Граница октонионной мерности (6, 7 или 8)
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire [WIDTH-1:0]         s,          // Вектор пространства S
    input  wire [WIDTH-1:0]         f,          // Калибровочное поле функций F
    output reg  [WIDTH-1:0]         s_next,     // [WIDTH FF] Зарегистрированный выход S
    output reg  [WIDTH-1:0]         f_next,     // [WIDTH FF] Зарегистрированный выход F
    output reg                      rank_1_monopole // [1 FF] Флаг адельного коллапса
);

    // --- 1. Входной регистровый барьер ---
    reg [WIDTH-1:0] s_reg, f_reg;
    reg             monopole_pipe; 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_reg <= {WIDTH{1'b0}};
            f_reg <= {WIDTH{1'b0}};
        end else begin
            s_reg <= s;
            f_reg <= f;
        end
    end

    // --- 2. Вес Хэмминга поля F (Безопасный для любой разрядности) ---
    reg [3:0] h_weight;
    always_comb begin
        h_weight = {3'b0, f_reg[0]};
        if (WIDTH > 1) h_weight = h_weight + {3'b0, f_reg[1]};
        if (WIDTH > 2) h_weight = h_weight + {3'b0, f_reg[2]};
        if (WIDTH > 3) h_weight = h_weight + {3'b0, f_reg[3]};
        if (WIDTH > 4) h_weight = h_weight + {3'b0, f_reg[4]};
        if (WIDTH > 5) h_weight = h_weight + {3'b0, f_reg[5]};
        if (WIDTH > 6) h_weight = h_weight + {3'b0, f_reg[6]};
        if (WIDTH > 7) h_weight = h_weight + {3'b0, f_reg[7]};
    end

    localparam [3:0] WIDTH_4B = WIDTH[3:0];

    wire q_active = (h_weight != 4'd0);
    wire scale_trigger = (h_weight >= (WIDTH_4B >> 1)) ^ h_weight[0];

    // Ограничиваем индексы верхним пределом WIDTH-1, защищая от X-propagation
    wire [2:0] idx_a = scale_trigger ? ((WIDTH > 4) ? 3'd4 : (WIDTH[2:0]-1'b1)) : 3'd3;
    wire [2:0] idx_b = scale_trigger ? 3'd3 : ((WIDTH > 4) ? 3'd4 : (WIDTH[2:0]-1'b1));

    // --- 3. Вычислительное ядро F1: плоскость Фано ---
    wire p4 = (s_reg[idx_a] ^ f_reg[idx_b]) & (s_reg[idx_b] ^ f_reg[idx_a]);
    wire [2:0] fano_triangle = {s_reg[idx_a], s_reg[idx_b], s_reg[idx_a] ^ s_reg[idx_b]};

    // --- 4. Безопасный макро-транзит Муфанг без хардкода индексов ---
    wire [WIDTH-1:0] s_tmp;
    wire [2*WIDTH-1:0] current_attractor;

    generate
        if (WIDTH == 6) begin : gen_w6
            // Индексы [5] и [4] гарантированно существуют для WIDTH=6
            assign s_tmp = q_active ? { (s_reg[5] ^ (fano_triangle[1] ^ fano_triangle[2])),
                                        (s_reg[4] ^ (fano_triangle[0] ^ fano_triangle[2])),
                                        s_reg[3:0] }
                                   : {WIDTH{1'b0}};
            assign current_attractor = 12'h9F1; 
        end 
        else if (WIDTH == 7) begin : gen_w7
            // Индексы [6:4] гарантированно существуют для WIDTH=7
            assign s_tmp = q_active ? { (s_reg[6:4] ^ fano_triangle[2:0]),
                                        s_reg[3:0] }
                                   : {WIDTH{1'b0}};
            assign current_attractor = 14'h19F1; 
        end 
        else begin : gen_w8 // Конфигурация по умолчанию для WIDTH >= 8
            // s_reg[WIDTH-1] динамически адаптируется под любой максимальный размер, не ломая компилятор
            assign s_tmp = q_active ? {  s_reg[WIDTH-1],
                                        (s_reg[6:4] ^ fano_triangle[2:0]),
                                        s_reg[3:0] }
                                   : {WIDTH{1'b0}};
            assign current_attractor = 16'h39F1; 
        end
    endgenerate

    // Операторы инцидентности поля
    wire [WIDTH-1:0] s_next_comb = q_active ? (s_tmp ^ f_reg) : {WIDTH{1'b0}};
    wire [WIDTH-1:0] f_next_comb = q_active ? (s_reg ^ (f_reg & {WIDTH{p4}})) : {WIDTH{1'b0}};

    // Безопасное сравнение векторов (разрядность строго совпадает на этапе элаборации)
    wire monopole_comb = ({s_next_comb, f_next_comb} == current_attractor);

    // --- 5. Выходной барьер фиксации инвариантов ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_next          <= {WIDTH{1'b0}};
            f_next          <= {WIDTH{1'b0}};
            monopole_pipe   <= 1'b0;
            rank_1_monopole <= 1'b0;
        end else begin
            s_next          <= s_next_comb;
            f_next          <= f_next_comb;
            monopole_pipe   <= monopole_comb;
            rank_1_monopole <= monopole_pipe; 
        end
    end

endmodule
`default_nettype wire // Корректный сброс глобальной директивы для компиляции других файлов проекта
