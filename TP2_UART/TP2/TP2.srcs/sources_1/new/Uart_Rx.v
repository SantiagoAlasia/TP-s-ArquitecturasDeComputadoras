`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: UNC
// Module Name: Uart_Rx
// Project Name: TP2-UART
// Description: Receptor de Datos.
//////////////////////////////////////////////////////////////////////////////////


module UartRx
#(
    parameter NB_DATA = 8,
    parameter NS_TICK = 16,      // Num. de ticks para el stop
    parameter N_TICKS = 16
)
(
    input  wire i_clk,
    input  wire i_reset,
    input  wire i_rx,
    input  wire i_tick,
    output wire o_rx_done,
    output wire [NB_DATA - 1 : 0] o_data
);

    localparam [1:0] IDLE  = 2'b00,
                     START = 2'b01,
                     DATA  = 2'b10,
                     STOP  = 2'b11;

    localparam NB_TICK_COUNT = $clog2(N_TICKS);
    localparam NB_BIT_COUNT  = $clog2(NB_DATA);
    localparam MEDIO_BIT     = (N_TICKS / 2) - 1;
    localparam BIT_COMPLETO  = N_TICKS - 1;

    reg [1:0] state, state_next;
    reg [NB_TICK_COUNT - 1 : 0] ticks, ticks_next;
    reg [NB_BIT_COUNT - 1 : 0]  bits,  bits_next;
    reg [NB_DATA - 1 : 0] shift, shift_next;
    reg rx_done, rx_done_next;

    reg rx_meta, rx_sync;

    always @(posedge i_clk)
    begin
        if (i_reset) 
        begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end
        else 
        begin
            rx_meta <= i_rx;
            rx_sync <= rx_meta;
        end
    end

    always @(posedge i_clk)
    begin
        if (i_reset)
        begin
            state   <= IDLE;
            ticks   <= {NB_TICK_COUNT{1'b0}};
            bits    <= {NB_BIT_COUNT{1'b0}};
            shift   <= {NB_DATA{1'b0}};
            rx_done <= 1'b0;
        end
        else 
        begin
            state   <= state_next;
            ticks   <= ticks_next;
            bits    <= bits_next;
            shift   <= shift_next;
            rx_done <= rx_done_next;
        end
    end

    always @(*)
    begin
        state_next   = state;
        ticks_next   = ticks;
        bits_next    = bits;
        shift_next   = shift;
        rx_done_next = 1'b0;

        case (state)
            IDLE:
                if (~rx_sync) 
                begin
                    state_next = START;
                    ticks_next = {NB_TICK_COUNT{1'b0}};
                end

            START:
                if (i_tick) 
                begin
                    if (ticks == MEDIO_BIT) 
                    begin
                        state_next = DATA;
                        ticks_next = {NB_TICK_COUNT{1'b0}};
                        bits_next  = {NB_BIT_COUNT{1'b0}};
                    end
                    else begin
                        ticks_next = ticks + 1'b1;
                    end
                end

            DATA:
                if (i_tick) 
                begin
                    if (ticks == BIT_COMPLETO) begin
                        ticks_next = {NB_TICK_COUNT{1'b0}};
                        shift_next = {rx_sync, shift[NB_DATA - 1 : 1]};
                        if (bits == NB_DATA - 1)
                            state_next = STOP;
                        else
                            bits_next = bits + 1'b1;
                    end
                    else 
                    begin
                        ticks_next = ticks + 1'b1;
                    end
                end

            STOP:
                if (i_tick) 
                begin
                    if (ticks == NS_TICK - 1) 
                    begin
                        state_next   = IDLE;
                        rx_done_next = rx_sync;
                    end
                    else 
                    begin
                        ticks_next = ticks + 1'b1;
                    end
                end

            default:
                state_next = IDLE;
        endcase
    end

    assign o_rx_done = rx_done;
    assign o_data    = shift;

endmodule