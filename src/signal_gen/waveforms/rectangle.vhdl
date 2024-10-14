-- TerosHDL Documentation:
--! @title Rectangle Waveform Generator
--! @author Pascal Gesell (gesep1 / gfcwfzkm)
--! @version 1.0
--! @date 14.10.2024
--! @brief This module generates a rectangle waveform.
--!
--! This module generates a rectangle waveform. The output signal is high for the first half of the counter range and low for the second half.
--! The counter range is 256 steps.
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity rectangle is
	port (
		--! Counter Signal
		counter : in unsigned(7 downto 0);
		--! Rectangle Waveform Signal
		rect_signal : out std_logic_vector(7 downto 0)
	);
end entity rectangle;

architecture rtl of rectangle is
	--! Amount of steps the counter has
	constant COUNTER_STEPS : integer := 256;
	--! Half of the counter steps
	constant COUNTER_HALF : integer := COUNTER_STEPS/2;
	--! Minimum value of the rectangle signal
	constant RECT_MIN : std_logic_vector(rect_signal'length-1 downto 0) := x"00";
	--! Maximum value of the rectangle signal
	constant RECT_MAX : std_logic_vector(rect_signal'length-1 downto 0) := x"FF";
begin

	rect_signal <= RECT_MAX when counter >= COUNTER_HALF else RECT_MIN;

end architecture;