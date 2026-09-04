`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UNC
// Engineer: 
// 
// Create Date: 08/27/2026 07:41:13 PM
// Design Name: 
// Module Name: test_ALU_Top
// Project Name: TP1_ALU
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module test_ALU_Top;
    parameter NB_DATA = 8;
    parameter NB_OP   = 6;
    parameter CLK_PERIOD = 10;

    // Entradas / Salidas
    reg  [NB_DATA - 1 : 0] i_switches;
    reg                    clk;
    reg                    i_load_1;
    reg                    i_load_2;
    reg                    i_load_3;
    wire [NB_DATA - 1 : 0] o_leds;

    // Instancia del DUT
    ALU_Top #(
        .NB_DATA (NB_DATA),
        .NB_OP   (NB_OP)
    ) DUT (
        .i_switches (i_switches),
        .clk        (clk),
        .i_load_1   (i_load_1),
        .i_load_2   (i_load_2),
        .i_load_3   (i_load_3),
        .o_leds     (o_leds)
    );

    // ---------- Generación de clock ----------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Funciones reutilizables
    task load_a(input [NB_DATA - 1 : 0] value);
    begin
        i_switches = value;
        i_load_1   = 1;
        #(CLK_PERIOD);          // un flanco de clock -> reg_a se carga
        i_load_1   = 0;
        #(CLK_PERIOD);
    end
    endtask

    task load_b(input [NB_DATA - 1 : 0] value);
    begin
        i_switches = value;
        i_load_2   = 1;
        #(CLK_PERIOD);          // un flanco de clock -> reg_b se carga
        i_load_2   = 0;
        #(CLK_PERIOD);
    end
    endtask

    task load_opcode(input [NB_OP - 1 : 0] value);
    begin
        i_switches = value;
        i_load_3   = 1;
        #(CLK_PERIOD);          // un flanco de clock -> reg_opcode se carga
        i_load_3   = 0;
        #(CLK_PERIOD);
    end
    endtask

    // ---------- Estímulos ----------
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, test_ALU_Top);

        i_switches = 0;
        i_load_1   = 0;
        i_load_2   = 0;
        i_load_3   = 0;
        #(CLK_PERIOD*2);

        // Caso 1: ADD, 5 + 3 = 8
        load_a(8'd5);
        load_b(8'd3);
        load_opcode(6'b100000);
        #10 $display("Caso 1  (ADD 5+3)        o_leds=%d  (esperado 8)", o_leds);

        // Caso 2: SUB, 10 - 4 = 6
        load_a(8'd10);
        load_b(8'd4);
        load_opcode(6'b100010);
        #10 $display("Caso 2  (SUB 10-4)       o_leds=%d  (esperado 6)", o_leds);

        // Caso 3: AND, 0xCC & 0xAA = 0x88
        load_a(8'hCC);
        load_b(8'hAA);
        load_opcode(6'b100100);
        #10 $display("Caso 3  (AND CC&AA)      o_leds=%h  (esperado 88)", o_leds);

        // Caso 4: OR, 0xCC | 0xAA = 0xEE
        load_a(8'hCC);
        load_b(8'hAA);
        load_opcode(6'b100101);
        #10 $display("Caso 4  (OR  CC|AA)      o_leds=%h  (esperado EE)", o_leds);

        // Caso 5: XOR, 0xCC ^ 0xAA = 0x66
        load_a(8'hCC);
        load_b(8'hAA);
        load_opcode(6'b100110);
        #10 $display("Caso 5  (XOR CC^AA)      o_leds=%h  (esperado 66)", o_leds);

        // Caso 6: SRL, 0x80 >> 2 = 0x20 (shift logico, rellena con 0)
        load_a(8'h80);
        load_b(8'd2);
        load_opcode(6'b000010);
        #10 $display("Caso 6  (SRL 80>>2)      o_leds=%h  (esperado 20)", o_leds);

        // Caso 7: SRA, 0x80 >>> 5 -> 8
        load_a(8'h80);
        load_b(8'd5);
        load_opcode(6'b000011);
        #10 $display("Caso 7  (SRA 80>>>5)     o_leds=%h (esperado FC)", o_leds);

        // Caso 8: NOR, 0x0F ~| 0xF0 = 0x00
        load_a(8'h0F);
        load_b(8'hF0);
        load_opcode(6'b100111);
        #10 $display("Caso 8  (NOR 0F,F0)      o_leds=%h  (esperado 00)", o_leds);

        // Caso 9: ADD con overflow, 200 + 100 = 300 -> 1 bit de Carry + 8 bits de salida (44d)
        load_a(8'd200);
        load_b(8'd100);
        load_opcode(6'b100000);
        #10 $display("Caso 9  (ADD overflow)   o_leds=%d  (esperado 44, 300 mod 256)", o_leds);

        // Caso 10: shift por 0 (no deberia cambiar nada)
        load_a(8'hA5);
        load_b(8'd0);
        load_opcode(6'b000010);   // SRL
        #10 $display("Caso 10 (SRL shift 0)    o_leds=%h  (esperado A5, sin cambios)", o_leds);

        // Caso 11: shift por un valor mayor al ancho de datos (8 bits)
        load_a(8'hFF);
        load_b(8'd10);            // desplazar 10 posiciones en un dato de 8 bits
        load_opcode(6'b000010);   // SRL
        #10 $display("Caso 11 (SRL shift >8)   o_leds=%h  (esperado 00, se vacia el registro)", o_leds);
        
        // Caso 12: cambiar solo el reg A0
        // no deberia cambiar la salida al no haber precionado el boton 3
        load_a(8'd20);
        #10 $display("Caso 12 (solo A cambio)  o_leds=%d  (esperado 0 TODAVIA, no se aprieto boton 3)", o_leds);

        // Caso 13: ahora si apretamos boton 3 de nuevo, sin cambiar opcode,
        // deberia recalcular con el A nuevo (20) y el B viejo (10) -> 30
        load_opcode(6'b100000); // ADD
        #10 $display("Caso 13 (dispara con A nuevo) o_leds=%d  (esperado 30)", o_leds);

        #(CLK_PERIOD*4);
        $finish;
    end

endmodule