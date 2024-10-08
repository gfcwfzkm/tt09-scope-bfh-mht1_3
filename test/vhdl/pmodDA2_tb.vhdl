
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library std;
use std.textio.all;

entity pmodDA2_tb is
end entity pmodDA2_tb;

architecture tb of pmodDA2_tb is
	component pmodDA2
		port (
			clk		: in std_logic;
			reset	: in std_logic;
			
			din		: in std_logic_vector(7 downto 0);
			start	: in std_logic;
			busy	: out std_logic;

			mosi	: out std_logic;
			sclk	: out std_logic;
			cs_n	: out std_logic
		);
	end component pmodDA2;

	constant CLKFREQ : real := 25.0e6;
	constant PERIOD : time := 1.0 sec / CLKFREQ;
	constant HALFPERIOD : time := PERIOD / 2.0;
	constant AMOUNT_OF_TESTS_I_DO : integer := 1000;

	signal tb_finished : boolean := false;
	signal tb_clk : std_logic := '0';
	signal tb_reset : std_logic := '1';
	signal tb_din : std_logic_vector(7 downto 0) := (others => '0');
	signal tb_start : std_logic := '0';
	signal tb_busy : std_logic;

	signal tb_mosi : std_logic;
	signal tb_sclk : std_logic;
	signal tb_cs_n : std_logic;

	signal spi_mosi_reg : std_logic_vector(15 downto 0) := (others => '0');
begin

	tb_clk <= not tb_clk after HALFPERIOD when not tb_finished else '0';

	dut : pmodDA2
		port map (
			clk => tb_clk,
			reset => tb_reset,
			din => tb_din,
			start => tb_start,
			busy => tb_busy,
			mosi => tb_mosi,
			sclk => tb_sclk,
			cs_n => tb_cs_n
	);
	
	SPISLAVE : process is
	begin
		-- wait for CS to go low
		wait until falling_edge(tb_cs_n);
		for i in 0 to 15 loop
			wait until falling_edge(tb_sclk);
			wait for 1 ns;
			spi_mosi_reg <= spi_mosi_reg(14 downto 0) & tb_mosi;
			wait for 1 ns;
		end loop;

	end process SPISLAVE;

	STIMULI : process is
		procedure idle_check is
		begin
			assert tb_cs_n = '1'
				report "CS signal is low, expected high / idle"
				severity FAILURE;
			assert tb_sclk = '1'
				report "SCLK signal is high, expected low / idle"
				severity FAILURE;
			assert tb_busy = '0'
				report "Busy signal is high, expected low / idle"
				severity FAILURE;
			assert tb_mosi = '0'
				report "MOSI signal is high, expected low / idle"
				severity FAILURE;
		end procedure;

		procedure check_DA2 (analog_value : std_logic_vector(7 downto 0)) is
		begin
			idle_check;

			tb_din <= analog_value;
			tb_start <= '1';
			wait until rising_edge(tb_clk);
			tb_start <= '0';

			wait until tb_busy = '1';
			wait until tb_busy = '0';

			wait for 1 ns;

			idle_check;

			assert spi_mosi_reg(11 downto 4) = analog_value
				report "Send analog value does not match received value" &
				"Expected: " & to_hstring(analog_value) &
				"Received: " & to_hstring(spi_mosi_reg(11 downto 4))
				severity FAILURE;
			assert spi_mosi_reg(13 downto 12) = "00"
				report "Expected Power-Down bits to be 0, but they are "
				& to_hstring(spi_mosi_reg(13 downto 12))
				severity FAILURE;
			assert spi_mosi_reg(3 downto 0) = "0000"
				report "Expected last four bits to be zero, but they are "
				& to_hstring(spi_mosi_reg(3 downto 0))
				severity WARNING;
		end procedure;

		variable seed1, seed2 : positive := 42;
		variable randomValue : real := 0.0;
	begin

		wait for 10 ns;
		tb_reset <= '0';
		wait for 10 ns;

		for i in 0 to AMOUNT_OF_TESTS_I_DO loop
			uniform(seed1, seed2, randomValue);
			check_DA2(std_logic_vector(to_unsigned(integer(randomValue * 255.0), 8)));
		end loop;

		report "Testbench finished" severity NOTE;

		tb_finished <= true;
		wait;

	end process STIMULI;

end architecture tb;