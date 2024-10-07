library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity trigger_gen is
	generic (
		c_HDMI_H_BITWIDTH	: positive := 10;
		c_HDMI_V_BITWIDTH	: positive := 10;
		c_TRIGGER_X_POS_MIN : positive := 480-32;
		c_TRIGGER_Y_POS_MIN : positive := 640-32
	);
	port (
		--! X Position of Display
		disp_x		: in unsigned(c_HDMI_H_BITWIDTH-1 downto 0);
		--! Y Position of Display
		disp_y		: in unsigned(c_HDMI_V_BITWIDTH-1 downto 0);

		--! Trigger Horizontal Position
		triggerXPos : unsigned(3 downto 0);
		--! Trigger Vertical Position
		triggerYPos : unsigned(4 downto 0);
		--! Channel Offset
		chOffset : in unsigned(4 downto 0);

		--! Output of active signal
		trigger_active	: out std_logic
	);
end entity trigger_gen;

architecture rtl of trigger_gen is
	signal triggerXPos_calced : unsigned(c_HDMI_H_BITWIDTH-1 downto 0);
	signal triggerYPos_calced : unsigned(c_HDMI_V_BITWIDTH-1 downto 0);
	signal channelOffset_calced : unsigned(c_HDMI_V_BITWIDTH-1 downto 0);
	signal trigger_active_x : std_logic;
	signal trigger_active_y : std_logic;
begin

	triggerXPos_calced <= shift_left(resize(triggerXPos, c_HDMI_H_BITWIDTH), 5);
	triggerYPos_calced <= shift_left(resize(triggerYPos, c_HDMI_V_BITWIDTH), 5);
	channelOffset_calced <= shift_left(resize(chOffset, c_HDMI_V_BITWIDTH), 5);

	trigger_active_x <= '1' when disp_x = triggerXPos_calced and disp_y > c_TRIGGER_Y_POS_MIN else '0';
	trigger_active_y <= '1' when disp_y = (triggerYPos_calced + channelOffset_calced) and disp_x > c_TRIGGER_X_POS_MIN else '0';

	trigger_active <= trigger_active_x or trigger_active_y;

end architecture;