library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity trigger_detection is
	port (
		last_sample				: in unsigned(7 downto 0);
		current_sample			: in unsigned(7 downto 0);
		trigger_threshold		: in unsigned(4 downto 0);
		
		sample_on_rising_edge	: in std_logic;

		triggered				: out std_logic
	);
end entity trigger_detection;

architecture rtl of trigger_detection is

begin

	

end architecture;