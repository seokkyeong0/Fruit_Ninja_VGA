`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/27 12:33:38
// Design Name: 
// Module Name: ISP_Cursor_Tracking
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


module ISP_Cursor_Tracking (
    input  logic clk,
    input  logic reset,
    input  logic mode,
    input  logic vsync,
    input  logic de,
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    input  logic [11:0] rgb444_in,
    output logic [11:0] rgb444_out,
    output logic [9:0] cursor_x,
    output logic [9:0] cursor_y,
    output logic cursor_active,
    output logic cursor_visible
);

    // ===== Red Detection =====
    logic [9:0] blob_x;
    logic [9:0] blob_y;
    logic blob_valid;
    logic [11:0] red_debug;
    logic [9:0] blob_y_flip;

    assign blob_y_flip = 10'd479 - blob_y;  
    ISP_Red_Detection U_ISP_Red_Detection(
        .clk(clk),
        .reset(reset),
        .vsync(vsync),
        .de(de),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .rgb444_in(rgb444_in),
        .rgb444_out(red_debug),
        .blob_x(blob_x),
        .blob_y(blob_y),
        .blob_valid(blob_valid)
    );
    
    // ===== Cursor Controller =====
    logic [8:0] cursor_angle;
    
    Cursor_Controller U_Cursor_Controller(
        .clk(clk),
        .reset(reset),
        .target_x(blob_x),
        .target_y(blob_y_flip),
        .target_valid(blob_valid),
        .vsync(vsync),
        .cursor_x(cursor_x),
        .cursor_y(cursor_y),
        .cursor_angle(cursor_angle),
        .cursor_active(cursor_active)
    );
    
    // ===== Cursor Renderer =====
    logic [11:0] cursor_pixel;
    
    Cursor_Renderer U_Cursor_Renderer(
        .clk(clk),
        .reset(reset),
        .pixel_x(x_pixel),
        .pixel_y(y_pixel),
        .cursor_x(cursor_x),
        .cursor_y(cursor_y),
        .cursor_angle(cursor_angle),
        .cursor_active(cursor_active),
        .cursor_pixel(cursor_pixel),
        .cursor_visible(cursor_visible)
    );
    
    // 디버그 모드 선택
    // 0: 정상, 1: 빨강감지
    
    always_comb begin
        case (mode)
            1'b0: rgb444_out = cursor_pixel;
            1'b1: begin
                if (cursor_visible) rgb444_out = cursor_pixel;
                else rgb444_out = red_debug;
            end
        endcase
    end

endmodule

//=============================================================================
// Cursor Controller
//=============================================================================
module Cursor_Controller(
    input  logic clk,
    input  logic reset,
    input  logic [9:0] target_x,
    input  logic [9:0] target_y,
    input  logic target_valid,
    input  logic vsync,
    output logic [9:0] cursor_x,
    output logic [9:0] cursor_y,
    output logic [8:0] cursor_angle,
    output logic cursor_active
);

    localparam FRAC_BITS = 8;
    localparam FP_WIDTH = 10 + FRAC_BITS;
    
    logic [FP_WIDTH-1:0] cursor_x_fp;
    logic [FP_WIDTH-1:0] cursor_y_fp;
    
    // vsync edge detection
    logic vsync_d1, vsync_d2;
    logic vsync_rising;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            vsync_d1 <= 1'b1;
            vsync_d2 <= 1'b1;
        end else begin
            vsync_d1 <= vsync;
            vsync_d2 <= vsync_d1;
        end
    end
    assign vsync_rising = vsync_d1 & ~vsync_d2;
    
    // target 샘플링
    logic target_valid_sampled;
    logic [9:0] target_x_sampled;
    logic [9:0] target_y_sampled;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            target_valid_sampled <= 1'b0;
            target_x_sampled <= 10'd320;
            target_y_sampled <= 10'd240;
        end else if (vsync_rising) begin
            target_valid_sampled <= target_valid;
            target_x_sampled <= target_x;
            target_y_sampled <= target_y;
        end
    end
    
    // Tracking State
    localparam LOST_TIMEOUT = 3'd5;
    logic [2:0] lost_count;
    logic tracking_active_reg;
    logic first_detect;
    
    // Outlier Rejection
    logic [9:0] prev_target_x, prev_target_y;
    localparam MAX_JUMP = 11'd150;  // 빠른 움직임 허용 위해 증가
    logic target_valid_filtered;
    logic allow_jump;
    
    always_comb begin
        logic [10:0] dx, dy, jump_dist;
        dx = (target_x_sampled > prev_target_x) ? 
             (target_x_sampled - prev_target_x) : (prev_target_x - target_x_sampled);
        dy = (target_y_sampled > prev_target_y) ? 
             (target_y_sampled - prev_target_y) : (prev_target_y - target_y_sampled);
        jump_dist = dx + dy;
        
        allow_jump = first_detect || !tracking_active_reg;
        target_valid_filtered = target_valid_sampled && (allow_jump || (jump_dist <= MAX_JUMP));
    end
    
    // 통합된 상태 머신
    always_ff @(posedge clk) begin
        if (reset) begin
            tracking_active_reg <= 1'b0;
            lost_count <= 3'd0;
            first_detect <= 1'b1;
            prev_target_x <= 10'd320;
            prev_target_y <= 10'd240;
        end else if (vsync_rising) begin
            if (target_valid) begin
                tracking_active_reg <= 1'b1;
                lost_count <= 3'd0;
                
                if (!tracking_active_reg) begin
                    first_detect <= 1'b1;
                end else if (target_valid_filtered && first_detect) begin
                    first_detect <= 1'b0;
                end
            end else begin
                if (lost_count < LOST_TIMEOUT)
                    lost_count <= lost_count + 1'b1;
                else
                    tracking_active_reg <= 1'b0;
            end
            
            if (target_valid_filtered) begin
                prev_target_x <= target_x_sampled;
                prev_target_y <= target_y_sampled;
            end
        end
    end
    
    // Moving Average
    localparam MA_SIZE = 4;
    localparam MA_SHIFT = 2;
    
    logic [9:0] ma_buffer_x [0:MA_SIZE-1];
    logic [9:0] ma_buffer_y [0:MA_SIZE-1];
    logic [11:0] ma_sum_x, ma_sum_y;
    logic [9:0] ma_avg_x, ma_avg_y;
    logic [2:0] ma_count;
    logic ma_ready;
    
    always_comb begin
        ma_sum_x = 12'd0;
        ma_sum_y = 12'd0;
        for (int i = 0; i < MA_SIZE; i++) begin
            ma_sum_x = ma_sum_x + {2'b0, ma_buffer_x[i]};
            ma_sum_y = ma_sum_y + {2'b0, ma_buffer_y[i]};
        end
        ma_avg_x = ma_sum_x[11:MA_SHIFT];
        ma_avg_y = ma_sum_y[11:MA_SHIFT];
    end
    
    assign ma_ready = (ma_count >= MA_SIZE);
    
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < MA_SIZE; i++) begin
                ma_buffer_x[i] <= 10'd320;
                ma_buffer_y[i] <= 10'd240;
            end
            ma_count <= 3'd0;
        end else if (vsync_rising && target_valid_filtered) begin
            if (allow_jump) begin
                for (int i = 0; i < MA_SIZE; i++) begin
                    ma_buffer_x[i] <= target_x_sampled;
                    ma_buffer_y[i] <= target_y_sampled;
                end
                ma_count <= MA_SIZE;
            end else begin
                for (int i = MA_SIZE-1; i > 0; i--) begin
                    ma_buffer_x[i] <= ma_buffer_x[i-1];
                    ma_buffer_y[i] <= ma_buffer_y[i-1];
                end
                ma_buffer_x[0] <= target_x_sampled;
                ma_buffer_y[0] <= target_y_sampled;
                if (ma_count < MA_SIZE)
                    ma_count <= ma_count + 1'b1;
            end
        end
    end
    
    // Smooth Interpolation
    logic [FP_WIDTH-1:0] target_x_fp, target_y_fp;
    logic signed [FP_WIDTH:0] diff_x, diff_y;
    
    assign target_x_fp = {ma_avg_x, {FRAC_BITS{1'b0}}};
    assign target_y_fp = {ma_avg_y, {FRAC_BITS{1'b0}}};
    
    always_comb begin
        diff_x = $signed({1'b0, target_x_fp}) - $signed({1'b0, cursor_x_fp});
        diff_y = $signed({1'b0, target_y_fp}) - $signed({1'b0, cursor_y_fp});
    end
    
    // ===== 세밀한 Adaptive Alpha =====
    // 거리에 따라 16단계로 세분화
    // 느린 움직임: 부드럽게 (alpha 낮음)
    // 빠른 움직임: 즉시 따라감 (alpha 높음)
    logic [7:0] alpha;
    logic [10:0] distance;
    
    always_comb begin
        logic [10:0] abs_dx, abs_dy;
        abs_dx = diff_x[FP_WIDTH] ? (-diff_x[FP_WIDTH-1:FRAC_BITS]) : diff_x[FP_WIDTH-1:FRAC_BITS];
        abs_dy = diff_y[FP_WIDTH] ? (-diff_y[FP_WIDTH-1:FRAC_BITS]) : diff_y[FP_WIDTH-1:FRAC_BITS];
        distance = abs_dx + abs_dy;
        
        // ===== 16단계 Alpha 테이블 =====
        // 
        // 거리(픽셀)  |  alpha  |  실제 비율  |  특성
        // -----------|---------|------------|------------------
        // > 300      |  255    |  100%      |  즉시 점프
        // > 200      |  250    |  98%       |  거의 즉시
        // > 150      |  230    |  90%       |  매우 빠름
        // > 120      |  200    |  78%       |  빠름
        // > 100      |  170    |  66%       |  빠름
        // > 80       |  140    |  55%       |  중간-빠름
        // > 60       |  115    |  45%       |  중간
        // > 45       |  90     |  35%       |  중간
        // > 35       |  70     |  27%       |  중간-느림
        // > 25       |  55     |  21%       |  느림
        // > 18       |  42     |  16%       |  느림
        // > 12       |  32     |  12%       |  부드러움
        // > 8        |  24     |  9%        |  부드러움
        // > 4        |  16     |  6%        |  매우 부드러움
        // > 2        |  10     |  4%        |  매우 부드러움
        // <= 2       |  6      |  2%        |  거의 정지 (미세 조정)
        
        if (distance > 300)
            alpha = 8'd255;     // 즉시 점프 (빠른 스와이프)
        else if (distance > 200)
            alpha = 8'd250;     // 거의 즉시
        else if (distance > 150)
            alpha = 8'd230;     // 매우 빠름
        else if (distance > 120)
            alpha = 8'd200;     // 빠름
        else if (distance > 100)
            alpha = 8'd170;     // 빠름
        else if (distance > 80)
            alpha = 8'd140;     // 중간-빠름
        else if (distance > 60)
            alpha = 8'd115;     // 중간
        else if (distance > 45)
            alpha = 8'd90;      // 중간
        else if (distance > 35)
            alpha = 8'd70;      // 중간-느림
        else if (distance > 25)
            alpha = 8'd55;      // 느림
        else if (distance > 18)
            alpha = 8'd42;      // 느림
        else if (distance > 12)
            alpha = 8'd32;      // 부드러움
        else if (distance > 8)
            alpha = 8'd24;      // 부드러움
        else if (distance > 4)
            alpha = 8'd16;      // 매우 부드러움
        else if (distance > 2)
            alpha = 8'd10;      // 매우 부드러움
        else
            alpha = 8'd6;       // 거의 정지 (미세 조정)
    end
    
    logic signed [FP_WIDTH+8:0] step_x, step_y;
    assign step_x = (diff_x * $signed({1'b0, alpha})) >>> 8;
    assign step_y = (diff_y * $signed({1'b0, alpha})) >>> 8;
    
    // 커서 위치 업데이트
    always_ff @(posedge clk) begin
        if (reset) begin
            cursor_x_fp <= {10'd320, {FRAC_BITS{1'b0}}};
            cursor_y_fp <= {10'd240, {FRAC_BITS{1'b0}}};
        end else if (tracking_active_reg) begin
            if (first_detect && target_valid_filtered) begin
                // 첫 감지: 즉시 위치로 점프
                cursor_x_fp <= target_x_fp;
                cursor_y_fp <= target_y_fp;
            end else if (ma_ready) begin
                logic signed [FP_WIDTH+1:0] new_x, new_y;
                new_x = $signed({2'b0, cursor_x_fp}) + step_x[FP_WIDTH:0];
                new_y = $signed({2'b0, cursor_y_fp}) + step_y[FP_WIDTH:0];
                
                // X 클램핑
                if (new_x < 0)
                    cursor_x_fp <= 0;
                else if (new_x > {10'd639, {FRAC_BITS{1'b0}}})
                    cursor_x_fp <= {10'd639, {FRAC_BITS{1'b0}}};
                else
                    cursor_x_fp <= new_x[FP_WIDTH-1:0];
                
                // Y 클램핑
                if (new_y < 0)
                    cursor_y_fp <= 0;
                else if (new_y > {10'd479, {FRAC_BITS{1'b0}}})
                    cursor_y_fp <= {10'd479, {FRAC_BITS{1'b0}}};
                else
                    cursor_y_fp <= new_y[FP_WIDTH-1:0];
            end
        end
    end
    
    assign cursor_active = tracking_active_reg;
    assign cursor_x = cursor_x_fp[FP_WIDTH-1:FRAC_BITS];
    assign cursor_y = cursor_y_fp[FP_WIDTH-1:FRAC_BITS];
    
    // ===== Angle Calculation =====
    logic [9:0] prev_cursor_x, prev_cursor_y;
    logic signed [10:0] vel_x, vel_y;
    localparam signed [10:0] VEL_THRESH = 11'sd2;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            cursor_angle <= 9'd0;
            prev_cursor_x <= 10'd320;
            prev_cursor_y <= 10'd240;
        end else if (vsync_rising && cursor_active) begin
            vel_x <= $signed({1'b0, cursor_x}) - $signed({1'b0, prev_cursor_x});
            vel_y <= $signed({1'b0, cursor_y}) - $signed({1'b0, prev_cursor_y});
            
            prev_cursor_x <= cursor_x;
            prev_cursor_y <= cursor_y;
            
            // 8방향 각도
            if (vel_x > VEL_THRESH && vel_y >= -VEL_THRESH && vel_y <= VEL_THRESH)
                cursor_angle <= 9'd0;       // →
            else if (vel_x > VEL_THRESH && vel_y < -VEL_THRESH)
                cursor_angle <= 9'd32;      // ↗
            else if (vel_x >= -VEL_THRESH && vel_x <= VEL_THRESH && vel_y < -VEL_THRESH)
                cursor_angle <= 9'd64;      // ↑
            else if (vel_x < -VEL_THRESH && vel_y < -VEL_THRESH)
                cursor_angle <= 9'd96;      // ↖
            else if (vel_x < -VEL_THRESH && vel_y >= -VEL_THRESH && vel_y <= VEL_THRESH)
                cursor_angle <= 9'd128;     // ←
            else if (vel_x < -VEL_THRESH && vel_y > VEL_THRESH)
                cursor_angle <= 9'd160;     // ↙
            else if (vel_x >= -VEL_THRESH && vel_x <= VEL_THRESH && vel_y > VEL_THRESH)
                cursor_angle <= 9'd192;     // ↓
            else if (vel_x > VEL_THRESH && vel_y > VEL_THRESH)
                cursor_angle <= 9'd224;     // ↘
        end
    end

endmodule

//=============================================================================
// Sword Sprite ROM
//=============================================================================
module Sword_Sprite_ROM(
    input  logic clk,
    input  logic [5:0] sprite_x,
    input  logic [5:0] sprite_y,
    input  logic [8:0] rotation,
    output logic [11:0] pixel_data,
    output logic pixel_alpha
);

    logic [15:0] sprite_rom [0:4095];
    
    initial begin
        $readmemh("sword_sprite.mem", sprite_rom);
    end
    
    logic [11:0] addr;
    assign addr = {sprite_y, sprite_x};
    
    logic [15:0] rom_data;
    always_ff @(posedge clk) begin
        rom_data <= sprite_rom[addr];
    end
    
    logic [11:0] rgb444;
    logic is_transparent;
    
    assign rgb444 = {rom_data[15:12], rom_data[10:7], rom_data[4:1]};
    assign is_transparent = (rom_data == 16'hffff) ||
                            ((rom_data[15:11] > 5'd28) && 
                             (rom_data[10:5] > 6'd56) && 
                             (rom_data[4:0] > 5'd28));
    
    assign pixel_data = rgb444;
    assign pixel_alpha = ~is_transparent;
    

endmodule

//=============================================================================
// Cursor Renderer
//=============================================================================
module Cursor_Renderer(
    input  logic clk,
    input  logic reset,
    input  logic [9:0] pixel_x,
    input  logic [9:0] pixel_y,
    input  logic [9:0] cursor_x,
    input  logic [9:0] cursor_y,
    input  logic [8:0] cursor_angle,
    input  logic cursor_active,
    output logic [11:0] cursor_pixel,
    output logic cursor_visible
);

    localparam SPRITE_SIZE = 64;
    localparam HALF_SIZE = 32;
    
    logic signed [11:0] rel_x, rel_y;
    logic in_sprite_area;
    logic [5:0] sprite_x, sprite_y;
    
    always_comb begin
        rel_x = $signed({2'b0, pixel_x}) - $signed({2'b0, cursor_x}) + HALF_SIZE;
        rel_y = $signed({2'b0, pixel_y}) - $signed({2'b0, cursor_y}) + HALF_SIZE;
        
        in_sprite_area = (rel_x >= 0) && (rel_x < SPRITE_SIZE) && 
                         (rel_y >= 0) && (rel_y < SPRITE_SIZE);
        
        sprite_x = in_sprite_area ? rel_x[5:0] : 6'd0;
        sprite_y = in_sprite_area ? rel_y[5:0] : 6'd0;
    end
    
    logic [11:0] sprite_data;
    logic sprite_alpha;
    
    Sword_Sprite_ROM U_ROM(
        .clk(clk),
        .sprite_x(sprite_x),
        .sprite_y(sprite_y),
        .rotation(cursor_angle),
        .pixel_data(sprite_data),
        .pixel_alpha(sprite_alpha)
    );
    
    logic in_sprite_area_d1, in_sprite_area_d2;
    logic cursor_active_d1, cursor_active_d2;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            in_sprite_area_d1 <= 1'b0;
            in_sprite_area_d2 <= 1'b0;
            cursor_active_d1 <= 1'b0;
            cursor_active_d2 <= 1'b0;
        end else begin
            in_sprite_area_d1 <= in_sprite_area;
            in_sprite_area_d2 <= in_sprite_area_d1;
            cursor_active_d1 <= cursor_active;
            cursor_active_d2 <= cursor_active_d1;
        end
    end
    
    always_comb begin
        if (cursor_active_d2 && in_sprite_area_d2 && sprite_alpha) begin
            cursor_pixel = sprite_data;
            cursor_visible = 1'b1;
        end else begin
            cursor_pixel = 12'd0;
            cursor_visible = 1'b0;
        end
    end

endmodule