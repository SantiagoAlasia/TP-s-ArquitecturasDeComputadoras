`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: UNC
// Module Name: Baud Rate Generator
// Project Name: TP2-UART
// Description: Contador modulo N que genera un tick OVERSAMPLING veces por baudio.
//              N = Clock / (BaudRate * OVERSAMPLING)
//////////////////////////////////////////////////////////////////////////////////

module BaudGenerator
#(
    parameter CLK_FREQ_HZ  = 100_000_000,
    parameter BAUD_RATE    = 19_200,
    parameter OVERSAMPLING = 16
)
(
    input  wire i_clk,
    input  wire i_reset,
    output wire o_tick
);

    localparam integer TICKS_POR_SEG = BAUD_RATE * OVERSAMPLING;
    // Redondeo al entero mas cercano
    localparam integer DIVISOR  = (CLK_FREQ_HZ + TICKS_POR_SEG/2) / TICKS_POR_SEG;
    localparam integer NB_COUNT = $clog2(DIVISOR);

    reg [NB_COUNT - 1 : 0] counter;

    always @(posedge i_clk)
    begin
        if (i_reset)
            counter <= {NB_COUNT{1'b0}};
        else if (o_tick)
            counter <= {NB_COUNT{1'b0}};
        else
            counter <= counter + 1'b1;
    end

    assign o_tick = (counter == DIVISOR - 1);

endmodule
