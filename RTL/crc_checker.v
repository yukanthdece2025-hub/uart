/**
 * @file crc_checker.v
 * @brief CRC-16 Checker Module
 * @author Yukanth Dece
 * @date 2026-05-19
 * @description Implements CRC-16 (polynomial: 0xA001) for frame reception
 * 
 * POLYNOMIAL: x^16 + x^15 + x^2 + 1 (0xA001)
 * 
 * This module verifies CRC for incoming frames.
 * A valid CRC should result in 0x0000 after processing
 * both the data and the received CRC bytes.
 */

module crc_checker #(
    parameter POLYNOMIAL = 16'hA001
)(
    input wire clk,
    input wire reset_n,
    input wire [7:0] data_in,          // Input data byte
    input wire data_valid,             // Data valid strobe
    input wire crc_reset,              // Reset CRC to 0xFFFF
    
    output reg [15:0] crc_out,         // Current CRC value
    output reg crc_match,              // CRC matches (crc_out == 0x0000)
    output reg crc_valid               // CRC check complete
);

    reg [15:0] crc_reg;
    integer i;
    reg [15:0] temp_crc;
    
    // ========== CRC-16 VERIFICATION ==========
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            crc_reg <= 16'hFFFF;
            crc_out <= 16'hFFFF;
            crc_match <= 0;
            crc_valid <= 0;
        end
        else begin
            crc_valid <= 0;  // Default: no completion
            crc_match <= 0;  // Default: no match
            
            if (crc_reset) begin
                crc_reg <= 16'hFFFF;
            end
            else if (data_valid) begin
                // ========== CRC-16 POLYNOMIAL CALCULATION ==========
                temp_crc = crc_reg;
                
                // Process all 8 bits of input data
                for (i = 0; i < 8; i = i + 1) begin
                    if ((temp_crc[0] ^ data_in[i]) == 1'b1) begin
                        temp_crc = (temp_crc >> 1) ^ POLYNOMIAL;
                    end
                    else begin
                        temp_crc = temp_crc >> 1;
                    end
                end
                
                crc_reg <= temp_crc;
                crc_out <= temp_crc;
                crc_valid <= 1;
                
                // Check if CRC is valid (should be 0x0000 after processing all data + CRC bytes)
                if (temp_crc == 16'h0000) begin
                    crc_match <= 1;
                end
            end
        end
    end

endmodule
