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
// Revision 0.02 - Registros instanciados con reset, salida combinacional
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
    input  wire                        clk,          // Señal de clock para los registros
    input  wire                        i_reset,      // Señal de reset
    input  wire                        i_load_1,     // Señal para cargar A
    input  wire                        i_load_2,     // Señal para cargar B
    input  wire                        i_load_3,     // Señal para cargar opcode
    
    output wire [NB_DATA - 1 : 0]      o_leds
);
    wire [NB_DATA - 1 : 0] reg_a;
    wire [NB_DATA - 1 : 0] reg_b;
    wire [NB_OP - 1 : 0]   reg_opcode;
    
    // Registro A
    Registro #(
        .NB (NB_DATA)
    ) reg_a_inst (
        .clk      (clk),
        .i_reset  (i_reset),
        .i_enable (i_load_1),
        .i_data   (i_switches),
        .o_data   (reg_a)
    );

    // Registro B
    Registro #(
        .NB (NB_DATA)
    ) reg_b_inst (
        .clk      (clk),
        .i_reset  (i_reset),
        .i_enable (i_load_2),
        .i_data   (i_switches),
        .o_data   (reg_b)
    );

    // Registro de Opcode: mismo modulo, otro ancho
    Registro #(
        .NB (NB_OP)
    ) reg_opcode_inst (
        .clk      (clk),
        .i_reset  (i_reset),
        .i_enable (i_load_3),
        .i_data   (i_switches[NB_OP - 1 : 0]),
        .o_data   (reg_opcode)
    );

    // Instancia del modulo ALU_Core
    ALU_Core #(
        .NB_DATA (NB_DATA),
        .NB_OP   (NB_OP)
    ) alu_core_inst (
        .o_result  (o_leds),
        .i_data_a  (reg_a),
        .i_data_b  (reg_b),
        .i_opcode  (reg_opcode)
    );

endmodule