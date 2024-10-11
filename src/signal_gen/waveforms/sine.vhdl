library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity sine is
	port (
		counter : in unsigned(6 downto 0);
		sine_signal : out std_logic_vector(7 downto 0)
	);
end entity sine;

architecture rtl of sine is
	constant COUNTER_STEPS : integer := 128;
	constant COUNTER_HALF : integer := COUNTER_STEPS/2;
    constant COUNTER_TOP : integer := COUNTER_STEPS - 1;
	constant QUARTER_TABLE_LEN : integer := 32;
	constant SINEWAVE_MAX : unsigned(sine_signal'length-1 downto 0) := x"FF";

	type lut_array is array (QUARTER_TABLE_LEN downto 0) of unsigned(sine_signal'length-1 downto 0);
	constant SINEWAVE_LUT : lut_array := (
        0 => x"83",
        1 => x"89",
        2 => x"8F",
        3 => x"96",
        4 => x"9C",
        5 => x"A2",
        6 => x"A8",
        7 => x"AE",
        8 => x"B3",
        9 => x"B9",
        10 => x"BF",
        11 => x"C4",
        12 => x"C9",
        13 => x"CE",
        14 => x"D3",
        15 => x"D7",
        16 => x"DC",
        17 => x"E0",
        18 => x"E3",
        19 => x"E7",
        20 => x"EA",
        21 => x"ED",
        22 => x"F0",
        23 => x"F3",
        24 => x"F5",
        25 => x"F7",
        26 => x"F8",
        27 => x"FA",
        28 => x"FB",
        29 => x"FC",
        30 => x"FD",
        31 => x"FD",
		others => x"FU"
	);

	signal sinewave : unsigned(sine_signal'length-1 downto 0);
begin

	sinewave <= SINEWAVE_LUT(to_integer(unsigned(counter)))									when counter < QUARTER_TABLE_LEN else					-- 0 - 31
				SINEWAVE_LUT(to_integer(COUNTER_HALF - 1 - unsigned(counter)))				when counter < COUNTER_HALF else						-- 32 - 63
				SINEWAVE_MAX - SINEWAVE_LUT(to_integer(unsigned(counter) - COUNTER_HALF))	when counter < (QUARTER_TABLE_LEN + COUNTER_HALF) else	-- 64 - 95
				SINEWAVE_MAX - SINEWAVE_LUT(to_integer(COUNTER_TOP - unsigned(counter)));															-- 96 - 127
	
	sine_signal <= std_logic_vector(sinewave);

end architecture;