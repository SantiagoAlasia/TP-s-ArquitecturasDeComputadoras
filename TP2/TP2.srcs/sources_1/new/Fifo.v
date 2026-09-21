`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: UNC
// Module Name: fifo
// Project Name: TP2-UART
// Description: Buffer Circular. FSM de 3 estados (idle, write, read) que implementa
//              las operaciones mediante dos punteros independientes.
//////////////////////////////////////////////////////////////////////////////////

module fifo
#(
    parameter NB_DATA = 8,  // Ancho de cada dato almacenado
    parameter N_DIR   = 16  // Cantidad de posiciones del buffer (debe ser potencia de 2)
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
    output wire                    o_done_write,
    output wire                    o_done_read
);

    // Estados de la FSM
    localparam [1:0] idle  = 2'b00;
    localparam [1:0] write = 2'b01;
    localparam [1:0] read  = 2'b10;

    localparam integer N_PTR = $clog2(N_DIR);

    // Memoria interna
    reg [NB_DATA - 1 : 0] mem [0 : N_DIR - 1];

    // Registros de estado
    reg [1:0]              state_reg;
    reg [N_PTR - 1 : 0]    wr_ptr_reg;
    reg [N_PTR - 1 : 0]    rd_ptr_reg;
    reg [N_PTR : 0]        count_reg;
    reg [NB_DATA - 1 : 0]  data_reg;
    reg                    done_write_reg;
    reg                    done_read_reg;

    reg [1:0]              next_state_reg;
    reg [N_PTR - 1 : 0]    next_wr_ptr_reg;
    reg [N_PTR - 1 : 0]    next_rd_ptr_reg;
    reg [N_PTR : 0]        next_count_reg;
    reg [NB_DATA - 1 : 0]  next_data_reg;
    
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
                done_write_reg   <= 1'b0;
                done_read_reg   <= 1'b0;
            end
        else
            begin
                state_reg  <= next_state_reg;
                wr_ptr_reg <= next_wr_ptr_reg;
                rd_ptr_reg <= next_rd_ptr_reg;
                count_reg  <= next_count_reg;
                data_reg   <= next_data_reg;
                done_write_reg   <= (state_reg == write);
                done_read_reg    <= (state_reg == read);
            end
    end

    // Escritura a Memoria
    always @(posedge i_clk)
    begin
        if (state_reg == write)
            mem[wr_ptr_reg] <= i_data;
    end

    // Next State Logic & Output Logic
    always @*
    begin
        next_state_reg  = state_reg;
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
                    next_wr_ptr_reg = wr_ptr_reg + 1'b1;
                    next_count_reg  = count_reg + 1'b1;
                    next_state_reg  = idle;
                end

            read:
                begin
                    next_data_reg   = mem[rd_ptr_reg];
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
    assign o_done_read  = done_read_reg;
    assign o_done_write  = done_write_reg;

endmodule
