`default_nettype none

// ============================================================================
// 1. АТОМАРНЫЙ ТАКТОВЫЙ 3D-УЗЕЛ С УПРАВЛЕНИЕМ РЕЖИМАМИ (Compact / Maximal)
// ============================================================================
module fano_atom_3d_node (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       is_compact_mode, // Переключатель полушарий (0 - Максимум, 1 - Компакт)
    input  logic [6:0] s_in,            // Вход пространственного поля (из X/Y соседей)
    input  logic [6:0] f_in,            // Вход временного поля (из Z соседей)
    output logic [6:0] s_next,          // Выход Пространства в сеть
    output logic [6:0] f_next           // Выход Времени в сеть
);
    logic [6:0] reg_s;
    logic [6:0] reg_f;

    // Паритетная защелка Муфанг
    wire p4 = (reg_s[3] ^ reg_f[4]) & (reg_s[4] ^ reg_f[3]);
    
    // Кососимметричный ассоциатор переключений
    wire [2:0] m = {reg_s[3], reg_s[4], reg_s[3] ^ reg_s[4]};
    
    // Выбор режима удержания формы или генерации хаоса
    wire [6:0] s_stage;
    assign s_stage[6:4] = is_compact_mode ? (reg_s[6:4] ^ 3'b100) : (reg_s[6:4] ^ m);
    assign s_stage[3:0] = reg_s[3:0];

    // Вычисление следующих состояний решетки
    wire [6:0] next_s_val = s_stage ^ f_in;
    wire [6:0] next_f_val = reg_s ^ (f_in & {7{p4}});

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_s <= 7'h3F; // Начальная калибровка узла
            reg_f <= 7'h00;
        end else begin
            reg_s <= next_s_val;
            reg_f <= next_f_val;
        end
    end

    assign s_next = reg_s;
    assign f_next = reg_f;
endmodule


// ============================================================================
// 2. ГЛОБАЛЬНЫЙ ТОРОИДАЛЬНЫЙ 3D-КРИСТАЛЛ (64 УЗЛА / СЕТКА СВЯЗЕЙ)
// ============================================================================
(* optimize_power = "TRUE", retiming = "TRUE" *)
module fano_3d_mesh #(
    parameter SIZE = 4
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       global_compact_en, // Управление энтропией всего кристалла
    input  logic [6:0] external_entropy [0:SIZE-1][0:SIZE-1][0:SIZE-1],
    output logic [6:0] crystal_s_out    [0:SIZE-1][0:SIZE-1][0:SIZE-1],
    output logic [6:0] crystal_f_out    [0:SIZE-1][0:SIZE-1][0:SIZE-1]
);

    // Внутренние шины трехмерного топоса
    wire [6:0] s_net [0:SIZE-1][0:SIZE-1][0:SIZE-1];
    wire [6:0] f_net [0:SIZE-1][0:SIZE-1][0:SIZE-1];

    generate
        genvar x, y, z;
        for (x = 0; x < SIZE; x = x + 1) begin: gen_x
            for (y = 0; y < SIZE; y = y + 1) begin: gen_y
                for (z = 0; z < SIZE; z = z + 1) begin: gen_z
                    
                    // Жесткое тороидальное замыкание 3D-пространства (Без краев)
                    localparam xl = (x == 0)        ? SIZE-1 : x-1;
                    localparam xr = (x == SIZE-1)   ? 0      : x+1;
                    localparam yd = (y == 0)        ? SIZE-1 : y-1;
                    localparam yu = (y == SIZE-1)   ? 0      : y+1;
                    localparam zb = (z == 0)        ? SIZE-1 : z-1;
                    localparam zf = (z == SIZE-1)   ? 0      : z+1;

                    // Сборка скрещенного поля: X/Y соседи и внешний хаос формируют Пространство
                    wire [6:0] s_in_wire = f_net[xl][y][z] ^ f_net[xr][y][z] ^ 
                                           f_net[x][yd][z] ^ f_net[x][yu][z] ^ 
                                           external_entropy[x][y][z];
                                      
                    // Z-соседи формируют поле Времени
                    wire [6:0] f_in_wire = s_net[x][y][zb] ^ s_net[x][y][zf];

                    // Инстанс тактового 3D-атома
                    fano_atom_3d_node atom_inst (
                        .clk            (clk),
                        .rst_n          (rst_n),
                        .is_compact_mode(global_compact_en),
                        .s_in           (s_in_wire),
                        .f_in           (f_in_wire),
                        .s_next         (s_net[x][y][z]),
                        .f_next         (f_net[x][y][z])
                    );

                    // Вывод текущего состояния слоя наружу
                    assign crystal_s_out[x][y][z] = s_net[x][y][z];
                    assign crystal_f_out[x][y][z] = f_net[x][y][z];

                end
            end
        end
    endgenerate
endmodule

`default_nettype wire
