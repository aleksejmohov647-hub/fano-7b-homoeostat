`timescale 1ns / 1ps
`default_nettype none // Полная изоляция цепей в симуляторе

module fano_gauge_tb;
    parameter int WIDTH = 8;
    
    // Все сигналы строго объявляем как логические типы
    logic                 clk;
    logic                 rst_n;
    logic  [WIDTH-1:0]    s;
    logic  [WIDTH-1:0]    f;
    
    wire   [WIDTH-1:0]    s_next;
    wire   [WIDTH-1:0]    f_next;
    wire                  rank_1_monopole;

    // Инстанцируем защищенное калибровочное minimax-ядро
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
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Основной поток верификации
    initial begin
        // Инициализация входных барьеров
        rst_n = 1'b0;
        s     = {WIDTH{1'b0}};
        f     = {WIDTH{1'b0}};

        // Удерживаем сброс 2 полных такта и снимаем строго по спаду, чтобы избежать гонок
        ##2; 
        @(negedge clk);
        rst_n = 1'b1; 
        
        $display("=========================================================");
        $display("   RUNNING: SECURE FANO-MUFANG MULTISCALE RTL TEST       ");
        $display("=========================================================");
        
        // --- Тест 1: Подача вакуумного шума (F = 0) ---
        @(posedge clk);
        s <= 8'hAA; 
        f <= 8'h00; 
        
        // Ждем 2 такта, чтобы данные прошли входной барьер и вышли на s_next/f_next
        repeat(2) @(posedge clk);
        #1; // Небольшая задержка чтения для красивого отображения в консоли
        $display("[Vacuum Test] Вход: s=AA, f=00 | s_next=%h, f_next=%h, Monopole=%b", s_next, f_next, rank_1_monopole);

        // --- Тест 2: Захват аттрактора N(12) ---
        $display("[Eversion Test] Запуск эверсии по модулю 13 на решетке N(12)...");
        
        @(posedge clk);
        s <= 8'h39; // Константа ATTR_N12 старшая часть
        f <= 8'hF1; // Константа ATTR_N12 младшая часть (в сумме 16'h39F1)

        // Конвейер: 
        // 1-й такт: запись в s_reg/f_reg
        // 2-й такт: вычисление s_next/f_next и запись в monopole_pipe
        // 3-й такт: фиксация в rank_1_monopole
        repeat(3) @(posedge clk);
        #1; // Сдвиг для захвата стабильного состояния регистра
        
        if (rank_1_monopole) begin
            $display("[SUCCESS] Адельный коллапс зафиксирован!");
            $display("[SUCCESS] Безопасный двухтактный замок монополя J взведен.");
        end else begin
            $display("[FAIL] Калибровочный замок не сработал. s_next=%h, f_next=%h", s_next, f_next);
        end

        $display("=========================================================");
        repeat(2) @(posedge clk);
        $finish;
    end

endmodule

`default_nettype wire // Возвращаем дефолтный режим
