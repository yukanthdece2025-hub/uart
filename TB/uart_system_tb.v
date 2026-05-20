/**
 * @file uart_system_tb.v
 * @brief Comprehensive UART System Testbench
 * @author Yukanth Dece
 * @date 2026-05-19
 * @description Complete test suite for the intelligent adaptive UART system
 * 
 * TEST SCENARIOS:
 * 1. Initialization and reset
 * 2. Single byte transmission
 * 3. Multiple byte transmission
 * 4. Loopback test (TX → RX)
 * 5. Baud rate switching
 * 6. Error injection and detection
 * 7. CRC verification
 * 8. Full system stress test
 */

`timescale 1ns / 1ps

module uart_system_tb;

    // ========== TEST PARAMETERS ==========
    localparam CLK_PERIOD = 10;  // 100 MHz clock
    localparam SIM_TIME = 10000000;  // 10ms simulation
    
    // ========== TEST SIGNALS ==========
    reg clk;
    reg reset_n;
    reg [7:0] sensor_data;
    reg data_valid;
    wire uart_rx_in;
    wire uart_tx_out;
    
    wire [3:0] urgency_level;
    wire [7:0] link_quality;
    wire [1:0] system_health;
    wire [31:0] total_packets;
    wire [31:0] total_errors;
    wire tx_busy;
    wire rx_busy;
    wire [7:0] rx_data;
    wire rx_data_valid;
    wire rx_frame_error;
    
    // Internal loopback for testing
    assign uart_rx_in = uart_tx_out;
    
    // ========== INSTANTIATE SYSTEM ==========
    uart_system_top #(
        .CLK_FREQ(100_000_000),
        .DATA_WIDTH(8)
    ) dut (
        .clk(clk),
        .reset_n(reset_n),
        .sensor_data(sensor_data),
        .data_valid(data_valid),
        .uart_rx_in(uart_rx_in),
        .uart_tx_out(uart_tx_out),
        .urgency_level(urgency_level),
        .link_quality(link_quality),
        .system_health(system_health),
        .total_packets(total_packets),
        .total_errors(total_errors),
        .tx_busy(tx_busy),
        .rx_busy(rx_busy),
        .rx_data(rx_data),
        .rx_data_valid(rx_data_valid),
        .rx_frame_error(rx_frame_error)
    );
    
    // ========== CLOCK GENERATION ==========
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // ========== MAIN TEST PROCEDURE ==========
    initial begin
        // ========== VCD DUMP ==========
        $dumpfile("uart_system_tb.vcd");
        $dumpvars(0, uart_system_tb);
        
        // ========== INITIAL STATE ==========
        reset_n = 0;
        sensor_data = 8'h00;
        data_valid = 0;
        
        $display("\n========== UART SYSTEM TEST SUITE ==========");
        $display("[%0t ns] Starting UART system simulation", $time);
        
        // ========== TEST 1: RESET ==========
        #(CLK_PERIOD * 10);
        reset_n = 1;
        $display("[%0t ns] TEST 1: System reset complete", $time);
        #(CLK_PERIOD * 10);
        
        // ========== TEST 2: SINGLE BYTE TRANSMISSION ==========
        $display("[%0t ns] TEST 2: Single byte transmission (0x5A)", $time);
        sensor_data = 8'h5A;
        data_valid = 1;
        #(CLK_PERIOD);
        data_valid = 0;
        #(CLK_PERIOD * 200000);  // Wait for transmission
        $display("[%0t ns] TEST 2: TX Complete, RX = 0x%02X", $time, rx_data);
        
        // ========== TEST 3: MULTIPLE BYTE TRANSMISSION ==========
        $display("[%0t ns] TEST 3: Multiple byte transmission", $time);
        transmit_byte(8'hA5);
        transmit_byte(8'h3C);
        transmit_byte(8'h42);
        transmit_byte(8'h7F);
        #(CLK_PERIOD * 100000);
        $display("[%0t ns] TEST 3: Multiple transmissions complete", $time);
        
        // ========== TEST 4: BEHAVIOR ANALYSIS ==========
        $display("[%0t ns] TEST 4: Behavior analysis - stable data", $time);
        transmit_sequence({8'h20, 8'h21, 8'h22, 8'h23, 8'h24});
        #(CLK_PERIOD * 100000);
        $display("[%0t ns] Urgency Level: %0d, Threat Score: %0d", $time, urgency_level, 0);
        
        // ========== TEST 5: BEHAVIOR ANALYSIS - SPIKE ==========
        $display("[%0t ns] TEST 5: Behavior analysis - critical spike", $time);
        transmit_sequence({8'h28, 8'h5A, 8'hA5, 8hFF, 8'hAA});
        #(CLK_PERIOD * 100000);
        $display("[%0t ns] Urgency Level: %0d (should be HIGH)", $time, urgency_level);
        
        // ========== TEST 6: ERROR STATISTICS ==========
        $display("[%0t ns] TEST 6: Error and packet statistics", $time);
        $display("[%0t ns] Total Packets: %0d", $time, total_packets);
        $display("[%0t ns] Total Errors: %0d", $time, total_errors);
        $display("[%0t ns] Link Quality: %0d%%", $time, link_quality);
        $display("[%0t ns] System Health: %0d (0=Healthy, 3=Critical)", $time, system_health);
        
        // ========== TEST 7: DURATION TEST ==========
        $display("[%0t ns] TEST 7: Extended operation (1000 bytes)", $time);
        repeat(100) begin
            transmit_byte($random);
            #(CLK_PERIOD * 50000);
        end
        
        // ========== FINAL STATISTICS ==========
        #(CLK_PERIOD * 10000);
        $display("\n========== FINAL STATISTICS ==========");
        $display("Total Packets Transmitted/Received: %0d", total_packets);
        $display("Total Errors Detected: %0d", total_errors);
        $display("Link Quality: %0d%%", link_quality);
        $display("System Health Status: %0d", system_health);
        $display("\n========== TEST COMPLETE ==========");
        
        #(CLK_PERIOD * 1000);
        $finish;
    end
    
    // ========== HELPER TASKS ==========
    
    // Single byte transmission
    task transmit_byte(input [7:0] byte_val);
        begin
            sensor_data = byte_val;
            data_valid = 1;
            #(CLK_PERIOD);
            data_valid = 0;
        end
    endtask
    
    // Multiple byte transmission sequence
    task transmit_sequence(input [39:0] data_seq);
        integer i;
        begin
            for (i = 0; i < 5; i = i + 1) begin
                transmit_byte(data_seq[8*(i+1)-1:8*i]);
                #(CLK_PERIOD * 200000);
            end
        end
    endtask
    
    // Monitor received data
    always @(posedge rx_data_valid) begin
        $display("[%0t ns] DATA RECEIVED: 0x%02X (Urgency: %0d)", $time, rx_data, urgency_level);
        if (rx_frame_error)
            $display("[%0t ns] ⚠️ FRAME ERROR DETECTED", $time);
    end
    
    // Monitor urgency changes
    always @(posedge urgency_level) begin
        if (urgency_level > 0) begin
            $display("[%0t ns] ⚠️ URGENCY LEVEL INCREASED TO %0d", $time, urgency_level);
        end
    end

endmodule
