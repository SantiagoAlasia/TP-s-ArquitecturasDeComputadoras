`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: UNC
// Module Name: Interface
// Project Name: TP2-UART
// Description: Maneja la recepcion de opcode+A+B desde la FIFO de RX, dispara
//              la ALU, y envia el resultado a la FIFO de TX.
//////////////////////////////////////////////////////////////////////////////////

module Interface
#(
    parameter NB_DATA   = 8,
    parameter NB_OPCODE = 6
)
(
    input  wire i_clk,
    input  wire i_reset,
    input  wire [NB_DATA - 1 : 0] i_rx_data,
    input  wire i_rx_empty,
    input  wire i_rx_done,     
    input  wire i_tx_full,
    input  wire [NB_DATA - 1 : 0] i_alu_result,

    output wire o_rx_read,
    output wire o_tx_write,
    output wire [NB_DATA - 1 : 0]   o_tx_data,
    output wire [NB_OPCODE - 1 : 0] o_alu_opcode,
    output wire [NB_DATA - 1 : 0]   o_alu_data_a,
    output wire [NB_DATA - 1 : 0]   o_alu_data_b
);

    // Estados de la FSM
    localparam [2:0] CHECK_EMPTY = 3'b000;
    localparam [2:0] READ_REQ    = 3'b001;
    localparam [2:0] READ_WAIT   = 3'b010;
    localparam [2:0] SEND        = 3'b011;

    // Indice del campo que se esta recibiendo: 0=opcode, 1=data_a, 2=data_b
    reg [1:0] byte_idx, next_byte_idx;

    reg [2:0]               state, state_next;
    reg [NB_OPCODE - 1 : 0] opcode, opcode_next;
    reg [NB_DATA - 1 : 0]   data_a, data_a_next;
    reg [NB_DATA - 1 : 0]   data_b, data_b_next;
    reg rx_read;
    reg tx_write;

    // FSM - State Reg
    always @(posedge i_clk)
    begin
        if (i_reset) 
        begin
            state    <= CHECK_EMPTY;
            byte_idx <= 2'd0;
            opcode   <= {NB_OPCODE{1'b0}};
            data_a   <= {NB_DATA{1'b0}};
            data_b   <= {NB_DATA{1'b0}};
        end
        else 
        begin
            state    <= state_next;
            byte_idx <= next_byte_idx;
            opcode   <= opcode_next;
            data_a   <= data_a_next;
            data_b   <= data_b_next;
        end
    end

    // Next State Logic & Output Logic
    always @(*)
    begin
        state_next    = state;
        next_byte_idx = byte_idx;
        opcode_next   = opcode;
        data_a_next   = data_a;
        data_b_next   = data_b;
        rx_read       = 1'b0;
        tx_write      = 1'b0;

        case (state)
            // Espera a que haya al menos un byte disponible para el campo actual
            CHECK_EMPTY:
                begin
                    if (!i_rx_empty)
                        state_next = READ_REQ;
                end

            // Pulsa el pedido de lectura por 1 ciclo
            READ_REQ:
                begin
                    rx_read    = 1'b1;
                    state_next = READ_WAIT;
                end

            // Espera el pulso de done de la FIFO: recien ahi i_rx_data es valido
            READ_WAIT:
                begin
                    if (i_rx_done)
                    begin
                        case (byte_idx)
                            2'd0: opcode_next = i_rx_data[NB_OPCODE - 1 : 0];
                            2'd1: data_a_next = i_rx_data;
                            2'd2: data_b_next = i_rx_data;
                            default: data_a_next = i_rx_data; 
                        endcase

                        if (byte_idx == 2'd2)
                        begin
                            next_byte_idx = 2'd0;
                            state_next    = SEND;
                        end
                        else
                        begin
                            next_byte_idx = byte_idx + 1'b1;
                            state_next    = CHECK_EMPTY;
                        end
                    end
                end

            // Encola el resultado de la ALU en la FIFO de TX
            SEND:
                begin
                    if (!i_tx_full) 
                    begin
                        tx_write   = 1'b1;
                        state_next = CHECK_EMPTY;
                    end
                end

            default:
                state_next = CHECK_EMPTY;
        endcase
    end

    assign o_rx_read    = rx_read;
    assign o_tx_write   = tx_write;
    assign o_tx_data    = i_alu_result;
    assign o_alu_opcode = opcode;
    assign o_alu_data_a = data_a;
    assign o_alu_data_b = data_b;

endmodule