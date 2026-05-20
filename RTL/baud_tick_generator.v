/**
 * @file baud_tick_generator.v
 * @brief Programmable Baud Rate Clock Generator
 * @author Yukanth Dece
 * @date 2026-05-19
 * @description Generates baud tick signals for all supported baud rates
 * 
 * This module generates timing pulses for UART TX/RX operations.
 * Supports 5 baud rates with 16x oversampling for accurate sampling.
 * 
 * SUPPORTED BAUD RATES:
 * - 9,600 bps
 * - 19,200 bps
 * - 38,400 bps
 * - 57,600 bps
 * - 115,200 bps
 */

module baud_tick_generator #(
    parameter CLK_FREQ = 100_000_000  // 100 MHz system clock
)(
    input wire clk,
    input wire reset_n,
    input wire [2:0] baud_select,     // 0-4 selects baud rate
    
    output reg baud_tick,              // Single tick per baud period
    output reg baud_tick_x16           // 16x oversampling clock
);

    // ========== BAUD RATE CONFIGURATION ==========
    // Divider = CLK_FREQ / (BAUD_RATE * 16)
    localparam DIV_9600   = CLK_FREQ / (9600 * 16);      // ~651
    localparam DIV_19200  = CLK_FREQ / (19200 * 16);     // ~326
    localparam DIV_38400  = CLK_FREQ / (38400 * 16);     // ~163
    localparam DIV_57600  = CLK_FREQ / (57600 * 16);     // ~109
    localparam DIV_115200 = CLK_FREQ / (115200 * 16);    // ~54
    
    reg [19:0] baud_divider;
    reg [19:0] tick_counter;
    reg [3:0] oversample_counter;
    
    // ========== SELECT BAUD DIVIDER ==========
    always @(*) begin
        case(baud_select)
            3'h0: baud_divider = DIV_9600;
            3'h1: baud_divider = DIV_19200;
            3'h2: baud_divider = DIV_38400;
            3'h3: baud_divider = DIV_57600;
            3'h4: baud_divider = DIV_115200;
            default: baud_divider = DIV_9600;
        endcase
    end
    
    // ========== TICK GENERATION ==========
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            tick_counter <= 0;
            oversample_counter <= 0;
            baud_tick <= 0;
            baud_tick_x16 <= 0;
        end
        else begin
            baud_tick <= 0;  // Default: no tick
            baud_tick_x16 <= 0;
            
            if (tick_counter >= baud_divider) begin
                tick_counter <= 0;
                baud_tick_x16 <= 1;  // 16x oversampling tick
                
                // Generate main baud tick every 16 cycles
                if (oversample_counter == 15) begin
                    baud_tick <= 1;
                    oversample_counter <= 0;
                end
                else begin
                    oversample_counter <= oversample_counter + 1;
                end
            end
            else begin
                tick_counter <= tick_counter + 1;
            end
        end
    end

endmodule
