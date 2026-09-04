`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UNC
// Engineer: 
// 
// Create Date: 08/27/2026 07:31:38 PM
// Design Name: 
// Module Name: Registros
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


module Registros
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
    input  wire [NB_DATA - 1 : 0]      i_alu_result, // Resultado que sale de la ALU
    
    output reg [NB_DATA - 1 : 0]      o_reg_a,
    output reg [NB_DATA - 1 : 0]      o_reg_b,
    output reg [NB_OP - 1 : 0]        o_reg_opcode,
    output reg [NB_DATA - 1 : 0]      o_reg_result
    
);

    // Reg A
    always @(posedge clk)
    begin
        if(i_load_1 == 1)
            o_reg_a <= i_switches;
    end

    // Reg B
    always @(posedge clk)
    begin
        if(i_load_2 == 1)
            o_reg_b <= i_switches;
    end

    // Reg Opcode
    reg load_3_dly; // Señal load_3 retardada medio ciclo de clock
    
    always @(posedge clk)
    begin
        load_3_dly <= i_load_3;
        
        if(i_load_3 == 1)
            o_reg_opcode <= i_switches[NB_OP - 1 : 0];
    end
    
    // Reg Salida
    always @(posedge clk)
    begin
        if(load_3_dly == 1)
            o_reg_result <= i_alu_result;
    end
endmodule
