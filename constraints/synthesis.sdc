# ========== Synopsys Design Constraints (SDC) File ==========
# Created for RTL-to-GDS2 flow of Intelligent Adaptive UART
# Author: Yukanth Dece
# Date: 2026-05-20

# ========== CLOCK DEFINITION ==========
set CLK_PERIOD 10.0
set CLK_FREQ 100

# Define main clock
create_clock -name clk -period $CLK_PERIOD [get_ports clk]

# Set clock uncertainty (jitter + skew)
set_clock_uncertainty 0.2 [get_clocks clk]

# ========== INPUT/OUTPUT TIMING CONSTRAINTS ==========

# Sensor data input - setup/hold requirements
set_input_delay -clock clk -max 2.0 [get_ports sensor_data]
set_input_delay -clock clk -min 0.5 [get_ports sensor_data]

# Data valid signal
set_input_delay -clock clk -max 2.0 [get_ports data_valid]
set_input_delay -clock clk -min 0.5 [get_ports data_valid]

# UART RX input with async characteristics
set_input_delay -clock clk -max 3.0 [get_ports uart_rx]
set_input_delay -clock clk -min 0.5 [get_ports uart_rx]

# UART TX output
set_output_delay -clock clk -max 2.0 [get_ports uart_tx]
set_output_delay -clock clk -min -0.5 [get_ports uart_tx]

# Status outputs
set_output_delay -clock clk -max 2.0 [get_ports {urgency_level link_quality system_health}]
set_output_delay -clock clk -min -0.5 [get_ports {urgency_level link_quality system_health}]

# ========== RESET CONSTRAINTS ==========
set_false_path -from [get_ports reset_n]

# ========== ASYNCHRONOUS TIMING PATHS ==========

# UART RX is asynchronous - no timing requirements
set_false_path -to [get_pins */uart_rx_sync1/D]

# No path through async reset
set_false_path -through [get_pins */reset_n]

# ========== AREA & POWER CONSTRAINTS ==========

# Set maximum area (in square microns)
set_max_area 50000

# Optimize for low power with leak power consideration
set_leakage_power_constraint 5000

# ========== CLOCK GATING CONSTRAINTS ==========

# Allow clock gating for power optimization
set_clock_gating_style -setup 0.5 -hold 0 [get_clocks clk]

# ========== DRIVER & LOAD INFORMATION ==========

# Assume typical IO buffer driving capability
set_driving_cell -lib_cell BUFX1 -pin Y [get_ports clk]
set_driving_cell -lib_cell BUFX1 -pin Y [get_ports reset_n]
set_driving_cell -lib_cell BUFX1 -pin Y [get_ports sensor_data]
set_driving_cell -lib_cell BUFX1 -pin Y [get_ports data_valid]

# Output load capacitance
set_load 0.5 [get_ports uart_tx]
set_load 0.5 [get_ports {urgency_level link_quality}]

# ========== MULTICYCLE PATHS (if needed) ==========

# UART baud counter may be multicycle
set_multicycle_path 10 -from [get_cells */baud_counter_reg*] -to [get_cells */baud_pulse_reg]

# ========== PROPAGATION DELAY CONSTRAINTS ==========

# Critical path: Sensor data -> Urgency level (must be < 9ns for setup margin)
set_max_delay 9.0 -from [get_ports sensor_data] -to [get_ports urgency_level]

# UART TX critical path
set_max_delay 8.0 -from [get_ports sensor_data] -to [get_ports uart_tx]

# ========== HOLD TIME CONSTRAINTS ==========

# Minimum delay through critical logic blocks
set_min_delay 0.1 -from [get_ports sensor_data] -to [get_ports urgency_level]

# ========== POWER OPTIMIZATION ==========

# Set power supply voltage (typical)
set_operating_conditions -voltage 3.3

# Temperature range
set_operating_temperature -min 0 -max 70

# ========== PLACEMENT CONSTRAINTS (if needed for P&R) ==========

# Group related cells for better placement
# Behavior analyzer should be close to baud selector
# set_cluster_cells {behavior_analyzer_cells}

# ========== ROUTING CONSTRAINTS ==========

# High-speed UART TX/RX should use metal layers 2-3
# set_routing_layers -min 2 -max 3 [get_nets uart_tx uart_rx]

# ========== INTERFACE TIMING ==========

# Typical external clock to Q (output register to pin)
# For IOPad cell: 1.5ns typical
set_output_delay -clock clk -max 1.5 [get_ports uart_tx]

# Typical external setup time (input pin to register)
# For IOPad cell: 0.5ns typical  
set_input_delay -clock clk -min 0.5 [get_ports uart_rx]

# ========== LINT & VERIFICATION CONSTRAINTS ==========

# Check for timing violations
check_design

# Report all paths that violate constraints
report_constraint -all_violators

echo "SDC file loaded successfully for $CLK_FREQ MHz design"
