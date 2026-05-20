/**
 * @file uart_transmitter.v
 * @brief UART Transmitter Module with Configurable Baud Rate
 * @author Yukanth Dece
 * @date 2026-05-20
 * @description Implements UART serial transmission with dynamic baud rate support
 *
 * Features:
 * - 8-bit data transmission
 * - Configurable baud rate via divider input
 * - Shift register based transmission
 * - Parity support (optional)
 * - Frame format: 1 start, 8 data, 1 stop
 */

module uart_transmitter #(
    parameter DATA_WIDTH = 8,
    parameter CLK_FREQ = 100_000_000
)(
    input wire clk,
    input wire reset_n,
    
    // Data Interface
    input wire [DATA_WIDTH-1:0] data_in,
    input wire data_valid,
    output reg tx_ready,
    
    // Baud Rate Control
    input wire [19:0] baud_divider,
    
    // UART Output
    output reg uart_tx,
    output reg tx_active
);

    // ========== STATE MACHINE ==========
    localparam IDLE = 3'b000;
    localparam START = 3'b001;
    localparam DATA = 3'b010;
    localparam STOP = 3'b011;
    localparam COMPLETE = 3'b100;
    
    reg [2:0] state;
    reg [7:0] tx_data;
    reg [3:0] bit_count;
    reg [19:0] baud_counter;
    reg baud_pulse;
    
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
    
    // ========== UART TRANSMISSION STATE MACHINE ==========
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            uart_tx <= 1;  // UART idle is HIGH
            tx_ready <= 1;
            tx_active <= 0;
            bit_count <= 0;
            tx_data <= 0;
        end
        else begin
            case(state)
                IDLE: begin
                    uart_tx <= 1;
                    tx_active <= 0;
                    tx_ready <= 1;
                    
                    if (data_valid) begin
                        tx_data <= data_in;
                        bit_count <= 0;
                        state <= START;
                        tx_ready <= 0;
                        tx_active <= 1;
                    end
                end
                
                START: begin
                    // Transmit START bit (LOW)
                    if (baud_pulse) begin
                        uart_tx <= 0;  // START bit
                        state <= DATA;
                    end
                end
                
                DATA: begin
                    // Transmit 8 data bits (LSB first)
                    if (baud_pulse) begin
                        uart_tx <= tx_data[bit_count];
                        
                        if (bit_count < DATA_WIDTH - 1)
                            bit_count <= bit_count + 1;
                        else
                            state <= STOP;
                    end
                end
                
                STOP: begin
                    // Transmit STOP bit (HIGH)
                    if (baud_pulse) begin
                        uart_tx <= 1;  // STOP bit
                        state <= COMPLETE;
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
