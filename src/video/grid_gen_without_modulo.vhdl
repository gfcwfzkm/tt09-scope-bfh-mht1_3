library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity Grid_Gen is
	generic (
		c_HDMI_H_BITWIDTH	: positive := 10;
		c_HDMI_V_BITWIDTH	: positive := 10;
		c_SCOPE_GRID_H		: positive := 64;
		c_SCOPE_GRID_V		: positive := 60;
		c_HDMI_H_VISIBLE	: positive := 640;
		c_HDMI_V_VISIBLE	: positive := 480
	);
	port (
		clk			: in std_logic;
		reset		: in std_logic;
		--! X Position of Display
		disp_x		: in unsigned(c_HDMI_H_BITWIDTH downto 0);
		--! Y Position of Display
		disp_y		: in unsigned(c_HDMI_V_BITWIDTH downto 0);
		line_end	: in std_logic;
		--! Output of active signal
		grid_active	: out std_logic
	);
end entity;

architecture rtl of Grid_Gen is
	constant c_GRID_H_BITWIDTH : positive := integer(ceil(log2(real(c_SCOPE_GRID_H))));
	constant c_GRID_V_BITWIDTH : positive := integer(ceil(log2(real(c_SCOPE_GRID_V))));
	
	signal grid_v_counter_reg, grid_v_counter_next : unsigned(c_GRID_V_BITWIDTH-1 downto 0) := (others => '0');

	signal grid_v : std_logic;
	signal grid_h : std_logic;
begin

	--! Check if the grid size is optimized for the module
	assert c_SCOPE_GRID_H = 64 report "Module optimized for 64 horizontal grid size" severity failure;

	--! Generate grid signal
	grid_v <= '1' when grid_v_counter_reg = to_unsigned(0, c_GRID_V_BITWIDTH-1) else
			  '1' when disp_y = c_HDMI_V_VISIBLE - 1 else '0';
	grid_h <= '1' when disp_x(c_GRID_H_BITWIDTH-1 downto 0) = to_unsigned(c_SCOPE_GRID_H, c_GRID_V_BITWIDTH) else
			  '1' when disp_x = c_HDMI_H_VISIBLE - 1 else '0';
	grid_active <= grid_v or grid_h;
	
	CLKREG : process (clk, reset)
	begin
		if reset = '1' then
			grid_v_counter_reg <= (others => '0');
		elsif rising_edge(clk) then
			grid_v_counter_reg <= grid_v_counter_next;
		end if;
	end process;

	NSL : process (disp_y, grid_v_counter_reg, line_end)
	begin
		grid_v_counter_next <= grid_v_counter_reg;

		-- Instead of modulo operation, a counter is now used
		if line_end = '1' then
			if grid_v_counter_reg = to_unsigned(0, c_GRID_V_BITWIDTH-1) then
				grid_v_counter_next <= to_unsigned(c_SCOPE_GRID_V-1, c_GRID_V_BITWIDTH);
			else
				grid_v_counter_next <= grid_v_counter_reg - 1;
			end if;
		elsif disp_y >= c_HDMI_V_VISIBLE then
			grid_v_counter_next <= to_unsigned(0, c_GRID_V_BITWIDTH);
		end if;
	end process NSL;
end architecture;