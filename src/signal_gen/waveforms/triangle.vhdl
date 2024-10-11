library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity triangle is
	port (
		counter : in unsigned(6 downto 0);
		triangle_signal : out std_logic_vector(7 downto 0)
	);
end entity triangle;

architecture rtl of triangle is
	constant COUNTER_STEPS : integer := 128;
	constant COUNTER_HALF : integer := COUNTER_STEPS/2;
begin

	triangle_signal <= (std_logic_vector(counter) & "0") when counter < COUNTER_HALF 
              else (std_logic_vector(COUNTER_STEPS - counter) & "0");

end architecture;