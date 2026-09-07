`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// test_auto_ALU_Top - Testbench con verificación automáctica
//////////////////////////////////////////////////////////////////////////////

module test_auto_ALU_Top;

    parameter NB_DATA = 8;
    parameter NB_OP   = 6;
    parameter N_TEST  = 200;

    reg                clk;
    reg                i_reset;
    reg  [NB_DATA-1:0] i_switches;
    reg                i_load_1, i_load_2, i_load_3;
    wire [NB_DATA-1:0] o_leds;

    // Reloj de 100 MHz
    always #5 clk = ~clk;

    integer errores, i, seed;
    reg [NB_DATA-1:0] a, b;
    reg [NB_OP-1:0]   op;
    reg [NB_OP-1:0]   ops [0:7];

    ALU_Top #(.NB_DATA(NB_DATA), .NB_OP(NB_OP)) DUT (
        .clk        (clk),
        .i_reset    (i_reset),
        .i_switches (i_switches),
        .i_load_1   (i_load_1),
        .i_load_2   (i_load_2),
        .i_load_3   (i_load_3),
        .o_leds     (o_leds)
    );

    // Modelo de referencia
    function [NB_DATA-1:0] alu_ref;
        input [NB_DATA-1:0] x, y;
        input [NB_OP-1:0]   o;
        case (o)
            6'b100000: alu_ref = x + y;              // ADD
            6'b100010: alu_ref = x - y;              // SUB
            6'b100100: alu_ref = x & y;              // AND
            6'b100101: alu_ref = x | y;              // OR
            6'b100110: alu_ref = x ^ y;              // XOR
            6'b100111: alu_ref = ~(x | y);           // NOR
            6'b000010: alu_ref = x >> y;             // SRL
            6'b000011: alu_ref = $signed(x) >>> y;   // SRA
            default:   alu_ref = {NB_DATA{1'b0}};    // opcode invalido
        endcase
    endfunction

    task carga;
        input [NB_DATA-1:0] valor;
        input [1:0]         sel;
        begin
            @(negedge clk);
            i_switches = valor;
            case (sel)
                2'd1: i_load_1 = 1;
                2'd2: i_load_2 = 1;
                2'd3: i_load_3 = 1;
            endcase
            @(negedge clk);
            @(negedge clk);
            i_load_1 = 0; i_load_2 = 0; i_load_3 = 0;
            @(negedge clk);
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, test_auto_ALU_Top);
        $timeformat(-9, 0, " ns", 10);   // que %t se imprima en ns

        errores = 0;
        seed    = 12345;           // semilla fija

        ops[0]=6'b100000; ops[1]=6'b100010; ops[2]=6'b100100; ops[3]=6'b100101;
        ops[4]=6'b100110; ops[5]=6'b100111; ops[6]=6'b000010; ops[7]=6'b000011;

        clk        = 0;
        i_reset    = 1;
        i_switches = 0; i_load_1 = 0; i_load_2 = 0; i_load_3 = 0;
        repeat (4) @(negedge clk);    // reset activo 4 ciclos
        i_reset = 0;
        repeat (2) @(negedge clk);
        #20;

        for (i = 0; i < N_TEST; i = i + 1) begin
            a = $random(seed);
            b = $random(seed);
            // 1 de cada 10 usa un opcode totalmente aleatorio para cubrir casos invalidos
            if (i % 10 == 0) op = $random(seed);
            else             op = ops[{$random(seed)} % 8];

            carga(a, 1);
            carga(b, 2);
            carga({{(NB_DATA-NB_OP){1'b0}}, op}, 3);
            #10;

            // !== detecta tambien X y Z
            if (o_leds !== alu_ref(a, b, op)) begin
                errores = errores + 1;
                $display("FALLO t=%0t | op=%b | a=%h b=%h | obtenido=%h | esperado=%h",
                         $time, op, a, b, o_leds, alu_ref(a, b, op));
            end
        end

        $display("--------------------------------------------------");
        $display(" Casos: %0d   Errores: %0d   %s",
                 N_TEST, errores, errores ? "TEST FAILED" : "TEST PASSED");
        $display("--------------------------------------------------");
        $finish;
    end

endmodule
