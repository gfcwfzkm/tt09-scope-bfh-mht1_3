-- TerosHDL Documentation
--! @title Trigger Detection
--! @author Pascal Gesell (gesep1 / gfcwfzkm)
--! @version 1.0
--! @date 09.10.2024
--! @brief Detects a trigger event based on the last and current sample.
--!
--! This module detects a trigger event based on the last and current sample. The trigger event
--! is detected when the current sample is above or below the trigger threshold and the last sample
--! was below or above the trigger threshold. The trigger event can be further controlled by the
--! sample_on_rising_edge signal, which can be used to trigger on the rising or falling edge of the signal.
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity trigger_detection is
	port (
		--! Last measured sample
		last_sample				: in unsigned(3 downto 0);
		--! Current measured sample
		current_sample			: in unsigned(3 downto 0);
		--! Trigger threshold
		trigger_threshold		: in unsigned(3 downto 0);
		
		--! Sample on rising edge if true
		sample_on_rising_edge	: in std_logic;

		--! Trigger event detected
		triggered				: out std_logic
	);
end entity trigger_detection;

architecture rtl of trigger_detection is

begin

	

end architecture;