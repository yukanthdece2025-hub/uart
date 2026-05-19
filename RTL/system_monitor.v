/**
 * @file system_monitor.v
 * @brief Real-Time Performance Monitoring Module
 * @author Yukanth Dece
 * @date 2026-05-19
 * @description Tracks system health and communication metrics
 * 
 * This module implements the MONITORING LAYER of the IACF.
 * Features:
 * - Real-time link quality calculation (0-100%)
 * - Error rate tracking
 * - Latency statistics (min, max, average)
 * - 4-level system health status
 * - Peak urgency tracking
 * - Comprehensive performance statistics
 */

module system_monitor #(
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire reset_n,
    input wire tx_active,              // Transmission in progress
    input wire rx_active,              // Reception in progress
    input wire error_detected,         // CRC or frame error
    input wire [3:0] urgency_level,
    input wire [7:0] threat_score,
    input wire [15:0] frame_latency,   // Latency for current frame
    
    output reg [7:0] link_quality,         // 0-100 %
    output reg [7:0] error_rate,           // 0-100 %
    output reg [15:0] latency_avg,
    output reg [15:0] latency_min,
    output reg [15:0] latency_max,
    output reg [1:0] system_health,        // 0=Healthy, 1=Warning, 2=Error, 3=Critical
    output reg [3:0] peak_urgency,
    output reg [31:0] total_packets,
    output reg [31:0] total_errors
);

    // ========== STATISTICS COUNTERS ==========
    reg [31:0] sample_counter;
    reg [31:0] error_counter;
    reg [31:0] latency_accumulator;
    reg [31:0] frame_counter;
    
    // Health status encoding
    localparam HEALTHY = 2'b00;
    localparam WARNING = 2'b01;
    localparam ERROR = 2'b10;
    localparam CRITICAL = 2'b11;
    
    // ========== MAIN MONITORING LOGIC ==========
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sample_counter <= 0;
            error_counter <= 0;
            latency_accumulator <= 0;
            frame_counter <= 0;
            link_quality <= 100;
            error_rate <= 0;
            system_health <= HEALTHY;
            peak_urgency <= 0;
            total_packets <= 0;
            total_errors <= 0;
            latency_min <= 16'hFFFF;
            latency_max <= 0;
            latency_avg <= 0;
        end
        else begin
            sample_counter <= sample_counter + 1;
            
            // ========== TRACK FRAME ACTIVITY ==========
            if (tx_active | rx_active) begin
                total_packets <= total_packets + 1;
                frame_counter <= frame_counter + 1;
                latency_accumulator <= latency_accumulator + frame_latency;
                
                // Track latency statistics
                if (frame_latency < latency_min)
                    latency_min <= frame_latency;
                if (frame_latency > latency_max)
                    latency_max <= frame_latency;
            end
            
            // ========== TRACK ERRORS ==========
            if (error_detected) begin
                error_counter <= error_counter + 1;
                total_errors <= total_errors + 1;
            end
            
            // ========== UPDATE PEAK URGENCY ==========
            if (urgency_level > peak_urgency)
                peak_urgency <= urgency_level;
            
            // ========== RECALCULATE METRICS PERIODICALLY ==========
            // Update every 10000 clock cycles
            if (sample_counter >= 10000) begin
                // Calculate error rate
                if (sample_counter > 0)
                    error_rate = (error_counter * 100) / (sample_counter / 100);
                else
                    error_rate = 0;
                
                // Calculate link quality
                link_quality = (error_rate > 100) ? 0 : (100 - error_rate);
                
                // ========== DETERMINE SYSTEM HEALTH ==========
                if (error_rate > 30 || threat_score > 240)
                    system_health <= CRITICAL;  // >30% errors or max threat
                else if (error_rate > 15 || threat_score > 200)
                    system_health <= ERROR;     // >15% errors or high threat
                else if (error_rate > 5 || threat_score > 150)
                    system_health <= WARNING;   // >5% errors or medium threat
                else
                    system_health <= HEALTHY;   // Normal operation
                
                // ========== CALCULATE AVERAGE LATENCY ==========
                if (frame_counter > 0)
                    latency_avg <= latency_accumulator / frame_counter;
                else
                    latency_avg <= 0;
                
                // Reset counters for next measurement window
                sample_counter <= 0;
                error_counter <= 0;
                latency_accumulator <= 0;
                frame_counter <= 0;
            end
        end
    end

endmodule
