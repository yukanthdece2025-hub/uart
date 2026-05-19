# IACF Architecture Documentation

## System Overview

The Intelligent Adaptive Communication Framework (IACF) is a 5-layer architecture for behavior-aware, real-time adaptive communication over UART.

## Layer 1: Intelligence Layer (Behavior Analyzer)

### Purpose
Analyzes incoming data streams to extract behavioral patterns and estimate urgency.

### Key Functions
- **Delta Analysis**: Calculates rate of change (dV/dt)
- **Anomaly Detection**: Uses Z-score statistical analysis
- **Trend Detection**: Classifies patterns as rising, falling, or stable
- **Threat Scoring**: Combines multiple factors into 0-255 threat level

### Output
- `urgency_level [3:0]`: 0=Low, 15=Critical
- `threat_score [7:0]`: 0-255 composite threat
- `delta_magnitude [7:0]`: Rate of change
- `is_anomaly`: Statistical anomaly flag
- `trend_direction [15:0]`: Pattern classification

### Threat Calculation Formula
```
Threat = (Delta_Factor × Weight_1) + 
         (Anomaly_Factor × Weight_2) +
         (Variance_Factor × Weight_3)
```

Where:
- Delta_Factor: 0-120 based on rate of change
- Anomaly_Factor: 0-100 if statistical anomaly detected
- Variance_Factor: 0-60 based on data volatility

## Layer 2: Scheduling Layer (Adaptive Priority Scheduler)

### Purpose
Implements intelligent packet scheduling with deadline awareness.

### Features
- **Dynamic Priority Queue**: 32-packet buffer with real-time sorting
- **Preemptive Scheduling**: Critical packets bypass normal queue
- **Deadline Awareness**: Time-sensitive packets prioritized
- **Starvation Prevention**: Age-based priority boost for waiting packets

### Priority Formula
```
Weighted_Priority = (Urgency × 1000) + (Deadline × 10) + (Wait_Age / 100)
```

This ensures:
- Urgent data gets immediate transmission
- Deadline-critical packets don't miss windows
- Aging prevents low-priority packets from starving

## Layer 3: Communication Layer (Adaptive UART)

### Purpose
Adapts transmission parameters based on urgency and system state.

### Baud Rate Adaptation
```
Urgency Level → Baud Rate Mapping:

0-2    → 9.6 kbps   (IDLE - Power optimized)
3-6    → 19.2 kbps  (LOW-MEDIUM)
7-10   → 38.4 kbps  (MEDIUM)
11-13  → 57.6 kbps  (MEDIUM-HIGH)
14-15  → 115.2 kbps (CRITICAL - Maximum)
```

### Benefits
- **Power Efficiency**: Low baud for non-critical data
- **Latency Optimization**: High baud for urgent data
- **Bandwidth Adaptation**: Matches communication to need
- **Graceful Degradation**: Maintains operation under load

## Layer 4: Reliability Layer (Error Handler)

### Purpose
Ensures reliable frame transmission with error detection and recovery.

### Implementation
- **CRC-16 Calculation**: Polynomial 0xA001 for error detection
- **Automatic Retry**: Up to 3 retransmission attempts
- **ACK/NACK Handling**: Confirms successful receipt
- **Error Statistics**: Tracks cumulative errors

### CRC-16 Algorithm
```verilog
for i = 0 to 7:
    if (CRC[0] XOR Data[i]) == 1:
        CRC = (CRC >> 1) XOR 0xA001
    else:
        CRC = CRC >> 1
```

## Layer 5: Monitoring Layer (System Monitor)

### Purpose
Provides real-time visibility into system health and performance.

### Metrics Tracked
- **Link Quality**: 0-100% based on error rate
- **Error Rate**: Percentage of frames with errors
- **Latency Statistics**: Min, max, average transmission time
- **System Health**: 4-level status (Healthy/Warning/Error/Critical)
- **Peak Urgency**: Maximum urgency level observed
- **Total Packets/Errors**: Cumulative statistics

### Health Status Determination
```
Healthy:   error_rate < 5%  AND threat_score < 100
Warning:   error_rate 5-15% OR threat_score 100-150
Error:     error_rate 15-30% OR threat_score 150-200
Critical:  error_rate > 30% OR threat_score > 200
```

## Performance Characteristics

### Latency
- **Decision Latency**: < 1 µs (behavior analysis)
- **Scheduling Latency**: < 5 µs (priority calculation)
- **Transmission Latency**: Variable with baud rate
  - 9.6 kbps: ~8.3 ms per byte
  - 115.2 kbps: ~0.69 ms per byte

### Throughput
- **Theoretical Maximum**: 115.2 kbps (critical urgency)
- **Average Normal**: 38.4 kbps (mixed priority)
- **Power-Optimized**: 9.6 kbps (idle state)

### Resource Usage
- **Logic Gates**: ~15,000 (estimated)
- **Memory**: 1.5 KB (queues + history buffers)
- **Power**: 50-200 mW typical (depends on baud rate)
