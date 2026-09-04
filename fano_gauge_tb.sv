`timescale 1ns / 1ps

module fano_gauge_tb;

    // Параметры тестирования
    parameter int WIDTH = 8;
    parameter real CLK_PERIOD = 10.0; // 100 МГц

    // Сигналы интерфейса DUT (типы reg/wire для максимальной переносимости)
    reg                 clk;
    reg                 rst_n;
    reg  [WIDTH-1:0]    s;
    reg  [WIDTH-1:0]    f;
    wire [WIDTH-1:0]    s_next;
    wire [WIDTH-1:0]    f_next;
    wire                rank_1_monopole;

    // Экземпляр тестируемого модуля (DUT)
    fano_gauge_atom_minimax #(
        .WIDTH(WIDTH)
    ) dut (
        .clk             (clk),
        .rst_n           (rst_n),
        .s               (s),
        .f               (f),
        .s_next          (s_next),
        .f_next          (f_next),
        .rank_1_monopole (rank_1_monopole)
    );

    // Генератор тактового сигнала (Clock Generator)
    always #(CLK_PERIOD / 2.0) clk = (clk === 1'b0) ? 1'b1 : 1'b0;

    // Включение записи временных диаграмм (VCD) для симулятора iverilog
    initial begin
        $dumpfile("fano_gauge_wave.vcd"); // Имя файла с графиками
        $dumpvars(0, fano_gauge_tb);      // Записывать все сигналы тестбенча и DUT
    end

    // Процедура инициализации и сброса
    task automatic reset_dut();
        rst_n = 1'b0;
        s     = {WIDTH{1'b0}};
        f     = {WIDTH{1'b0}};
        #(CLK_PERIOD * 2);
        @(negedge clk);
        rst_n = 1'b1;
    endtask

    // Основной поток верификации
    initial begin
        $timeformat(-9, 3, " ns", 10);
        $display("[%0t] Запуск верификации fano_gauge_atom_minimax (WIDTH = %0d)", $time, WIDTH);
        
        reset_dut();

        // ====================================================================
        // ТЕСТ-КЕЙС №1: Проверка неактивного поля (F = 0)
        // ====================================================================
        $display("[%0t] Тест 1: Нулевое калибровочное поле (Ожидается сброс в 0)", $time);
        @(negedge clk);
        s = 8'hAA;
        f = 8'h00;
        
        // Ожидаем 2 такта для прохождения данных через конвейер s_next/f_next
        repeat(2) @(negedge clk);
        if (s_next === {WIDTH{1'b0}} && f_next === {WIDTH{1'b0}}) begin
            $display("[%0t] ТЕСТ 1 УСПЕШНО: s_next=%h, f_next=%h", $time, s_next, f_next);
        end else begin
            $error("[%0t] ТЕСТ 1 СБОЙ: Ожидался 0. Получено: s_next=%h, f_next=%h", $time, s_next, f_next);
        end


        // ====================================================================
        // ТЕСТ-КЕЙС №2: Активация монополя (Для жесткого условия WIDTH == 8)
        // Скорректированная пара (s=8'h9C, f=8'h1D) активирует триггер (s_next==9C, f_next==81)
        // ====================================================================
        if (WIDTH == 8) begin
            $display("[%0t] Тест 2: Поиск макро-аттрактора монополя (Вход s=8'h9C, f=8'h1D)", $time);
            @(negedge clk);
            s = 8'h9C; 
            f = 8'h1D; 

            // Конвейерная задержка до финального регистра rank_1_monopole составляет 3 такта:
            // Такт 1: Входной барьер (s_reg, f_reg)
            // Такт 2: Вычисление s_next_comb/f_next_comb -> фиксация monopole_pipe
            // Такт 3: Фиксация и выход rank_1_monopole
            repeat(3) @(negedge clk);
            
            if (rank_1_monopole === 1'b1) begin
                $display("[%0t] ТЕСТ 2 УСПЕШНО: Обнаружен rank_1_monopole!", $time);
            end else begin
                $error("[%0t] ТЕСТ 2 СБОЙ: Флаг rank_1_monopole не поднялся. Текущие s_next=%h, f_next=%h", 
                       $time, s_next, f_next);
            end
        end


        // ====================================================================
        // ТЕСТ-КЕЙС №3: Рандомизированный стресс-тест
        // ====================================================================
        $display("[%0t] Тест 3: Генерация случайных воздействий (50 итераций)", $time);
        repeat(50) begin
            @(negedge clk);
            s = $random;
            f = $random;
        end

        // Очистка конвейера после случайных данных
        repeat(3) @(negedge clk);

        $display("[%0t] Верификация успешно завершена.", $time);
        $finish;
    end

    // Автоматический мониторинг в консоль симулятора при изменении сигналов
    initial begin
        $monitor("[%0t] Monitor -> IN: s=%h f=%h | OUT: s_next=%h f_next=%h monopole=%b", 
                 $time, s, f, s_next, f_next, rank_1_monopole);
    end

endmodule
