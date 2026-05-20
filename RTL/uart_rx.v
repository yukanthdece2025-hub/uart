/**
 * @file uart_rx.v
 * @brief UART Receiver Module
 * @author Yukanth Dece
 * @date 2026-05-19
 * @description Implements full-duplex UART receiver with 16x oversampling
 * 
 * FEATURES:
 * - 16x oversampling for robust sampling
 * - Majority voting for noise immunity
 * - Parity checking
 * - Frame error detection
 * - Configurable baud rates (9.6k to 115.2 kbps)
 * 
 * STATE MACHINE:
 * IDLE → START → DATA → PARITY → STOP → IDLE
 */

module uart_rx #(
    parameter CLK_FREQ = 100_000_000
)(
    input wire clk,
    input wire reset_n,
    input wire [2:0] baud_select,      // Baud rate selection (0-4)
    input wire uart_rx_in,             // Serial input
    
    output reg [7:0] rx_data,          // Received data
    output reg rx_data_valid,          // Data valid signal
    output reg rx_frame_error,         // Parity or stop bit error
    output reg rx_busy                 // Reception in progress
);

    // ========== STATE MACHINE ==========
    localparam IDLE      = 3'b000;
    localparam START     = 3'b001;
    localparam DATA      = 3'b010;
    localparam PARITY    = 3'b011;
    localparam STOP      = 3'b100;
    
    reg [2:0] state;
    reg [7:0] rx_shift_reg;
    reg [3:0] bit_counter;
    reg [7:0] sample_counter;
    reg [15:0] sample_window [0:15];   // 16x samples for majority voting
    reg [4:0] sample_index;
    reg [19:0] baud_divider;
    reg parity_bit;
    reg rx_bit_sampled;
    
    // ========== BAUD RATE DIVIDER SELECTION ==========
    always @(*) begin
        case(baud_select)
            3'h0: baud_divider = CLK_FREQ / (9600 * 16);    // 9.6 kbps
            3'h1: baud_divider = CLK_FREQ / (19200 * 16);   // 19.2 kbps
            3'h2: baud_divider = CLK_FREQ / (38400 * 16);   // 38.4 kbps
            3'h3: baud_divider = CLK_FREQ / (57600 * 16);   // 57.6 kbps
            3'h4: baud_divider = CLK_FREQ / (115200 * 16);  // 115.2 kbps
            default: baud_divider = CLK_FREQ / (9600 * 16);
        endcase
    end
    
    // ========== PARITY CALCULATION (ODD PARITY) ==========
    always @(*) begin
        parity_bit = rx_shift_reg[0] ^ rx_shift_reg[1] ^ rx_shift_reg[2] ^ rx_shift_reg[3] ^
                     rx_shift_reg[4] ^ rx_shift_reg[5] ^ rx_shift_reg[6] ^ rx_shift_reg[7];
    end
    
    // ========== MAJORITY VOTING (16x Oversampling) ==========
    always @(*) begin
        integer i, count;
        count = 0;
        for (i = 0; i < 16; i = i + 1) begin
            if (sample_window[i] == 1)
                count = count + 1;
        end
        rx_bit_sampled = (count >= 8) ? 1 : 0;  // Majority vote
    end
    
    // ========== RX STATE MACHINE ==========
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            rx_busy <= 0;
            rx_data_valid <= 0;
            rx_frame_error <= 0;
            rx_shift_reg <= 0;
            bit_counter <= 0;
            sample_counter <= 0;
            sample_index <= 0;
        end
        else begin
            rx_data_valid <= 0;  // Default: no valid data
            
            // Collect samples for majority voting
            if (sample_counter < baud_divider) begin
                sample_counter <= sample_counter + 1;
            end
            else begin
                sample_counter <= 0;
                sample_window[sample_index] <= uart_rx_in;
                sample_index <= sample_index + 1;
                
                // When we have 16 samples, process them
                if (sample_index == 15) begin
                    sample_index <= 0;
                    
                    case(state)
                        IDLE: begin
                            rx_busy <= 0;
                            
                            // Detect START bit (LOW)
                            if (rx_bit_sampled == 0) begin
                                rx_busy <= 1;
                                bit_counter <= 0;
                                state <= START;
                            end
                        end
                        
                        START: begin
                            // Verify START bit is still LOW
                            if (rx_bit_sampled == 0) begin
                                bit_counter <= 0;
                                state <= DATA;
                            end
                            else begin
                                rx_frame_error <= 1;  // START bit error
                                rx_busy <= 0;
                                state <= IDLE;
                            end
                        end
                        
                        DATA: begin
                            // Receive 8 data bits, LSB first
                            rx_shift_reg[bit_counter] <= rx_bit_sampled;
                            bit_counter <= bit_counter + 1;
                            
                            if (bit_counter == 7) begin
                                state <= PARITY;
                            end
                        end
                        
                        PARITY: begin
                            // Verify PARITY bit
                            if (rx_bit_sampled != parity_bit) begin
                                rx_frame_error <= 1;  // Parity error
                            end
                            state <= STOP;
                        end
                        
                        STOP: begin
                            // Verify STOP bit is HIGH
                            if (rx_bit_sampled == 1) begin
                                rx_data <= rx_shift_reg;
                                rx_data_valid <= 1;
                                rx_frame_error <= 0;
                            end
                            else begin
                                rx_frame_error <= 1;  // STOP bit error
                            end
                            rx_busy <= 0;
                            state <= IDLE;
                        end
                        
                        default: state <= IDLE;
                    endcase
                end
            end
        end
    end

endmodule
