`timescale 1ns/1ps

module test_fifo;

    parameter NB_DATA    = 8;
    parameter N_DIR      = 4;   // Valor chico para el test
    parameter CLK_PERIOD = 10;

    reg                    clk;
    reg                    reset;
    reg                    read;
    reg                    write;
    reg  [NB_DATA - 1 : 0] data_in;
    wire                   full;
    wire                   empty;
    wire [NB_DATA - 1 : 0] data_out;
    wire                   done;

    Fifo #(
        .NB_DATA (NB_DATA),
        .N_DIR   (N_DIR)
    ) DUT (
        .i_clk   (clk),
        .i_reset (reset),
        .i_read  (read),
        .i_write (write),
        .i_data  (data_in),
        .o_full  (full),
        .o_empty (empty),
        .o_data  (data_out),
        .o_done  (done)
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Tarea: escribir un byte y esperar a que la FIFO confirme
    task write_byte(input [NB_DATA-1:0] value);
    begin
        @(negedge clk);
        data_in = value;
        write   = 1;
        @(negedge clk);
        write   = 0;
    end
    endtask

    // Tarea: pulsar read
    task read_byte;
    begin
        @(negedge clk);
        read = 1;
        @(negedge clk);
        read = 0;
    end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, test_fifo);

        reset   = 1;
        read    = 0;
        write   = 0;
        data_in = 0;
        #(CLK_PERIOD*2);
        reset = 0;
        #(CLK_PERIOD*2);

        // ============================================================
        // Caso 1: empty debe estar en 1 al arrancar
        // ============================================================
        $display("Caso 1  empty inicial = %b (esperado 1)", empty);

        // ============================================================
        // Caso 2: escribir un dato, leerlo, verificar orden FIFO
        // ============================================================
        write_byte(8'hAA);
        #(CLK_PERIOD);
        $display("Caso 2a empty tras 1 escritura = %b (esperado 0)", empty);

        read_byte;
        #(CLK_PERIOD*2);  // esperar el pulso de done (1 ciclo despues del estado read)
        $display("Caso 2b data_out = %h (esperado AA)", data_out);
        $display("Caso 2c empty tras leer el unico dato = %b (esperado 1)", empty);

        // ============================================================
        // Caso 3: FIFO real (First In First Out) con 3 datos
        // ============================================================
        write_byte(8'h11);
        write_byte(8'h22);
        write_byte(8'h33);
        #(CLK_PERIOD);

        read_byte;
        #(CLK_PERIOD*2);
        $display("Caso 3a primer dato leido = %h (esperado 11)", data_out);

        read_byte;
        #(CLK_PERIOD*2);
        $display("Caso 3b segundo dato leido = %h (esperado 22)", data_out);

        read_byte;
        #(CLK_PERIOD*2);
        $display("Caso 3c tercer dato leido = %h (esperado 33)", data_out);
        $display("Caso 3d empty tras vaciar = %b (esperado 1)", empty);

        // ============================================================
        // Caso 4: leer con buffer vacio - no deberia pasar nada raro
        // ============================================================
        read_byte;
        #(CLK_PERIOD*2);
        $display("Caso 4  leer vacio: empty sigue = %b (esperado 1, sin cambios)", empty);

        // ============================================================
        // Caso 5: llenar completamente el buffer (N_DIR=4) y verificar full
        // ============================================================
        write_byte(8'hA0);
        write_byte(8'hA1);
        write_byte(8'hA2);
        write_byte(8'hA3);
        #(CLK_PERIOD);
        $display("Caso 5  full tras llenar (4/4) = %b (esperado 1)", full);

        // Intentar escribir con buffer lleno (no deberia hacer nada)
        write_byte(8'hFF);
        #(CLK_PERIOD);
        $display("Caso 5b full sigue en 1 tras intento de escritura extra = %b (esperado 1)", full);

        // Vaciar todo y confirmar que el orden se mantuvo (no se colo el FF)
        read_byte; #(CLK_PERIOD*2);
        $display("Caso 5c dato = %h (esperado A0)", data_out);
        read_byte; #(CLK_PERIOD*2);
        $display("Caso 5d dato = %h (esperado A1)", data_out);
        read_byte; #(CLK_PERIOD*2);
        $display("Caso 5e dato = %h (esperado A2)", data_out);
        read_byte; #(CLK_PERIOD*2);
        $display("Caso 5f dato = %h (esperado A3)", data_out);
        $display("Caso 5g empty tras vaciar todo = %b (esperado 1)", empty);

        // ============================================================
        // Caso 6: pulso de o_done, escritura vs lectura
        // ============================================================
        write_byte(8'h55);
        #(CLK_PERIOD*3);
        $display("Caso 6  (verificar o_done en la waveform para write y read)");
        read_byte;
        #(CLK_PERIOD*3);

        #(CLK_PERIOD*4);
        $finish;
    end

endmodule