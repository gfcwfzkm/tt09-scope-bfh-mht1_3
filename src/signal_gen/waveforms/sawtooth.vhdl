library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity sawtooth is
	port (
		counter : in unsigned(6 downto 0);
		saw_signal : out std_logic_vector(7 downto 0)
	);
end entity sawtooth;

architecture rtl of sawtooth is
begin

	saw_signal <= (std_logic_vector(counter) & "0");

end architecture;