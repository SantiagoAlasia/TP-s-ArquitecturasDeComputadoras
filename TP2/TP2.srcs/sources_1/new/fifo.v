`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: UNC
// Module Name: fifo
// Project Name: TP2-UART
// Description: Bugger FIFO Circular
//////////////////////////////////////////////////////////////////////////////////

module fifo
#(
    parameter NB_DATA = 8,  // Num. de bits que conforman un dato.
    parameter N_DIR   = 16  // Num. de direcciones del buffer.
)
(
    input  wire                    i_clk,
    input  wire                    i_reset,
    input  wire                    i_read,
    input  wire                    i_write,
    input  wire [NB_DATA - 1 : 0]  i_data,
    
    output wire                    o_full,
    output wire                    o_empty,
    output wire [NB_DATA - 1 : 0]  o_data,
    output wire                    o_done
);

    // Estados de la FSM
    localparam [1:0] idle  = 2'b00;
    localparam [1:0] write = 2'b01;
    localparam [1:0] read  = 2'b10;

    localparam integer N_PTR = $clog2(N_DIR);

    // Array de Registros
    reg [NB_DATA - 1 : 0] buffer [0 : N_DIR - 1];

    reg [1:0]           state_reg;
    reg [1:0]           next_state_reg;

    reg [N_PTR - 1 : 0]   wr_ptr_reg,  next_wr_ptr_reg;
    reg [N_PTR - 1 : 0]   rd_ptr_reg,  next_rd_ptr_reg;
    reg [N_PTR : 0]       count_reg,   next_count_reg;
    reg [NB_DATA - 1 : 0] data_reg,    next_data_reg;

    // Banderas combinacionales
    wire full  = (count_reg == N_DIR);
    wire empty = (count_reg == 0);

    // FSM - State Reg
    always @(posedge i_clk)
    begin
        if (i_reset)
            begin
                state_reg  <= idle;
                wr_ptr_reg <= 0;
                rd_ptr_reg <= 0;
                count_reg  <= 0;
                data_reg   <= 0;
            end
        else
            begin
                state_reg  <= next_state_reg;
                wr_ptr_reg <= next_wr_ptr_reg;
                rd_ptr_reg <= next_rd_ptr_reg;
                count_reg  <= next_count_reg;
                data_reg   <= next_data_reg;
            end
    end

    // Next State Logic & Output Logic
    always @*
    begin
        next_state_reg  = idle;
        next_wr_ptr_reg = wr_ptr_reg;
        next_rd_ptr_reg = rd_ptr_reg;
        next_count_reg  = count_reg;
        next_data_reg   = data_reg;

        case (state_reg)
            idle:
                begin
                    if (i_write && !full)
                        next_state_reg = write;
                    else if (i_read && !empty)
                        next_state_reg = read;
                end

            write:
                begin
                    next_wr_ptr_reg    = wr_ptr_reg + 1'b1;
                    next_count_reg     = count_reg + 1'b1;
                    buffer[wr_ptr_reg] = i_data;
                    next_state_reg     = idle;
                end

            read:
                begin
                    next_data_reg   = buffer[rd_ptr_reg];
                    next_rd_ptr_reg = rd_ptr_reg + 1'b1;
                    next_count_reg  = count_reg - 1'b1;
                    next_state_reg  = idle;
                end

            default:
                next_state_reg = idle;
        endcase
    end

    assign o_full  = full;
    assign o_empty = empty;
    assign o_data  = data_reg;
    assign o_done  = (state_reg == write) || (state_reg == read);

endmodule