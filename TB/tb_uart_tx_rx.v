/**
 * @file tb_uart_tx_rx.v
 * @brief Testbench for UART TX/RX with Loopback
 * @author Yukanth Dece
 * @date 2026-05-19
 * @description Tests UART transmitter and receiver with loopback connection
 */

`timescale 1ns / 1ps

module tb_uart_tx_rx;

    localparam CLK_PERIOD = 10;  // 100 MHz
    localparam TEST_BYTES = 8;
    
    reg clk;
    reg reset_n;
    reg [2:0] baud_select;
    reg [7:0] tx_data;
    reg tx_data_valid;
    wire uart_tx_out;
    wire tx_busy;
    wire tx_complete;
    
    wire [7:0] rx_data;
    wire rx_data_valid;
    wire rx_frame_error;
    wire rx_busy;
    
    // Internal loopback
    wire uart_rx_in = uart_tx_out;
    
    // Instantiate TX
    uart_tx #(
        .CLK_FREQ(100_000_000)
    ) tx_inst (
        .clk(clk),
        .reset_n(reset_n),
        .baud_select(baud_select),
        .tx_data(tx_data),
        .tx_data_valid(tx_data_valid),
        .uart_tx_out(uart_tx_out),
        .tx_busy(tx_busy),
        .tx_complete(tx_complete)
    );
    
    // Instantiate RX
    uart_rx #(
        .CLK_FREQ(100_000_000)
    ) rx_inst (
        .clk(clk),
        .reset_n(reset_n),
        .baud_select(baud_select),
        .uart_rx_in(uart_rx_in),
        .rx_data(rx_data),
        .rx_data_valid(rx_data_valid),
        .rx_frame_error(rx_frame_error),
        .rx_busy(rx_busy)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Test procedure
    initial begin
        $dumpfile("tb_uart_tx_rx.vcd");
        $dumpvars(0, tb_uart_tx_rx);
        
        reset_n = 0;
        tx_data_valid = 0;
        baud_select = 0;  // 9.6 kbps
        
        #(CLK_PERIOD * 20);
        reset_n = 1;
        
        $display("\n========== UART TX/RX LOOPBACK TEST ==========");
        $display("Testing at 9.6 kbps");
        
        // Send test bytes
        transmit_and_verify(8'h00, "0x00 - NULL");
        transmit_and_verify(8'h55, "0x55 - Pattern1");
        transmit_and_verify(8'hAA, "0xAA - Pattern2");
        transmit_and_verify(8'hFF, "0xFF - MAX");
        transmit_and_verify(8'h3C, "0x3C - Random");
        
        $display("========== TEST COMPLETE ==========");
        #(CLK_PERIOD * 10000);
        $finish;
    end
    
    task transmit_and_verify(input [7:0] test_byte, input string desc);
        begin
            $display("Transmitting: %s", desc);
            tx_data = test_byte;
            tx_data_valid = 1;
            #(CLK_PERIOD);
            tx_data_valid = 0;
            
            // Wait for transmission and reception
            wait(tx_complete);
            $display("  ✓ TX Complete");
            
            wait(rx_data_valid);
            $display("  ✓ RX Complete: 0x%02X", rx_data);
            
            if (rx_data == test_byte) begin
                $display("  ✓ DATA MATCH - PASS");
            end
            else begin
                $display("  ✗ DATA MISMATCH - FAIL (Expected: 0x%02X, Got: 0x%02X)", test_byte, rx_data);
            end
            
            if (rx_frame_error) begin
                $display("  ⚠️ Frame error detected");
            end
            
            #(CLK_PERIOD * 50000);
        end
    endtask

endmodule
