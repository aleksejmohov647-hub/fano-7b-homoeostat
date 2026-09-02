`default_nettype none

module octornion_mufang_lut #(parameter int WIDTH = 12) (
    input  logic [2:0] index_i, index_j, 
    input  logic [WIDTH-1:0] data_in,
    output logic [WIDTH-1:0] data_out, sign_out
);
    always_comb begin
        sign_out = 1'b0; data_out = data_in;
        if (index_i != 3'd0 && index_j != 3'd0) begin
            if (index_i == index_j) sign_out = 1'b1;
            else begin
                case ({index_i, index_j})
                    6'b001_010, 6'b010_011, 6'b011_001, 6'b001_100, 6'b100_101, 6'b101_001: sign_out = 1'b0;
                    6'b010_001, 6'b011_010, 6'b001_011, 6'b100_001, 6'b101_100, 6'b001_101: sign_out = 1'b1;
                    6'b001_111, 6'b111_110, 6'b110_001, 6'b010_100, 6'b100_110, 6'b110_010: sign_out = 1'b0;
                    6'b111_001, 6'b110_111, 6'b001_110, 6'b100_010, 6'b110_100, 6'b010_110: sign_out = 1'b1;
                    default: begin data_out = '0; sign_out = 1'b0; end
                endcase
            end
        end
    end
endmodule

module aspg_projection_scaler_v3 #(parameter int WIDTH = 12, FXP_WIDTH = 16) (
    input  logic clk, rst_n, 
    input  logic signed [FXP_WIDTH-1:0] cos_theta, sin_theta_sqrt3,
    input  logic [7:0] q_order, 
    output logic [WIDTH-1:0] w_ord_34, w_dis_34, delta_reg
);
    logic [WIDTH-1:0] calculated_ord;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin w_ord_34 <= 12'd72; w_dis_34 <= 12'd69; delta_reg <= 12'd11; end
        else begin
            calculated_ord <= WIDTH'((((q_order == 8'd0) ? 12'd72 : 12'd24) * cos_theta) >>> (FXP_WIDTH-1));
            w_ord_34  <= calculated_ord ^ WIDTH'(q_order);
            w_dis_34  <= (calculated_ord - 12'd3) ^ WIDTH'(~q_order); 
            delta_reg <= WIDTH'(((12'd11 * sin_theta_sqrt3) >>> (FXP_WIDTH-1)) + 12'd3);
        end
    end
endmodule

module aspg_multiscale_node_v3 #(parameter int WIDTH = 12, Q_BITS = 8) (
    input  logic clk, rst_n, 
    input  logic [WIDTH-1:0] w_ord_34, w_dis_34, delta_reg,
    input  logic [Q_BITS-1:0] q_order, input logic [5:0] micro_comb, 
    input  logic [WIDTH-1:0] w_cycle, f_ext_flux, oct_tensor_in, input logic oct_sign_in, 
    output logic [WIDTH-1:0] w_next, acoustic_wave, output logic gauge_valid, mufang_lock
);
    logic [WIDTH-1:0] s_p3, s_m3, s_p4, s_m4; logic [7:0] s_int, chord_m; logic [6:0] c; logic [11:0] topo_ring; logic p4;
    assign s_p3 = w_cycle + w_ord_34; assign s_m3 = w_cycle - w_dis_34;
    assign s_p4 = w_cycle + delta_reg; assign s_m4 = w_cycle - delta_reg;
    assign s_int = w_cycle[7:0] ^ f_ext_flux[7:0];
    assign p4 = ^((s_int ^ f_ext_flux[7:0]) & (s_int ^ f_ext_flux[11:4]));
    always_comb begin
        case ({~q_order[0], p4})
            2'b00: w_next = s_p3; 2'b01: w_next = s_m3;
            2'b10: w_next = s_p4; 2'b11: w_next = s_m4;
        endcase
    end
    assign chord_m = s_int ^ (f_ext_flux[7:0] & {8{p4}}) ^ (~q_order[0] ? 8'h7F : 8'h55);
    assign c = {chord_m^chord_m, chord_m^chord_m, chord_m^chord_m, chord_m, chord_m^chord_m, chord_m^chord_m, chord_m^chord_m};
    assign gauge_valid = !((|c[3:0]) & (|c[6:4]));
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin topo_ring <= 12'b1; mufang_lock <= 1'b0; end
        else if (~q_order[0] && ((micro_comb == 6'b10) || (micro_comb == 6'b100))) begin
            mufang_lock <= (~^w_cycle) ^ (~q_order[0]) | (&chord_m[6:0]);
            topo_ring   <= oct_sign_in ? ~({topo_ring[10:0], topo_ring[11]} ^ oct_tensor_in) : ({topo_ring[10:0], topo_ring[11]} ^ oct_tensor_in); 
        end else begin mufang_lock <= 1'b0; topo_ring <= topo_ring; end
    end
    assign acoustic_wave = topo_ring;
endmodule

module mufang_systolic_grid_7n_v3 #(parameter int NODES = 7, WIDTH = 12) (
    input  logic clk, rst_n, input logic [7:0] q_order, input logic [5:0] micro_comb,
    input  logic [WIDTH-1:0] w_ord_34, w_dis_34, delta_reg, 
    input  logic [WIDTH-1:0] spatial_flux [NODES-1:0], spatial_cycle [NODES-1:0],
    output logic [WIDTH-1:0] global_acoustic_wave, output logic global_gauge_valid
);
    logic [WIDTH-1:0] node_w_next [NODES-1:0], node_acoustic [NODES-1:0], oct_data_net [NODES-1:0];
    logic node_valid [NODES-1:0], node_lock [NODES-1:0], oct_sign_net [NODES-1:0];
    genvar i;
    generate
        for (i = 0; i < NODES; i++) begin : gen_nodes
            octornion_mufang_lut #(WIDTH) octornion_inst (3'(i), 3'((i + 1) % NODES), node_w_next[i], oct_data_net[i], oct_sign_net[i]);
            aspg_multiscale_node_v3 #(WIDTH, 8) node_core (clk, rst_n, w_ord_34, w_dis_34, delta_reg, q_order, micro_comb, spatial_cycle[i], spatial_flux[i], oct_data_net[i], oct_sign_net[i], node_w_next[i], node_acoustic[i], node_valid[i], node_lock[i]);
        end
    </generate>
    assign global_gauge_valid = &node_valid;
    always_comb begin
        global_acoustic_wave = '0;
        for (int k = 0; k < NODES; k++) if (node_valid[k]) global_acoustic_wave = global_acoustic_wave ^ node_acoustic[k] ^ {WIDTH{node_lock[k]}};
    end
endmodule

module final_top_aspg_processor_7n #(parameter int NODES = 7, WIDTH = 12, FXP_WIDTH = 16) (
    input  logic clk, rst_n, input logic [7:0] q_order, input logic [5:0] micro_comb, input logic signed [FXP_WIDTH-1:0] cos_theta, sin_theta_sqrt3,
    input  logic [WIDTH-1:0] spatial_flux [NODES-1:0], spatial_cycle [NODES-1:0], output logic [WIDTH-1:0] global_acoustic_wave, output logic global_gauge_valid
);
    logic [WIDTH-1:0] dyn_w_ord, dyn_w_dis, dyn_delta;
    aspg_projection_scaler_v3 #(WIDTH, FXP_WIDTH) scaler (clk, rst_n, cos_theta, sin_theta_sqrt3, q_order, dyn_w_ord, dyn_w_dis, dyn_delta);
    mufang_systolic_grid_7n_v3 #(NODES, WIDTH) grid (clk, rst_n, q_order, micro_comb, dyn_w_ord, dyn_w_dis, dyn_delta, spatial_flux, spatial_cycle, global_acoustic_wave, global_gauge_valid);
endmodule

`default_nettype wire
