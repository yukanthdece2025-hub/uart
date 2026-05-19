/**
 * @file adaptive_priority_scheduler.v
 * @brief Dynamic Priority Scheduling Engine
 * @author Yukanth Dece
 * @date 2026-05-19
 * @description Implements behavior-driven packet scheduling with deadline awareness
 * 
 * This module implements the SCHEDULING LAYER of the IACF architecture.
 * Features:
 * - Dynamic priority queue management
 * - Deadline-aware packet scheduling
 * - Preemptive scheduling for critical packets
 * - Age-based priority boost to prevent starvation
 * - Real-time queue statistics
 * 
 * SCHEDULING PRIORITY FORMULA:
 * Weighted_Priority = (Urgency × 1000) + (Deadline × 10) + (Wait_Age / 100)
 */

module adaptive_priority_scheduler #(
    parameter QUEUE_DEPTH = 32,
    parameter PACKET_WIDTH = 32
)(
    input wire clk,
    input wire reset_n,
    input wire enqueue,
    input wire dequeue,
    input wire [PACKET_WIDTH-1:0] packet_in,
    input wire [3:0] priority_in,      // 0-15, higher = more urgent
    input wire [15:0] deadline_in,     // Clock cycles until deadline
    
    output reg [PACKET_WIDTH-1:0] packet_out,
    output reg [3:0] priority_out,
    output wire queue_empty,
    output wire queue_full,
    output reg [7:0] queue_count,
    output reg [3:0] max_priority_pending,
    output reg [7:0] avg_wait_time
);

    // ========== QUEUE STORAGE ==========
    reg [PACKET_WIDTH-1:0] queue [0:QUEUE_DEPTH-1];
    reg [3:0] priority_queue [0:QUEUE_DEPTH-1];
    reg [15:0] deadline_queue [0:QUEUE_DEPTH-1];
    reg [15:0] age_counter [0:QUEUE_DEPTH-1];     // Wait time counter
    
    reg [7:0] head, tail;
    integer i, j, min_idx;
    reg [15:0] temp_priority, min_priority;
    
    assign queue_empty = (queue_count == 0);
    assign queue_full = (queue_count == QUEUE_DEPTH);
    
    // ========== MAIN PROCESSING ==========
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            head <= 0;
            tail <= 0;
            queue_count <= 0;
            max_priority_pending <= 0;
            avg_wait_time <= 0;
        end
        else begin
            // ========== INCREMENT AGE FOR ALL PACKETS ==========
            for (i = 0; i < QUEUE_DEPTH; i = i + 1) begin
                if (age_counter[i] > 0)
                    age_counter[i] <= age_counter[i] + 1;  // Age increases over time
            end
            
            // ========== ENQUEUE OPERATION ==========
            if (enqueue && !queue_full) begin
                queue[tail] <= packet_in;
                priority_queue[tail] <= priority_in;
                deadline_queue[tail] <= deadline_in;
                age_counter[tail] <= 1;  // Start aging counter
                
                tail <= (tail + 1) % QUEUE_DEPTH;
                queue_count <= queue_count + 1;
            end
            
            // ========== DEQUEUE OPERATION ==========
            if (dequeue && !queue_empty) begin
                // Find highest priority packet (preemptive scheduling)
                min_idx = 0;
                min_priority = 0;
                
                for (i = 0; i < queue_count; i = i + 1) begin
                    // Weighted priority calculation
                    temp_priority = (priority_queue[(head + i) % QUEUE_DEPTH] * 1000) +
                                   (deadline_queue[(head + i) % QUEUE_DEPTH] * 10) +
                                   (age_counter[(head + i) % QUEUE_DEPTH] / 100);
                    
                    if (temp_priority > min_priority) begin
                        min_priority = temp_priority;
                        min_idx = i;
                    end
                end
                
                // Output the highest priority packet
                packet_out <= queue[(head + min_idx) % QUEUE_DEPTH];
                priority_out <= priority_queue[(head + min_idx) % QUEUE_DEPTH];
                
                // Remove selected packet from queue
                for (i = min_idx; i < queue_count - 1; i = i + 1) begin
                    queue[(head + i) % QUEUE_DEPTH] <= queue[(head + i + 1) % QUEUE_DEPTH];
                    priority_queue[(head + i) % QUEUE_DEPTH] <= priority_queue[(head + i + 1) % QUEUE_DEPTH];
                    deadline_queue[(head + i) % QUEUE_DEPTH] <= deadline_queue[(head + i + 1) % QUEUE_DEPTH];
                    age_counter[(head + i) % QUEUE_DEPTH] <= age_counter[(head + i + 1) % QUEUE_DEPTH];
                end
                
                queue_count <= queue_count - 1;
            end
        end
    end
    
    // ========== PRIORITY & STATISTICS CALCULATION ==========
    always @(*) begin
        reg [15:0] total_wait;
        
        // Find maximum priority pending
        max_priority_pending = 0;
        total_wait = 0;
        
        for (i = 0; i < queue_count; i = i + 1) begin
            if (priority_queue[(head + i) % QUEUE_DEPTH] > max_priority_pending)
                max_priority_pending = priority_queue[(head + i) % QUEUE_DEPTH];
            total_wait = total_wait + age_counter[(head + i) % QUEUE_DEPTH];
        end
        
        // Calculate average wait time
        if (queue_count > 0)
            avg_wait_time = total_wait / queue_count;
        else
            avg_wait_time = 0;
    end

endmodule
