//Copyright (C)2014-2024 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.10.02 
//Created Time: 2024-10-07 11:02:14
create_clock -name clk_50MHz -period 20 -waveform {0 10} [get_ports {clk_50MHz}]
create_generated_clock -name clk_25MHz -source [get_ports {clk_50MHz}] -master_clock clk_50MHz -divide_by 2 [get_regs {clk_25MHz_s0}]
create_generated_clock -name hdmi_clock -source [get_ports {clk_50MHz}] -master_clock clk_50MHz -divide_by 2 [get_ports {uo_out[1]}]
