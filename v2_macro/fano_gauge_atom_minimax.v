`timescale 1ns / 1ps
`default_nettype wire

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

    // --- 1. Матрица макро-аттракторов (Инварианты распада контура) ---
    localparam [15:0] ATTR_N12 = 16'h39F1;   // Решетка N(12)=157 (WIDTH=8)
    localparam [13:0] ATTR_N10 = 14'h19F1;   // Решетка N(10)=111 (WIDTH=7)
    localparam [11:0] ATTR_N6  = 12'h9F1;    // Решетка N(6)=43   (WIDTH=6)

    // --- 2. Входной регистровый барьер (16 FF при WIDTH=8) ---
    reg [WIDTH-1:0] s_reg, f_reg;
    reg             monopole_pipe; // [1 FF] Конвейерный замок

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_reg <= {WIDTH{1'b0}};
            f_reg <= {WIDTH{1'b0}};
        end else begin
            s_reg <= s;
            f_reg <= f;
        end
    end

    // --- 3. Вес Хэмминга поля F (Плоский сумматор, 1 ярус LUT) ---
    reg [3:0] h_weight;
    always_comb begin
        h_weight = 4'd0;
        h_weight = h_weight + {3'b0, f_reg[0]} + {3'b0, f_reg[1]} + {3'b0, f_reg[2]} + {3'b0, f_reg[3]};
        if (WIDTH > 4) h_weight = h_weight + {3'b0, f_reg[4]};
        if (WIDTH > 5) h_weight = h_weight + {3'b0, f_reg[5]};
        if (WIDTH > 6) h_weight = h_weight + {3'b0, f_reg[6]};
        if (WIDTH > 7) h_weight = h_weight + {3'b0, f_reg[7]};
    end

    // Активация: поле ненулевое (Вакуумный барьер)
    wire q_active = (h_weight != 4'd0);

    // Бифуркация: порог s = WIDTH/2, инверсия по младшему биту веса Хэмминга
    wire scale_trigger = (h_weight >= (WIDTH[3:0] >> 1)) ^ h_weight[0];

    wire [2:0] idx_a = scale_trigger ? 3'd4 : 3'd3;
    wire [2:0] idx_b = scale_trigger ? 3'd3 : 3'd4;

    // --- 4. Вычислительное ядро F1: плоскость Фано (Тильда Фано) ---
    wire p4 = (s_reg[idx_a] ^ f_reg[idx_b]) & (s_reg[idx_b] ^ f_reg[idx_a]);
    wire [2:0] fano_triangle = {s_reg[idx_a], s_reg[idx_b], s_reg[idx_a] ^ s_reg[idx_b]};

    // --- 5. Макро-транзит Муфанг: единая схема для всех мерностей ---
    wire [WIDTH-1:0] s_tmp;
    generate
        if (WIDTH == 6) begin : gen_w6
            // Полное восстановление неассоциативного баланса Муфанг для 6 бит
            assign s_tmp = q_active ? { (s_reg[5] ^ (fano_triangle[1] ^ fano_triangle[2])),
                                        (s_reg[4] ^ (fano_triangle[0] ^ fano_triangle[2])),
                                        s_reg[3:0] }
                                   : {WIDTH{1'b0}};
        end else if (WIDTH == 7) begin : gen_w7
            assign s_tmp = q_active ? { (s_reg[6:4] ^ fano_triangle[2:0]),
                                        s_reg[3:0] }
                                   : {WIDTH{1'b0}};
        end else begin : gen_w8
            assign s_tmp = q_active ? {  s_reg[7],
                                        (s_reg[6:4] ^ fano_triangle[2:0]),
                                        s_reg[3:0] }
                                   : {WIDTH{1'b0}};
        end
    endgenerate

    // Операторы инцидентности поля
    wire [WIDTH-1:0] s_next_comb = q_active ? (s_tmp ^ f_reg) : {WIDTH{1'b0}};
    wire [WIDTH-1:0] f_next_comb = q_active ? (s_reg ^ (f_reg & {WIDTH{p4}})) : {WIDTH{1'b0}};

    // Адаптивное выравнивание разрядности макро-аттрактора деранжирования
    wire [2*WIDTH-1:0] current_attractor = (WIDTH == 8) ? ATTR_N12 :
                                           (WIDTH == 7) ? ATTR_N10 : ATTR_N6;

    wire monopole_comb = ({s_next_comb, f_next_comb} == current_attractor);

    // --- 6. Выходной барьер фиксации инвариантов (18 FF при WIDTH=8) ---
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
            rank_1_monopole <= monopole_pipe; // Двухтактный безопасный замок монополя J
        end
    end
endmodule
