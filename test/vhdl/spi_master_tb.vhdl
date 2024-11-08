
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library std;
use std.textio.all;

entity spi_master_tb is
end entity spi_master_tb;

architecture tb of spi_master_tb is
	component spi_master is
		generic (
			MSB_FIRST : boolean;
			NBITS : positive
		);
		port (
			clk			: in std_logic;
			reset		: in std_logic;
			
			start		: in std_logic;
			busy_wait	: in std_logic;
			data_in		: in std_logic_vector(7 downto 0);
			data_out	: out std_logic_vector(7 downto 0);
			busy		: out std_logic;

			sclk		: out std_logic;
			mosi		: out std_logic;
			miso		: in std_logic;
			cs			: out std_logic
		);
	end component spi_master;

	signal tb_finished : boolean := false;
	signal dut_clk : std_logic := '0';
	signal dut_reset : std_logic := '1';
	signal dut_start : std_logic := '0';
	signal dut_busy_wait : std_logic := '0';
	signal dut_data_in : std_logic_vector(7 downto 0) := (others => '0');
	signal dut_data_out : std_logic_vector(7 downto 0);
	signal dut_busy : std_logic;
	signal dut_sclk : std_logic;
	signal dut_mosi : std_logic;
	signal dut_miso : std_logic := '0';
	signal dut_cs : std_logic;

	type std_logic_array is array(natural range <>) of STD_LOGIC_VECTOR(7 downto 0);

	signal test_miso : std_logic_vector(7 downto 0);
	signal test_mosi : std_logic_vector(7 downto 0);
	-- Frequency should be 25MHz for testing:
	constant half_period : time := 20 ns;

