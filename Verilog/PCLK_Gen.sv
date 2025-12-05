`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/21 14:06:38
// Design Name: 
// Module Name: pclk_gen
// Project Name: 
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


module PCLK_Gen (
    input  logic clk,
    input  logic reset,
    output logic pclk
);

    logic [1:0] p_counter;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            p_counter <= 0;
        end else begin
            if (p_counter == 3) begin
                p_counter <= 0;
                pclk      <= 1'b1;
            end else begin
                p_counter <= p_counter + 1;
                pclk      <= 1'b0;
            end
        end
    end
endmodule