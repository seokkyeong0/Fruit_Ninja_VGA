`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/21 14:07:19
// Design Name: 
// Module Name: frame_buffer
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


module Frame_Buffer(
    // Write Side
    input logic        wclk,
    input logic        we,
    input logic [16:0] wAddr,
    input logic [15:0] wData,
    // Read Side
    input  logic        rclk,
    input  logic        oe,
    input  logic [16:0] rAddr,
    output logic [15:0] rData
);

    logic [15:0] mem [0:(320*240)-1];

    // Clock Domain이 다른 CDC 구간이 존재하기 때문에 frame buffer 사용
    // Write Side (OV7670 Clock Domain)
    always_ff @(posedge wclk) begin
        if (we) begin
            mem[wAddr] <= wData;
        end
    end

    // Read Side (FPGA Clock Domain)
    always_ff @(posedge rclk) begin
        if (oe) begin
            rData <= mem[rAddr];
        end
    end
endmodule
