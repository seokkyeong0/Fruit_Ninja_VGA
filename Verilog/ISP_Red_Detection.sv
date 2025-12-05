`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/27 12:29:55
// Design Name: 
// Module Name: ISP_Red_Detection
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


module ISP_Red_Detection(
    input  logic clk,
    input  logic reset,
    input  logic vsync,
    input  logic de,
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    input  logic [11:0] rgb444_in,
    output logic [11:0] rgb444_out,
    output logic [9:0] blob_x,
    output logic [9:0] blob_y,
    output logic blob_valid
);

    // Line Buffer signals
    logic [11:0] line0, line1, line2;
    logic [9:0] x_buf;
    logic window_valid;
    
    Line_Buffer #(
        .WIDTH(640),
        .DEPTH(3)
    ) U_Line_Buffer (
        .clk(clk),
        .reset(reset),
        .de(de),
        .pixel_in(rgb444_in),
        .x_pixel(x_pixel),
        .line0(line0),
        .line1(line1),
        .line2(line2),
        .x_out(x_buf),
        .window_valid(window_valid)
    );
    
    // RGB to HSV
    logic [7:0] hue, sat, val;
    logic hsv_valid;
    
    RGB_to_HSV U_RGB_to_HSV(
        .clk(clk),
        .reset(reset),
        .valid_in(window_valid),
        .rgb444(line1),
        .valid_out(hsv_valid),
        .hue(hue),
        .sat(sat),
        .val(val)
    );
    
    // Red Color Filter
    logic red_detected;
    logic red_valid;
    
    Red_Color_Filter U_Red_Filter(
        .clk(clk),
        .reset(reset),
        .valid_in(hsv_valid),
        .hue(hue),
        .sat(sat),
        .val(val),
        .valid_out(red_valid),
        .red_detected(red_detected)
    );
    
    // 3x3 window for morphological filter
    logic [2:0][2:0] morph_window;
    logic [2:0] window_shift [0:2];
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            window_shift[0] <= 3'b0;
            window_shift[1] <= 3'b0;
            window_shift[2] <= 3'b0;
        end else if (red_valid) begin
            window_shift[0] <= {window_shift[0][1:0], red_detected};
            window_shift[1] <= window_shift[0];
            window_shift[2] <= window_shift[1];
        end
    end
    
    assign morph_window[0] = window_shift[2];
    assign morph_window[1] = window_shift[1];
    assign morph_window[2] = window_shift[0];
    
    // Morphological Filter
    logic filtered;
    logic filter_valid;

    assign rgb444_out = (filter_valid && filtered && blob_valid) ? 12'hF00 : 12'h000;
    
    Morphological_Filter U_Morph_Filter(
        .clk(clk),
        .reset(reset),
        .valid_in(red_valid),
        .window(morph_window),
        .valid_out(filter_valid),
        .filtered(filtered)
    );
    
    // Blob Detector
    Blob_Detector U_Blob_Detector(
        .clk(clk),
        .reset(reset),
        .vsync(vsync),
        .de(filter_valid),
        .red_pixel(filtered),
        .x_pos(x_buf),
        .y_pos(y_pixel),
        .blob_x(blob_x),
        .blob_y(blob_y),
        .blob_valid(blob_valid)
    );

endmodule

//=============================================================================
// Line Buffer - 3라인 버퍼
//=============================================================================
module Line_Buffer #(
    parameter WIDTH = 640,
    parameter DEPTH = 3
)(
    input  logic clk,
    input  logic reset,
    input  logic de,
    input  logic [11:0] pixel_in,
    input  logic [9:0] x_pixel,
    output logic [11:0] line0,    // 현재 라인
    output logic [11:0] line1,    // 1라인 전
    output logic [11:0] line2,    // 2라인 전
    output logic [9:0] x_out,
    output logic window_valid
);

    // 라인 버퍼 메모리
    logic [11:0] buffer0 [0:WIDTH-1];
    logic [11:0] buffer1 [0:WIDTH-1];
    
    // 읽기 주소 (2클럭 지연)
    logic [9:0] rd_addr;
    logic [9:0] x_d1, x_d2;
    logic de_d1, de_d2;
    
    // 쓰기 및 읽기
    always_ff @(posedge clk) begin
        if (reset) begin
            x_d1 <= 10'd0;
            x_d2 <= 10'd0;
            de_d1 <= 1'b0;
            de_d2 <= 1'b0;
        end else begin
            // 지연 파이프라인
            x_d1 <= x_pixel;
            x_d2 <= x_d1;
            de_d1 <= de;
            de_d2 <= de_d1;
            
            // 쓰기 (현재 픽셀)
            if (de) begin
                buffer1[x_pixel] <= buffer0[x_pixel];  // line0 → line1
                buffer0[x_pixel] <= pixel_in;          // 새 픽셀 → line0
            end
        end
    end
    
    // 읽기 (2클럭 후)
    logic [11:0] buf0_rd, buf1_rd;
    logic [11:0] pixel_d1, pixel_d2;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            buf0_rd <= 12'd0;
            buf1_rd <= 12'd0;
            pixel_d1 <= 12'd0;
            pixel_d2 <= 12'd0;
        end else begin
            buf0_rd <= buffer0[x_pixel];
            buf1_rd <= buffer1[x_pixel];
            pixel_d1 <= pixel_in;
            pixel_d2 <= pixel_d1;
        end
    end
    
    // 출력 할당
    assign line0 = pixel_d2;   // 현재 라인 (2클럭 지연된 입력)
    assign line1 = buf0_rd;    // 1라인 전
    assign line2 = buf1_rd;    // 2라인 전
    assign x_out = x_d2;
    assign window_valid = de_d2 && (x_d2 >= 10'd1) && (x_d2 < WIDTH-1);

endmodule

module RGB_to_HSV(
    input  logic clk,
    input  logic reset,
    input  logic valid_in,
    input  logic [11:0] rgb444,  // R[11:8], G[7:4], B[3:0]
    output logic valid_out,
    output logic [7:0] hue,      // 0-179 (OpenCV 스타일)
    output logic [7:0] sat,      // 0-255
    output logic [7:0] val       // 0-255
);

    // RGB444 추출 및 8비트로 확장
    logic [7:0] r8, g8, b8;
    assign r8 = {rgb444[11:8], rgb444[11:8]};  // 4비트 -> 8비트 (복제)
    assign g8 = {rgb444[7:4], rgb444[7:4]};    // 4비트 -> 8비트 (복제)
    assign b8 = {rgb444[3:0], rgb444[3:0]};    // 4비트 -> 8비트 (복제)

    // Stage 1: Min, Max 찾기 및 Delta 계산 (통합)
    logic [7:0] max_val, min_val;
    logic [7:0] delta;
    logic [7:0] r_d1, g_d1, b_d1;
    logic [7:0] max_d1, min_d1;  // 파이프라인용
    logic valid_d1, valid_d2;
    
    // **단일 always_ff 블록으로 통합**
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            max_val <= 8'd0;
            min_val <= 8'd0;
            max_d1 <= 8'd0;
            min_d1 <= 8'd0;
            delta <= 8'd0;
            r_d1 <= 8'd0;
            g_d1 <= 8'd0;
            b_d1 <= 8'd0;
            valid_d1 <= 1'b0;
            valid_d2 <= 1'b0;
        end else begin
            // Pipeline stage 1
            valid_d1 <= valid_in;
            r_d1 <= r8;
            g_d1 <= g8;
            b_d1 <= b8;
            
            // Max 계산
            if (r8 >= g8 && r8 >= b8)
                max_val <= r8;
            else if (g8 >= r8 && g8 >= b8)
                max_val <= g8;
            else
                max_val <= b8;
            
            // Min 계산
            if (r8 <= g8 && r8 <= b8)
                min_val <= r8;
            else if (g8 <= r8 && g8 <= b8)
                min_val <= g8;
            else
                min_val <= b8;
            
            // Pipeline stage 2
            valid_d2 <= valid_d1;
            max_d1 <= max_val;
            min_d1 <= min_val;
            delta <= max_val - min_val;
        end
    end

    // Stage 2: HSV 계산
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            hue <= 8'd0;
            sat <= 8'd0;
            val <= 8'd0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= valid_d2;
            
            // Value = Max
            val <= max_d1;
            
            // Saturation
            if (max_d1 == 8'd0)
                sat <= 8'd0;
            else
                sat <= (delta * 255) / max_d1;  // 간단한 근사
            
            // Hue 계산 (간소화 버전)
            if (delta == 8'd0) begin
                hue <= 8'd0;  // Undefined, 0으로 설정
            end else begin
                // Max 채널 결정
                if (max_d1 == r_d1) begin
                    // Red is max: Hue = 0-60 (between magenta and yellow)
                    if (g_d1 >= b_d1)
                        hue <= ((g_d1 - b_d1) * 30) / delta;  // 0-30
                    else
                        hue <= 180 - (((b_d1 - g_d1) * 30) / delta);  // 150-180
                end else if (max_d1 == g_d1) begin
                    // Green is max: Hue = 60-120
                    hue <= 60 + (((b_d1 - r_d1) * 30) / delta);
                end else begin
                    // Blue is max: Hue = 120-180
                    hue <= 120 + (((r_d1 - g_d1) * 30) / delta);
                end
            end
        end
    end

endmodule

module Red_Color_Filter(
    input  logic clk,
    input  logic reset,
    input  logic valid_in,
    input  logic [7:0] hue,
    input  logic [7:0] sat,
    input  logic [7:0] val,
    output logic valid_out,
    output logic red_detected
);

    // 약간 완화된 파라미터 (검출률 향상)
    localparam HUE_LOW_MIN  = 8'd0;
    localparam HUE_LOW_MAX  = 8'd6;     // 8 → 12 (약간 넓힘)
    localparam HUE_HIGH_MIN = 8'd170;    // 172 → 168 (약간 넓힘)
    localparam HUE_HIGH_MAX = 8'd180;
    
    localparam SAT_MIN      = 8'd150;    // 150 → 120 (약간 완화)
    localparam SAT_MAX      = 8'd255;
    
    localparam VAL_MIN      = 8'd120;     // 80 → 60 (약간 완화)
    localparam VAL_MAX      = 8'd255;    // 240 → 250 (약간 완화)
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            red_detected <= 1'b0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= valid_in;
            
            if (valid_in && 
                sat >= SAT_MIN && sat <= SAT_MAX &&
                val >= VAL_MIN && val <= VAL_MAX) begin
                
                if ((hue >= HUE_LOW_MIN && hue <= HUE_LOW_MAX) ||
                    (hue >= HUE_HIGH_MIN && hue <= HUE_HIGH_MAX)) begin
                    red_detected <= 1'b1;
                end else begin
                    red_detected <= 1'b0;
                end
            end else begin
                red_detected <= 1'b0;
            end
        end
    end

endmodule

module Morphological_Filter(
    input  logic clk,
    input  logic reset,
    input  logic valid_in,
    input  logic [2:0][2:0] window,
    output logic valid_out,
    output logic filtered
);

    // 간단한 Opening만 사용 (Erosion → Dilation)
    // Closing 제거하여 더 많은 영역 통과
    
    // Stage 1: 약한 Erosion
    logic eroded;
    logic valid_d1;
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            eroded <= 1'b0;
            valid_d1 <= 1'b0;
        end else begin
            valid_d1 <= valid_in;
            // 9개 중 4개 이상이면 통과 (6 → 4로 완화)
            eroded <= (window[0][0] + window[0][1] + window[0][2] +
                      window[1][0] + window[1][1] + window[1][2] +
                      window[2][0] + window[2][1] + window[2][2]) >= 4'd4;
        end
    end

    // Stage 2: Erosion window
    logic [2:0][2:0] eroded_window;
    logic valid_d2;
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            eroded_window <= '0;
            valid_d2 <= 1'b0;
        end else begin
            valid_d2 <= valid_d1;
            eroded_window[0] <= eroded_window[1];
            eroded_window[1] <= eroded_window[2];
            eroded_window[2] <= {eroded_window[2][1:0], eroded};
        end
    end

    // Stage 3: Dilation (더 관대하게)
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            filtered <= 1'b0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= valid_d2;
            // 하나라도 있으면 통과
            filtered <= |eroded_window[0] | |eroded_window[1] | |eroded_window[2];
        end
    end

endmodule

module Blob_Detector(
    input  logic clk,
    input  logic reset,
    input  logic vsync,
    input  logic de,
    input  logic red_pixel,
    input  logic [9:0] x_pos,
    input  logic [9:0] y_pos,
    output logic [9:0] blob_x,
    output logic [9:0] blob_y,
    output logic blob_valid
);

    // 현재 blob 추적
    logic [19:0] current_sum_x;
    logic [19:0] current_sum_y;
    logic [18:0] current_count;
    
    // 가장 큰 blob 저장
    logic [19:0] largest_sum_x;
    logic [19:0] largest_sum_y;
    logic [18:0] largest_count;
    
    // 이전 픽셀 상태
    logic red_pixel_d1;
    logic [9:0] x_pos_d1, y_pos_d1;
    
    logic vsync_d1, vsync_d2;
    logic vsync_falling;
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            vsync_d1 <= 1'b0;
            vsync_d2 <= 1'b0;
        end else begin
            vsync_d1 <= vsync;
            vsync_d2 <= vsync_d1;
        end
    end
    
    assign vsync_falling = vsync_d2 & ~vsync_d1;
    
    // Blob Boundary Detection
    logic new_blob;
    always_comb begin
        if (red_pixel && !red_pixel_d1) begin
            new_blob = 1'b1;
        end else if (red_pixel && red_pixel_d1) begin
            new_blob = (x_pos > x_pos_d1 + 10'd20);
        end else begin
            new_blob = 1'b0;
        end
    end
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            current_sum_x <= 20'd0;
            current_sum_y <= 20'd0;
            current_count <= 19'd0;
            largest_sum_x <= 20'd0;
            largest_sum_y <= 20'd0;
            largest_count <= 19'd0;
            red_pixel_d1 <= 1'b0;
            x_pos_d1 <= 10'd0;
            y_pos_d1 <= 10'd0;
        end else if (vsync_falling) begin
            if (current_count > largest_count) begin
                largest_sum_x <= current_sum_x;
                largest_sum_y <= current_sum_y;
                largest_count <= current_count;
            end
            
            current_sum_x <= 20'd0;
            current_sum_y <= 20'd0;
            current_count <= 19'd0;
            largest_sum_x <= 20'd0;
            largest_sum_y <= 20'd0;
            largest_count <= 19'd0;
            
        end else if (de) begin
            red_pixel_d1 <= red_pixel;
            x_pos_d1 <= x_pos;
            y_pos_d1 <= y_pos;
            
            if (red_pixel) begin
                if (new_blob) begin
                    if (current_count > largest_count) begin
                        largest_sum_x <= current_sum_x;
                        largest_sum_y <= current_sum_y;
                        largest_count <= current_count;
                    end
                    
                    current_sum_x <= x_pos;
                    current_sum_y <= y_pos;
                    current_count <= 19'd1;
                end else begin
                    current_sum_x <= current_sum_x + x_pos;
                    current_sum_y <= current_sum_y + y_pos;
                    current_count <= current_count + 1'b1;
                end
            end

        end
    end
    
    // Centroid Calculation 
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            blob_x <= 10'd320;
            blob_y <= 10'd240;
            blob_valid <= 1'b0;
        end else if (vsync_falling) begin
            if (largest_count > 19'd20) begin
                blob_x <= largest_sum_x / largest_count;
                blob_y <= largest_sum_y / largest_count;
                blob_valid <= 1'b1;
            end else begin
                blob_valid <= 1'b0;
            end
        end
    end

endmodule