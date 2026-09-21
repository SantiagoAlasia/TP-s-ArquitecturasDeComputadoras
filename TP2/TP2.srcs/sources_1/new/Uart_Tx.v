`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: UNC
// Module Name: Uart_Tx
// Project Name: TP2-UART
// Description: Transmisor de datos.
//////////////////////////////////////////////////////////////////////////////////

module uart_tx
#(
    parameter ND_BIT          = 8,      // Num. de bit por dato
    parameter TICKS_POR_BIT   = 16,     // Num. de ticks por dato
    parameter NS_TICK         = 16      // Num. de ticks para el stop
)
(
    input  wire i_clk,
    input  wire i_reset,
    input  wire i_tx_start,
    input  wire i_tick,
    input  wire [ND_BIT - 1 : 0]i_data,
    
    output wire o_tx,
    output wire o_tx_done
);

    // Estados de la FSM
    localparam [1:0] idle  = 2'b00;
    localparam [1:0] start = 2'b01;
    localparam [1:0] data  = 2'b10;
    localparam [1:0] stop  = 2'b11;
    
    // Tamaño del contador de Ticks
    localparam integer ND_TICK = $clog2(TICKS_POR_BIT);
    
    reg [1:0]            state_reg;
    reg                  tx_reg;
    reg [ND_BIT - 1 : 0] data_reg;
    reg [ND_TICK - 1 : 0]tick_count;
    reg [ND_BIT - 1 : 0] bit_count;
    reg                  tx_done_reg;
    
    reg [1:0]            next_state_reg;
    reg                  next_tx_reg;
    reg [ND_BIT - 1 : 0] next_data_reg;
    reg [ND_TICK - 1 : 0]next_tick_count;
    reg [ND_BIT - 1 : 0] next_bit_count;

    // FSM - State Reg
    always @(posedge i_clk)
    begin
        if (i_reset)
            begin
                state_reg  <= idle;
                data_reg   <= 0; 
                tx_reg     <= 1'b1;
                tick_count <= 0;
                bit_count  <= 0;
            end
        else 
            begin
                state_reg  <= next_state_reg;
                data_reg   <= next_data_reg;
                tick_count <= next_tick_count;
                bit_count  <= next_bit_count;
                tx_reg     <= next_tx_reg;
            end
    end

    // Next State Logic & Output Logic
    always @*
    begin
        next_state_reg  = state_reg;
        next_tx_reg     = tx_reg;
        next_data_reg   = data_reg;
        next_tick_count = tick_count;
        next_bit_count  = bit_count;
        //tx_done_reg     = 1'b0;      
        
        case(state_reg)
            idle:
                begin
                    next_tx_reg = 1'b1;
                    if (i_tx_start)
                        begin
                            next_state_reg  = start;
                            next_data_reg   = i_data;
                            tx_done_reg     = 1'b0;  
                            next_tick_count = 0;
                        end
                end
            start:
                begin
                    next_tx_reg = 1'b0;
                    if (i_tick)
                        begin
                            if(tick_count == TICKS_POR_BIT - 1)
                                begin
                                    next_state_reg  = data;
                                    next_tick_count = 0;
                                end
                            else
                                next_tick_count = tick_count + 1;
                        end
                end
            data:
                begin
                    next_tx_reg = data_reg[0];
                    if (i_tick)
                        begin
                            if(tick_count == TICKS_POR_BIT - 1)
                                begin
                                    next_data_reg   = data_reg >> 1; 
                                    next_tick_count = 0;
                                    
                                    if(bit_count == ND_BIT - 1)
                                        begin
                                            next_state_reg  = stop;
                                            next_bit_count  = 0;
                                            next_tick_count = 0;
                                        end
                                    else
                                        next_bit_count = bit_count + 1;
                                end
                            else
                                next_tick_count = tick_count + 1;
                        end
                end
            stop:
                begin
                    next_tx_reg = 1'b1;
                    if(i_tick)
                        begin
                            if(tick_count == NS_TICK - 1)
                                begin
                                    next_state_reg  = idle;
                                    next_tick_count = 0;   
                                    tx_done_reg     = 1'b1;                                   
                                end
                            else
                                next_tick_count = tick_count + 1;
                        end
                end    
        endcase
    end

    assign o_tx_done = tx_done_reg;
    assign o_tx = tx_reg;    

endmodule