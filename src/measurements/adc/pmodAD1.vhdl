-- TerosHDL Documentation:
--! @title PmodAD1 - Analog to Digital Converter Module
--! @author Pascal Gesell (gesep1 / gfcwfzkm)
--! @version 1.0
--! @date 09.10.2024
--! @brief PmodAD1 module for the Digilent PmodAD1 module.
--!
--! This module implements the PmodAD1 module for the Digilent PmodAD1 module. The module
--! is used to read analog values from the PmodAD1 module using the SPI interface. While
--! the pmod supports 12 bit resolution, this module only reads the 8 most significant bits
--! and only a single channel instead of dual channel.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity pmodAD1 is
	port (
		--! Clock signal
		clk   : in std_logic;
		--! Asynchronous reset signal
		reset : in std_logic;
		
		-- Control & Data
		--! Start signal - initiates the SPI transaction
		start	: in std_logic;
		--! Busy signal - indicates that the SPI transaction is in progress
		busy	: out std_logic;
		--! Data out signal - the data received from the SPI slave
		data	: out std_logic_vector(7 downto 0);

		-- SPI
		--! Serial clock signal
		sclk	: out std_logic;
		--! Master In Slave Out signal
		miso	: in std_logic;
		--! Chip select signal (active low)
		cs_n	: out std_logic
	);
end entity pmodAD1;

architecture rtl of pmodAD1 is
	--! State machine states
	type state_type is (
		IDLE,	--! Idle state
		SHIFT,	--! Shift state
		DONE	--! Done state
	);

	--! State machine signals
	signal state_reg, state_next : state_type;

	--! Shift register for the received data
	signal shift_reg, shift_next : std_logic_vector(7 downto 0);
	--! Counter for the shift state
	signal cnt_reg, cnt_next : unsigned(3 downto 0);
	--! Clock signal for the SPI
	signal sclk_reg, sclk_next : std_logic;
begin

	sclk <= sclk_reg;
	cs_n <= '0' when state_reg = SHIFT else '1';
	busy <= '1' when state_reg /= IDLE else '0';
	data <= shift_reg;

	--! Basic clocked registers and reset logic
	CLKREG : process (clk, reset) is
	begin
		if reset = '1' then
			state_reg <= IDLE;
			shift_reg <= (others => '0');
			cnt_reg <= (others => '0');
			sclk_reg <= '1';
		elsif rising_edge(clk) then
			state_reg <= state_next;
			shift_reg <= shift_next;
			cnt_reg <= cnt_next;
			sclk_reg <= sclk_next;
		end if;
	end process CLKREG;
	
	--! State machine process
	FSM : process (state_reg, cnt_reg, sclk_reg, shift_reg, miso, start) is
	begin
		state_next <= state_reg;
		shift_next <= shift_reg;
		cnt_next <= cnt_reg;
		sclk_next <= sclk_reg;
		
		case state_reg is
			when IDLE =>
				if start = '1' then
					state_next <= SHIFT;
					shift_next <= (others => '0');
					cnt_next <= "1111";
				end if;
			when SHIFT =>
				sclk_next <= not sclk_reg;

				if cnt_reg >= 4 then
					shift_next(0) <= miso;
				end if;

				if sclk_reg = '0' then
					if cnt_reg = 0 then
						state_next <= DONE;
					else
						cnt_next <= cnt_reg - 1;
						if cnt_reg >= 5 and cnt_reg <= 11 then
							shift_next(7 downto 1) <= shift_reg(6 downto 0);
						end if;
					end if;
				end if;
			when DONE =>
				state_next <= IDLE;
				sclk_next <= '1';
			when others =>
				state_next <= IDLE;
		end case;
	end process FSM;

end architecture;