library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library std;
use std.textio.all;

entity minsky_circle_tb is
end entity minsky_circle_tb;

architecture testbench of minsky_circle_tb is
	component minsky_circle is
		generic (
			NBITS : integer := 8;
			SHIFTSIZE : integer := 2;
			ADD_OFFSET : integer := 127;
			COSINE_INIT : integer := 120
		);
		port (
			clk   : in std_logic;
			reset : in std_logic;

			calc_next : in std_logic;
			busy : out std_logic;

			cosine_u : out unsigned(NBITS-1 downto 0);
			sine_u : out unsigned(NBITS-1 downto 0);
			cosine_s : out signed(NBITS-1 downto 0);
			sine_s : out signed(NBITS-1 downto 0)
		);
	end component minsky_circle;

	signal clk : std_logic := '0';
	signal reset, calc_next : std_logic;
	signal busy : std_logic;
	signal cosine, sine : unsigned(7 downto 0);
	signal tb_finished : boolean := false;
begin

	dut: minsky_circle
		generic map (
			NBITS => 8,
			SHIFTSIZE => 2,
			COSINE_INIT => 120,
			ADD_OFFSET => 127
		)
		port map (
			clk => clk,
			reset => reset,
			calc_next => calc_next,
			busy => busy,
			cosine_u => cosine,
			sine_u => sine,
			cosine_s => open,
			sine_s => open
		);

	-- Clock process definitions
	clk <= not clk after 2 ns when tb_finished = false else '0';

	-- Stimulus process
	stim_proc: process
	begin
		reset <= '1';
		calc_next <= '0';
		wait for 1 ns;
		reset <= '0';
		calc_next <= '1';
		wait for 200 ns;
		calc_next <= '0';
		tb_finished <= true;
		wait;
	end process;

end architecture testbench;