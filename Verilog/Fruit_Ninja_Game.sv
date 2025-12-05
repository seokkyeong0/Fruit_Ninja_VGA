`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Fruit Ninja Style Game - Fixed Version (Separated Modules)
// 
// 수정 사항:
// 1. 과일 베면 다음 과일 안나오는 버그 수정
// 2. 게임오버 후 재시작 시 초기화 문제 수정
// 3. 업스케일 크기 80x80으로 변경
// 4. 과일 속도 증가 및 다양한 각도
// 5. 나타나자마자 놓침 판정 방지
// 6. FRUIT NINJA 이미지 2배 크기로 중앙 정렬
// 7. GAME OVER 텍스트 추가
//////////////////////////////////////////////////////////////////////////////////
 
module Fruit_Ninja_Game (
    input  logic clk,
    input  logic reset,
    input  logic vsync,
    input  logic de,
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    input  logic [9:0] cursor_x,
    input  logic [9:0] cursor_y,
    input  logic cursor_active,
    input  logic [11:0] background_pixel,
    output logic [11:0] pixel_out,
    output logic game_active
);
 
    // ===== 파라미터 =====
    localparam MAX_FRUITS = 8;
    localparam DISPLAY_SIZE = 80;        // 80x80 크기
    localparam INITIAL_LIVES = 3;
    
    // ===== 게임 상태 =====
    localparam ST_TITLE    = 2'd0;
    localparam ST_PLAYING  = 2'd1;
    localparam ST_GAMEOVER = 2'd2;
    
    logic [1:0] game_state;
    
    // ===== vsync edge detection =====
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
    
    // ===== LFSR =====
    logic [15:0] lfsr;
    
    always_ff @(posedge clk) begin
        if (reset)
            lfsr <= 16'hACE1;
        else
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    end
    
    // ===== 과일 데이터 =====
    logic [MAX_FRUITS-1:0] fruit_active;
    logic [9:0] fruit_x [MAX_FRUITS];
    logic [9:0] fruit_y [MAX_FRUITS];
    logic signed [11:0] fruit_vx [MAX_FRUITS];
    logic signed [11:0] fruit_vy [MAX_FRUITS];
    logic [2:0] fruit_type [MAX_FRUITS];
    logic [MAX_FRUITS-1:0] fruit_sliced;
    logic [MAX_FRUITS-1:0] fruit_entered;
    
    // ===== 점수/라이프 =====
    logic [15:0] score;
    logic [1:0] lives;
    logic [7:0] hover_timer;
    logic game_start_pulse;
    
    // ===== 충돌 신호 =====
    logic [MAX_FRUITS-1:0] collision_detected;
    logic [MAX_FRUITS-1:0] fruit_missed;

    // ===== 서브모듈 인스턴스 =====
    
    Game_State_Machine U_State_Machine (
        .clk(clk),
        .reset(reset),
        .vsync_rising(vsync_rising),
        .cursor_x(cursor_x),
        .cursor_y(cursor_y),
        .cursor_active(cursor_active),
        .lives(lives),
        .game_state(game_state),
        .hover_timer(hover_timer),
        .game_start_pulse(game_start_pulse)
    );
    
    Fruit_Spawner #(
        .MAX_FRUITS(MAX_FRUITS)
    ) U_Fruit_Spawner (
        .clk(clk),
        .reset(reset),
        .vsync_rising(vsync_rising),
        .game_state(game_state),
        .game_start_pulse(game_start_pulse),
        .lfsr(lfsr),
        .collision_detected(collision_detected),
        .fruit_missed(fruit_missed),
        .fruit_active(fruit_active),
        .fruit_x(fruit_x),
        .fruit_y(fruit_y),
        .fruit_vx(fruit_vx),
        .fruit_vy(fruit_vy),
        .fruit_type(fruit_type),
        .fruit_sliced(fruit_sliced),
        .fruit_entered(fruit_entered)
    );
    
    Collision_Detector #(
        .MAX_FRUITS(MAX_FRUITS),
        .DISPLAY_SIZE(DISPLAY_SIZE)
    ) U_Collision (
        .clk(clk),
        .reset(reset),
        .vsync_rising(vsync_rising),
        .game_state(game_state),
        .cursor_x(cursor_x),
        .cursor_y(cursor_y),
        .cursor_active(cursor_active),
        .fruit_active(fruit_active),
        .fruit_x(fruit_x),
        .fruit_y(fruit_y),
        .fruit_vy(fruit_vy),
        .fruit_entered(fruit_entered),
        .fruit_sliced(fruit_sliced),
        .collision_detected(collision_detected),
        .fruit_missed(fruit_missed)
    );
    
    Score_Life_Manager #(
        .MAX_FRUITS(MAX_FRUITS),
        .INITIAL_LIVES(INITIAL_LIVES)
    ) U_Score_Life (
        .clk(clk),
        .reset(reset),
        .vsync_rising(vsync_rising),
        .game_state(game_state),
        .game_start_pulse(game_start_pulse),
        .collision_detected(collision_detected),
        .fruit_missed(fruit_missed),
        .fruit_type(fruit_type),
        .score(score),
        .lives(lives)
    );
    
    // ===== 렌더링 =====
    logic [11:0] fruit_pixel;
    logic fruit_visible;
    logic [11:0] ui_pixel;
    logic ui_visible;
    
    Fruit_Renderer #(
        .MAX_FRUITS(MAX_FRUITS),
        .DISPLAY_SIZE(DISPLAY_SIZE)
    ) U_Fruit_Renderer (
        .clk(clk),
        .reset(reset),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .fruit_active(fruit_active),
        .fruit_x(fruit_x),
        .fruit_y(fruit_y),
        .fruit_type(fruit_type),
        .fruit_sliced(fruit_sliced),
        .pixel_out(fruit_pixel),
        .pixel_visible(fruit_visible)
    );
    
    UI_Renderer U_UI_Renderer (
        .clk(clk),
        .reset(reset),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .game_state(game_state),
        .score(score),
        .lives(lives),
        .hover_timer(hover_timer),
        .pixel_out(ui_pixel),
        .pixel_visible(ui_visible)
    );
    
    // ===== 최종 출력 =====
    always_comb begin
        if (ui_visible)
            pixel_out = ui_pixel;
        else if (fruit_visible)
            pixel_out = fruit_pixel;
        else
            pixel_out = background_pixel;
    end
    
    assign game_active = (game_state == ST_PLAYING);

endmodule


//////////////////////////////////////////////////////////////////////////////////
// Game State Machine
//////////////////////////////////////////////////////////////////////////////////
module Game_State_Machine (
    input  logic clk,
    input  logic reset,
    input  logic vsync_rising,
    input  logic [9:0] cursor_x,
    input  logic [9:0] cursor_y,
    input  logic cursor_active,
    input  logic [1:0] lives,
    output logic [1:0] game_state,
    output logic [7:0] hover_timer,
    output logic game_start_pulse
);

    localparam ST_TITLE    = 2'd0;
    localparam ST_PLAYING  = 2'd1;
    localparam ST_GAMEOVER = 2'd2;
    
    // 버튼 영역
    localparam BTN_START_X = 220, BTN_START_Y = 280;
    localparam BTN_START_W = 200, BTN_START_H = 60;
    localparam BTN_MENU_X = 220, BTN_MENU_Y = 320;
    localparam BTN_MENU_W = 200, BTN_MENU_H = 60;
    localparam HOVER_TIME = 8'd180;
    
    logic [1:0] state_reg;
    logic [7:0] hover_count;
    logic on_button;
    
    // 버튼 체크
    always_comb begin
        on_button = 1'b0;
        if (cursor_active) begin
            case (state_reg)
                ST_TITLE: begin
                    if (cursor_x >= BTN_START_X && cursor_x < BTN_START_X + BTN_START_W &&
                        cursor_y >= BTN_START_Y && cursor_y < BTN_START_Y + BTN_START_H)
                        on_button = 1'b1;
                end
                ST_GAMEOVER: begin
                    if (cursor_x >= BTN_MENU_X && cursor_x < BTN_MENU_X + BTN_MENU_W &&
                        cursor_y >= BTN_MENU_Y && cursor_y < BTN_MENU_Y + BTN_MENU_H)
                        on_button = 1'b1;
                end
                default: on_button = 1'b0;
            endcase
        end
    end
    
    // 상태 머신
    always_ff @(posedge clk) begin
        if (reset) begin
            state_reg <= ST_TITLE;
            hover_count <= 8'd0;
            game_start_pulse <= 1'b0;
        end else if (vsync_rising) begin
            game_start_pulse <= 1'b0;  // 기본값
            
            case (state_reg)
                ST_TITLE: begin
                    if (on_button) begin
                        if (hover_count >= HOVER_TIME) begin
                            state_reg <= ST_PLAYING;
                            hover_count <= 8'd0;
                            game_start_pulse <= 1'b1;  // 게임 시작 펄스
                        end else begin
                            hover_count <= hover_count + 1'b1;
                        end
                    end else begin
                        hover_count <= 8'd0;
                    end
                end
                
                ST_PLAYING: begin
                    if (lives == 2'd0) begin
                        state_reg <= ST_GAMEOVER;
                        hover_count <= 8'd0;
                    end
                end
                
                ST_GAMEOVER: begin
                    if (on_button) begin
                        if (hover_count >= HOVER_TIME) begin
                            state_reg <= ST_TITLE;
                            hover_count <= 8'd0;
                        end else begin
                            hover_count <= hover_count + 1'b1;
                        end
                    end else begin
                        hover_count <= 8'd0;
                    end
                end
                
                default: state_reg <= ST_TITLE;
            endcase
        end
    end
    
    assign game_state = state_reg;
    assign hover_timer = hover_count;

endmodule


//////////////////////////////////////////////////////////////////////////////////
// Fruit Spawner - 수정됨
// - 속도 증가
// - 다양한 각도
// - 시작 위치 y=520 (화면 밖)
// - fruit_entered 관리
//////////////////////////////////////////////////////////////////////////////////
module Fruit_Spawner #(
    parameter MAX_FRUITS = 8
)(
    input  logic clk,
    input  logic reset,
    input  logic vsync_rising,
    input  logic [1:0] game_state,
    input  logic game_start_pulse,
    input  logic [15:0] lfsr,
    input  logic [MAX_FRUITS-1:0] collision_detected,
    input  logic [MAX_FRUITS-1:0] fruit_missed,
    output logic [MAX_FRUITS-1:0] fruit_active,
    output logic [9:0] fruit_x [MAX_FRUITS],
    output logic [9:0] fruit_y [MAX_FRUITS],
    output logic signed [11:0] fruit_vx [MAX_FRUITS],
    output logic signed [11:0] fruit_vy [MAX_FRUITS],
    output logic [2:0] fruit_type [MAX_FRUITS],
    output logic [MAX_FRUITS-1:0] fruit_sliced,
    output logic [MAX_FRUITS-1:0] fruit_entered
);

    localparam ST_PLAYING = 2'd1;
    
    // 스폰 타이머
    logic [7:0] spawn_timer;
    logic [7:0] spawn_interval;
    
    // 빈 슬롯 찾기
    logic [2:0] next_slot;
    logic slot_found;
    
    always_comb begin
        next_slot = 3'd0;
        slot_found = 1'b0;
        for (int i = 0; i < MAX_FRUITS; i++) begin
            if (!fruit_active[i] && !slot_found) begin
                next_slot = i[2:0];
                slot_found = 1'b1;
            end
        end
    end
    
    integer i;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            fruit_active <= '0;
            fruit_sliced <= '0;
            fruit_entered <= '0;
            spawn_timer <= 8'd0;
            spawn_interval <= 8'd60;
            
            for (i = 0; i < MAX_FRUITS; i++) begin
                fruit_x[i] <= 10'd320;
                fruit_y[i] <= 10'd550;
                fruit_vx[i] <= 12'sd0;
                fruit_vy[i] <= 12'sd0;
                fruit_type[i] <= 3'd0;
            end
        end else if (vsync_rising) begin
            // ===== 게임 시작 시 완전 초기화 =====
            if (game_start_pulse) begin
                fruit_active <= '0;
                fruit_sliced <= '0;
                fruit_entered <= '0;
                spawn_timer <= 8'd0;
                spawn_interval <= 8'd60;
                
                for (i = 0; i < MAX_FRUITS; i++) begin
                    fruit_x[i] <= 10'd320;
                    fruit_y[i] <= 10'd550;
                    fruit_vx[i] <= 12'sd0;
                    fruit_vy[i] <= 12'sd0;
                    fruit_type[i] <= 3'd0;
                end
            end
            else if (game_state == ST_PLAYING) begin
                // ===== 충돌/놓침 처리 =====
                for (i = 0; i < MAX_FRUITS; i++) begin
                    if (collision_detected[i]) begin
                        fruit_active[i] <= 1'b0;
                        fruit_sliced[i] <= 1'b0;
                        fruit_entered[i] <= 1'b0;
                    end
                    else if (fruit_missed[i]) begin
                        fruit_active[i] <= 1'b0;  // 즉시 비활성화
                        fruit_sliced[i] <= 1'b0;
                        fruit_entered[i] <= 1'b0;
                    end
                    else if (!fruit_active[i]) begin
                        fruit_sliced[i] <= 1'b0;
                        fruit_entered[i] <= 1'b0;
                    end
                end
                
                // ===== 스폰 로직 =====
                if (spawn_timer >= spawn_interval) begin
                    if (slot_found) begin
                        fruit_active[next_slot] <= 1'b1;
                        fruit_sliced[next_slot] <= 1'b0;
                        fruit_entered[next_slot] <= 1'b0;
                        
                        // 다양한 시작 위치
                        case (lfsr[1:0])
                            2'b00: fruit_x[next_slot] <= 10'd60 + {4'd0, lfsr[9:4]};
                            2'b01: fruit_x[next_slot] <= 10'd200 + {4'd0, lfsr[9:4]};
                            2'b10: fruit_x[next_slot] <= 10'd340 + {4'd0, lfsr[9:4]};
                            2'b11: fruit_x[next_slot] <= 10'd480 + {4'd0, lfsr[9:4]};
                        endcase
                        
                        fruit_y[next_slot] <= 10'd520;  // 화면 밖에서 시작
                        
                        // X 속도 (위치에 따라 방향 결정)
                        if (lfsr[1:0] == 2'b00 || lfsr[1:0] == 2'b01)
                            fruit_vx[next_slot] <= 12'sd16 + $signed({5'd0, lfsr[5:0]});
                        else
                            fruit_vx[next_slot] <= -12'sd16 - $signed({5'd0, lfsr[5:0]});
                        
                        // Y 속도 (빠르게)
                        fruit_vy[next_slot] <= -12'sd160 - $signed({4'd0, lfsr[6:0]});
                        
                        // 타입
                        if (lfsr[11:8] == 4'hF)
                            fruit_type[next_slot] <= 3'd6;
                        else
                            fruit_type[next_slot] <= lfsr[2:0] % 3'd6;
                    end
                    
                    spawn_timer <= 8'd0;
                    spawn_interval <= 8'd45 + {2'd0, lfsr[5:0]};
                end else begin
                    spawn_timer <= spawn_timer + 1'b1;
                end
                
                // ===== 물리 업데이트 =====
                for (i = 0; i < MAX_FRUITS; i++) begin
                    if (fruit_active[i] && !fruit_sliced[i]) begin
                        logic signed [12:0] new_x, new_y;
                        new_x = $signed({3'b0, fruit_x[i]}) + (fruit_vx[i] >>> 4);
                        new_y = $signed({3'b0, fruit_y[i]}) + (fruit_vy[i] >>> 4);
                        
                        // 화면 진입 체크
                        if (new_y < 13'sd450 && new_y > 13'sd0) begin
                            fruit_entered[i] <= 1'b1;
                        end
                        
                        // 화면 밖이면 비활성화
                        if (new_y > 13'sd560 || new_x < -13'sd80 || new_x > 13'sd720) begin
                            fruit_active[i] <= 1'b0;
                        end else begin
                            fruit_x[i] <= new_x[9:0];
                            fruit_y[i] <= new_y[9:0];
                        end
                        
                        // 중력
                        fruit_vy[i] <= fruit_vy[i] + 12'sd4;
                    end
                end
            end else begin
                fruit_active <= '0;
                fruit_sliced <= '0;
                fruit_entered <= '0;
                spawn_timer <= 8'd0;
            end
        end
    end

endmodule


//////////////////////////////////////////////////////////////////////////////////
// Collision Detector - 수정됨
// - fruit_entered 체크로 즉시 놓침 방지
// - 하강 중일 때만 놓침 판정
//////////////////////////////////////////////////////////////////////////////////
module Collision_Detector #(
    parameter MAX_FRUITS = 8,
    parameter DISPLAY_SIZE = 80
)(
    input  logic clk,
    input  logic reset,
    input  logic vsync_rising,
    input  logic [1:0] game_state,
    input  logic [9:0] cursor_x,
    input  logic [9:0] cursor_y,
    input  logic cursor_active,
    input  logic [MAX_FRUITS-1:0] fruit_active,
    input  logic [9:0] fruit_x [MAX_FRUITS],
    input  logic [9:0] fruit_y [MAX_FRUITS],
    input  logic signed [11:0] fruit_vy [MAX_FRUITS],
    input  logic [MAX_FRUITS-1:0] fruit_entered,
    input  logic [MAX_FRUITS-1:0] fruit_sliced,
    output logic [MAX_FRUITS-1:0] collision_detected,
    output logic [MAX_FRUITS-1:0] fruit_missed
);

    localparam ST_PLAYING = 2'd1;
    localparam HITBOX_SIZE = 50;  // 80x80에 맞춤
    
    // 이미 놓친 과일 추적 (재감지 방지)
    logic [MAX_FRUITS-1:0] already_missed;
    logic [MAX_FRUITS-1:0] already_scored;
    
    integer i;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            collision_detected <= '0;
            fruit_missed <= '0;
            already_missed <= '0;
            already_scored <= '0;
        end else if (vsync_rising) begin
            collision_detected <= '0;
            fruit_missed <= '0;
            
            if (game_state == ST_PLAYING) begin
                for (i = 0; i < MAX_FRUITS; i++) begin
                    // 비활성화된 과일은 already_missed 플래그 초기화
                    if (!fruit_active[i]) begin
                        already_missed[i] <= 1'b0;
                        already_scored[i] <= 1'b0;
                    end
                    
                    if (fruit_active[i] && !fruit_sliced[i]) begin
                        // 충돌 체크
                        logic signed [11:0] dx, dy;
                        logic [10:0] abs_dx, abs_dy;
                        
                        dx = $signed({2'b0, cursor_x}) - $signed({2'b0, fruit_x[i]});
                        dy = $signed({2'b0, cursor_y}) - $signed({2'b0, fruit_y[i]});
                        abs_dx = dx[11] ? (-dx[10:0]) : dx[10:0];
                        abs_dy = dy[11] ? (-dy[10:0]) : dy[10:0];
                        
                        if (cursor_active && abs_dx < HITBOX_SIZE && abs_dy < HITBOX_SIZE && !already_scored) begin
                            collision_detected[i] <= 1'b1;
                            already_scored[i] <= 1'b1;
                        end
                        
                        // 놓침 체크: 아직 놓침 판정 안 받은 과일만
                        if (fruit_entered[i] && fruit_vy[i] > 12'sd0 && fruit_y[i] > 10'd500 && !already_missed[i]) begin
                            fruit_missed[i] <= 1'b1;
                            already_missed[i] <= 1'b1;  // 이 과일은 이미 놓침 처리됨
                        end
                    end
                end
            end else begin
                // 게임 중이 아니면 초기화
                already_missed <= '0;
                already_scored <= '0;
            end
        end
    end

endmodule


//////////////////////////////////////////////////////////////////////////////////
// Score & Life Manager - 수정됨
// - game_start_pulse로 확실한 초기화
//////////////////////////////////////////////////////////////////////////////////
module Score_Life_Manager #(
    parameter MAX_FRUITS = 8,
    parameter INITIAL_LIVES = 3
)(
    input  logic clk,
    input  logic reset,
    input  logic vsync_rising,
    input  logic [1:0] game_state,
    input  logic game_start_pulse,
    input  logic [MAX_FRUITS-1:0] collision_detected,
    input  logic [MAX_FRUITS-1:0] fruit_missed,
    input  logic [2:0] fruit_type [MAX_FRUITS],
    output logic [15:0] score,
    output logic [1:0] lives
);

    localparam ST_TITLE   = 2'd0;
    localparam ST_PLAYING = 2'd1;
    
    function automatic [7:0] get_fruit_score(input [2:0] ftype);
        case (ftype)
            3'd0: get_fruit_score = 8'd50; // apple
            3'd1: get_fruit_score = 8'd30; // banana
            3'd2: get_fruit_score = 8'd20; // berry
            3'd3: get_fruit_score = 8'd10; // carrot
            3'd4: get_fruit_score = 8'd100; // golden apple
            3'd5: get_fruit_score = 8'd40; // orange
            default: get_fruit_score = 8'd0;
        endcase
    endfunction
    
    logic [15:0] score_reg;
    logic [1:0] lives_reg;
    
    integer i;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            score_reg <= 16'd0;
            lives_reg <= INITIAL_LIVES[1:0];
        end else if (vsync_rising) begin
            // 게임 타이틀 및 시작 초기화
            if (game_start_pulse || game_state == ST_TITLE) begin
                score_reg <= 16'd0;
                lives_reg <= INITIAL_LIVES[1:0];
            end
            else if (game_state == ST_PLAYING && lives_reg > 2'd0) begin
                logic life_lost;
                logic [15:0] score_add;
                
                life_lost = 1'b0;
                score_add = 16'd0;
                
                // 모든 과일의 점수를 먼저 계산
                for (i = 0; i < MAX_FRUITS; i++) begin
                    if (collision_detected[i]) begin
                        if (fruit_type[i] == 3'd6) begin
                            life_lost = 1'b1;
                        end else begin
                            score_add = score_add + {8'd0, get_fruit_score(fruit_type[i])};
                        end
                    end
                    if (fruit_missed[i] && fruit_type[i] != 3'd6) begin
                        life_lost = 1'b1;
                    end
                end
                
                // 한 번에 점수 업데이트
                if (score_add > 16'd0)
                    score_reg <= score_reg + score_add;
                
                if (life_lost && lives_reg > 2'd0)
                    lives_reg <= lives_reg - 1'b1;
            end
        end
    end
    
    assign score = score_reg;
    assign lives = lives_reg;

endmodule


//////////////////////////////////////////////////////////////////////////////////
// Fruit Renderer - 수정됨
// - 80x80 크기
//////////////////////////////////////////////////////////////////////////////////
module Fruit_Renderer #(
    parameter MAX_FRUITS = 8,
    parameter DISPLAY_SIZE = 80
)(
    input  logic clk,
    input  logic reset,
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    input  logic [MAX_FRUITS-1:0] fruit_active,
    input  logic [9:0] fruit_x [MAX_FRUITS],
    input  logic [9:0] fruit_y [MAX_FRUITS],
    input  logic [2:0] fruit_type [MAX_FRUITS],
    input  logic [MAX_FRUITS-1:0] fruit_sliced,
    output logic [11:0] pixel_out,
    output logic pixel_visible
);

    localparam HALF_SIZE = DISPLAY_SIZE / 2;  // 40
    localparam SPRITE_SIZE = 16;
    
    // ROM
    (* ram_style = "block" *) logic [15:0] fruit_rom_0 [0:255];
    (* ram_style = "block" *) logic [15:0] fruit_rom_1 [0:255];
    (* ram_style = "block" *) logic [15:0] fruit_rom_2 [0:255];
    (* ram_style = "block" *) logic [15:0] fruit_rom_3 [0:255];
    (* ram_style = "block" *) logic [15:0] fruit_rom_4 [0:255];
    (* ram_style = "block" *) logic [15:0] fruit_rom_5 [0:255];
    (* ram_style = "block" *) logic [15:0] bomb_rom [0:255];
    
    initial begin
        $readmemh("apple.mem", fruit_rom_0);
        $readmemh("banana.mem", fruit_rom_1);
        $readmemh("berry.mem", fruit_rom_2);
        $readmemh("carrot.mem", fruit_rom_3);
        $readmemh("golden_apple.mem", fruit_rom_4);
        $readmemh("orange.mem", fruit_rom_5);
        $readmemh("bomb.mem", bomb_rom);
    end
     
    // 히트 검사
    logic hit_found;
    logic [3:0] sprite_x, sprite_y;
    logic [2:0] hit_type;
    
    always_comb begin
        hit_found = 1'b0;
        sprite_x = 4'd0;
        sprite_y = 4'd0;
        hit_type = 3'd0;
        
        for (int j = MAX_FRUITS - 1; j >= 0; j--) begin
            if (fruit_active[j] && !fruit_sliced[j] && !hit_found) begin
                logic signed [11:0] rel_x, rel_y;
                rel_x = $signed({2'b0, x_pixel}) - $signed({2'b0, fruit_x[j]}) + HALF_SIZE;
                rel_y = $signed({2'b0, y_pixel}) - $signed({2'b0, fruit_y[j]}) + HALF_SIZE;
                
                if (rel_x >= 0 && rel_x < DISPLAY_SIZE && rel_y >= 0 && rel_y < DISPLAY_SIZE) begin
                    hit_found = 1'b1;
                    // 80/16 = 5 → rel / 5
                    // 근사: (rel * 13) >> 6 ≈ rel / 5
                    sprite_x = (rel_x * 13) >> 6;
                    sprite_y = (rel_y * 13) >> 6;
                    if (sprite_x > 4'd15) sprite_x = 4'd15;
                    if (sprite_y > 4'd15) sprite_y = 4'd15;
                    hit_type = fruit_type[j];
                end
            end
        end
    end
    
    logic [7:0] rom_addr;
    assign rom_addr = {sprite_y, sprite_x};
    
    // ROM 읽기
    logic [11:0] rom_data_0, rom_data_1, rom_data_2;
    logic [11:0] rom_data_3, rom_data_4, rom_data_5;
    logic [11:0] rom_data_bomb;
    
    always_ff @(posedge clk) begin
        rom_data_0 <= {fruit_rom_0[rom_addr][15:12], fruit_rom_0[rom_addr][10:7], fruit_rom_0[rom_addr][4:1]};
        rom_data_1 <= {fruit_rom_1[rom_addr][15:12], fruit_rom_1[rom_addr][10:7], fruit_rom_1[rom_addr][4:1]};
        rom_data_2 <= {fruit_rom_2[rom_addr][15:12], fruit_rom_2[rom_addr][10:7], fruit_rom_2[rom_addr][4:1]};
        rom_data_3 <= {fruit_rom_3[rom_addr][15:12], fruit_rom_3[rom_addr][10:7], fruit_rom_3[rom_addr][4:1]};
        rom_data_4 <= {fruit_rom_4[rom_addr][15:12], fruit_rom_4[rom_addr][10:7], fruit_rom_4[rom_addr][4:1]};
        rom_data_5 <= {fruit_rom_5[rom_addr][15:12], fruit_rom_5[rom_addr][10:7], fruit_rom_5[rom_addr][4:1]};
        rom_data_bomb <= {bomb_rom[rom_addr][15:12], bomb_rom[rom_addr][10:7], bomb_rom[rom_addr][4:1]};
    end
    
    // 파이프라인
    logic hit_found_d1;
    logic [2:0] hit_type_d1;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            hit_found_d1 <= 1'b0;
            hit_type_d1 <= 3'd0;
        end else begin
            hit_found_d1 <= hit_found;
            hit_type_d1 <= hit_type;
        end
    end
    
    // 출력 선택
    logic [11:0] selected_pixel;
    
    always_comb begin
        case (hit_type_d1)
            3'd0: selected_pixel = rom_data_0;
            3'd1: selected_pixel = rom_data_1;
            3'd2: selected_pixel = rom_data_2;
            3'd3: selected_pixel = rom_data_3;
            3'd4: selected_pixel = rom_data_4;
            3'd5: selected_pixel = rom_data_5;
            3'd6: selected_pixel = rom_data_bomb;
            default: selected_pixel = 12'hfff;
        endcase
    end
    
    assign pixel_out = selected_pixel;
    assign pixel_visible = hit_found_d1 && (selected_pixel != 12'hfff);

endmodule


//////////////////////////////////////////////////////////////////////////////////
// UI Renderer - FIXED
//////////////////////////////////////////////////////////////////////////////////
module UI_Renderer (
    input  logic clk,
    input  logic reset,
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    input  logic [1:0] game_state,
    input  logic [15:0] score,
    input  logic [1:0] lives,
    input  logic [7:0] hover_timer,
    output logic [11:0] pixel_out,
    output logic pixel_visible
);

    localparam ST_TITLE    = 2'd0;
    localparam ST_PLAYING  = 2'd1;
    localparam ST_GAMEOVER = 2'd2;
    
    // 색상
    localparam [11:0] COL_WHITE  = 12'hFFF;
    localparam [11:0] COL_RED    = 12'hF22;
    localparam [11:0] COL_GREEN  = 12'h2F2;
    localparam [11:0] COL_YELLOW = 12'hFF0;
    localparam [11:0] COL_ORANGE = 12'hF80;
    localparam [11:0] COL_GRAY   = 12'h888;
    localparam [11:0] COL_DARK   = 12'h333;
    
    // 버튼 영역
    localparam BTN_START_X = 220, BTN_START_Y = 280;
    localparam BTN_START_W = 200, BTN_START_H = 60;
    localparam BTN_MENU_X = 220, BTN_MENU_Y = 320;
    localparam BTN_MENU_W = 200, BTN_MENU_H = 60;
    localparam HOVER_TIME = 180;
    
    // 숫자 폰트
    logic [7:0] digit_font [0:79];
    
    initial begin
        digit_font[0]  = 8'b00111100; digit_font[1]  = 8'b01100110;
        digit_font[2]  = 8'b01101110; digit_font[3]  = 8'b01110110;
        digit_font[4]  = 8'b01100110; digit_font[5]  = 8'b01100110;
        digit_font[6]  = 8'b00111100; digit_font[7]  = 8'b00000000;
        digit_font[8]  = 8'b00011000; digit_font[9]  = 8'b00111000;
        digit_font[10] = 8'b00011000; digit_font[11] = 8'b00011000;
        digit_font[12] = 8'b00011000; digit_font[13] = 8'b00011000;
        digit_font[14] = 8'b01111110; digit_font[15] = 8'b00000000;
        digit_font[16] = 8'b00111100; digit_font[17] = 8'b01100110;
        digit_font[18] = 8'b00000110; digit_font[19] = 8'b00001100;
        digit_font[20] = 8'b00110000; digit_font[21] = 8'b01100000;
        digit_font[22] = 8'b01111110; digit_font[23] = 8'b00000000;
        digit_font[24] = 8'b00111100; digit_font[25] = 8'b01100110;
        digit_font[26] = 8'b00000110; digit_font[27] = 8'b00011100;
        digit_font[28] = 8'b00000110; digit_font[29] = 8'b01100110;
        digit_font[30] = 8'b00111100; digit_font[31] = 8'b00000000;
        digit_font[32] = 8'b00001100; digit_font[33] = 8'b00011100;
        digit_font[34] = 8'b00111100; digit_font[35] = 8'b01101100;
        digit_font[36] = 8'b01111110; digit_font[37] = 8'b00001100;
        digit_font[38] = 8'b00001100; digit_font[39] = 8'b00000000;
        digit_font[40] = 8'b01111110; digit_font[41] = 8'b01100000;
        digit_font[42] = 8'b01111100; digit_font[43] = 8'b00000110;
        digit_font[44] = 8'b00000110; digit_font[45] = 8'b01100110;
        digit_font[46] = 8'b00111100; digit_font[47] = 8'b00000000;
        digit_font[48] = 8'b00111100; digit_font[49] = 8'b01100000;
        digit_font[50] = 8'b01111100; digit_font[51] = 8'b01100110;
        digit_font[52] = 8'b01100110; digit_font[53] = 8'b01100110;
        digit_font[54] = 8'b00111100; digit_font[55] = 8'b00000000;
        digit_font[56] = 8'b01111110; digit_font[57] = 8'b00000110;
        digit_font[58] = 8'b00001100; digit_font[59] = 8'b00011000;
        digit_font[60] = 8'b00110000; digit_font[61] = 8'b00110000;
        digit_font[62] = 8'b00110000; digit_font[63] = 8'b00000000;
        digit_font[64] = 8'b00111100; digit_font[65] = 8'b01100110;
        digit_font[66] = 8'b01100110; digit_font[67] = 8'b00111100;
        digit_font[68] = 8'b01100110; digit_font[69] = 8'b01100110;
        digit_font[70] = 8'b00111100; digit_font[71] = 8'b00000000;
        digit_font[72] = 8'b00111100; digit_font[73] = 8'b01100110;
        digit_font[74] = 8'b01100110; digit_font[75] = 8'b00111110;
        digit_font[76] = 8'b00000110; digit_font[77] = 8'b00001100;
        digit_font[78] = 8'b00111000; digit_font[79] = 8'b00000000;
    end
    
    // 하트 아이콘
    logic [15:0] heart_icon [0:15];
    
    initial begin
        heart_icon[0]  = 16'b0000000000000000;
        heart_icon[1]  = 16'b0011110011110000;
        heart_icon[2]  = 16'b0111111111111000;
        heart_icon[3]  = 16'b1111111111111100;
        heart_icon[4]  = 16'b1111111111111100;
        heart_icon[5]  = 16'b1111111111111100;
        heart_icon[6]  = 16'b0111111111111000;
        heart_icon[7]  = 16'b0011111111110000;
        heart_icon[8]  = 16'b0001111111100000;
        heart_icon[9]  = 16'b0000111111000000;
        heart_icon[10] = 16'b0000011110000000;
        heart_icon[11] = 16'b0000001100000000;
        heart_icon[12] = 16'b0000000000000000;
        heart_icon[13] = 16'b0000000000000000;
        heart_icon[14] = 16'b0000000000000000;
        heart_icon[15] = 16'b0000000000000000;
    end
    
    // Title Image ROM (64x64 pixels)
    (* ram_style = "block" *) logic [11:0] title_rom [0:4095];
    initial begin
        $readmemh("fruit_ninja_title.mem", title_rom);
    end
    
    // BCD
    logic [3:0] score_digit [4:0];
    always_comb begin
        score_digit[4] = (score / 10000) % 10;
        score_digit[3] = (score / 1000) % 10;
        score_digit[2] = (score / 100) % 10;
        score_digit[1] = (score / 10) % 10;
        score_digit[0] = score % 10;
    end
    
    // 렌더링
    logic [11:0] ui_color;
    logic ui_hit;
    
    always_comb begin
        ui_color = 12'h000;
        ui_hit = 1'b0;
        
        case (game_state)
            ST_TITLE: begin
                // 타이틀 이미지 (64x64를 2배 확대하여 128x128로 표시)
                // X: 256~384 (중앙), Y: 152~280 (버튼 위)
                if (x_pixel >= 222 && x_pixel < 478 &&
                    y_pixel >= 72 && y_pixel < 328) begin
                    logic [9:0] title_x, title_y;
                    logic [11:0] title_addr;
                    
                    title_x = (x_pixel - 222) >> 2;  // /4 (4배 확대)
                    title_y = (y_pixel - 72) >> 2;   // /4
                    title_addr = title_y * 64 + title_x;
                    
                    if (title_rom[title_addr] != 12'h000) begin
                        ui_hit = 1'b1;
                        ui_color = title_rom[title_addr];
                    end
                end
                
                // 시작 버튼
                if (x_pixel >= BTN_START_X && x_pixel < BTN_START_X + BTN_START_W &&
                    y_pixel >= BTN_START_Y && y_pixel < BTN_START_Y + BTN_START_H) begin
                    ui_hit = 1'b1;
                    if (hover_timer > 0) begin
                        if (x_pixel < BTN_START_X + ((hover_timer * BTN_START_W) / HOVER_TIME))
                            ui_color = COL_GREEN;
                        else
                            ui_color = COL_GRAY;
                    end else begin
                        ui_color = COL_GRAY;
                    end
                    if (x_pixel < BTN_START_X + 3 || x_pixel >= BTN_START_X + BTN_START_W - 3 ||
                        y_pixel < BTN_START_Y + 3 || y_pixel >= BTN_START_Y + BTN_START_H - 3)
                        ui_color = COL_WHITE;
                end
            end
            
            ST_PLAYING: begin
                // 점수 배경
                if (x_pixel >= 10 && x_pixel < 140 && y_pixel >= 10 && y_pixel < 56) begin
                    ui_hit = 1'b1;
                    ui_color = COL_DARK;
                    if (x_pixel < 13 || x_pixel >= 137 || y_pixel < 13 || y_pixel >= 52)
                        ui_color = COL_YELLOW;
                end
                
                // 점수 숫자
                if (y_pixel >= 18 && y_pixel < 49) begin
                    for (int d = 0; d < 5; d++) begin
                        logic [9:0] dx;
                        dx = 20 + d * 24;
                        if (x_pixel >= dx && x_pixel < dx + 16) begin
                            logic [2:0] fx, fy;
                            logic [6:0] faddr;
                            fx = (x_pixel - dx) >> 1;
                            fy = (y_pixel - 18) >> 2;
                            faddr = score_digit[4-d] * 8 + fy;
                            if (fx < 8 && fy < 8 && digit_font[faddr][7-fx]) begin
                                ui_hit = 1'b1;
                                ui_color = COL_YELLOW;
                            end
                        end
                    end
                end
                
                // 라이프
                if (y_pixel >= 15 && y_pixel < 45) begin
                    for (int h = 0; h < 3; h++) begin
                        logic [9:0] hx;
                        hx = 595 - h * 35;
                        if (x_pixel >= hx && x_pixel < hx + 30) begin
                            logic [3:0] ix, iy;
                            ix = (x_pixel - hx) >> 1;
                            iy = (y_pixel - 15) >> 1;
                            if (ix < 16 && iy < 16 && heart_icon[iy][15-ix]) begin
                                ui_hit = 1'b1;
                                ui_color = (h < lives) ? COL_RED : 12'h422;
                            end
                        end
                    end
                end
            end
            
            ST_GAMEOVER: begin
                // GAME OVER 텍스트 (2배 크기: 16x16 → 32x32)
                // 버튼 위에 배치 (Y=180~212)
                if (y_pixel >= 180 && y_pixel < 212) begin
                    logic [7:0] letter_pattern [0:7];
                    logic [5:0] char_x, char_y;
                    char_y = (y_pixel - 180) >> 2;  // /4 (32/8=4)
                    
                    // G (X: 136~168)
                    if (x_pixel >= 168 && x_pixel < 200) begin
                        letter_pattern[0] = 8'b01111110;
                        letter_pattern[1] = 8'b11000000;
                        letter_pattern[2] = 8'b11000000;
                        letter_pattern[3] = 8'b11001110;
                        letter_pattern[4] = 8'b11000110;
                        letter_pattern[5] = 8'b11000110;
                        letter_pattern[6] = 8'b01111100;
                        letter_pattern[7] = 8'b00000000;
                        char_x = (x_pixel - 168) >> 2;
                        if (char_x < 8 && char_y < 8 && letter_pattern[char_y][7-char_x]) begin
                            ui_hit = 1'b1;
                            ui_color = COL_YELLOW;
                        end
                    end
                    
                    // A (X: 172~204)
                    if (x_pixel >= 204 && x_pixel < 236) begin
                        letter_pattern[0] = 8'b00111100;
                        letter_pattern[1] = 8'b01100110;
                        letter_pattern[2] = 8'b01100110;
                        letter_pattern[3] = 8'b01111110;
                        letter_pattern[4] = 8'b01100110;
                        letter_pattern[5] = 8'b01100110;
                        letter_pattern[6] = 8'b01100110;
                        letter_pattern[7] = 8'b00000000;
                        char_x = (x_pixel - 204) >> 2;
                        if (char_x < 8 && char_y < 8 && letter_pattern[char_y][7-char_x]) begin
                            ui_hit = 1'b1;
                            ui_color = COL_YELLOW;
                        end
                    end
                    
                    // M (X: 208~240)
                    if (x_pixel >= 240 && x_pixel < 272) begin
                        letter_pattern[0] = 8'b11000110;
                        letter_pattern[1] = 8'b11101110;
                        letter_pattern[2] = 8'b11111110;
                        letter_pattern[3] = 8'b11010110;
                        letter_pattern[4] = 8'b11000110;
                        letter_pattern[5] = 8'b11000110;
                        letter_pattern[6] = 8'b11000110;
                        letter_pattern[7] = 8'b00000000;
                        char_x = (x_pixel - 240) >> 2;
                        if (char_x < 8 && char_y < 8 && letter_pattern[char_y][7-char_x]) begin
                            ui_hit = 1'b1;
                            ui_color = COL_YELLOW;
                        end
                    end
                    
                    // E (X: 244~276)
                    if (x_pixel >= 276 && x_pixel < 308) begin
                        letter_pattern[0] = 8'b01111110;
                        letter_pattern[1] = 8'b01100000;
                        letter_pattern[2] = 8'b01100000;
                        letter_pattern[3] = 8'b01111100;
                        letter_pattern[4] = 8'b01100000;
                        letter_pattern[5] = 8'b01100000;
                        letter_pattern[6] = 8'b01111110;
                        letter_pattern[7] = 8'b00000000;
                        char_x = (x_pixel - 276) >> 2;
                        if (char_x < 8 && char_y < 8 && letter_pattern[char_y][7-char_x]) begin
                            ui_hit = 1'b1;
                            ui_color = COL_YELLOW;
                        end
                    end
                    
                    // O (X: 296~328)
                    if (x_pixel >= 338 && x_pixel < 370) begin
                        letter_pattern[0] = 8'b00111100;
                        letter_pattern[1] = 8'b01100110;
                        letter_pattern[2] = 8'b01100110;
                        letter_pattern[3] = 8'b01100110;
                        letter_pattern[4] = 8'b01100110;
                        letter_pattern[5] = 8'b01100110;
                        letter_pattern[6] = 8'b00111100;
                        letter_pattern[7] = 8'b00000000;
                        char_x = (x_pixel - 338) >> 2;
                        if (char_x < 8 && char_y < 8 && letter_pattern[char_y][7-char_x]) begin
                            ui_hit = 1'b1;
                            ui_color = COL_YELLOW;
                        end
                    end
                    
                    // V (X: 332~364)
                    if (x_pixel >= 374 && x_pixel < 406) begin
                        letter_pattern[0] = 8'b01100110;
                        letter_pattern[1] = 8'b01100110;
                        letter_pattern[2] = 8'b01100110;
                        letter_pattern[3] = 8'b01100110;
                        letter_pattern[4] = 8'b01100110;
                        letter_pattern[5] = 8'b00111100;
                        letter_pattern[6] = 8'b00011000;
                        letter_pattern[7] = 8'b00000000;
                        char_x = (x_pixel - 374) >> 2;
                        if (char_x < 8 && char_y < 8 && letter_pattern[char_y][7-char_x]) begin
                            ui_hit = 1'b1;
                            ui_color = COL_YELLOW;
                        end
                    end
                    
                    // E (X: 368~400)
                    if (x_pixel >= 410 && x_pixel < 442) begin
                        letter_pattern[0] = 8'b01111110;
                        letter_pattern[1] = 8'b01100000;
                        letter_pattern[2] = 8'b01100000;
                        letter_pattern[3] = 8'b01111100;
                        letter_pattern[4] = 8'b01100000;
                        letter_pattern[5] = 8'b01100000;
                        letter_pattern[6] = 8'b01111110;
                        letter_pattern[7] = 8'b00000000;
                        char_x = (x_pixel - 410) >> 2;
                        if (char_x < 8 && char_y < 8 && letter_pattern[char_y][7-char_x]) begin
                            ui_hit = 1'b1;
                            ui_color = COL_YELLOW;
                        end
                    end
                    
                    // R (X: 404~436)
                    if (x_pixel >= 446 && x_pixel < 478) begin
                        letter_pattern[0] = 8'b01111100;
                        letter_pattern[1] = 8'b01100110;
                        letter_pattern[2] = 8'b01100110;
                        letter_pattern[3] = 8'b01111100;
                        letter_pattern[4] = 8'b01101000;
                        letter_pattern[5] = 8'b01100110;
                        letter_pattern[6] = 8'b01100011;
                        letter_pattern[7] = 8'b00000000;
                        char_x = (x_pixel - 446) >> 2;
                        if (char_x < 8 && char_y < 8 && letter_pattern[char_y][7-char_x]) begin
                            ui_hit = 1'b1;
                            ui_color = COL_YELLOW;
                        end
                    end
                end
                
                // 점수 박스
                if (x_pixel >= 200 && x_pixel < 440 && y_pixel >= 240 && y_pixel < 300) begin
                    ui_hit = 1'b1;
                    ui_color = COL_DARK;
                    if (x_pixel < 203 || x_pixel >= 437 || y_pixel < 243 || y_pixel >= 297)
                        ui_color = COL_YELLOW;
                end
                
                // 점수 숫자
                if (y_pixel >= 255 && y_pixel < 287) begin
                    for (int d = 0; d < 5; d++) begin
                        logic [9:0] dx;
                        dx = 250 + d * 35;
                        if (x_pixel >= dx && x_pixel < dx + 28) begin
                            logic [2:0] fx, fy;
                            logic [6:0] faddr;
                            fx = (x_pixel - dx) >> 2;
                            fy = (y_pixel - 255) >> 2;
                            faddr = score_digit[4-d] * 8 + fy;
                            if (fx < 8 && fy < 8 && digit_font[faddr][7-fx]) begin
                                ui_hit = 1'b1;
                                ui_color = COL_WHITE;
                            end
                        end
                    end
                end
                
                // 메뉴 버튼
                if (x_pixel >= BTN_MENU_X && x_pixel < BTN_MENU_X + BTN_MENU_W &&
                    y_pixel >= BTN_MENU_Y && y_pixel < BTN_MENU_Y + BTN_MENU_H) begin
                    ui_hit = 1'b1;
                    if (hover_timer > 0) begin
                        if (x_pixel < BTN_MENU_X + ((hover_timer * BTN_MENU_W) / HOVER_TIME))
                            ui_color = COL_GREEN;
                        else
                            ui_color = COL_GRAY;
                    end else begin
                        ui_color = COL_GRAY;
                    end
                    if (x_pixel < BTN_MENU_X + 3 || x_pixel >= BTN_MENU_X + BTN_MENU_W - 3 ||
                        y_pixel < BTN_MENU_Y + 3 || y_pixel >= BTN_MENU_Y + BTN_MENU_H - 3)
                        ui_color = COL_WHITE;
                end
            end
            
            default: begin
                ui_hit = 1'b0;
                ui_color = 12'h000;
            end
        endcase
    end
    
    assign pixel_out = ui_color;
    assign pixel_visible = ui_hit;

endmodule