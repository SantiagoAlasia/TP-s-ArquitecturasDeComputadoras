`timescale 1ns/1ps

module test_uart_tx;

    parameter ND_BIT        = 8;
    parameter TICKS_POR_BIT = 16;
    parameter NS_TICK       = 16;
    parameter CLK_PERIOD    = 10;
    parameter TICK_PERIOD   = 4;   // cada cuantos ciclos de clk se genera 1 tick

    reg                    clk;
    reg                    reset;
    reg                    tx_start;
    reg  [ND_BIT - 1 : 0]  data_in;
    wire                   tx;
    wire                   tx_done;

    // ---------- DUT ----------
    uart_tx #(
        .ND_BIT        (ND_BIT),
        .TICKS_POR_BIT (TICKS_POR_BIT),
        .NS_TICK       (NS_TICK)
    ) DUT (
        .i_clk      (clk),
        .i_reset    (reset),
        .i_tx_start (tx_start),
        .i_tick     (tick),
        .i_data     (data_in),
        .o_tx       (tx),
        .o_tx_done  (tx_done)
    );

    // ---------- Clock ----------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ---------- Generador de tick simplificado ----------
    reg        tick;
    reg [7:0]  tick_counter;

    always @(posedge clk)
    begin
        if (reset)
        begin
            tick_counter <= 0;
            tick <= 1'b0;
        end
        else if (tick_counter == TICK_PERIOD - 1)
        begin
            tick_counter <= 0;
            tick <= 1'b1;
        end
        else
        begin
            tick_counter <= tick_counter + 1;
            tick <= 1'b0;
        end
    end

    // ---------- Monitor de la salida serie ----------
    // Se dispara cada vez que "tx" cambia, para ver los bits a medida que salen
    initial
        $monitor("t=%0t  tx=%b  tx_done=%b  state=%b", $time, tx, tx_done, DUT.state_reg);

    // ---------- Estimulos ----------
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, test_uart_tx);

        reset    = 1;
        tx_start = 0;
        data_in  = 8'b0;
        #(CLK_PERIOD*3);

        reset = 0;
        #(CLK_PERIOD*3);

        // Transmitir 01011101
        data_in  = 8'b01011101;
        tx_start = 1;
        #(CLK_PERIOD);
        tx_start = 0;

        // Esperar a que termine (start + 8 datos + stop, cada uno TICKS_POR_BIT*TICK_PERIOD ciclos de clk)
        wait (tx_done == 1'b1);
        #(CLK_PERIOD*5);

        $display("Transmision completa. Byte enviado: %b", 8'b10011010);
        $finish;
    end

endmodule