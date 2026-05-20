#!/bin/bash
# ========== Simulation Runner Script ==========
# Compiles and runs the complete UART testbench
# Author: Yukanth Dece
# Date: 2026-05-20

set -e  # Exit on error

echo "========== INTELLIGENT ADAPTIVE UART TESTBENCH =========="
echo "Compiling RTL modules and testbenches..."
echo ""

# Create simulation directory
mkdir -p sim_output
cd sim_output

# Compile RTL modules
echo "[1/5] Compiling behavior_analyzer.v..."
iverilog -o iacf.vvp ../RTL/behavior_analyzer.v

echo "[2/5] Compiling adaptive_baud_selector.v..."
iverilog -o iacf.vvp ../RTL/adaptive_baud_selector.v

echo "[3/5] Compiling error_handler.v..."
iverilog -o iacf.vvp ../RTL/error_handler.v

echo "[4/5] Compiling system_monitor.v..."
iverilog -o iacf.vvp ../RTL/system_monitor.v

echo "[5/5] Compiling UART modules and top-level..."
iverilog -o iacf.vvp \
    ../RTL/uart_transmitter.v \
    ../RTL/uart_receiver.v \
    ../RTL/intelligent_uart_top_complete.v \
    ../TB/tb_intelligent_uart_complete.v

echo ""
echo "Compilation successful!"
echo ""
echo "========== RUNNING SIMULATION =========="
vvp iacf.vvp -vcd

echo ""
echo "========== SIMULATION COMPLETE =========="
echo "Waveforms saved to: tb_intelligent_uart.vcd"
echo ""
echo "To view waveforms:"
echo "  gtkwave tb_intelligent_uart.vcd &"
echo ""
