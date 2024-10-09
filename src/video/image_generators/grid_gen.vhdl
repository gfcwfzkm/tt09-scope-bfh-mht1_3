-- TerosHDL Documentation:
--! @title Grid Generator
--! @author Pascal Gesell (gesep1 / gfcwfzkm)
--! @version 1.0
--! @date 09.10.2024
--! @brief Generates a grid on the display.
--!
--! This module generates a grid on the display. The grid is generated based on the display position
--! and the grid size, resulting in a grid that is displayed on the screen.
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Grid_Gen is
	generic (
		--! HDMI Horizontal Bitwidth
		c_HDMI_H_BITWIDTH	: positive := 10;
		--! HDMI Vertical Bitwidth
		c_HDMI_V_BITWIDTH	: positive := 10;
		--! Scope Grid Horizontal
		c_SCOPE_GRID_H		: positive := 60;
		--! Scope Grid Vertical
		c_SCOPE_GRID_V		: positive := 64;
		--! HDMI Horizontal Visible
		c_HDMI_H_VISIBLE	: positive := 480;
		--! HDMI Vertical Visible
		c_HDMI_V_VISIBLE	: positive := 640
	);
	port (
		--! X Position of Display
		disp_x		: in unsigned(c_HDMI_H_BITWIDTH-1 downto 0);
		--! Y Position of Display
		disp_y		: in unsigned(c_HDMI_V_BITWIDTH-1 downto 0);
		--! Output of active signal
		grid_active	: out std_logic
	);
end entity;

architecture rtl of Grid_Gen is
begin
	--! Generate the grid
	process (disp_x, disp_y)
	begin
		-- Generate a grid that results in 10 x 10 board
		if (((disp_x mod c_SCOPE_GRID_H = 0) or (disp_y mod c_SCOPE_GRID_V = 0)) or (disp_y = (c_HDMI_V_VISIBLE-1))) or (disp_x = (c_HDMI_H_VISIBLE-1)) then
			grid_active <= '1';
		else
			grid_active <= '0';
		end if;
	end process;
end architecture;