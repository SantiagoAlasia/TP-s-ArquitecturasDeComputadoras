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
    input  wire                        clk,          // Señal de clock para los registros
    input  wire                        i_load_1,     // Señal para cargar A
    input  wire                        i_load_2,     // Señal para cargar B
    input  wire                        i_load_3,     // Señal para cargar opcode y disparar resultado
    
    output wire [NB_DATA - 1 : 0]      o_leds
);
    wire [NB_DATA - 1 : 0] alu_result;
    wire [NB_DATA - 1 : 0] reg_result;
    wire [NB_DATA - 1 : 0] reg_a;
    wire [NB_DATA - 1 : 0] reg_b;
    wire [NB_OP - 1 : 0]   reg_opcode;
    
    // Instancia del modulo Registros
    Registros #(
        .NB_DATA (NB_DATA),
        .NB_OP   (NB_OP)
    ) registros_inst(
        .i_switches     (i_switches),
        .clk            (clk),
        .i_load_1       (i_load_1),    
        .i_load_2       (i_load_2),     
        .i_load_3       (i_load_3),     
        .i_alu_result   (alu_result),
    
        .o_reg_a        (reg_a),
        .o_reg_b        (reg_b),
        .o_reg_opcode   (reg_opcode),
        .o_reg_result   (reg_result)
    );

    // Instancia del modulo ALU_Core
    ALU_Core #(
        .NB_DATA (NB_DATA),
        .NB_OP   (NB_OP)
    ) alu_core_inst (
        .o_result  (alu_result),
        
        .i_data_a  (reg_a),
        .i_data_b  (reg_b),
        .i_opcode  (reg_opcode)
    );

    assign o_leds = reg_result;

endmodule