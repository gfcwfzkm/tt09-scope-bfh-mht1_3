module gw_gao(
    \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[14] ,
    \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[13] ,
    \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[12] ,
    \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[11] ,
    \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[10] ,
    \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[9] ,
    \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[8] ,
    \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[7] ,
    \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[6] ,
    \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[5] ,
    \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[4] ,
    \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[3] ,
    \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[2] ,
    \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[1] ,
    \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[0] ,
    \uo_out[3] ,
    \uo_out[1] ,
    tms_pad_i,
    tck_pad_i,
    tdi_pad_i,
    tdo_pad_o
);

input \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[14] ;
input \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[13] ;
input \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[12] ;
input \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[11] ;
input \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[10] ;
input \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[9] ;
input \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[8] ;
input \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[7] ;
input \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[6] ;
input \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[5] ;
input \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[4] ;
input \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[3] ;
input \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[2] ;
input \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[1] ;
input \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[0] ;
input \uo_out[3] ;
input \uo_out[1] ;
input tms_pad_i;
input tck_pad_i;
input tdi_pad_i;
output tdo_pad_o;

wire \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[14] ;
wire \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[13] ;
wire \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[12] ;
wire \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[11] ;
wire \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[10] ;
wire \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[9] ;
wire \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[8] ;
wire \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[7] ;
wire \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[6] ;
wire \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[5] ;
wire \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[4] ;
wire \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[3] ;
wire \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[2] ;
wire \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[1] ;
wire \TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[0] ;
wire \uo_out[3] ;
wire \uo_out[1] ;
wire tms_pad_i;
wire tck_pad_i;
wire tdi_pad_i;
wire tdo_pad_o;
wire tms_i_c;
wire tck_i_c;
wire tdi_i_c;
wire tdo_o_c;
wire [9:0] control0;
wire gao_jtag_tck;
wire gao_jtag_reset;
wire run_test_idle_er1;
wire run_test_idle_er2;
wire shift_dr_capture_dr;
wire update_dr;
wire pause_dr;
wire enable_er1;
wire enable_er2;
wire gao_jtag_tdi;
wire tdo_er1;

IBUF tms_ibuf (
    .I(tms_pad_i),
    .O(tms_i_c)
);

IBUF tck_ibuf (
    .I(tck_pad_i),
    .O(tck_i_c)
);

IBUF tdi_ibuf (
    .I(tdi_pad_i),
    .O(tdi_i_c)
);

OBUF tdo_obuf (
    .I(tdo_o_c),
    .O(tdo_pad_o)
);

GW_JTAG  u_gw_jtag(
    .tms_pad_i(tms_i_c),
    .tck_pad_i(tck_i_c),
    .tdi_pad_i(tdi_i_c),
    .tdo_pad_o(tdo_o_c),
    .tck_o(gao_jtag_tck),
    .test_logic_reset_o(gao_jtag_reset),
    .run_test_idle_er1_o(run_test_idle_er1),
    .run_test_idle_er2_o(run_test_idle_er2),
    .shift_dr_capture_dr_o(shift_dr_capture_dr),
    .update_dr_o(update_dr),
    .pause_dr_o(pause_dr),
    .enable_er1_o(enable_er1),
    .enable_er2_o(enable_er2),
    .tdi_o(gao_jtag_tdi),
    .tdo_er1_i(tdo_er1),
    .tdo_er2_i(1'b0)
);

gw_con_top  u_icon_top(
    .tck_i(gao_jtag_tck),
    .tdi_i(gao_jtag_tdi),
    .tdo_o(tdo_er1),
    .rst_i(gao_jtag_reset),
    .control0(control0[9:0]),
    .enable_i(enable_er1),
    .shift_dr_capture_dr_i(shift_dr_capture_dr),
    .update_dr_i(update_dr)
);

ao_top_0  u_la0_top(
    .control(control0[9:0]),
    .trig0_i(\uo_out[3] ),
    .data_i({\TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[14] ,\TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[13] ,\TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[12] ,\TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[11] ,\TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[10] ,\TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[9] ,\TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[8] ,\TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[7] ,\TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[6] ,\TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[5] ,\TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[4] ,\TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[3] ,\TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[2] ,\TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[1] ,\TinyTapeout_Test/MEASUREMENTS/sample_start_address_reg[0] }),
    .clk_i(\uo_out[1] )
);

endmodule
