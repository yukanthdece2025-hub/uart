# RTL to GDS2 Flow Guide - Intelligent Adaptive UART

## Overview

This document provides a comprehensive guide for converting the Intelligent Adaptive Communication Framework (IACF) from RTL to GDS2 (physical layout).

## Current Status

✅ **RTL Design**: Complete and simulation-verified  
✅ **Testbench**: Comprehensive with 7 test cases  
✅ **Synthesis Constraints**: SDC file provided  
⏳ **Next Steps**: Synthesis → Place & Route → Physical Verification → GDS2

## Design Summary

### Architecture Layers

1. **Intelligence Layer** - `behavior_analyzer.v`
   - Delta analysis for rate of change
   - Anomaly detection using statistical methods
   - Urgency estimation (0-15 levels)
   - Threat scoring (0-255)

2. **Communication Layer** - `adaptive_baud_selector.v`
   - Dynamic baud rate selection (9.6 kbps to 115.2 kbps)
   - Urgency-driven speed adaptation
   - 5 predefined baud rates

3. **UART Layer** (NEW)
   - **TX Module**: `uart_transmitter.v`
     - 8-bit data transmission
     - Configurable baud rate
     - START (1) + DATA (8) + STOP (1) frame
   - **RX Module**: `uart_receiver.v`
     - 8-bit data reception
     - 16x oversampling for robust sampling
     - Frame error detection

4. **Reliability Layer** - `error_handler.v`
   - CRC-16 error detection
   - Automatic retransmission (up to 3 retries)
   - ACK/NACK response handling

5. **Monitoring Layer** - `system_monitor.v`
   - Real-time performance tracking
   - Link quality monitoring (0-100%)
   - Error rate calculation
   - System health status (4 levels)
   - Latency statistics

### Design Specifications

| Parameter | Value | Notes |
|-----------|-------|-------|
| Clock Frequency | 100 MHz | 10ns period |
| Data Width | 8 bits | Per transmission |
| UART Data Rates | 5 levels | 9.6k to 115.2k bps |
| Max Retries | 3 | On CRC error |
| Queue Depth | 32 | Packet scheduler |
| Urgency Levels | 16 | 0 (idle) to 15 (critical) |
| Max Area Budget | 50,000 µm² | Approximate |

## Synthesis Phase

### Prerequisites

- **Synthesis Tool**: Synopsys DC, Cadence RTL Compiler, or Yosys
- **Technology Library**: 65nm, 45nm, 28nm, or 5nm (varies by target)
- **Liberty Files**: .lib files for timing/power characterization
- **LEF Files**: Library Exchange Format for physical cells
- **Constraints**: `constraints/synthesis.sdc`

### Synthesis Steps (Using Synopsys DC)

```tcl
# 1. Set up design environment
set_app_var search_path {./lib ./rtl}
set_app_var link_library {typical.lib}
set_app_var target_library {typical.lib}

# 2. Read design
read_verilog -rtlplus {
    RTL/behavior_analyzer.v
    RTL/adaptive_baud_selector.v
    RTL/error_handler.v
    RTL/system_monitor.v
    RTL/uart_transmitter.v
    RTL/uart_receiver.v
    RTL/intelligent_uart_top_complete.v
}

# 3. Set current design
current_design intelligent_uart_top_complete

# 4. Read constraints
read_sdc constraints/synthesis.sdc

# 5. Elaborate and optimize
elaborate -rtl
optimize_rtl -phase true

# 6. Link library
link

# 7. Compile with constraints
compile -inc_all_leaf_cells -ungroup_all

# 8. Generate reports
report_timing -max_paths 10 > reports/timing.rpt
report_area > reports/area.rpt
report_power -analysis_view > reports/power.rpt

# 9. Write netlist
write -format verilog -hierarchy -output intelligent_uart_netlist.v
write_sdf intelligent_uart.sdf
```

### Expected Results

- **Gate Count**: ~15,000-20,000 gates (typical)
- **Area**: 40,000-50,000 µm² (65nm technology)
- **Power**: 50-100 mW @ 100 MHz (estimated)
- **Setup Margin**: > 1ns (good timing closure)
- **Hold Margin**: > 0.1ns (no violations expected)

## Place & Route Phase

### P&R Tool Setup (Using Cadence Innovus)

```tcl
# 1. Initialize design
setDesignMode -process 65
initializeDesign -iconRpt reports/init.rpt

# 2. Import netlist and constraints
loadNetlist intelligent_uart_netlist.v
loadConstraints constraints/synthesis.sdc

# 3. Floorplan creation
setFloorplan -site 1.4 -d 1000 1000 50 50 50 50

# 4. Power distribution network
addStripe -direction horizontal -layer metal4 -width 2 -spacing 10 -set_to_set_distance 100
addStripe -direction vertical -layer metal3 -width 2 -spacing 10 -set_to_set_distance 100

# 5. Placement
placeInstance -prePlaced
optDesign -preCTS

# 6. Clock tree synthesis
specifyClockTree -clkfile clocks.ctstch
optDesign -postCTS

# 7. Routing
route
optDesign -postRoute

# 8. Generate output
gdsOut reports/intelligent_uart.gds
```

