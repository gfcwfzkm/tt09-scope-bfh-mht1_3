//Copyright (C)2014-2024 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.10.02 
//Created Time: 2024-10-14 13:26:56
create_clock -name clk_27MHz -period 37.037 -waveform {0 18.518} [get_ports {clk_27MHz}]
create_generated_clock -name clk_25MHz -source [get_nets {clk_50MHz}] -master_clock clk_50MHz -divide_by 2 [get_regs {clk_25MHz_s0}]
create_generated_clock -name hdmi_clock -source [get_nets {clk_50MHz}] -master_clock clk_50MHz -divide_by 2 [get_ports {uo_out[1]}]
create_generated_clock -name clk_50MHz -source [get_ports {clk_27MHz}] -master_clock clk_27MHz -divide_by 27 -multiply_by 50 [get_nets {clk_50MHz}]
