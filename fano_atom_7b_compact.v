module fano_atom_7b_compact (
    input  wire [6:0] s,
    input  wire [6:0] f,
    output wire [6:0] s_next,
    output wire [6:0] f_next
);

    wire p4;

    // Tetrad time trigger: logical AND of bits [3:0] of spatial tensor
    assign p4 = &s[3:0];

    // Affine eversion with strict operator precedence:
    // 1) XOR top 3 bits with mask 3'b100
    // 2) Concatenate with lower 4 bits
    // 3) XOR entire 7-bit result with entropy flux f
    assign s_next = ({ s[6:4] ^ 3'b100, s[3:0] }) ^ f;

    // Dissipative shunt:
    // If p4 == 1, f_next = s ^ f; else f_next = s
    // Implemented via masking f with 7 copies of p4
    assign f_next = s ^ (f & {7{p4}});

endmodule
