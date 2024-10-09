-- TerosHDL Documentation:
--! @title Minsky Circle Generator
--! @author Pascal Gesell (gesep1 / gfcwfzkm)
--! @version 1.0
--! @date 09.10.2024
--! @brief Generates a circle using the Minsky Circle Algorithm.
--!
--! This module generates a circle using the Minsky Circle Algorithm. The algorithm
--! is based on the generation of a circle using simple arithmetic operations like
--! addition, subtraction and bit-shifting. The algorithm is based on the following
--! equations:
--!
--! cosine_new = cosine_old - (sine_old >> shift)
--!
--! sine_new = sine_old + (cosine_new >> shift)		-- Use the new cosine value!
--!
--! The algorithms origins and a basic explanation can be found here:
--! https://dspace.mit.edu/bitstream/handle/1721.1/6086/AIM-239.pdf on page 74, Item 149.
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity minsky_circle is
	generic (
		--! Number of bits used for the sine and cosine values
		NBITS : integer := 8;
		--! Number of bits to shift the values
		SHIFTSIZE : integer := 2;
		--! Initial cosine value
		COSINE_INIT : integer := 120;
		--! Offset to add to the sine and cosine values
		ADD_OFFSET : integer := 127
	);
	port (
		--! Clock signal
		clk   : in std_logic;
		--! Asynchronous reset signal
		reset : in std_logic;

		--! Signal to start the calculation
		calc_next : in std_logic;
		--! Signal indicating that the calculation is in progress
		busy : out std_logic;
		
		--! Unsigned output of the cosine value, offset added
		cosine_u : out unsigned(NBITS-1 downto 0);
		--! Unsigned output of the sine value, offset added
		sine_u : out unsigned(NBITS-1 downto 0);
		--! Signed output of the cosine value
		cosine_s : out signed(NBITS-1 downto 0);
		--! Signed output of the sine value
		sine_s : out signed(NBITS-1 downto 0)
	);
end entity minsky_circle;

architecture rtl of minsky_circle is
	--! State machine states
	type state_type is (
		IDLE, 	--! Idle state
		CALC	--! Calculation state
	);

	signal state_reg : state_type;	--! Current state
	signal state_next : state_type; --! Next state
	signal cosine_reg : signed(NBITS-1 downto 0);	--! Current cosine value
	signal cosine_next : signed(NBITS-1 downto 0);	--! Next cosine value
	signal sine_reg : signed(NBITS-1 downto 0);		--! Current sine value
	signal sine_next : signed(NBITS-1 downto 0);	--! Next sine value
begin

	--! Basic clocked registers and reset logic
	CLKREG : process(clk, reset) is
	begin
		if reset = '1' then
			cosine_reg <= to_signed(COSINE_INIT, NBITS);
			sine_reg <= to_signed(0, NBITS);
			state_reg <= IDLE;
		elsif rising_edge(clk) then
			cosine_reg <= cosine_next;
			sine_reg <= sine_next;
			state_reg <= state_next;
		end if;
	end process CLKREG;

	--! Calculation process NSL
	NSL : process(state_reg, calc_next, cosine_reg, sine_reg) is
	begin
		cosine_next <= cosine_reg;
		sine_next <= sine_reg;
		state_next <= state_reg;

		case state_reg is
			when IDLE =>
				if calc_next = '1' then
					state_next <= CALC;
					cosine_next <= cosine_reg - shift_right(sine_reg, SHIFTSIZE);
				end if;
			when CALC =>
				sine_next <= sine_reg + shift_right(cosine_reg, SHIFTSIZE);
				state_next <= IDLE;
		end case;
	end process NSL;

	-- Output
	cosine_u <= resize(unsigned(cosine_reg + to_signed(ADD_OFFSET, NBITS)), NBITS);
	sine_u <= resize(unsigned(sine_reg + to_signed(ADD_OFFSET, NBITS)), NBITS);
	cosine_s <= cosine_reg;
	sine_s <= sine_reg;
	busy <= '0' when state_reg = IDLE else '1';

end architecture;