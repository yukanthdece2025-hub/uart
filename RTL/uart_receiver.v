/**
 * @file uart_receiver.v
 * @brief UART Receiver Module with Configurable Baud Rate
 * @author Yukanth Dece
 * @date 2026-05-20
 * @description Implements UART serial reception with dynamic baud rate support
 *
 * Features:
 * - 8-bit data reception
 * - Configurable baud rate via divider input
 * - Oversampling-based edge detection (16x oversampling)
 * - Frame format: 1 start, 8 data, 1 stop
 * - Error detection (frame error flag)
 */

module uart_receiver #(
    parameter DATA_WIDTH = 8,
    parameter CLK_FREQ = 100_000_000
)(
    input wire clk,
    input wire reset_n,
    
    // UART Input
    input wire uart_rx,
    
    // Baud Rate Control
    input wire [19:0] baud_divider,
    
    // Data Output Interface
    output reg [DATA_WIDTH-1:0] data_out,
    output reg data_valid,
    output reg frame_error,
    input wire data_ack
);

    // ========== STATE MACHINE ==========
    localparam IDLE = 3'b000;
    localparam START = 3'b001;
    localparam DATA = 3'b010;
    localparam STOP = 3'b011;
    localparam COMPLETE = 3'b100;
    
    reg [2:0] state;
    reg [7:0] rx_data;
    reg [3:0] bit_count;
    reg [19:0] baud_counter;
    reg baud_pulse;
    reg [4:0] sample_counter;  // 16x oversampling
    reg rx_sync1, rx_sync2;     // Metastability protection
    
    // ========== BAUD RATE GENERATOR ==========
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            baud_counter <= 0;
            baud_pulse <= 0;
        end
        else begin
            baud_pulse <= 0;
            if (baud_counter >= baud_divider - 1) begin
                baud_counter <= 0;
                baud_pulse <= 1;
            end
            else begin
                baud_counter <= baud_counter + 1;
            end
        end
    end
    
    // ========== SYNCHRONIZER FOR RX INPUT ==========
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            rx_sync1 <= 1;
            rx_sync2 <= 1;
        end
        else begin
            rx_sync1 <= uart_rx;
            rx_sync2 <= rx_sync1;
        end
    end
    
    // ========== UART RECEPTION STATE MACHINE ==========
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            data_valid <= 0;
            frame_error <= 0;
            bit_count <= 0;
            sample_counter <= 0;
            rx_data <= 0;
        end
        else begin
            // Clear data_valid after acknowledgment
            if (data_ack)
                data_valid <= 0;
            
            case(state)
                IDLE: begin
                    frame_error <= 0;
                    sample_counter <= 0;
                    
                    // Wait for START bit (falling edge on rx_sync2)
                    if (!rx_sync2) begin
                        state <= START;
                        baud_counter <= 0;
                    end
                end
                
                START: begin
                    // Verify START bit at middle of bit period
                    if (baud_pulse) begin
                        if (sample_counter < 7) begin
                            sample_counter <= sample_counter + 1;
                        end
                        else begin
                            if (!rx_sync2) begin
                                state <= DATA;
                                bit_count <= 0;
                                sample_counter <= 0;
                            end
                            else begin
                                state <= IDLE;  // False START
                            end
                        end
                    end
                end
                
                DATA: begin
                    // Sample 8 data bits at middle of each bit period
                    if (baud_pulse) begin
                        if (sample_counter < 7) begin
                            sample_counter <= sample_counter + 1;
                        end
                        else begin
                            rx_data[bit_count] <= rx_sync2;
                            sample_counter <= 0;
                            
                            if (bit_count < DATA_WIDTH - 1)
                                bit_count <= bit_count + 1;
                            else
                                state <= STOP;
                        end
                    end
                end
                
                STOP: begin
                    // Verify STOP bit
                    if (baud_pulse) begin
                        if (sample_counter < 7) begin
                            sample_counter <= sample_counter + 1;
                        end
                        else begin
                            if (rx_sync2) begin
                                // Valid STOP bit
                                data_out <= rx_data;
                                data_valid <= 1;
                                frame_error <= 0;
                            end
                            else begin
                                // Frame error - no STOP bit
                                frame_error <= 1;
                            end
                            state <= COMPLETE;
                            sample_counter <= 0;
                        end
                    end
                end
                
                COMPLETE: begin
                    if (baud_pulse) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
