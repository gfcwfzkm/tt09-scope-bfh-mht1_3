-- TerosHDL Documentation:
--! @title Channel Generator
--! @author Pascal Gesell (gesep1 / gfcwfzkm)
--! @version 1.0
--! @date 09.10.2024
--! @brief Generates a channel signal based on the display position.
--!
--! This module generates a channel signal based on the display position. The channel signal is generated
--! based on the current sample, the last sample, the amplitude, and the offset of the channel.
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity channel_gen is
	generic (
		--! HDMI Horizontal Bitwidth
		c_HDMI_H_BITWIDTH	: positive := 10;
		--! HDMI Vertical Bitwidth
		c_HDMI_V_BITWIDTH	: positive := 10;
		--! Line width
		c_LINEWIDTH			: positive := 32;
		--! Maximum Y position of the display
		c_DISPY_MAX			: positive := 640
	);
	port (
		--! X Position of Display
		disp_x : in unsigned(c_HDMI_H_BITWIDTH-1 downto 0);
		--! Y Position of Display
		disp_y : in unsigned(c_HDMI_V_BITWIDTH-1 downto 0);

		--! Display the channel as a dot instead of a line
		ShowDotInsteadOfLine : in std_logic;

		--! Current sample to be displayed
		currentSample : in unsigned(7 downto 0);
		--! Last sample to be displayed
		lastSample : in unsigned(7 downto 0);

		--! Channel amplitude
		chAmplitude : in signed(2 downto 0);
		--! Channel offset
		chOffset : in unsigned(4 downto 0);

		--! Output of the sample signal
		channel : out std_logic;
		--! Output of the offset signal
		offset : out std_logic
	);
end entity channel_gen;

architecture rtl of channel_gen is
	--! Sample Calculated by shifting it depending on the amplitude and adding the offsetCalced to it
	signal tempCurrentSampleCalced : unsigned(c_HDMI_V_BITWIDTH downto 0);
	--! Last Sample Calculated by shifting it depending on the amplitude and adding the offsetCalced to it
	signal tempLastSampleCalced : unsigned(c_HDMI_V_BITWIDTH downto 0);
	--! Current Sample Calculated (if the calculated position is out of bounds, set to the maximum)
	signal currentSampleCalced : unsigned(c_HDMI_V_BITWIDTH-1 downto 0);
	--! Last Sample Calculated (if the calculated position is out of bounds, set to the maximum)
	signal lastSampleCalced : unsigned(c_HDMI_V_BITWIDTH-1 downto 0);
	--! Offset Calculated (chOffset * 32)
	signal offsetCalced : unsigned(c_HDMI_V_BITWIDTH-1 downto 0);
	--! Active signal for the line mode
	signal lineMode : std_logic;
	--! Active signal for the dot mode
	signal dotMode : std_logic;
begin

	-- Multiply the channel offset by 16 (offset moves in 16 pixel steps)
	offsetCalced <= shift_left(resize(unsigned(chOffset), c_HDMI_V_BITWIDTH), 5);

	offset <= '1' when disp_x < to_unsigned(c_LINEWIDTH, c_HDMI_H_BITWIDTH) and disp_y = offsetCalced else '0';

	tempCurrentSampleCalced <= shift_right((resize(unsigned(currentSample), c_HDMI_V_BITWIDTH+1)), to_integer(-chAmplitude)) + offsetCalced	when chAmplitude < 0 else
						   	   resize(currentSample, c_HDMI_V_BITWIDTH+1) + offsetCalced													when chAmplitude = 0 else
							   shift_left((resize(currentSample, c_HDMI_V_BITWIDTH+1)), to_integer(chAmplitude)) + offsetCalced;

	tempLastSampleCalced <= shift_right((resize(unsigned(lastSample), c_HDMI_V_BITWIDTH+1)), to_integer(-chAmplitude)) + offsetCalced	when chAmplitude < 0 else
							resize(lastSample, c_HDMI_V_BITWIDTH+1) + offsetCalced														when chAmplitude = 0 else
							shift_left((resize(unsigned(lastSample), c_HDMI_V_BITWIDTH+1)), to_integer(chAmplitude)) + offsetCalced;
	
	currentSampleCalced <= tempCurrentSampleCalced(c_HDMI_V_BITWIDTH-1 downto 0) when tempCurrentSampleCalced(c_HDMI_V_BITWIDTH) = '0' else
						   to_unsigned(c_DISPY_MAX - 1, c_HDMI_V_BITWIDTH);
	
	lastSampleCalced <= tempLastSampleCalced(c_HDMI_V_BITWIDTH-1 downto 0) when tempLastSampleCalced(c_HDMI_V_BITWIDTH) = '0' else
						to_unsigned(c_DISPY_MAX - 1, c_HDMI_V_BITWIDTH);

	lineMode <= '1' when (disp_y >= currentSampleCalced and disp_y <= lastSampleCalced) or
						 (disp_y <= currentSampleCalced and disp_y >= lastSampleCalced) else '0';

	dotMode <= '1' when disp_y = currentSampleCalced else '0';

	channel <= dotMode when ShowDotInsteadOfLine = '1' else lineMode;

end architecture;