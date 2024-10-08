
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library std;
use std.textio.all;

entity debouncer_tb is
end entity debouncer_tb;

architecture tb of debouncer_tb is
	constant F_CLK : positive := 25_000_000; --! FPGA clock frequency in Hz
	constant CLK_PERIOD : time := 1 sec / F_CLK;
	constant CLK_H_PERIOD : time := CLK_PERIOD / 2;

	constant VGA_FREQ : positive := 60; --! VGA refresh rate in Hz
	constant CNT_TOP : positive := F_CLK / VGA_FREQ; --! VGA refresh period in clock cycles

	signal tb_finished : boolean := false;
	signal clk : std_logic := '0';
	signal reset : std_logic := '1';
	signal input : std_logic := '0';
	signal deb_en : std_logic := '0';
	signal output : std_logic;
	signal released : std_logic;
	signal pressed : std_logic;

	signal counter : integer := 0;
begin

	clk <= not clk after CLK_H_PERIOD when not tb_finished else '0';

	--! Instantiate the debouncer
	DUT : entity work.debouncer
		generic map (
			DEBOUNCE_COUNTER_MAX => 7
		)
		port map (
			clk => clk,
			reset => reset,
			in_raw => input,
			deb_en => deb_en,
			debounced => output,
			released => released,
			pressed => pressed
	);

	CNT : process is
	begin
		while tb_finished = false loop
			wait until falling_edge(clk);
			if counter = CNT_TOP then
				deb_en <= '1';
				counter <= 0;
			else
				deb_en <= '0';
				counter <= counter + 1;
			end if;
		end loop;
		wait;		
	end process CNT;

	--! Testbench process
	TB : process is
	begin
		wait for 10 ns;
		reset <= '0';
		wait for 10 ns;

		--! Test debouncing
		input <= '1';
		wait for 200 ms;
		input <= '0';
		wait for 200 ms;

		tb_finished <= true;

		wait;
	end process TB;

end architecture tb;