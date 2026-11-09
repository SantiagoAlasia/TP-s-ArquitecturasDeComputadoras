`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: UNC
// Module Name: Uart_Top
// Project Name: TP3
// Description: Integracion de todos los modulos.
//////////////////////////////////////////////////////////////////////////////////

module Uart_Top
#(
    parameter CLK_FREQ_HZ  = 100_000_000,
    parameter BAUD_RATE    = 19_200,        
    parameter OVERSAMPLING = 16,            
    parameter NB_DATA      = 8,                  // Tamaño en bits para los mensajes
    parameter NS_TICKS     = 16,                 // Ticks para el stop
    parameter N_DIR        = 16                  // Tamaño de las Fifos
)
(
    input  wire                   clk,          
    input  wire                   i_reset,       // Señal de reset
    input  wire                   i_rx,          // Entrada de datos serial
    input  wire [NB_DATA - 1 : 0] i_data_tx,     // Entrada de datos para transmitir
    input  wire                   i_write_fifo_tx,     
    input  wire                   i_read_fifo_rx,      
    
    output wire                   o_read_done,
    output wire                   o_fifo_rx_empty,
    output wire                   o_tx,          // Salida de datos serial
    output wire [NB_DATA - 1 : 0] o_data_rx      // Salida de datos recibidos
);
    wire                   tick;
    
    // FIFO + UART-RX
    wire [NB_DATA - 1 : 0] data_rx;
    wire                   rx_done;
    wire                   write_fifo_rx;
    wire                   read_fifo_rx;
    wire                   empty_fifo_rx;
    wire                   done_read_fifo_rx;
    wire [NB_DATA - 1 : 0] data_fifo_rx;
    
    // FIFO + UART-TX
    wire                   tx_start;
    wire                   tx_done;
    wire [NB_DATA - 1 : 0] data_tx;
    wire                   write_fifo_tx;
    wire                   read_fifo_tx;
    wire                   full_fifo_tx;
    wire                   empty_fifo_tx;
    wire                   done_read_fifo_tx;
    wire [NB_DATA - 1 : 0] data_fifo_tx;
    wire                   tx_busy;
    wire                   cond = !empty_fifo_tx && !tx_busy;
    reg                    cond_prev;
    wire                   read_pulse = cond && !cond_prev;

    // Baud Rate Generator
    BaudGenerator #(
        .CLK_FREQ_HZ  (CLK_FREQ_HZ),
        .BAUD_RATE    (BAUD_RATE),
        .OVERSAMPLING (OVERSAMPLING)
    ) baud_generator_inst (
        .i_clk   (clk),
        .i_reset (i_reset),
        .o_tick  (tick)
    );
    
    // UART RX
    UartRx #(
        .NB_DATA (NB_DATA),
        .NS_TICK (NS_TICKS),
        .N_TICKS (OVERSAMPLING)
    ) uart_rx_inst (
        .i_clk     (clk),
        .i_reset   (i_reset),
        .i_tick    (tick),
        .i_rx      (i_rx),
        .o_rx_done (rx_done),
        .o_data    (data_rx)
    );
    
    // Fifo de Rx
    fifo #(
        .NB_DATA (NB_DATA),
        .N_DIR   (N_DIR)
    ) fifo_rx_inst (
        .i_clk        (clk),
        .i_reset      (i_reset),
        .i_read       (read_fifo_rx),
        .i_write      (write_fifo_rx),
        .i_data       (data_rx),
        .o_data       (data_fifo_rx),
        .o_empty      (empty_fifo_rx),
        .o_full       (),
        .o_done_write (),
        .o_done_read  (done_read_fifo_rx)
    );
    
    // Fifo de Tx
    fifo #(
        .NB_DATA (NB_DATA),
        .N_DIR   (N_DIR)
    ) fifo_tx_inst (
        .i_clk        (clk),
        .i_reset      (i_reset),
        .i_read       (read_fifo_tx),
        .i_write      (write_fifo_tx),
        .i_data       (data_fifo_tx),
        .o_data       (data_tx),
        .o_empty      (empty_fifo_tx),
        .o_full       (full_fifo_tx),
        .o_done_write (),
        .o_done_read  (done_read_fifo_tx)
    );

    // FF que genera un pulso para el incio de transmicion
    always @(posedge clk)
    begin
        if (i_reset)
            cond_prev <= 1'b0;
        else
            cond_prev <= cond;
    end

    // UART TX
    uart_tx #(
        .ND_BIT         (NB_DATA),
        .TICKS_POR_BIT  (OVERSAMPLING),
        .NS_TICK        (NS_TICKS)
    ) uart_tx_inst (
        .i_clk      (clk),
        .i_reset    (i_reset),
        .i_tick     (tick),
        .i_tx_start (tx_start),
        .o_tx_done  (tx_done),
        .o_busy     (tx_busy),
        .i_data     (data_tx),
        .o_tx       (o_tx)
    );

    assign write_fifo_rx   = rx_done;
    assign tx_start        = done_read_fifo_tx;
    assign read_fifo_tx    = read_pulse;
    assign i_data_tx       = data_fifo_tx;
    assign i_read_fifo_rx  = read_fifo_rx;
    assign i_write_fifo_tx = write_fifo_tx;
    assign o_data_rx       = data_fifo_rx;
    assign o_read_done     = done_read_fifo_rx;
    assign o_fifo_rx_empty = empty_fifo_rx;
    
endmodule