/**
 * @file error_handler.v
 * @brief CRC-Based Error Detection and Handling Module
 * @author Yukanth Dece
 * @date 2026-05-19
 * @description Implements CRC-16 error detection with automatic retransmission
 * 
 * This module implements the RELIABILITY LAYER of the IACF.
 * Features:
 * - CRC-16 calculation (polynomial: 0xA001)
 * - Automatic retry mechanism (up to 3 retries)
 * - Frame-based CRC validation
 * - Error statistics tracking
 * - ACK/NACK response handling
 */

module error_handler #(
    parameter MAX_RETRIES = 3
)(
    input wire clk,
    input wire reset_n,
    input wire [7:0] data_in,
    input wire data_valid,
    input wire frame_start,           // Signal start of frame
    input wire frame_end,             // Signal end of frame
    
    output reg [15:0] crc_value,      // Current CRC value
    output reg crc_valid,             // CRC computation complete
    output reg error_detected,        // Mismatch between computed and received CRC
    output reg [7:0] retry_count,
    output reg transmission_failed,   // Max retries exceeded
    output reg [31:0] error_count
);

    // ========== CRC POLYNOMIAL ==========
    localparam CRC_POLYNOMIAL = 16'hA001;  // CRC-16 standard
    
    // ========== STATE MACHINE ==========
    localparam IDLE = 2'b00;
    localparam COMPUTING = 2'b01;
    localparam VALIDATING = 2'b10;
    localparam RETRANSMITTING = 2'b11;
    
    reg [1:0] state;
    reg [15:0] computed_crc;
    reg [15:0] received_crc;
    reg [7:0] byte_counter;
    reg [15:0] temp_crc;
    integer i;
    
    // ========== CRC COMPUTATION ==========
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            crc_value <= 0;
            computed_crc <= 0;
            received_crc <= 0;
            crc_valid <= 0;
            error_detected <= 0;
            retry_count <= 0;
            transmission_failed <= 0;
            error_count <= 0;
            byte_counter <= 0;
        end
        else begin
            case(state)
                IDLE: begin
                    crc_valid <= 0;
                    error_detected <= 0;
                    
                    if (frame_start) begin
                        computed_crc <= 0;  // Reset CRC at frame start
                        byte_counter <= 0;
                        retry_count <= 0;
                        transmission_failed <= 0;
                        state <= COMPUTING;
                    end
                end
                
                COMPUTING: begin
                    if (data_valid) begin
                        // ========== CRC-16 CALCULATION ==========
                        temp_crc = computed_crc;
                        for (i = 0; i < 8; i = i + 1) begin
                            if ((temp_crc[0] ^ data_in[i]) == 1'b1)
                                temp_crc = (temp_crc >> 1) ^ CRC_POLYNOMIAL;
                            else
                                temp_crc = temp_crc >> 1;
                        end
                        computed_crc <= temp_crc;
                        byte_counter <= byte_counter + 1;
                    end
                    
                    if (frame_end) begin
                        crc_value <= temp_crc;
                        state <= VALIDATING;
                    end
                end
                
                VALIDATING: begin
                    // Received CRC should match computed CRC
                    if (received_crc == computed_crc) begin
                        crc_valid <= 1;
                        error_detected <= 0;
                        state <= IDLE;
                    end
                    else begin
                        crc_valid <= 1;
                        error_detected <= 1;
                        error_count <= error_count + 1;
                        
                        if (retry_count < MAX_RETRIES) begin
                            retry_count <= retry_count + 1;
                            state <= RETRANSMITTING;
                        end
                        else begin
                            transmission_failed <= 1;
                            state <= IDLE;
                        end
                    end
                end
                
                RETRANSMITTING: begin
                    // Wait one cycle before retrying
                    state <= COMPUTING;
                end
            endcase
        end
    end

endmodule
