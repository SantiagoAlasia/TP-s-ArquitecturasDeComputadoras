`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.09.2026 14:50:20
// Design Name: 
// Module Name: tb_baud_generator
// Project Name: 
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

module tb_baud_generator;
 
    localparam CLK_PERIOD = 10;
 
    localparam DIV_100MHZ_19200 = 326;
    localparam DIV_100MHZ_9600  = 651;
    localparam DIV_50MHZ_19200  = 163;
 
    reg clk   = 0;
    reg reset = 1;
 
    wire tick_100mhz_19200;
    wire tick_100mhz_9600;
    wire tick_50mhz_19200;
 
    reg [1:0] sel = 0;
    reg       tick;
 
    integer errors = 0;
 
    always #(CLK_PERIOD / 2) clk = ~clk;
 
    always @(*) begin
        case (sel)
            2'd0:    tick = tick_100mhz_19200;
            2'd1:    tick = tick_100mhz_9600;
            default: tick = tick_50mhz_19200;
        endcase
    end
 
    Baud_Rate_Generator #(
        .CLK_FREQ_HZ(100_000_000), .BAUD_RATE(19_200), .OVERSAMPLING(16)
    ) dut_100mhz_19200 (.i_clk(clk), .i_reset(reset), .o_tick(tick_100mhz_19200));
 
    Baud_Rate_Generator #(
        .CLK_FREQ_HZ(100_000_000), .BAUD_RATE(9_600), .OVERSAMPLING(16)
    ) dut_100mhz_9600 (.i_clk(clk), .i_reset(reset), .o_tick(tick_100mhz_9600));
 
    Baud_Rate_Generator #(
        .CLK_FREQ_HZ(50_000_000), .BAUD_RATE(19_200), .OVERSAMPLING(16)
    ) dut_50mhz_19200 (.i_clk(clk), .i_reset(reset), .o_tick(tick_50mhz_19200));
 
    task check_tick;
        input [1:0]      dut;
        input integer    expected;
        input [8*12-1:0] name;
        integer t0, cycles, i, errors_before;
        begin
            errors_before = errors;
            sel = dut;
            @(posedge clk);
 
            @(posedge tick);
            for (i = 0; i < 5; i = i + 1) begin
                t0 = $time;
                @(posedge tick);
                cycles = ($time - t0) / CLK_PERIOD;
                if (cycles != expected) begin
                    errors = errors + 1;
                    $display("FAIL %0s: tick every %0d cycles, expected %0d", name, cycles, expected);
                end
            end
 
            @(posedge clk); #1;
            if (tick) begin
                errors = errors + 1;
                $display("FAIL %0s: tick lasts more than one cycle", name);
            end
 
            if (errors == errors_before)
                $display("OK   %0s: tick every %0d cycles", name, cycles);
        end
    endtask
 
    task check_reset;
        integer ticks_in_reset, cycles_to_first_tick;
        begin
            sel = 0;
            ticks_in_reset = 0;
            cycles_to_first_tick = 0;
 
            reset = 1;
            @(posedge clk);
            repeat (2 * DIV_100MHZ_19200) begin
                @(posedge clk);
                if (tick) ticks_in_reset = ticks_in_reset + 1;
            end
            @(negedge clk);
            reset = 0;
 
            while (!tick && cycles_to_first_tick < 2 * DIV_100MHZ_19200) begin
                @(posedge clk);
                cycles_to_first_tick = cycles_to_first_tick + 1;
            end
 
            if (ticks_in_reset != 0) begin
                errors = errors + 1;
                $display("FAIL reset: %0d ticks while in reset", ticks_in_reset);
            end
            else if (cycles_to_first_tick != DIV_100MHZ_19200) begin
                errors = errors + 1;
                $display("FAIL reset: first tick after %0d cycles, expected %0d",
                         cycles_to_first_tick, DIV_100MHZ_19200);
            end
            else
                $display("OK   reset: no ticks in reset, counter restarts from zero");
        end
    endtask
 
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_baud_generator);
 
        repeat (4) @(negedge clk);
        reset = 0;
 
        check_tick(0, DIV_100MHZ_19200, "100MHz 19200");
        check_tick(1, DIV_100MHZ_9600,  "100MHz 9600");
        check_tick(2, DIV_50MHZ_19200,  "50MHz 19200");
        check_reset;
 
        $display("%s (%0d errors)", errors ? "TEST FAILED" : "TEST PASSED", errors);
        $finish;
    end
 
endmodule
 