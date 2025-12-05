`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/11/22 14:00:26
// Design Name: 
// Module Name: sccb_master
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


module SCCB_Master (
    // Global Signals
    input  logic       clk,
    input  logic       reset,
    // SCCB External Signals (changed: explicit in/out/oe)
    output logic       SIO_C,
    input  logic       SIO_D_in,   // reading the pin
    output logic       SIO_D_out,  // driving value
    output logic       SIO_D_oe    // output enable (1 -> drive, 0 -> release)
);

    typedef enum {
        IDLE,
        START,
        SLAVE_ADDR,
        REG_ADDR,
        REG_DATA,
        SLAVE_ADDR_ACK,
        REG_ADDR_ACK,
        REG_DATA_ACK,
        NACK,
        DELAY,
        STOP
    } sccb_state;

    sccb_state state, state_next;

    localparam N_REG = 75;

    logic [7:0] addr_rom [0:N_REG-1];
    logic [7:0] reg_rom  [0:N_REG-1];

    initial begin
        addr_rom[0]  = 8'h12; reg_rom[0]  = 8'h80;
        addr_rom[1]  = 8'h11; reg_rom[1]  = 8'hF0;
        addr_rom[2]  = 8'h6B; reg_rom[2]  = 8'h14;
        addr_rom[3]  = 8'h12; reg_rom[3]  = 8'h14;
        addr_rom[4]  = 8'h17; reg_rom[4]  = 8'h04;
        addr_rom[5]  = 8'h18; reg_rom[5]  = 8'h19;
        addr_rom[6]  = 8'h32; reg_rom[6]  = 8'h00;
        addr_rom[7]  = 8'h40; reg_rom[7]  = 8'hD0;
        addr_rom[8]  = 8'h3A; reg_rom[8]  = 8'h04;
        addr_rom[9]  = 8'h14; reg_rom[9]  = 8'h18;
        addr_rom[10] = 8'h4F; reg_rom[10] = 8'hB3;
        addr_rom[11] = 8'h50; reg_rom[11] = 8'hB3;
        addr_rom[12] = 8'h51; reg_rom[12] = 8'h00;
        addr_rom[13] = 8'h52; reg_rom[13] = 8'h3D;
        addr_rom[14] = 8'h53; reg_rom[14] = 8'hA7;
        addr_rom[15] = 8'h54; reg_rom[15] = 8'hE4;
        addr_rom[16] = 8'h58; reg_rom[16] = 8'h9E;
        addr_rom[17] = 8'h3D; reg_rom[17] = 8'hC0;
        addr_rom[18] = 8'h17; reg_rom[18] = 8'h15;
        addr_rom[19] = 8'h18; reg_rom[19] = 8'h03;
        addr_rom[20] = 8'h32; reg_rom[20] = 8'h00;
        addr_rom[21] = 8'h19; reg_rom[21] = 8'h03;
        addr_rom[22] = 8'h1A; reg_rom[22] = 8'h7B;
        addr_rom[23] = 8'h03; reg_rom[23] = 8'h00;
        addr_rom[24] = 8'h0F; reg_rom[24] = 8'h41;
        addr_rom[25] = 8'h1E; reg_rom[25] = 8'h00;
        addr_rom[26] = 8'h33; reg_rom[26] = 8'h0B;
        addr_rom[27] = 8'h3C; reg_rom[27] = 8'h78;
        addr_rom[28] = 8'h69; reg_rom[28] = 8'h00;
        addr_rom[29] = 8'h74; reg_rom[29] = 8'h00;
        addr_rom[30] = 8'hB0; reg_rom[30] = 8'h84;
        addr_rom[31] = 8'hB1; reg_rom[31] = 8'h0C;
        addr_rom[32] = 8'hB2; reg_rom[32] = 8'h0E;
        addr_rom[33] = 8'hB3; reg_rom[33] = 8'h80;
        addr_rom[34] = 8'h70; reg_rom[34] = 8'h3A;
        addr_rom[35] = 8'h71; reg_rom[35] = 8'h35;
        addr_rom[36] = 8'h72; reg_rom[36] = 8'h11;
        addr_rom[37] = 8'h73; reg_rom[37] = 8'hF1;
        addr_rom[38] = 8'hA2; reg_rom[38] = 8'h02;
        addr_rom[39] = 8'h7A; reg_rom[39] = 8'h20;
        addr_rom[40] = 8'h7B; reg_rom[40] = 8'h10;
        addr_rom[41] = 8'h7C; reg_rom[41] = 8'h1E;
        addr_rom[42] = 8'h7D; reg_rom[42] = 8'h35;
        addr_rom[43] = 8'h7E; reg_rom[43] = 8'h5A;
        addr_rom[44] = 8'h7F; reg_rom[44] = 8'h69;
        addr_rom[45] = 8'h80; reg_rom[45] = 8'h76;
        addr_rom[46] = 8'h81; reg_rom[46] = 8'h80;
        addr_rom[47] = 8'h82; reg_rom[47] = 8'h88;
        addr_rom[48] = 8'h83; reg_rom[48] = 8'h8F;
        addr_rom[49] = 8'h84; reg_rom[49] = 8'h96;
        addr_rom[50] = 8'h85; reg_rom[50] = 8'hA3;
        addr_rom[51] = 8'h86; reg_rom[51] = 8'hAF;
        addr_rom[52] = 8'h87; reg_rom[52] = 8'hC4;
        addr_rom[53] = 8'h88; reg_rom[53] = 8'hD7;
        addr_rom[54] = 8'h89; reg_rom[54] = 8'hE8;
        addr_rom[55] = 8'h13; reg_rom[55] = 8'hE0;
        addr_rom[56] = 8'h00; reg_rom[56] = 8'h00;
        addr_rom[57] = 8'h10; reg_rom[57] = 8'h00;
        addr_rom[58] = 8'h0D; reg_rom[58] = 8'h40;
        addr_rom[59] = 8'h14; reg_rom[59] = 8'h18;
        addr_rom[60] = 8'hA5; reg_rom[60] = 8'h05;
        addr_rom[61] = 8'hAB; reg_rom[61] = 8'h07;
        addr_rom[62] = 8'h24; reg_rom[62] = 8'h95;
        addr_rom[63] = 8'h25; reg_rom[63] = 8'h33;
        addr_rom[64] = 8'h26; reg_rom[64] = 8'hE3;
        addr_rom[65] = 8'h9F; reg_rom[65] = 8'h78;
        addr_rom[66] = 8'hA0; reg_rom[66] = 8'h68;
        addr_rom[67] = 8'hA1; reg_rom[67] = 8'h03;
        addr_rom[68] = 8'hA6; reg_rom[68] = 8'hD8;
        addr_rom[69] = 8'hA7; reg_rom[69] = 8'hD8;
        addr_rom[70] = 8'hA8; reg_rom[70] = 8'hF0;
        addr_rom[71] = 8'hA9; reg_rom[71] = 8'h90;
        addr_rom[72] = 8'hAA; reg_rom[72] = 8'h94;
        addr_rom[73] = 8'h13; reg_rom[73] = 8'hE7;
        addr_rom[74] = 8'h69; reg_rom[74] = 8'h07;
    end

    // internal regs
    logic [7:0] tx_data_reg, tx_data_next;
    logic       tx_ready_reg, tx_ready_next;
    logic       tx_done_reg, tx_done_next;
    logic [7:0] rx_data_reg, rx_data_next;
    logic       rx_done_reg, rx_done_next;

    logic sio_c_reg, sio_c_next;
    logic sio_d_reg, sio_d_next;

    logic [$clog2(1500000)-1:0] cnt_reg, cnt_next;
    logic [2:0] bit_cnt_reg, bit_cnt_next;
    logic [$clog2(N_REG)-1:0] rom_cnt_reg, rom_cnt_next;

    logic ack_sig_reg, ack_sig_next;

    // outputs assigned to regs
    assign tx_ready = tx_ready_reg;
    assign tx_done  = tx_done_reg;
    assign rx_data  = rx_data_reg;
    assign rx_done  = rx_done_reg;

    assign SIO_D_out = sio_d_reg;
    assign SIO_D_oe  = (state == SLAVE_ADDR_ACK || state == REG_ADDR_ACK || state == REG_DATA_ACK) ? 1'b0 : 1'b1;
    assign SIO_C = sio_c_reg;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state        <= IDLE;
            tx_data_reg  <= 0;
            tx_ready_reg <= 1;
            tx_done_reg  <= 0;
            rx_data_reg  <= 0;
            rx_done_reg  <= 0;
            sio_c_reg    <= 1;
            sio_d_reg    <= 1;
            cnt_reg      <= 0;
            bit_cnt_reg  <= 0;
            rom_cnt_reg  <= 0;
            ack_sig_reg  <= 1;
        end else begin
            state        <= state_next;
            tx_data_reg  <= tx_data_next;
            tx_ready_reg <= tx_ready_next;
            tx_done_reg  <= tx_done_next;
            rx_data_reg  <= rx_data_next;
            rx_done_reg  <= rx_done_next;
            sio_c_reg    <= sio_c_next;
            sio_d_reg    <= sio_d_next;
            cnt_reg      <= cnt_next;
            bit_cnt_reg  <= bit_cnt_next;
            rom_cnt_reg  <= rom_cnt_next;
            ack_sig_reg  <= ack_sig_next;
        end
    end

    always_comb begin
        state_next    = state;
        tx_data_next  = tx_data_reg;
        tx_ready_next = tx_ready_reg;
        tx_done_next  = tx_done_reg;
        rx_data_next  = rx_data_reg;
        rx_done_next  = rx_done_reg;
        sio_c_next    = sio_c_reg;
        sio_d_next    = sio_d_reg;
        cnt_next      = cnt_reg;
        bit_cnt_next  = bit_cnt_reg;
        rom_cnt_next  = rom_cnt_reg;
        ack_sig_next  = ack_sig_reg;

        case (state)
            IDLE: begin
                tx_data_next  = 0;
                rx_data_next  = 0;
                tx_ready_next = 1;
                tx_done_next  = 0;
                rx_done_next  = 0;
                if (!reset && (rom_cnt_reg < N_REG)) begin
                    state_next = START;
                    sio_d_next = 0;
                    tx_ready_next = 0;
                end
            end
            START: begin
                sio_c_next = (cnt_reg < 500) ? 1'b1 : 1'b0;
                if (cnt_reg == 1000 - 1) begin
                    state_next   = SLAVE_ADDR;
                    tx_data_next = 8'h42;
                    sio_d_next   = tx_data_next[7];
                    cnt_next = 0;
                end else begin
                    cnt_next = cnt_reg + 1;
                end
            end
            SLAVE_ADDR: begin
                sio_c_next = (cnt_reg >= 250 && cnt_reg < 750) ? 1'b1 : 1'b0;
                sio_d_next = tx_data_next[7];
                if (cnt_reg == 1000 - 1) begin
                    tx_data_next = tx_data_reg << 1;
                    cnt_next = 0;
                    bit_cnt_next = bit_cnt_reg + 1;
                    if (bit_cnt_reg == 8 - 1) begin
                        state_next   = SLAVE_ADDR_ACK;
                        bit_cnt_next = 0;
                    end
                end else begin
                    cnt_next = cnt_reg + 1;
                end
            end
            SLAVE_ADDR_ACK: begin
                sio_c_next = (cnt_reg >= 250 && cnt_reg < 750) ? 1'b1 : 1'b0;
                if (cnt_reg == 500 - 1) begin
                    ack_sig_next = SIO_D_in;
                end

                if (cnt_reg == 1000 - 1) begin
                    cnt_next = 0;
                    if (ack_sig_reg == 0) begin
                        state_next   = REG_ADDR;
                        tx_data_next = addr_rom[rom_cnt_reg];
                        sio_d_next   = tx_data_next[7];
                        ack_sig_next = 1;
                    end else begin
                        state_next = NACK;
                    end
                end else begin
                    cnt_next = cnt_reg + 1;
                end
            end
            REG_ADDR: begin
                sio_c_next = (cnt_reg >= 250 && cnt_reg < 750) ? 1'b1 : 1'b0;
                sio_d_next = tx_data_next[7];
                if (cnt_reg == 1000 - 1) begin
                    tx_data_next = tx_data_reg << 1;
                    cnt_next = 0;
                    bit_cnt_next = bit_cnt_reg + 1;
                    if (bit_cnt_reg == 8 - 1) begin
                        state_next   = REG_ADDR_ACK;
                        bit_cnt_next = 0;
                    end
                end else begin
                    cnt_next = cnt_reg + 1;
                end                
            end
            REG_ADDR_ACK: begin
                sio_c_next = (cnt_reg >= 250 && cnt_reg < 750) ? 1'b1 : 1'b0;
                if (cnt_reg == 500 - 1) begin
                    ack_sig_next = SIO_D_in;
                end

                if (cnt_reg == 1000 - 1) begin
                    cnt_next = 0;
                    if (ack_sig_reg == 0) begin
                        state_next   = REG_DATA;
                        tx_data_next = reg_rom[rom_cnt_reg];
                        sio_d_next   = tx_data_next[7];
                        ack_sig_next = 1;
                    end else begin
                        state_next = NACK;
                    end
                end else begin
                    cnt_next = cnt_reg + 1;
                end                
            end
            REG_DATA: begin
                sio_c_next = (cnt_reg >= 250 && cnt_reg < 750) ? 1'b1 : 1'b0;
                sio_d_next = tx_data_next[7];
                if (cnt_reg == 1000 - 1) begin
                    tx_data_next = tx_data_reg << 1;
                    cnt_next = 0;
                    bit_cnt_next = bit_cnt_reg + 1;
                    if (bit_cnt_reg == 8 - 1) begin
                        state_next   = REG_DATA_ACK;
                        bit_cnt_next = 0;
                    end
                end else begin
                    cnt_next = cnt_reg + 1;
                end                     
            end
            REG_DATA_ACK: begin
                sio_c_next = (cnt_reg >= 250 && cnt_reg < 750) ? 1'b1 : 1'b0;
                if (cnt_reg == 500 - 1) begin
                    ack_sig_next = SIO_D_in;
                end

                if (cnt_reg == 1000 - 1) begin
                    cnt_next = 0;
                    if (ack_sig_reg == 0) begin
                        state_next   = STOP;
                        ack_sig_next = 1;
                        sio_d_next = 0;
                    end else begin
                        state_next = NACK;
                    end
                end else begin
                    cnt_next = cnt_reg + 1;
                end                      
            end
            NACK: begin
                sio_c_next = (cnt_reg >= 250 && cnt_reg < 750) ? 1'b1 : 1'b0;
                if (cnt_reg == 1000 - 1) begin
                    cnt_next = 0;
                    state_next = STOP;
                    sio_d_next = 1'b0;
                end else begin
                    cnt_next = cnt_reg + 1;
                end
            end
            STOP: begin
                sio_c_next = (cnt_reg < 500) ? 1'b0 : 1'b1;
                if (cnt_reg == 1000 - 1) begin
                    cnt_next = 0;
                    sio_d_next = 1'b1;
                    tx_done_next = 1;
                    state_next = DELAY;
                end else begin
                    cnt_next = cnt_reg + 1;
                end
            end
            DELAY: begin
                tx_done_next = 0;
                if (rom_cnt_reg == 0) begin
                    if (cnt_reg == 1500000 - 1) begin
                        cnt_next = 0;
                        state_next = IDLE;
                        rom_cnt_next = rom_cnt_reg + 1;
                    end else begin
                        cnt_next = cnt_reg + 1;
                    end
                end else begin
                    if (cnt_reg == 1000 - 1) begin
                        cnt_next = 0;
                        state_next = IDLE;
                        rom_cnt_next = rom_cnt_reg + 1;
                    end else begin
                        cnt_next = cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule
