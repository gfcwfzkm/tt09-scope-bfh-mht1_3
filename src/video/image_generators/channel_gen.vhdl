library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity channel_gen is
	generic (
		c_HDMI_H_BITWIDTH	: positive := 10;
		c_HDMI_V_BITWIDTH	: positive := 10;
		c_LINEWIDTH			: positive := 32
	);
	port (		
		disp_x : in unsigned(c_HDMI_H_BITWIDTH-1 downto 0);
		disp_y : in unsigned(c_HDMI_V_BITWIDTH-1 downto 0);

		ShowDotInsteadOfLine : in std_logic;

		currentSample : in unsigned(7 downto 0);
		lastSample : in unsigned(7 downto 0);

		chAmplitude : in signed(2 downto 0);
		chOffset : in unsigned(4 downto 0);

		channel : out std_logic;
		offset : out std_logic
	);
end entity channel_gen;

architecture rtl of channel_gen is
	signal currentSampleCalced : unsigned(c_HDMI_V_BITWIDTH-1 downto 0);
	signal lastSampleCalced : unsigned(c_HDMI_V_BITWIDTH-1 downto 0);
	signal offsetCalced : unsigned(c_HDMI_V_BITWIDTH-1 downto 0);
	signal lineMode : std_logic;
	signal dotMode : std_logic;
begin

	-- Multiply the channel offset by 16 (offset moves in 16 pixel steps)
	offsetCalced <= shift_left(resize(unsigned(chOffset), c_HDMI_V_BITWIDTH), 5);

	offset <= '1' when disp_x < to_unsigned(c_LINEWIDTH, c_HDMI_H_BITWIDTH) and disp_y = offsetCalced else '0';
	
	currentSampleCalced <= shift_right((resize(unsigned(currentSample), c_HDMI_V_BITWIDTH)), to_integer(-chAmplitude)) + offsetCalced	when chAmplitude < 0 else
						   resize(currentSample, c_HDMI_V_BITWIDTH) + offsetCalced												when chAmplitude = 0 else
						   shift_left((resize(currentSample, c_HDMI_V_BITWIDTH)), to_integer(chAmplitude)) + offsetCalced;
	
	lastSampleCalced <= shift_right((resize(unsigned(lastSample), c_HDMI_V_BITWIDTH)), to_integer(-chAmplitude)) + offsetCalced		when chAmplitude < 0 else
						   resize(lastSample, c_HDMI_V_BITWIDTH) + offsetCalced													when chAmplitude = 0 else
						   shift_left((resize(unsigned(lastSample), c_HDMI_V_BITWIDTH)), to_integer(chAmplitude)) + offsetCalced;
	
	lineMode <= '1' when (disp_y >= currentSampleCalced and disp_y <= lastSampleCalced) or
						 (disp_y <= currentSampleCalced and disp_y >= lastSampleCalced) else '0';
	
	dotMode <= '1' when disp_y = currentSampleCalced else '0';
	
	channel <= dotMode when ShowDotInsteadOfLine = '1' else lineMode;

end architecture;