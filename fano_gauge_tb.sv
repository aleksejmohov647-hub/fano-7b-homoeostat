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

    // Generator taktovoy chastoty (period 10ns)
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Osnovnoy potok verifikacii
    initial begin
        // Inicializaciya vhodnyh barierov
        rst_n = 1'b0;
        s     = {WIDTH{1'b0}};
        f     = {WIDTH{1'b0}};

        // Uderzhivaem sbros 2 polnyh takta i snimaem strogo po spadu, chtoby izbezhat gonok
        repeat(2) @(posedge clk); 
        @(negedge clk);
        rst_n = 1'b1; 
        
        $display("=========================================================");
        $display("   RUNNING: SECURE FANO-MUFANG MULTISCALE RTL TEST       ");
        $display("=========================================================");
        
        // --- Test 1: Podacha vakuumnogo shuma (F = 0) ---
        @(posedge clk);
        s <= 8'hAA; 
        f <= 8'h00; 
        
        // Zhdem 2 takta, chtoby dannye proshli vhodnoy barier i vyshli na s_next/f_next
        repeat(2) @(posedge clk);
        #1; // Nebolshaya zaderzhka chteniya dlya krasivogo otobrazheniya v konsoli
        $display("[Vacuum Test] Vhod: s=AA, f=00 | s_next=%h, f_next=%h, Monopole=%b", s_next, f_next, rank_1_monopole);

        // --- Test 2: Zahvat attraktora N(12) ---
        $display("[Eversion Test] Zapusk eversii po modulyu 13 na reshetke N(12)...");
        
        @(posedge clk);
        s <= 8'h39; // Konstanta ATTR_N12 starshaya chast
        f <= 8'hF1; // Konstanta ATTR_N12 mladshaya chast (v summe 16'h39F1)

        // Konveyer: 
        // 1-y takt: zapis v s_reg/f_reg
        // 2-y takt: vychislenie s_next/f_next i zapis v monopole_pipe
        // 3-y takt: fiksaciya v rank_1_monopole
        repeat(3) @(posedge clk);
        #1; // Sdvig dlya zahvata stabilnogo sostoyaniya registra
        
        if (rank_1_monopole) begin
            $display("[SUCCESS] Adelny kollaps zafiksirovan!");
            $display("[SUCCESS] Bezopasny dvuhtaktny zamok monopola J vzveden.");
        end else begin
            $display("[FAIL] Kalibrovochny zamok ne srabotal. s_next=%h, f_next=%h", s_next, f_next);
        end

        $display("=========================================================");
        repeat(2) @(posedge clk);
        $finish;
    end

endmodule

`default_nettype wire // Vozvraschaem defoltny rezhim
