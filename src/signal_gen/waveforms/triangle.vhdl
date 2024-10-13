library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity triangle is
	port (
		counter : in unsigned(7 downto 0);
		triangle_signal : out std_logic_vector(7 downto 0)
	);
end entity triangle;

architecture rtl of triangle is
	constant COUNTER_STEPS : integer := 256;
	constant COUNTER_HALF : integer := COUNTER_STEPS/2;
	signal calc_triangle : std_logic_vector(7 downto 0);
begin

	calc_triangle <= std_logic_vector(counter) when counter < COUNTER_HALF 
              else std_logic_vector(COUNTER_STEPS - 1 - counter);
	triangle_signal <= calc_triangle(6 downto 0) & calc_triangle(6);

end architecture;