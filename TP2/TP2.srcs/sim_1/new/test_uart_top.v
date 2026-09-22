`timescale 1ns/1ps

module test_Uart_Top;

    // ---------- Parametros de simulacion (clock chico solo para acelerar el test) ----------
    localparam CLK_FREQ_HZ_TB  = 1_228_800;   // da un divisor chico, no es el valor real de la placa
    localparam BAUD_RATE_TB    = 19_200;
    localparam OVERSAMPLING_TB = 16;
    localparam NB_DATA_TB      = 8;
    localparam NB_OP_TB        = 6;
    localparam CLK_PERIOD      = 10;

    // Recalculo el mismo divisor que calcula BaudGenerator, para saber cuanto dura cada bit serie
    localparam integer TICKS_POR_SEG_TB    = BAUD_RATE_TB * OVERSAMPLING_TB;
    localparam integer DIVISOR_TB          = (CLK_FREQ_HZ_TB + TICKS_POR_SEG_TB/2) / TICKS_POR_SEG_TB;
    localparam integer BIT_PERIOD_CYCLES   = DIVISOR_TB * OVERSAMPLING_TB;
    localparam integer BIT_PERIOD_NS       = BIT_PERIOD_CYCLES * CLK_PERIOD;

    reg                       clk;
    reg                       reset;
    reg                       rx_line;
    wire                      tx_line;
    wire [NB_DATA_TB - 1 : 0] leds;

    Uart_Top #(
        .CLK_FREQ_HZ  (CLK_FREQ_HZ_TB),
        .BAUD_RATE    (BAUD_RATE_TB),
        .OVERSAMPLING (OVERSAMPLING_TB),
        .NB_DATA      (NB_DATA_TB),
        .NB_OP        (NB_OP_TB),
        .NS_TICKS     (OVERSAMPLING_TB),
        .N_DIR        (16)
    ) DUT (
        .clk     (clk),
        .i_reset (reset),
        .i_rx    (rx_line),
        .o_tx    (tx_line),
        .o_leds  (leds)
    );

    // ---------- Clock ----------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ---------- Enviar un byte por la linea serie i_rx (LSB primero) ----------
    task send_byte(input [NB_DATA_TB - 1 : 0] value);
        integer i;
        begin
            rx_line = 1'b0;                 // start bit
            #(BIT_PERIOD_NS);
            for (i = 0; i < NB_DATA_TB; i = i + 1)
            begin
                rx_line = value[i];         // LSB primero
                #(BIT_PERIOD_NS);
            end
            rx_line = 1'b1;                 // stop bit
            #(BIT_PERIOD_NS);
        end
    endtask

    // ---------- Recibir un byte de la linea serie o_tx (muestreo en el centro de cada bit) ----------
    task recv_byte(output [NB_DATA_TB - 1 : 0] value);
        integer i;
        begin
            @(negedge tx_line);             // arranca el start bit
            #(BIT_PERIOD_NS + BIT_PERIOD_NS/2); // saltar start bit completo + medio bit de dato
            for (i = 0; i < NB_DATA_TB; i = i + 1)
            begin
                value[i] = tx_line;
                #(BIT_PERIOD_NS);
            end
        end
    endtask

    reg [NB_DATA_TB - 1 : 0] byte_recibido;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, test_Uart_Top);

        reset   = 1;
        rx_line = 1'b1;   // linea idle en alto
        #(CLK_PERIOD*5);
        reset = 0;
        #(CLK_PERIOD*5);

        // ============================================================
        // Caso 1: ADD, opcode=0x20 (bits bajos 100000), A=5, B=3
        // Orden esperado por Interface: opcode, luego A, luego B
        // ============================================================
        send_byte(8'b00100000);   // opcode ADD (los 6 bits bajos son 100000)
        send_byte(8'd5);          // A
        send_byte(8'd3);          // B

        // Dar tiempo a que Interface + ALU_Core procesen (es rapido, pero
        // dejamos margen generoso)
        #(BIT_PERIOD_NS*4);

        $display("Caso 1a o_leds tras ADD 5+3 = %d (esperado 8)", leds);

        // Capturar lo que la placa retransmite por o_tx
        recv_byte(byte_recibido);
        $display("Caso 1b byte recibido por o_tx = %d (esperado 8)", byte_recibido);

        // ============================================================
        // Caso 2: SUB, opcode=0x22 (bits bajos 100010), A=10, B=4
        // ============================================================
        send_byte(8'b00100010);   // opcode SUB
        send_byte(8'd10);         // A
        send_byte(8'd4);          // B

        #(BIT_PERIOD_NS*4);
        $display("Caso 2a o_leds tras SUB 10-4 = %d (esperado 6)", leds);

        recv_byte(byte_recibido);
        $display("Caso 2b byte recibido por o_tx = %d (esperado 6)", byte_recibido);

        #(BIT_PERIOD_NS*4);
        $finish;
    end

endmodule