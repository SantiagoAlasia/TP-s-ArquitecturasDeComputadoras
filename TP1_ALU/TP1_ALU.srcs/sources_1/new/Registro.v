module Registro
#(
    parameter NB = 8
)
(
    input  wire              clk,
    input  wire              i_enable,
    input  wire              i_reset,   
    input  wire [NB - 1 : 0] i_data,
    output reg  [NB - 1 : 0] o_data
);

    always @(posedge clk)
    begin
        if (i_reset)
            o_data <= {NB{1'b0}}
        if (i_enable)
            o_data <= i_data;
    end

endmodule