begin
	dut_miso <= test_miso(7);

	dut : spi_master
		generic map (
			MSB_FIRST => true,
			NBITS => 8
		)
		port map (
			clk => dut_clk,
			reset => dut_reset,
			start => dut_start,
			busy_wait => dut_busy_wait,
			data_in => dut_data_in,
			data_out => dut_data_out,
			busy => dut_busy,
			sclk => dut_sclk,
			mosi => dut_mosi,
			miso => dut_miso,
			cs => dut_cs
		);
	
	dut_clk <= not dut_clk after half_period when not tb_finished;

	TB_DUT : process is
		-- create a procedure to perform a single SPI transaction
		procedure spi_transaction_singlebyte(data_into_SPIMASTER : std_logic_vector(7 downto 0);
											 data_out_SPIMASTER : std_logic_vector(7 downto 0)) is
		begin
			-- Check that busy signal is low, cs is high and sclk is low
			assert dut_busy = '0' report "Busy signal is high" severity failure;
			assert dut_cs = '1' report "CS signal is low" severity failure;
			assert dut_sclk = '0' report "SCLK signal is high" severity failure;

			dut_data_in <= data_into_SPIMASTER;
			test_miso <= data_out_SPIMASTER;
			test_mosi <= (others => '0');
			dut_start <= '1';
			wait until rising_edge(dut_clk);
			dut_start <= '0';

			-- wait for CS to go low
			wait until falling_edge(dut_cs);
			for i in 0 to 7 loop
				wait until rising_edge(dut_sclk);
				test_mosi <= test_mosi(6 downto 0) & dut_mosi;
				wait until falling_edge(dut_sclk);
				test_miso <= test_miso(6 downto 0) & dut_miso;
			end loop;

			-- wait for CS to go high
			wait until rising_edge(dut_cs);
			
			-- Wait until rising-edge of clock
			-- Realistically, this would be the time to check the data out
			wait until rising_edge(dut_clk);	
			-- check that the data out is correct
			assert dut_data_out = data_out_SPIMASTER report "Data out is incorrect" severity failure;
			assert test_mosi = data_into_SPIMASTER report "Data in is incorrect" severity failure;
			
			-- Check that busy signal is low, cs is high and sclk is low
			assert dut_busy = '0' report "Busy signal is high" severity failure;
			assert dut_cs = '1' report "CS signal is low" severity failure;
			assert dut_sclk = '0' report "SCLK signal is high" severity failure;
		end procedure spi_transaction_singlebyte;

		procedure spi_transaction_multibyte(data_into_SPIMASTER : std_logic_array;
											data_out_SPIMASTER : std_logic_array) is
		begin
			-- Check that busy signal is low, cs is high and sclk is low
			assert dut_busy = '0' report "Busy signal is high" severity failure;
			assert dut_cs = '1' report "CS signal is low" severity failure;
			assert dut_sclk = '0' report "SCLK signal is high" severity failure;

			dut_busy_wait <= '1';
			for i in 0 to data_into_SPIMASTER'length-1 loop
				dut_data_in <= data_into_SPIMASTER(i);
				test_miso <= data_out_SPIMASTER(i);
				test_mosi <= (others => '0');

				dut_start <= '1';
				wait until rising_edge(dut_clk);
				dut_start <= '0';

				-- wait for CS to go low
				if i = 0 then
					wait until falling_edge(dut_cs);
				end if;				
				
				for j in 0 to 7 loop
					wait until rising_edge(dut_sclk);
					test_mosi <= test_mosi(6 downto 0) & dut_mosi;
					wait until falling_edge(dut_sclk);
					test_miso <= test_miso(6 downto 0) & dut_miso;
				end loop;

				if dut_busy = '1' then
					wait until falling_edge(dut_busy);
				end if;

				-- Wait until rising-edge of clock
				-- Realistically, this would be the time to check the data out
				wait until rising_edge(dut_clk);				
				-- check that the data out is correct
				assert dut_data_out = data_out_SPIMASTER(i) report "Data out is incorrect" severity failure;
				assert test_mosi = data_into_SPIMASTER(i) report "Data in is incorrect" severity failure;
			end loop;
			dut_busy_wait <= '0';

			-- wait for CS to go high
			wait until rising_edge(dut_cs);

			-- Check that busy signal is low, cs is high and sclk is low
			assert dut_busy = '0' report "Busy signal is high" severity failure;
			assert dut_cs = '1' report "CS signal is low" severity failure;
			assert dut_sclk = '0' report "SCLK signal is high" severity failure;
		end procedure spi_transaction_multibyte;

		variable seed1, seed2 : positive := 999;
		variable randomIn : real;
		variable randomOut : real;

		variable data_in_array : std_logic_array(0 to 7) := (
			x"0F",
			x"F0",
			x"FF",
			x"55",
			x"AA",
			x"00",
			x"FF",
			x"42"
		);

		variable data_out_array : std_logic_array(0 to 7) := (
			x"00",
			x"F0",
			x"FF",
			x"55",
			x"42",
			x"FF",
			x"0F",
			x"AA"
		);
	begin
		wait for 1 ns;
		wait until falling_edge(dut_clk);
		dut_reset <= '0';
		wait for 1 ns;

		-- Perform a few specific SPI transactions on certain edge cases
		spi_transaction_singlebyte(x"FF", x"0F");
		spi_transaction_singlebyte(x"00", x"FF");
		spi_transaction_singlebyte(x"F0", x"F0");
		spi_transaction_singlebyte(x"0F", x"0F");
		spi_transaction_singlebyte(x"55", x"55");
		spi_transaction_singlebyte(x"AA", x"FF");
		spi_transaction_singlebyte(x"55", x"AA");

		-- Perform a few specific SPI transactions on certain edge cases
		spi_transaction_multibyte(data_in_array, data_out_array);

		-- Simulate a single write cycle to a FRAM device
		-- Write to address 0x00FF the data 0x00 0x01 0x02 in that order
		data_in_array(0) := x"00";
		data_in_array(1) := x"FF";
		data_in_array(2) := x"00";
		data_in_array(3) := x"01";
		data_in_array(4) := x"02";

		data_out_array(0) := x"00";
		data_out_array(1) := x"00";
		data_out_array(2) := x"00";
		data_out_array(3) := x"00";
		data_out_array(4) := x"00";

		-- First enable the write operation
		spi_transaction_singlebyte(x"06", x"00");
		-- Write the data to the FRAM device
		spi_transaction_multibyte(data_in_array, data_out_array);

		-- Simulate a single read cycle from a FRAM device
		-- Read from address 0x00FF the data 0x00 0x01 0x02 in that order
		data_in_array(3) := x"00";
		data_in_array(4) := x"00";
		data_out_array(3) := x"01";
		data_out_array(4) := x"02";
		
		-- Read the data from the FRAM device
		spi_transaction_multibyte(data_in_array, data_out_array);

		-- Use a random number generator to test the SPI transactions
		for i in 0 to 1000 loop
			uniform(seed1, seed2, randomIn);
			uniform(seed1, seed2, randomOut);
			
			spi_transaction_singlebyte(std_logic_vector(to_unsigned(integer(randomIn * 255.0), 8)),
									   std_logic_vector(to_unsigned(integer(randomOut * 255.0), 8)));
			
			for j in 0 to 7 loop	
				uniform(seed1, seed2, randomIn);
				uniform(seed1, seed2, randomOut);
				data_in_array(j) := std_logic_vector(to_unsigned(integer(randomIn * 255.0), 8));
				data_out_array(j) := std_logic_vector(to_unsigned(integer(randomOut * 255.0), 8));
			end loop;
			spi_transaction_multibyte(data_in_array, data_out_array);
		end loop;

		tb_finished <= true;
		wait;
	end process TB_DUT;
end architecture tb;