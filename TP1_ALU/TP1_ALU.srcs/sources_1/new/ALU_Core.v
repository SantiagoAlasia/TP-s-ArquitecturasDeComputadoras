`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UNC
// Engineer: 
// 
// Create Date: 08/27/2026 07:31:38 PM
// Design Name: 
// Module Name: ALU_Core
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

module ALU_Core 
#(
    parameter NB_DATA = 8,
    parameter NB_OP   = 6 
)
(
    output wire [NB_DATA - 1 : 0] o_result,
    
    input wire [NB_DATA - 1 : 0] i_data_a, // dato A
    input wire [NB_DATA - 1 : 0] i_data_b, // dato B
    input wire [NB_OP   - 1 : 0] i_opcode  // Operacion
);
    
    localparam [NB_OP - 1 : 0] ADD = 6'b100000;
    localparam [NB_OP - 1 : 0] SUB = 6'b100010;
    localparam [NB_OP - 1 : 0] AND = 6'b100100;
    localparam [NB_OP - 1 : 0] OR  = 6'b100101;
    localparam [NB_OP - 1 : 0] XOR = 6'b100110;
    localparam [NB_OP - 1 : 0] SRA = 6'b000011;
    localparam [NB_OP - 1 : 0] SRL = 6'b000010;
    localparam [NB_OP - 1 : 0] NOR = 6'b100111;
  
    reg [NB_DATA - 1 : 0] res;
  
    always @(*)
    begin
        case(i_opcode)
            ADD : res = i_data_a + i_data_b;
            SUB : res = i_data_a - i_data_b;
            AND : res = i_data_a & i_data_b;
            OR  : res = i_data_a | i_data_b;
            XOR : res = i_data_a ^ i_data_b;
            SRA : res = $signed(i_data_a) >>> i_data_b;
            SRL : res = i_data_a >> i_data_b;
            NOR : res = ~(i_data_a | i_data_b);
            default : res = {NB_DATA{1'b0}};
        endcase
    end
  
    assign o_result = res;
  
endmodule