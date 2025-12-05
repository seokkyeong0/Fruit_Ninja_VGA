`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/26 15:19:11
// Design Name: 
// Module Name: VGAReader
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


module VGAReader (
    input  logic                         clk,
    input  logic                         reset,
    input  logic                         DE,
    input  logic [                  9:0] x_pixel,
    input  logic [                  9:0] y_pixel,
    output logic [$clog2(320*240)-1 : 0] addr,
    input  logic [                 15:0] imgData,
    output logic [                  3:0] r_port,
    output logic [                  3:0] g_port,
    output logic [                  3:0] b_port
);

    // VGA (640x480) → QVGA (320x240) 좌표 변환
    logic [8:0] qvga_x;  // 0-319
    logic [8:0] qvga_y;  // 0-239
    
    assign qvga_x = x_pixel[9:1];  // x / 2
    assign qvga_y = y_pixel[9:1];  // y / 2

    // Pipeline Stage 1: 곱셈만 (MREG 활용)
    logic [16:0] mult_result;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            mult_result <= 17'd0;
        end else begin
            mult_result <= 320 * qvga_y;  // 곱셈 결과만 레지스터링
        end
    end
    
    // Pipeline Stage 2: 덧셈 (PREG 활용)
    logic [16:0] addr_calc;
    logic [8:0]  qvga_x_d1;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            addr_calc  <= 17'd0;
            qvga_x_d1  <= 9'd0;
        end else begin
            qvga_x_d1 <= qvga_x;                    // qvga_x도 1클럭 지연
            addr_calc <= mult_result + qvga_x_d1;   // 덧셈 결과 레지스터링
        end
    end
    
    // Enable 신호 파이프라인 (주소 계산과 동기화)
    logic img_display_en;
    logic img_display_en_d1;
    logic img_display_en_d2;
    logic img_display_en_d3;
    
    // VGA 영역 체크 (640x480 전체 영역에서 유효)
    assign img_display_en = DE && (x_pixel < 640) && (y_pixel < 480);
    
    always_ff @(posedge clk) begin
        if (reset) begin
            img_display_en_d1 <= 1'b0;
            img_display_en_d2 <= 1'b0;
            img_display_en_d3 <= 1'b0;
        end else begin
            img_display_en_d1 <= img_display_en;    // Stage 1
            img_display_en_d2 <= img_display_en_d1; // Stage 2
            img_display_en_d3 <= img_display_en_d2; // Stage 3 (Frame Buffer 지연)
        end
    end
    
    // 주소 출력
    assign addr = img_display_en_d2 ? addr_calc : 17'd0;
    
    // RGB 출력 (Frame Buffer 1클럭 지연 보상)
    always_ff @(posedge clk) begin
        if (reset) begin
            r_port <= 4'd0;
            g_port <= 4'd0;
            b_port <= 4'd0;
        end else if (img_display_en_d3) begin
            r_port <= imgData[15:12];
            g_port <= imgData[10:7];
            b_port <= imgData[4:1];
        end else begin
            r_port <= 4'd0;
            g_port <= 4'd0;
            b_port <= 4'd0;
        end
    end

endmodule