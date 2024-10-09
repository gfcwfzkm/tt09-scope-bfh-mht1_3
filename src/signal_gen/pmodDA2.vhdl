-- TerosHDL Documentation:
--! @title PmodDA2 - Digital to Analog Converter Module
--! @author Pascal Gesell (gesep1 / gfcwfzkm)
--! @version 1.0
--! @date 09.10.2024
--! @brief PmodDA2 module for the Digilent PmodDA2 module.
--!
--! This module implements the PmodDA2 module for the Digilent PmodDA2 module. The module
--! is used to write digital values to the PmodDA2 module using the SPI interface. While the 
--! pmod supports a 12 bit resolution and dual channel, this module only writes the 8 most
--! significant bits and only a single channel.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity pmodDA2 is
	port (
		--! Clock signal
		clk		: in std_logic;
		--! Asynchronous reset signal
		reset	: in std_logic;
		
		--! Data to be written to the PmodDA2 module
		din		: in std_logic_vector(7 downto 0);
		--! Start signal - initiates the SPI transaction
		start	: in std_logic;
		--! Busy signal - indicates that the SPI transaction is in progress
		busy	: out std_logic;

		--! Master Out Slave In signal
		mosi	: out std_logic;
		--! Serial clock signal
		sclk	: out std_logic;
		--! Chip select signal (active low)
		cs_n	: out std_logic
	);
end entity pmodDA2;

architecture rtl of pmodDA2 is
	--! State machine states
	type state_type is (
		IDLE,	--! Idle state
		SHIFT,	--! Shift state
		DONE	--! Done state
	);

	--! State machine register
	signal state_reg, state_next : state_type;

	--! Shift register for the data to be sent
	signal shift_reg, shift_next : std_logic_vector(7 downto 0);
	--! Counter for the shift state
	signal cnt_reg, cnt_next : unsigned(3 downto 0);
	--! Clock signal for the SPI
	signal sclk_reg, sclk_next : std_logic;
begin

	sclk <= not sclk_reg;
	cs_n <= '0' when state_reg = SHIFT else '1';
	busy <= '1' when state_reg /= IDLE else '0';

	--! Basic clocked registers and reset logic
	CLKREG : process (clk, reset) is
	begin
		if reset = '1' then
			state_reg <= IDLE;
			shift_reg <= (others => '0');
			cnt_reg <= (others => '0');
			sclk_reg <= '0';
		elsif rising_edge(clk) then
			state_reg <= state_next;
			shift_reg <= shift_next;
			cnt_reg <= cnt_next;
			sclk_reg <= sclk_next;
		end if;
	end process CLKREG;

	--! State machine process
	FSM : process (state_reg, cnt_reg, sclk_reg, shift_reg, din, start) is
	begin
		state_next <= state_reg;
		shift_next <= shift_reg;
		cnt_next <= cnt_reg;
		sclk_next <= sclk_reg;
		mosi <= '0';

		case state_reg is
			when IDLE =>
				if start = '1' then
					state_next <= SHIFT;
					shift_next <= din;
					cnt_next <= "1111";
					sclk_next <= '0';
				end if;
			when SHIFT =>
				sclk_next <= not sclk_reg;
				if sclk_reg = '1' then
					if cnt_reg = 0 then
						state_next <= DONE;
					else
						cnt_next <= cnt_reg - 1;
						if cnt_reg >= 4 and cnt_reg <= 11 then
							shift_next(7 downto 1) <= shift_reg(6 downto 0);
							shift_next(0) <= '0';
						end if;
					end if;
				end if;

				if cnt_reg <= 11 and cnt_reg >= 4 then
					mosi <= shift_reg(7);
				end if;
			when DONE =>
				sclk_next <= '0';				
				state_next <= IDLE;
		end case;
	end process FSM;

end architecture;