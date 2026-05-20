/**
 * @file uart_system_top.v
 * @brief Enhanced UART System Top-Level Integration
 * @author Yukanth Dece
 * @date 2026-05-19
 * @description Integrates all UART components with IACF intelligence layers
 * 
 * This module combines:
 * 1. UART TX/RX (serial communication)
 * 2. CRC generation and checking (error detection)
 * 3. Behavior analysis (intelligence)
 * 4. Priority scheduling (adaptive)
 * 5. Baud adaptation (dynamic)
 * 6. System monitoring (performance tracking)
 */

module uart_system_top #(
    parameter CLK_FREQ = 100_000_000,
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire reset_n,
    
    // Sensor Interface
    input wire [DATA_WIDTH-1:0] sensor_data,
    input wire data_valid,
    
    // UART Serial Interface
    input wire uart_rx_in,
    output wire uart_tx_out,
    
    // Status and Control
    output wire [3:0] urgency_level,
    output wire [7:0] link_quality,
    output wire [1:0] system_health,
    output wire [31:0] total_packets,
    output wire [31:0] total_errors,
    output wire tx_busy,
    output wire rx_busy,
    output wire [7:0] rx_data,
    output wire rx_data_valid,
    output wire rx_frame_error
);

    // ========== INTERNAL SIGNALS ==========
    wire [2:0] selected_baud;
    wire [7:0] threat_score;
    wire [15:0] mean_value;
    wire tx_complete;
    wire [7:0] crc_tx_data;
    wire [15:0] crc_tx_out;
    wire crc_tx_valid;
    wire [15:0] crc_rx_out;
    wire crc_rx_match;
    wire crc_rx_valid;
    
    // ========== LAYER 1: INTELLIGENT ANALYSIS ==========
    behavior_analyzer #(
        .DATA_WIDTH(DATA_WIDTH),
        .HISTORY_DEPTH(16),
        .ANOMALY_THRESHOLD(2)
    ) behavior_inst (
        .clk(clk),
        .reset_n(reset_n),
        .sensor_data(sensor_data),
        .data_valid(data_valid),
        .urgency_level(urgency_level),
        .delta_magnitude(),
        .is_anomaly(),
        .threat_score(threat_score),
        .trend_direction(),
        .mean_value(mean_value),
        .variance(),
        .analyzer_ready()
    );
    
    // ========== LAYER 2: ADAPTIVE BAUD SELECTION ==========
    adaptive_baud_selector #(
        .CLK_FREQ(CLK_FREQ)
    ) baud_inst (
        .clk(clk),
        .reset_n(reset_n),
        .urgency_level(urgency_level),
        .baud_divider(),
        .selected_baud(selected_baud),
        .baud_rate(),
        .baud_changed()
    );
    
    // ========== LAYER 3: UART TX WITH CRC ==========
    uart_tx #(
        .CLK_FREQ(CLK_FREQ)
    ) uart_tx_inst (
        .clk(clk),
        .reset_n(reset_n),
        .baud_select(selected_baud),
        .tx_data(sensor_data),
        .tx_data_valid(data_valid),
        .uart_tx_out(uart_tx_out),
        .tx_busy(tx_busy),
        .tx_complete(tx_complete)
    );
    
    // ========== LAYER 4: UART RX WITH CRC ==========
    uart_rx #(
        .CLK_FREQ(CLK_FREQ)
    ) uart_rx_inst (
        .clk(clk),
        .reset_n(reset_n),
        .baud_select(selected_baud),
        .uart_rx_in(uart_rx_in),
        .rx_data(rx_data),
        .rx_data_valid(rx_data_valid),
        .rx_frame_error(rx_frame_error),
        .rx_busy(rx_busy)
    );
    
    // ========== LAYER 5: CRC GENERATION (TX) ==========
    crc_generator #(
        .POLYNOMIAL(16'hA001)
    ) crc_gen_inst (
        .clk(clk),
        .reset_n(reset_n),
        .data_in(sensor_data),
        .data_valid(data_valid),
        .crc_reset(!data_valid),
        .crc_out(crc_tx_out),
        .crc_valid(crc_tx_valid)
    );
    
    // ========== LAYER 6: CRC CHECKING (RX) ==========
    crc_checker #(
        .POLYNOMIAL(16'hA001)
    ) crc_chk_inst (
        .clk(clk),
        .reset_n(reset_n),
        .data_in(rx_data),
        .data_valid(rx_data_valid),
        .crc_reset(!rx_data_valid),
        .crc_out(crc_rx_out),
        .crc_match(crc_rx_match),
        .crc_valid(crc_rx_valid)
    );
    
    // ========== LAYER 7: SYSTEM MONITORING ==========
    system_monitor #(
        .DATA_WIDTH(DATA_WIDTH)
    ) monitor_inst (
        .clk(clk),
        .reset_n(reset_n),
        .tx_active(tx_busy),
        .rx_active(rx_busy),
        .error_detected(rx_frame_error | !crc_rx_match),
        .urgency_level(urgency_level),
        .threat_score(threat_score),
        .frame_latency(16'h0),
        .link_quality(link_quality),
        .error_rate(),
        .latency_avg(),
        .latency_min(),
        .latency_max(),
        .system_health(system_health),
        .peak_urgency(),
        .total_packets(total_packets),
        .total_errors(total_errors)
    );

endmodule
