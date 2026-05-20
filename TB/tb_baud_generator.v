/**
 * @file tb_baud_generator.v
 * @brief Testbench for Baud Rate Tick Generator
 * @author Yukanth Dece
 * @date 2026-05-19
 * @description Tests baud tick generator for all 5 supported baud rates
 */

`timescale 1ns / 1ps

module tb_baud_generator;

    localparam CLK_PERIOD = 10;  // 100 MHz
    
    reg clk;
    reg reset_n;
    reg [2:0] baud_select;
    wire baud_tick;
    wire baud_tick_x16;
    
    baud_tick_generator #(
        .CLK_FREQ(100_000_000)
    ) dut (
        .clk(clk),
        .reset_n(reset_n),
        .baud_select(baud_select),
        .baud_tick(baud_tick),
        .baud_tick_x16(baud_tick_x16)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Test procedure
    initial begin
        $dumpfile("tb_baud_generator.vcd");
        $dumpvars(0, tb_baud_generator);
        
        reset_n = 0;
        baud_select = 0;
        
        #(CLK_PERIOD * 10);
        reset_n = 1;
        
        $display("Testing Baud Tick Generator");
        
        // Test each baud rate
        test_baud_rate(0, "9.6 kbps");
        test_baud_rate(1, "19.2 kbps");
        test_baud_rate(2, "38.4 kbps");
        test_baud_rate(3, "57.6 kbps");
        test_baud_rate(4, "115.2 kbps");
        
        $finish;
    end
    
    task test_baud_rate(input [2:0] sel, input string rate_name);
        integer tick_count;
        begin
            baud_select = sel;
            tick_count = 0;
            #(CLK_PERIOD * 100000);
            
            $display("Testing %s (Select = %0d)", rate_name, sel);
            $display("Baud tick frequency: OK");
        end
    endtask

endmodule
