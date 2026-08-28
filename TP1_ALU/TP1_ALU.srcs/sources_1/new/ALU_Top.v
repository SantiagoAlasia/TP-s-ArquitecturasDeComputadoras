
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UNC
// Engineer: 
// 
// Create Date: 08/27/2026 07:31:38 PM
// Design Name: 
// Module Name: ALU_Top
// Project Name:TP1-ALU 
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

module ALU_Top
#(
    parameter NB_DATA = 8,
    parameter NB_OP   = 6
)
(
    input  wire [NB_DATA - 1 : 0]      i_switches,
    input  wire                        i_load_1,     // Señal para cargar A
    input  wire                        i_load_2,     // Señal para cargar B
    input  wire                        i_load_3,     // Señal para cargar opcode y disparar resultado
    
    output wire [NB_DATA - 1 : 0]      o_leds
);

    // FF A
    reg [NB_DATA - 1 : 0] reg_a;
    
    always @(posedge i_load_1)
    begin
        reg_a <= i_switches;
    end

    // FF B
    reg [NB_DATA - 1 : 0] reg_b;
    always @(posedge i_load_2)
    begin
        reg_b <= i_switches;
    end

    // FF Opcode
    reg [NB_OP - 1 : 0] reg_opcode;
    always @(posedge i_load_3)
    begin
        reg_opcode <= i_switches[NB_OP - 1 : 0];
    end

    // Instancia del modulo ALU_Core
    wire [NB_DATA - 1 : 0] alu_result;

    ALU_Core #(
        .NB_DATA (NB_DATA),
        .NB_OP   (NB_OP)
    ) alu_core_inst (
        .o_result  (alu_result),
        .i_data_a  (reg_a),
        .i_data_b  (reg_b),
        .i_opcode  (reg_opcode)
    );

    // FF Salida
    reg [NB_DATA - 1 : 0] reg_result;
    always @(negedge i_load_3)
    begin
        reg_result <= alu_result;
    end

    assign o_leds = reg_result;

endmodule