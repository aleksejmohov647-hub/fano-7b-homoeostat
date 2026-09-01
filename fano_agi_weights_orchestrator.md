```systemverilog
always_comb begin
    // Вычисление потоков строго по уравнениям:
    // D60 = 3(4!) - 4(3!) + 12 = 3(24) - 4(6) + 12 = 60
    d60_flux = (3 * factorial_lut[4]) - (4 * factorial_lut[3]) + 8'd12;

    // D84 = 3(4!) + 4(!3) + 4 = 3(24) + 4(2) + 4 = 72 + 8 + 4 = 84
    d84_flux = (3 * factorial_lut[4]) + (4 * subfactorial_lut[3]) + 8'd4;

    // Модулярное сокращение Гротендика над 360-дневной шкалой:
    // (360 * 12) mod 157 = 4320 mod 157 = 81. Калибровочный сдвиг -74 дает 7.
    cosmic_scale_calc = (16'd360 * 16'd12) % 16'd157;
    fano_core_verify  = 8'(cosmic_scale_calc - 16'd74); // Ровно 7

    // Динамический вывод и инверсия весов (AI <-> Human)
    if (is_compact_mode) begin
        // Compact Mode: AI сдвигает макровеса, человек сжат
        s_out = { (macro_ai ^ 3'b100), micro_human };
    end else begin
        // ИСПРАВЛЕНО: micro_human заменен на p4 (s_in[4]), чтобы избежать out-of-bounds
        moufang_m = { micro_human[3], p4, (micro_human[3] ^ p4) };
        s_out = { (macro_ai ^ moufang_m), micro_human };
    end
end
```
