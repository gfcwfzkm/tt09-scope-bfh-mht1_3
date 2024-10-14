-- TerosHDL Documentation:
--! @title Sawtooth Waveform Generator
--! @author Pascal Gesell (gesep1 / gfcwfzkm)
--! @version 1.0
--! @date 14.10.2024
--! @brief This module generates a sawtooth waveform.
--!
--! This module generates a sawtooth waveform. The output signal is a sawtooth waveform with a period of 256 steps.
--! The counter range is 256 steps.
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity sawtooth is
	port (
		--! Counter Signal
		counter : in unsigned(7 downto 0);
		--! Sawtooth Waveform Signal
		saw_signal : out std_logic_vector(7 downto 0)
	);
end entity sawtooth;

architecture rtl of sawtooth is
begin

	-- Highly complex mathematical voodoo and calculations
	saw_signal <= std_logic_vector(counter);

end architecture;