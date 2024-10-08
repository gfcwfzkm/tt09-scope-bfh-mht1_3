
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library std;
use std.textio.all;

entity pmodAD1_tb is
end entity pmodAD1_tb;

architecture rtl of pmodAD1_tb is
	-- Component Declaration
	component pmodAD1 is
		port (
			clk   : in std_logic;
			reset : in std_logic;
			
			-- Control & Data
			start	: in std_logic;
			busy	: out std_logic;
			data	: out std_logic_vector(7 downto 0);

			-- SPI
			sclk	: out std_logic;
			miso	: in std_logic;
			cs_n	: out std_logic
		);
	end component pmodAD1;

	constant CLKFREQ : real := 25.0e6;
	constant PERIOD : time := 1.0 sec / CLKFREQ;
	constant HALFPERIOD : time := PERIOD / 2.0;
	constant AMOUNT_OF_TESTS_I_DO : integer := 1000;

	-- Signal Declaration
	signal tb_finished : boolean := false;
	signal tb_clk : std_logic := '0';
	signal tb_reset : std_logic := '1';
	signal tb_start : std_logic := '0';
	signal tb_busy : std_logic;
	signal tb_data : std_logic_vector(7 downto 0);
	signal tb_sclk : std_logic;
	signal tb_miso : std_logic;
	signal tb_cs_n : std_logic;

	signal spi_miso_reg : std_logic_vector(15 downto 0) := (others => '0');
	signal spi_adc_reg : std_logic_vector(15 downto 0) := (others => '0');
begin

	tb_clk <= not tb_clk after HALFPERIOD when not tb_finished else '0';
	tb_miso <= spi_miso_reg(15);

	-- DUT Instantiation
	dut : pmodAD1
		port map (
			clk => tb_clk,
			reset => tb_reset,
			start => tb_start,
			busy => tb_busy,
			data => tb_data,
			sclk => tb_sclk,
			miso => tb_miso,
			cs_n => tb_cs_n
	);

	SPISLAVE : process is
	begin
		wait until falling_edge (tb_cs_n);
		spi_miso_reg <= spi_adc_reg;
		wait for 22 ns; -- Datasheet t_3 - Delay from !CS until SDTATA three-state disabled
		for i in 0 to 15 loop
			wait until falling_edge(tb_sclk);
			wait for 40 ns; -- Datasheet t_4 - Data access time after SCLK falling edge
			spi_miso_reg <= spi_miso_reg(14 downto 0) & spi_miso_reg(15);
		end loop;
	end process SPISLAVE;

	STIMULI : process is
		procedure sample_adc (adc_data : std_logic_vector(15 downto 0)) is
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
			
			spi_adc_reg <= adc_data;
			tb_start <= '1';
			wait until rising_edge(tb_clk);
			tb_start <= '0';

			wait until tb_busy = '1';
			wait until tb_busy = '0';

			assert tb_data = adc_data(11 downto 4)
				report "Data mismatch! Expected: " & to_string(adc_data(11 downto 4)) &
				" Got: " & to_string(tb_data)
				severity FAILURE;
		end procedure;

		variable seed1, seed2 : integer := 42;
		variable randomADC : real := 0.0;
	begin
		wait for 10 ns;
		tb_reset <= '0';
		wait for 10 ns;
	
		for i in 0 to AMOUNT_OF_TESTS_I_DO loop
			uniform(seed1, seed2, randomADC);
			sample_adc(std_logic_vector(to_unsigned(integer(randomADC * 65535.0), 16)));
		end loop;

		tb_finished <= TRUE;

		wait;

	end process STIMULI;

end architecture;