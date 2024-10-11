library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity rectangle is
	port (
		counter : in unsigned(6 downto 0);
		rect_signal : out std_logic_vector(7 downto 0)
	);
end entity rectangle;

architecture rtl of rectangle is
	constant COUNTER_STEPS : integer := 128;
	constant COUNTER_HALF : integer := COUNTER_STEPS/2;
	constant RECT_MIN : std_logic_vector(rect_signal'length-1 downto 0) := x"00";
	constant RECT_MAX : std_logic_vector(rect_signal'length-1 downto 0) := x"FF";
begin

	rect_signal <= RECT_MAX when counter >= COUNTER_HALF else RECT_MIN;

end architecture;