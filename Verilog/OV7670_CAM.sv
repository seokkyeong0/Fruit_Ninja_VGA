`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/21 14:48:50
// Design Name: 
// Module Name: OV7670_CAM
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
 
//////////////////////////////////////////////////////////////////////////////////
// OV7670_CAM with Fruit Ninja Game
// 
// 구성:
// - OV7670 카메라 입력
// - ISP 빨간색 감지 및 커서 트래킹
// - Fruit Ninja 게임 로직
// - VGA 출력
//////////////////////////////////////////////////////////////////////////////////

module OV7670_CAM(
    input  logic       clk,
    input  logic       reset,
    // Debuging
    input  logic       mode,
    // OV7670 Side
    output logic       xclk,
    input  logic       pclk,
    input  logic       href,
    input  logic       vsync,
    input  logic [7:0] data,
    // VGA Port
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] r_port,
    output logic [3:0] g_port,
    output logic [3:0] b_port,
    // SCCB Port
    output logic       SIO_C,
    inout  logic       SIO_D
);

    /////////////////////////////
    // SCCB Protocol
    /////////////////////////////

    logic sio_d_in;
    logic sio_d_out;
    logic sio_d_oe;

    IOBUF u_iobuf_sio_d (
        .I(sio_d_out),
        .O(sio_d_in),
        .IO(SIO_D),
        .T(~sio_d_oe)
    );

    SCCB_Master U_SCCB_Master(
        .clk(clk),
        .reset(reset),
        .SIO_C(SIO_C),
        .SIO_D_in(sio_d_in),
        .SIO_D_out(sio_d_out),
        .SIO_D_oe(sio_d_oe)
    );

    //////////////////////////////
    // System Clock Generator
    //////////////////////////////

    logic sys_clk;

    assign xclk = sys_clk;

    PCLK_Gen U_Pixel_Clk_Gen(
        .clk(clk),
        .reset(reset),
        .pclk(sys_clk)
    );

    /////////////////////////////
    // Reset Synchronizers
    /////////////////////////////
    
    logic reset_pclk_sync1, reset_pclk_sync2, reset_pclk;
    
    always_ff @(posedge pclk) begin
        if (reset) begin
            reset_pclk_sync1 <= 1'b1;
            reset_pclk_sync2 <= 1'b1;
        end else begin
            reset_pclk_sync1 <= 1'b0;
            reset_pclk_sync2 <= reset_pclk_sync1;
        end
    end
    
    always_ff @(posedge pclk) begin
        reset_pclk <= reset_pclk_sync2;
    end
    
    logic reset_sys_sync1, reset_sys_sync2, reset_sys;
    
    always_ff @(posedge sys_clk) begin
        if (reset) begin
            reset_sys_sync1 <= 1'b1;
            reset_sys_sync2 <= 1'b1;
        end else begin
            reset_sys_sync1 <= 1'b0;
            reset_sys_sync2 <= reset_sys_sync1;
        end
    end
    
    always_ff @(posedge sys_clk) begin
        reset_sys <= reset_sys_sync2;
    end

    //////////////////////////////
    // Pixel Coordinates & DE
    //////////////////////////////

    logic [9:0] x_pixel, y_pixel;
    logic DE;

    VGA_Syncher U_VGA_Syncher(
        .clk(sys_clk),
        .reset(reset_sys),
        .h_sync(h_sync),
        .v_sync(v_sync),
        .DE(DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel)
    );

    ////////////////////////////////////////
    // OV7670 Controller & Frame Buffer
    ////////////////////////////////////////

    logic [16:0] wAddr;
    logic [15:0] wData;
    logic [16:0] rAddr;
    logic [15:0] rData;
    logic write_en;

    OV7670_Mem_Controller U_OV7670_Mem_Controller(
        .clk(pclk),
        .reset(reset_pclk),
        .href(href),
        .vsync(vsync),
        .data(data),
        .we(write_en),
        .wAddr(wAddr),
        .wData(wData)
    );

    Frame_Buffer U_Frame_Buffer(
        .wclk(pclk),
        .we(write_en),
        .wAddr(wAddr),
        .wData(wData),
        .rclk(sys_clk),
        .oe(1'b1),
        .rAddr(rAddr),
        .rData(rData)
    );

    ///////////////////////////////////////
    // Camera to RGB444
    ///////////////////////////////////////

    logic [11:0] rgb444_camera;
    
    VGAReader U_VGAReader(
        .clk(sys_clk),
        .reset(reset_sys),
        .DE(DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .imgData(rData),
        .addr(rAddr),
        .r_port(rgb444_camera[11:8]),
        .g_port(rgb444_camera[7:4]),
        .b_port(rgb444_camera[3:0])
    );
    
    ///////////////////////////////////////
    // ISP Cursor Tracking
    ///////////////////////////////////////
    
    logic [11:0] cursor_pixel;
    logic [9:0] cursor_x;
    logic [9:0] cursor_y;
    logic cursor_active;
    logic cursor_visible;
    
    ISP_Cursor_Tracking U_ISP_Cursor_Tracking(
        .clk(sys_clk),
        .reset(reset_sys),
        .mode(mode),
        .vsync(v_sync),
        .de(DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .rgb444_in(rgb444_camera),
        .rgb444_out(cursor_pixel),
        .cursor_x(cursor_x),
        .cursor_y(cursor_y),
        .cursor_active(cursor_active),
        .cursor_visible(cursor_visible)
    );

    ///////////////////////////////////////
    // Background ROM (160x120 upscaled)
    ///////////////////////////////////////
    
    logic [11:0] background_pixel;
    
    Background_ImgROM U_Background_ImgROM(
        .clk(sys_clk),
        .reset(reset_sys),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .pixel_out(background_pixel)
    );
    
    // 배경 파이프라인 지연 (커서 렌더러와 동기화)
    logic [11:0] background_d1, background_d2;
    
    always_ff @(posedge sys_clk) begin
        background_d1 <= background_pixel;
        background_d2 <= background_d1;
    end

    ///////////////////////////////////////
    // Fruit Ninja Game
    ///////////////////////////////////////
    
    logic [11:0] game_pixel;
    logic game_active;
    
    Fruit_Ninja_Game U_Game(
        .clk(sys_clk),
        .reset(reset_sys),
        .vsync(v_sync),
        .de(DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .cursor_x(cursor_x),
        .cursor_y(cursor_y),
        .cursor_active(cursor_active),
        .background_pixel(background_d2),
        .pixel_out(game_pixel),
        .game_active(game_active)
    );

    ///////////////////////////////////////
    // Final Output Composition
    ///////////////////////////////////////
    
    // 우선순위:
    // 1. 커서 (cursor_visible)
    // 2. 게임 그래픽 (game_pixel)
    
    logic [11:0] final_pixel;
    
    always_comb begin
        if (cursor_visible)
            final_pixel = cursor_pixel;
        else begin
            if (mode) final_pixel = cursor_pixel;
            else final_pixel = game_pixel;
        end
    end
    
    assign r_port = final_pixel[11:8];
    assign g_port = final_pixel[7:4];
    assign b_port = final_pixel[3:0];

endmodule