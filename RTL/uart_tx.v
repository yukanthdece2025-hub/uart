/**
 * @file uart_tx.v
 * @brief UART Transmitter Module
 * @author Yukanth Dece
 * @date 2026-05-19
 * @description Implements full-duplex UART transmitter with configurable baud rate
 * 
 * FRAME FORMAT: 1 Start + 8 Data + 1 Parity (optional) + 1 Stop = 10-11 bits
 * BAUD RATES: 9.6k to 115.2 kbps (5 selectable)
 * 
 * STATE MACHINE:
 * IDLE → TRANSMIT → PARITY → STOP → IDLE
 */

module uart_tx #(
    parameter CLK_FREQ = 100_000_000
)(
    input wire clk,
    input wire reset_n,
    input wire [2:0] baud_select,      // Baud rate selection (0-4)
    input wire [7:0] tx_data,          // Data to transmit
    input wire tx_data_valid,          // Data valid signal (load data)
    
    output reg uart_tx_out,            // Serial output
    output reg tx_busy,                // Transmission in progress
    output reg tx_complete             // Frame sent
);

    // ========== STATE MACHINE ==========
    localparam IDLE      = 3'b000;
    localparam START     = 3'b001;
    localparam DATA      = 3'b010;
    localparam PARITY    = 3'b011;
    localparam STOP      = 3'b100;
    
    reg [2:0] state;
    reg [7:0] tx_shift_reg;
    reg [3:0] bit_counter;
    reg [19:0] cycle_counter;
    reg [19:0] baud_divider;
    reg parity_bit;
    
    // ========== BAUD RATE DIVIDER SELECTION ==========
    always @(*) begin
        case(baud_select)
            3'h0: baud_divider = CLK_FREQ / 9600;       // 9.6 kbps
            3'h1: baud_divider = CLK_FREQ / 19200;      // 19.2 kbps
            3'h2: baud_divider = CLK_FREQ / 38400;      // 38.4 kbps
            3'h3: baud_divider = CLK_FREQ / 57600;      // 57.6 kbps
            3'h4: baud_divider = CLK_FREQ / 115200;     // 115.2 kbps
            default: baud_divider = CLK_FREQ / 9600;
        endcase
    end
    
    // ========== PARITY CALCULATION (ODD PARITY) ==========
    always @(*) begin
        parity_bit = tx_shift_reg[0] ^ tx_shift_reg[1] ^ tx_shift_reg[2] ^ tx_shift_reg[3] ^
                     tx_shift_reg[4] ^ tx_shift_reg[5] ^ tx_shift_reg[6] ^ tx_shift_reg[7];
    end
    
    // ========== TX STATE MACHINE ==========
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            uart_tx_out <= 1;  // Idle state = HIGH
            tx_busy <= 0;
            tx_complete <= 0;
            tx_shift_reg <= 0;
            bit_counter <= 0;
            cycle_counter <= 0;
        end
        else begin
            tx_complete <= 0;  // Default: no completion
            
            case(state)
                IDLE: begin
                    uart_tx_out <= 1;  // Line idle
                    tx_busy <= 0;
                    cycle_counter <= 0;
                    
                    // Load data when valid signal received
                    if (tx_data_valid) begin
                        tx_shift_reg <= tx_data;
                        tx_busy <= 1;
                        state <= START;
                    end
                end
                
                START: begin
                    // Send START bit (LOW)
                    uart_tx_out <= 0;
                    cycle_counter <= cycle_counter + 1;
                    
                    // Hold start bit for one bit period
                    if (cycle_counter >= baud_divider) begin
                        cycle_counter <= 0;
                        bit_counter <= 0;
                        state <= DATA;
                    end
                end
                
                DATA: begin
                    // Send 8 data bits, LSB first
                    uart_tx_out <= tx_shift_reg[0];
                    cycle_counter <= cycle_counter + 1;
                    
                    if (cycle_counter >= baud_divider) begin
                        cycle_counter <= 0;
                        tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};  // Shift right
                        bit_counter <= bit_counter + 1;
                        
                        if (bit_counter == 7) begin
                            state <= PARITY;
                        end
                    end
                end
                
                PARITY: begin
                    // Send PARITY bit
                    uart_tx_out <= parity_bit;
                    cycle_counter <= cycle_counter + 1;
                    
                    if (cycle_counter >= baud_divider) begin
                        cycle_counter <= 0;
                        state <= STOP;
                    end
                end
                
                STOP: begin
                    // Send STOP bit (HIGH) - 1 bit period
                    uart_tx_out <= 1;
                    cycle_counter <= cycle_counter + 1;
                    
                    if (cycle_counter >= baud_divider) begin
                        cycle_counter <= 0;
                        tx_complete <= 1;
                        tx_busy <= 0;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
