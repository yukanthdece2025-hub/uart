/**
 * @file crc_generator.v
 * @brief CRC-16 Generator Module
 * @author Yukanth Dece
 * @date 2026-05-19
 * @description Implements CRC-16 (polynomial: 0xA001) for frame transmission
 * 
 * POLYNOMIAL: x^16 + x^15 + x^2 + 1 (0xA001)
 * 
 * This module calculates CRC for outgoing frames to ensure
 * data integrity during transmission.
 */

module crc_generator #(
    parameter POLYNOMIAL = 16'hA001
)(
    input wire clk,
    input wire reset_n,
    input wire [7:0] data_in,          // Input data byte
    input wire data_valid,             // Data valid strobe
    input wire crc_reset,              // Reset CRC to 0xFFFF
    
    output reg [15:0] crc_out,         // Current CRC value
    output reg crc_valid               // CRC calculation complete
);

    reg [15:0] crc_reg;
    integer i;
    reg [15:0] temp_crc;
    
    // ========== CRC CALCULATION ==========
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            crc_reg <= 16'hFFFF;
            crc_out <= 16'hFFFF;
            crc_valid <= 0;
        end
        else begin
            crc_valid <= 0;  // Default: no completion
            
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
            end
        end
    end

endmodule
