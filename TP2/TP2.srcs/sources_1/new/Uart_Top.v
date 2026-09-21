`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: UNC
// Module Name: Uart_Top
// Project Name: TP2-UART
// Description: Integracion de todos los modulos.
//////////////////////////////////////////////////////////////////////////////////

module Uart_Top
#(
    parameter CLK_FREQ_HZ  = 100_000_000,
    parameter BAUD_RATE    = 19_200,
    parameter OVERSAMPLING = 16,
    parameter NB_DATA      = 8,
    parameter NB_OP        = 6,
    parameter NS_TICKS     = 16,                 // Ticks para el stop
    parameter N_DIR        = 16                  // Tamaño de las Fifos
)
(
    input  wire                   clk,          
    input  wire                   i_reset,      // Señal de reset
    input  wire                   i_rx,
    
    output wire                   o_tx,
    output wire [NB_DATA - 1 : 0] o_leds
);
    wire                   tick;
    wire [NB_DATA - 1 : 0] data_rx;
    wire                   rx_done;
    wire                   tx_start;
    wire                   tx_done;
    wire                   data_tx;
    wire                   read_fifo_rx;
    wire                   write_fifo_rx;
    wire                   empty_fifo_rx;
    wire                   data_fifo_rx;
    wire                   write_fifo_tx;
    wire                   full_fifo_tx;
    wire                   data_fifo_tx;
    wire                   alu_data_a;
    wire                   alu_data_b;
    wire                   alu_data_op;
    wire                   alu_result;
    
    // Baud Rate Generator
    BaudGenerator #(
        .CLK_FREQ_HZ  (CLK_FREQ_HZ),
        .BAUD_RATE    (BAUD_RATE),
        .OVERSAMPLING (OVERSAMPLING)
    ) baud_generator_inst (
        .i_clk     (clk),
        .i_reset (i_reset),
        .o_tick  (tick)
    );
    
    // UART RX
    UartRx #(
        .NB_DATA (NB_DATA),
        .N_TICKS (OVERSAMPLING)
    ) uart_rx_inst (
        .i_clk     (i_clk),
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
        .i_clk        (i_clk),
        .i_reset    (i_reset),
        .i_read     (read_fifo_rx),
        .i_write    (write_fifo_rx),
        .i_data     (data_rx),
        .o_data     (data_fifo_rx),
        .o_empty    (empty_fifo_rx)
    );
    
    // Interface
    Interface #(
        .NB_DATA    (NB_DATA),
        .NB_OPCODE  (NB_OP)   
    ) interface_inst (
        .i_clk        (i_clk),
        .i_reset      (i_reset),
        .i_rx_data    (data_fifo_rx),
        .i_rx_empty   (empty_fifo_rx),
        .i_tx_full    (full_fifo_tx),
        .i_alu_result (alu_result),
        .o_rx_read    (read_fifo_rx),
        .o_tx_write   (write_fifo_tx),
        .o_tx_data    (data_fifo_tx),
        .o_alu_opcode (alu_data_op),
        .o_alu_data_a (alu_data_a),
        .o_alu_data_b (alu_data_b)
    );
    
    // ALU_Core
    ALU_Core #(
        .NB_DATA (NB_DATA),
        .NB_OP   (NB_OP)
    ) alu_core_inst (
        .o_result  (alu_result),
        .i_data_a  (alu_data_a),
        .i_data_b  (alu_data_b),
        .i_opcode  (alu_data_op)
    );
    
    // Fifo de Tx
    fifo #(
        .NB_DATA (NB_DATA),
        .N_DIR   (N_DIR)
    ) fifo_tx_inst (
        .i_clk         (i_clk),
        .i_reset     (i_reset),
        .i_read      (tx_done),
        .i_write     (write_fifo_tx),
        .i_data      (data_fifo_tx),
        .o_data      (data_tx),
        .o_done_read (tx_start),
        .o_full      (full_fifo_tx)
    );
    
    // UART TX
    uart_tx #(
        .ND_BIT         (NB_DATA),
        .TICKS_POR_BIT  (OVERSAMPLING),
        .NS_TICK        (NS_TICKS)
    ) uart_tx_inst (
        .i_clk        (i_clk),
        .i_reset    (i_reset),
        .i_tick     (tick),
        .i_tx_start (tx_start),
        .o_tx_done  (tx_done),
        .i_data     (data_tx),
        .o_tx       (o_tx)
    );

    assign o_leds = alu_result;
    
endmodule