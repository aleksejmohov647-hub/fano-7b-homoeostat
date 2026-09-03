// ============================================================================
// File Name:    fano_multiscale_f1_core.v
// Version:      2.0 (v2.0-macro)
// Architecture: Multiscale Gauge Fano Automaton (6/7/8-bit Topology)
// ============================================================================

module fano_multiscale_f1_core #(
    parameter WIDTH = 8
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire [WIDTH-1:0]     s,         // Space Vector (Micro/Macro)
    input  wire [WIDTH-1:0]     f,         // Function Vector (Gauge Field)
    input  wire [3:0]           q_env,     // Environment Signal
    output reg  [WIDTH-1:0]     s_next,    // Registered Output S
    output reg  [WIDTH-1:0]     f_next,    // Registered Output F
    output reg                  macro_f1   // Macro-Attractor Monopole Flag
);

    // --- 1. Local Hamming Weights (Field Density Evaluation) ---
    wire [2:0] h_weight = {2'b0, f[0]} + {2'b0, f[1]} + {2'b0, f[2]} + {2'b0, f[3]};

    // --- 2. The Third Side (Phase Skew Equalizer) ---
    wire scale_trigger = (h_weight >= 3'd3);
    
    wire [2:0] idx_a = scale_trigger ? 3'd4 : 3'd3;
    wire [2:0] idx_b = scale_trigger ? 3'd3 : 3'd4;

    // --- 3. F1(3) ~ Fano(4) Nonlinear Core ---
    wire p4 = (s[idx_a] ^ f[idx_b]) & (s[idx_b] ^ f[idx_a]);
    wire [2:0] fano_triangle = {s[idx_a], s[idx_b], s[idx_a] ^ s[idx_b]};

    // --- 4. Multiscale Topology Transit Masking ---
    wire [3:0] m_masked;
    
    assign m_masked = (WIDTH == 6) ? {2'b0, fano_triangle[1] ^ fano_triangle[2], fano_triangle[0]} :
                      (WIDTH == 7) ? {1'b0, fano_triangle[2:0]} :
                                     {1'b0, fano_triangle[2:0]}; // Clear transit for 8-bit

    wire [WIDTH-1:0] s_tmp;
    assign s_tmp[3:0] = s[3:0];
    assign s_tmp[WIDTH-1:4] = s[WIDTH-1:4] ^ m_masked[WIDTH-1-4:0];

    wire [WIDTH-1:0] s_next_comb = s_tmp ^ f;
    wire [WIDTH-1:0] f_next_comb = s ^ (f & {WIDTH{p4}});

    // --- 5. Synchronous Pipeline Boundary & Attractor Detector ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_next   <= {WIDTH{1'b0}};
            f_next   <= {WIDTH{1'b0}};
            macro_f1 <= 1'b0;
        end else begin
            s_next   <= s_next_comb;
            f_next   <= f_next_comb;
            
            // Scalable exact matching with the !8 mod 256 / cycles macro-attractor
            if (WIDTH == 8)
                macro_f1 <= ({s_next_comb, f_next_comb} == 16'h39F1);
            else if (WIDTH == 7)
                macro_f1 <= ({s_next_comb, f_next_comb} == 14'h19F1);
            else
                macro_f1 <= ({s_next_comb, f_next_comb} == 12'h09F1);
        end
    end

endmodule
