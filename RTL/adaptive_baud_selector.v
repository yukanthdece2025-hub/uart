/**
 * @file adaptive_baud_selector.v
 * @brief Dynamic Baud Rate Selection Module
 * @author Yukanth Dece
 * @date 2026-05-19
 * @description Selects optimal baud rate based on urgency level
 * 
 * This module implements the ADAPTIVE COMMUNICATION LAYER of the IACF.
 * It provides dynamic baud rate adaptation:
 * - Urgency 0-2 → 9.6 kbps (power optimized)
 * - Urgency 3-6 → 19.2 kbps (low-medium)
 * - Urgency 7-10 → 38.4 kbps (medium)
 * - Urgency 11-13 → 57.6 kbps (medium-high)
 * - Urgency 14-15 → 115.2 kbps (critical)
 */

module adaptive_baud_selector #(
    parameter CLK_FREQ = 100_000_000  // 100 MHz default
)(
    input wire clk,
    input wire reset_n,
    input wire [3:0] urgency_level,    // 0-15, higher = more urgent
    
    output reg [19:0] baud_divider,    // Clock divider for UART
    output reg [2:0] selected_baud,    // 0-4 for 5 baud rates
    output wire [31:0] baud_rate,      // Current baud rate in bps
    output reg baud_changed            // Flag when baud rate changes
);

    // ========== BAUD RATE LOOKUP TABLE ==========
    // Divider = CLK_FREQ / BAUD_RATE / 16 (for 16x oversampling)
    localparam BAUD_9600 = CLK_FREQ / (9600 * 16);         // ~651
    localparam BAUD_19200 = CLK_FREQ / (19200 * 16);       // ~326
    localparam BAUD_38400 = CLK_FREQ / (38400 * 16);       // ~163
    localparam BAUD_57600 = CLK_FREQ / (57600 * 16);       // ~109
    localparam BAUD_115200 = CLK_FREQ / (115200 * 16);     // ~54
    
    reg [2:0] prev_baud;
    
    // ========== MAIN BAUD SELECTION LOGIC ==========
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            selected_baud <= 0;
            baud_divider <= BAUD_9600;
            prev_baud <= 0;
            baud_changed <= 0;
        end
        else begin
            prev_baud <= selected_baud;
            baud_changed <= 0;  // Default: no change
            
            // ========== SELECT BAUD RATE BASED ON URGENCY ==========
            case(urgency_level)
                4'h0, 4'h1, 4'h2: begin
                    selected_baud <= 0;
                    baud_divider <= BAUD_9600;      // 9.6 kbps - IDLE
                end
                4'h3, 4'h4, 4'h5, 4'h6: begin
                    selected_baud <= 1;
                    baud_divider <= BAUD_19200;     // 19.2 kbps - LOW-MEDIUM
                end
                4'h7, 4'h8, 4'h9, 4'hA: begin
                    selected_baud <= 2;
                    baud_divider <= BAUD_38400;     // 38.4 kbps - MEDIUM
                end
                4'hB, 4'hC, 4'hD: begin
                    selected_baud <= 3;
                    baud_divider <= BAUD_57600;     // 57.6 kbps - MEDIUM-HIGH
                end
                4'hE, 4'hF: begin
                    selected_baud <= 4;
                    baud_divider <= BAUD_115200;    // 115.2 kbps - CRITICAL
                end
                default: begin
                    selected_baud <= 0;
                    baud_divider <= BAUD_9600;
                end
            endcase
            
            // Flag if baud rate changed
            if (prev_baud != selected_baud)
                baud_changed <= 1;
        end
    end
    
    // ========== BAUD RATE OUTPUT ==========
    assign baud_rate = CLK_FREQ / baud_divider;

endmodule
