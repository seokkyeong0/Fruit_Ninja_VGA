`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/21 14:15:52
// Design Name: 
// Module Name: OV7670_Mem_Controller
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


module OV7670_Mem_Controller(
    input  logic       clk,
    input  logic       reset,
    // OV7670 Side
    input  logic       href,
    input  logic       vsync,
    input  logic [7:0] data,
    // Memory Side
    output logic        we,
    output logic [16:0] wAddr,
    output logic [15:0] wData
);

    logic [17:0] pixelCounter;
    logic [15:0] pixelData;
    logic        vsync_prev;
    logic        we_prev;
    wire         vsync_falling = vsync_prev & ~vsync;

    assign wData = pixelData;

    always_ff @(posedge clk) begin
        if (reset) begin
            pixelCounter <= 0;
            pixelData    <= 0;
            we           <= 1'b0;
            we_prev      <= 1'b0;
            wAddr        <= 0;
            vsync_prev   <= 0;
        end else begin
            vsync_prev <= vsync;
            we_prev    <= we;
            
            if (we_prev) begin
                wAddr <= wAddr + 1;
            end
            
            if (vsync_falling) begin
                wAddr        <= 0;
                pixelCounter <= 0;
                we           <= 1'b0;
            end
            else if (href) begin
                if (pixelCounter[0] == 1'b0) begin
                    we              <= 1'b0;
                    pixelData[15:8] <= data;
                end else begin
                    we             <= 1'b1;
                    pixelData[7:0] <= data;
                end
                pixelCounter <= pixelCounter + 1;
            end 
            else begin
                we <= 1'b0;
            end
        end
    end
endmodule