## Physical Verification

### Design Rule Check (DRC)

```bash
# Using Calibre DRC
calibre -drc -hier -runset DEVICE.drc intelligent_uart.gds

# Common DRC checks for UART design:
# - Metal spacing rules
# - Via stacking rules
# - Antenna rules (for gate oxide protection)
# - Density rules (CMP uniformity)
```

### Layout vs Schematic (LVS)

```bash
# Verify gate-level netlist matches layout
calibre -lvs -hier intelligent_uart.gds intelligent_uart_netlist.v

# LVS checks:
# - Device connectivity
# - Pin connections
# - Device parameters
```

### Parasitic Extraction

```bash
# Extract RC parasitics for final timing analysis
calibre -xrc -hier intelligent_uart.gds

# Generates SPEF file for final STA
```

## Post-Layout Timing

### Static Timing Analysis (STA)

```tcl
# Primetime STA script
read_netlist intelligent_uart_netlist.v
read_sdf intelligent_uart.sdf
read_parasitics intelligent_uart.spef
read_sdc constraints/synthesis.sdc
read_lib typical.lib

update_timing
report_timing -max_paths 20 -delay_type max
report_timing -max_paths 20 -delay_type min
report_design_summary
```

## File Outputs Summary

| Phase | Input Files | Output Files | Tool |
|-------|------------|--------------|------|
| RTL | .v files | behavior sim | iverilog/ModelSim |
| Synthesis | netlist.v, .sdc | netlist.v, .sdf | DC/RTL Compiler |
| P&R | netlist.v, .sdf, .lef | layout.def, power.spl | Innovus |
| Verification | layout.def | .rpt (DRC/LVS) | Calibre |
| Final | layout.def | **design.gds** | Innovus/Calibre |

## GDS2 Delivery Checklist

- [ ] DRC: All violations resolved
- [ ] LVS: Clean match between netlist and layout
- [ ] Timing: All paths meet constraints with margin
- [ ] Power: Within budget (< 100 mW estimated)
- [ ] Area: Within budget (< 50,000 µm²)
- [ ] Antenna: No oxide rupture risk
- [ ] ESD: Proper protection circuits
- [ ] Documentation: Design notes and known issues
- [ ] GDS2 file: Final layout in GDS format
- [ ] GDSII Validation: No structural issues

## Recommended Tool Flow

### Open Source Flow (Minimal Cost)
```
RTL → Yosys → Nextpnr/Graywolf → OpenROAD → GDS2
```

### Commercial Flow (Industry Standard)
```
RTL → Synopsys DC → Cadence Innovus → Calibre → GDS2
```

### Hybrid Flow
```
RTL → Yosys → Cadence Innovus → Calibre → GDS2
```

## Timing Closure Strategy

### If timing violations occur:

1. **Setup Violations**
   - Increase clock period (lower frequency)
   - Insert pipeline stages
   - Optimize critical path logic
   - Use faster standard cells

2. **Hold Violations**
   - Add delay buffers
   - Adjust buffer chain
   - Use slower cells in non-critical areas
   - Adjust placement

## Power Optimization

### Techniques for RTL-to-GDS2:

1. **Clock Gating** - Already enabled in SDC
2. **Power Gating** - For idle domains
3. **Multi-Vt Cells** - Mix of HVt/LVt cells
4. **Memory Optimization** - Use embedded memory when available
5. **Voltage Scaling** - Reduced Vdd for non-critical paths

## Next Steps

1. **Obtain Technology Files**
   - Contact foundry (TSMC, Samsung, GF)
   - Download PDK (Process Design Kit)
   - Extract .lib and .lef files

2. **Run Synthesis**
   - Use provided SDC file
   - Verify timing closure
   - Review area/power reports

3. **Execute P&R**
   - Follow tool-specific guidelines
   - Ensure DRC compliance
   - Validate timing post-layout

4. **Final Verification**
   - DRC and LVS clean
   - STA timing verified
   - Ready for tapeout!

## Support & References

- **Verilog Standards**: IEEE 1364-2005
- **SDF Format**: IEEE 1497-2001
- **GDSII Format**: Caltech (1982)
- **Timing Analysis**: Static Timing Analysis (STA) principles
- **Design Rules**: Technology-specific (foundry provided)

---

**Status**: ✅ Ready for Synthesis  
**Last Updated**: 2026-05-20  
**Version**: 1.0.0
