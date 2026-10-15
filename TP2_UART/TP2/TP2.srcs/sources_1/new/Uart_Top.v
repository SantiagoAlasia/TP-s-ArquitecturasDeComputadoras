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
    parameter NB_DATA      = 8,                  // Tamaño en bits para los operandos
    parameter NB_OP        = 6,                  // Tamaño en bits para el opcode
    parameter NS_TICKS     = 16,                 // Ticks para el stop
    parameter N_DIR        = 16                  // Tamaño de las Fifos
)
(
    input  wire                   clk,          
    input  wire                   i_reset,       // Señal de reset
    input  wire                   i_rx,          // Entrada de datos
    
    output wire                   o_tx,          // Salida de datos
    output wire [NB_DATA - 1 : 0] o_leds         // Para visualizar en la placa el resultado de la operacion
);
    wire                   tick;
    
    // FIFO + UART-RX
    wire [NB_DATA - 1 : 0] data_rx;
    wire                   rx_done;
    wire                   read_fifo_rx;
    wire                   write_fifo_rx;
    wire                   empty_fifo_rx;
    wire                   done_read_fifo_rx;
    wire [NB_DATA - 1 : 0] data_fifo_rx;
    
    // FIFO + UART-TX
    wire                   tx_start;
    wire                   tx_done;
    wire [NB_DATA - 1 : 0] data_tx;
    wire                   read_fifo_tx;
    wire                   write_fifo_tx;
    wire                   full_fifo_tx;
    wire                   empty_fifo_tx;
    wire                   done_read_fifo_tx;
    wire [NB_DATA - 1 : 0] data_fifo_tx;
    wire                   tx_busy;
    wire                   cond = !empty_fifo_tx && !tx_busy;
    reg                    cond_prev;
    wire                   read_pulse = cond && !cond_prev;
    
    // ALU
    wire [NB_DATA - 1 : 0] alu_data_a;
    wire [NB_DATA - 1 : 0] alu_data_b;
    wire [NB_OP   - 1 : 0] alu_data_op;
    wire [NB_DATA - 1 : 0] alu_result;

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
    
    // Interface
    Interface #(
        .NB_DATA    (NB_DATA),
        .NB_OPCODE  (NB_OP)   
    ) interface_inst (
        .i_clk        (clk),
        .i_reset      (i_reset),
        .i_rx_data    (data_fifo_rx),
        .i_rx_empty   (empty_fifo_rx),
        .i_rx_done    (done_read_fifo_rx),
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

    assign write_fifo_rx = rx_done;
    assign tx_start = done_read_fifo_tx;
    assign read_fifo_tx = read_pulse;
    assign o_leds = alu_result;
    
endmodule