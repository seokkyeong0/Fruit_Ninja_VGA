`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/28 17:02:16
// Design Name: 
// Module Name: Background_ImgROM
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


module Background_ImgROM (
    input  logic clk,
    input  logic reset,
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    output logic [11:0] pixel_out
);

    (* ram_style = "block" *) logic [15:0] bg_rom [0:19199];
    
    initial begin
        $readmemh("ninja_bg.mem", bg_rom);
    end
    
    logic [7:0] x_rom;
    logic [6:0] y_rom;
    logic [14:0] addr;
    
    assign x_rom = x_pixel[9:2];
    assign y_rom = y_pixel[9:2];
    assign addr = y_rom * 8'd160 + x_rom;
    
    always_ff @(posedge clk) begin
        if (reset)
            pixel_out <= 12'd0;
        else
            pixel_out <= {bg_rom[addr][15:12], bg_rom[addr][10:7], bg_rom[addr][4:1]};
    end

endmodule
