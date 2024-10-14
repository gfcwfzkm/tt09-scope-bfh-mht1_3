-- Requires: rectange, sawtooth, sine, triangle
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity waveform_test is
end entity waveform_test;

architecture rtl of waveform_test is

	signal tb_finished : boolean := false;
	signal tb_clk : std_logic := '0';
	signal tb_counter : unsigned(6 downto 0) := (others => '0');
	signal tb_sine_signal : std_logic_vector(7 downto 0);
	signal tb_triangle_signal : std_logic_vector(7 downto 0);
	signal tb_rect_signal : std_logic_vector(7 downto 0);
	signal tb_saw_signal : std_logic_vector(7 downto 0);
begin

	sawtooth_inst : entity work.sawtooth
  		port map (
    		counter => tb_counter,
    		saw_signal => tb_saw_signal
  	);

	triangle_inst : entity work.triangle
  		port map (
			counter => tb_counter,
			triangle_signal => tb_triangle_signal
  	);

	rectangle_inst : entity work.rectangle
  		port map (
			counter => tb_counter,
			rect_signal => tb_rect_signal
  	);

	sine_inst : entity work.sine
  		port map (
			counter => tb_counter,
			sine_signal => tb_sine_signal
  	);

	tb_clk <= not tb_clk after 1 ns when not tb_finished else '0';

	process(tb_clk)
	begin
		if rising_edge(tb_clk) then
			tb_counter <= tb_counter + 1;
		end if;
	end process;

	STIMULI : process
	begin
		
		wait for 600 ns;
		tb_finished <= true;
		wait;
	end process;


end architecture;