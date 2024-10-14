-- TerosHDL Documentation:
--! @title Triangle Waveform Generator
--! @author Pascal Gesell (gesep1 / gfcwfzkm)
--! @version 1.0
--! @date 14.10.2024
--! @brief This module generates a triangle waveform.
--!
--! This module generates a triangle waveform. The output signal is a triangle waveform with a period of 256 steps.
--! The counter range is 256 steps.
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity triangle is
	port (
		--! Counter Signal
		counter : in unsigned(7 downto 0);
		--! Triangle Waveform Signal
		triangle_signal : out std_logic_vector(7 downto 0)
	);
end entity triangle;

architecture rtl of triangle is
	--! Amount of steps the counter has
	constant COUNTER_STEPS : integer := 256;
	--! Half of the counter steps
	constant COUNTER_HALF : integer := COUNTER_STEPS/2;
	--! Intermediate signal for the triangle calculation
	signal calc_triangle : std_logic_vector(7 downto 0);
begin

	-- Calculate the triangle waveform
	calc_triangle <= std_logic_vector(counter) when counter < COUNTER_HALF 
              else std_logic_vector(COUNTER_STEPS - 1 - counter);
	
	-- Assign the calculated triangle waveform to the output signal
	triangle_signal <= calc_triangle(6 downto 0) & calc_triangle(6);

end architecture;