library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;

entity video_tb is end;

architecture bench of video_tb is

	signal dut_rgb : std_logic_vector(2 downto 0);
	signal dut_hsync, dut_vsync, dut_de, dut_reset : std_logic;

	signal clk : std_logic := '0';
	signal tb_finished : boolean := false;
begin

	-- The state machine we want to test
	video_inst : entity work.video
		port map (
    		clk => clk,
    		reset => dut_reset,
    		r => dut_rgb(2),
    		g => dut_rgb(1),
    		b => dut_rgb(0),
    		hsync => dut_hsync,
    		vsync => dut_vsync,
    		de => dut_de
	);


	-- Generate Clock and finish the simulation if tb_finished is True
	CLKGEN : process begin
		if (tb_finished = false) then
			clk <= '1'; wait for 5 ns;
			clk <= '0'; wait for 5 ns;
		else
			wait;
		end if;
	end process CLKGEN;
	
	TESTING : process is
		variable count : integer := 0;
	begin 
		report "Start of automated test";
		
		dut_reset <= '1';
		wait until rising_edge(clk);
		wait until falling_edge(clk);
		dut_reset <= '0';
		
		while (count < 1237500) loop
			wait until rising_edge(clk);
			count := count + 1;
		end loop;

		tb_finished <= True;
		wait;

	end process TESTING;		
end architecture;