`timescale 1ns / 1ps

module fano_gauge_tb;
    parameter int WIDTH = 8;
    
    reg                 clk;
    reg                 rst_n;
    reg  [WIDTH-1:0]    s;
    reg  [WIDTH-1:0]    f;
    wire [WIDTH-1:0]    s_next;
    wire [WIDTH-1:0]    f_next;
    wire                rank_1_monopole;

    // Инстанцируем калибровочный minimax-атом
    fano_gauge_atom_minimax #(.WIDTH(WIDTH)) uut (
        .clk(clk),
        .rst_n(rst_n),
        .s(s),
        .f(f),
        .s_next(s_next),
        .f_next(f_next),
        .rank_1_monopole(rank_1_monopole)
    );

    // Генератор тактовой частоты (период 10нс)
    always #5 clk = ~clk;

    initial begin
        // Инициализация системы счета
        clk = 0;
        rst_n = 0;
        s = 0;
        f = 0;

        #10;
        rst_n = 1; // Выход из сброса, фиксация вакуумного барьера
        #10;

        $display("=========================================================");
        $display("   ЗАПУСК КАЛИБРОВОЧНОГО ТЕСТА FANO-MUFANG MULTISCALE   ");
        $display("=========================================================");
        
        // --- Тест 1: Подача вакуумного шума (F = 0) ---
        // Поле пустое, автомат должен держать нулевой ранг на выходе
        s = 8'hAA; f = 8'h00; #10;
        $display("[Vacuum Test] Вход: s=AA, f=00 | s_next=%h, f_next=%h, Monopole=%b", s_next, f_next, rank_1_monopole);

        // --- Тест 2: Имитация динамической эверсии и захвата аттракторы N(12) ---
        // Подаем калибровочные значения, которые через конвейерный барьер 
        // должны точно совпасть с локальным инвариантом ATTR_N12 (16'h39F1)
        $display("[Eversion Test] Активация калибровочного поля на решетке N(12)...");
        
        // Шаг 1: Инжекция состояний
        s = 8'h39; f = 8'hF1; #10; 
        
        // Шаг 2: Прохождение через первый ярус триггеров (monopole_pipe)
        #10; 
        
        // Шаг 3: Проверка двухтактного безопасного замка
        if (rank_1_monopole) begin
            $display("[SUCCESS] Адельный коллапс зафиксирован!");
            $display("[SUCCESS] Ранг 1 монополя J активен. Код верифицирован.");
        end else begin
            $display("[WARNING] Система находится в состоянии распределенного шума.");
        end

        $display("=========================================================");
        #10;
        $finish;
    end
endmodule
