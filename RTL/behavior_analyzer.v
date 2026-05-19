/**
 * @file behavior_analyzer.v
 * @brief Intelligent Data Behavior Analysis Module
 * @author Yukanth Dece
 * @date 2026-05-19
 * @description Analyzes incoming data streams for patterns, anomalies, and urgency
 * 
 * This module implements the INTELLIGENCE LAYER of the IACF architecture.
 * It performs:
 * - Delta Analysis (rate of change detection)
 * - Anomaly Detection (statistical deviation)
 * - Urgency Estimation (threat level assessment)
 * - Trend Detection (rising/falling/stable classification)
 * 
 * OUTPUTS:
 * - urgency_level [3:0]: 0=Low, 15=Critical
 * - delta_magnitude [7:0]: Rate of change magnitude
 * - is_anomaly: Statistical anomaly flag
 * - threat_score [7:0]: Composite threat score 0-255
 * - trend_direction [15:0]: Trend classification
 */

module behavior_analyzer #(
    parameter DATA_WIDTH = 8,
    parameter HISTORY_DEPTH = 16,
    parameter ANOMALY_THRESHOLD = 2  // Standard deviations
)(
    input wire clk,
    input wire reset_n,
    
    // Data Input Interface
    input wire [DATA_WIDTH-1:0] sensor_data,
    input wire data_valid,
    
    // Behavior Analysis Output
    output reg [3:0] urgency_level,      // 0=Low, 15=Critical
    output reg [7:0] delta_magnitude,    // Rate of change magnitude
    output reg is_anomaly,               // Anomaly flag
    output reg [7:0] threat_score,       // 0-255, higher = more critical
    output reg [15:0] trend_direction,   // Rising/Falling/Stable
    
    // Statistics Output
    output reg [15:0] mean_value,
    output reg [15:0] variance,
    output wire analyzer_ready
);

    // ========== HISTORY BUFFER ==========
    reg [DATA_WIDTH-1:0] data_history [0:HISTORY_DEPTH-1];
    reg [7:0] write_ptr;
    reg [7:0] sample_count;
    
    // ========== RUNNING STATISTICS ==========
    reg [23:0] sum_samples;
    reg [31:0] sum_squares;
    reg [DATA_WIDTH-1:0] min_value;
    reg [DATA_WIDTH-1:0] max_value;
    reg [DATA_WIDTH-1:0] prev_data;
    
    assign analyzer_ready = (sample_count >= 8);
    
    // ========== MAIN PROCESSING LOGIC ==========
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            write_ptr <= 0;
            sample_count <= 0;
            sum_samples <= 0;
            sum_squares <= 0;
            prev_data <= 0;
            urgency_level <= 0;
            delta_magnitude <= 0;
            is_anomaly <= 0;
            threat_score <= 0;
            trend_direction <= 16'h8000;  // Stable
            min_value <= 8'hFF;
            max_value <= 8'h00;
        end
        else if (data_valid) begin
            // ========== STORE DATA IN HISTORY ==========
            data_history[write_ptr] <= sensor_data;
            
            // ========== UPDATE STATISTICS ==========
            sum_samples <= sum_samples + sensor_data;
            sum_squares <= sum_squares + (sensor_data * sensor_data);
            
            if (sensor_data < min_value) min_value <= sensor_data;
            if (sensor_data > max_value) max_value <= sensor_data;
            
            // ========== DELTA CALCULATION ==========
            delta_magnitude <= (sensor_data > prev_data) ? 
                              (sensor_data - prev_data) : 
                              (prev_data - sensor_data);
            
            // ========== TREND DETECTION ==========
            if (sensor_data > prev_data + 5) begin
                trend_direction <= 16'hFFFF;  // Rising Spike
            end
            else if (sensor_data < prev_data - 5) begin
                trend_direction <= 16'h0000;   // Falling Spike
            end
            else begin
                trend_direction <= 16'h8000;   // Stable
            end
            
            prev_data <= sensor_data;
            write_ptr <= write_ptr + 1;
            if (sample_count < HISTORY_DEPTH)
                sample_count <= sample_count + 1;
        end
    end
    
    // ========== REAL-TIME CALCULATIONS ==========
    always @(*) begin
        // Calculate Mean
        if (sample_count > 0)
            mean_value = sum_samples / sample_count;
        else
            mean_value = 0;
        
        // Calculate Variance
        if (sample_count > 1)
            variance = (sum_squares / sample_count) - (mean_value * mean_value);
        else
            variance = 0;
    end
    
    // ========== ANOMALY DETECTION & URGENCY SCORING ==========
    always @(*) begin
        reg [15:0] temp_threat;
        reg [15:0] upper_bound;
        reg [15:0] lower_bound;
        
        // Calculate statistical bounds
        upper_bound = mean_value + (variance >> ANOMALY_THRESHOLD);
        lower_bound = mean_value - (variance >> ANOMALY_THRESHOLD);
        
        // Detect anomaly if current data is outside bounds
        is_anomaly = (prev_data > upper_bound || prev_data < lower_bound) ? 1 : 0;
        
        // ========== THREAT SCORING ==========
        temp_threat = 0;
        
        // Factor 1: Delta Magnitude (Rate of Change)
        if (delta_magnitude > 100)
            temp_threat = temp_threat + 120;  // Extreme rate of change
        else if (delta_magnitude > 50)
            temp_threat = temp_threat + 80;   // Rapid change
        else if (delta_magnitude > 25)
            temp_threat = temp_threat + 40;   // Moderate change
        
        // Factor 2: Anomaly Detection
        if (is_anomaly)
            temp_threat = temp_threat + 100;
        
        // Factor 3: Variance Analysis
        if (variance > 2000)
            temp_threat = temp_threat + 60;   // High volatility
        else if (variance > 1000)
            temp_threat = temp_threat + 40;   // Medium volatility
        
        // Normalize threat score
        threat_score = (temp_threat > 255) ? 255 : temp_threat;
        
        // ========== MAP THREAT TO URGENCY LEVEL ==========
        if (threat_score > 220)
            urgency_level = 15;  // CRITICAL
        else if (threat_score > 190)
            urgency_level = 14;  // CRITICAL
        else if (threat_score > 160)
            urgency_level = 12;  // HIGH
        else if (threat_score > 130)
            urgency_level = 11;  // HIGH
        else if (threat_score > 100)
            urgency_level = 8;   // MEDIUM
        else if (threat_score > 70)
            urgency_level = 6;   // LOW-MEDIUM
        else if (threat_score > 40)
            urgency_level = 3;   // LOW
        else
            urgency_level = 0;   // IDLE
    end

endmodule
