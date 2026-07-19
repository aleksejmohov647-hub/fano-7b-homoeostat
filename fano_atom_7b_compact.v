module fano_atom_7b_compact (
    input  wire [6:0] s,
    input  wire [6:0] f,
    output wire [6:0] s_next,
    output wire [6:0] f_next
);
    wire p4;
    assign p4 = &s[3:0];
    assign s_next = ({ s[6:4] ^ 3'b100, s[3:0] }) ^ f;
    assign f_next = s ^ (f & {7{p4}});
endmodule

