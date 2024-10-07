# Tests

Due to the lack of experience in cocotb and Verilog, the usual tests for TinyTapeout are not available. Instead, a [dummy.v](dummy.v) file is provided to bypass the cocotb tests.

The actual testbenches can be found in [the vhdl directory](vhdl/) and can be run using GHDL or NVC. With the exception of the [debouncer](vhdl/debouncer_tb.vhdl) test, all tests are self-checking.