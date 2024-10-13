library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity sine is
	port (
		counter : in unsigned(7 downto 0);
		sine_signal : out std_logic_vector(7 downto 0)
	);
end entity sine;

architecture rtl of sine is
	constant COUNTER_STEPS : integer := 256;
	constant COUNTER_HALF : integer := COUNTER_STEPS/2;
    constant COUNTER_TOP : integer := COUNTER_STEPS - 1;
	constant QUARTER_TABLE_LEN : integer := COUNTER_HALF/2;
	constant SINEWAVE_MAX : unsigned(sine_signal'length-1 downto 0) := x"FF";

	type lut_array is array (QUARTER_TABLE_LEN downto 0) of unsigned(sine_signal'length-1 downto 0);
	constant SINEWAVE_LUT : lut_array := (
        0 => x"80",
        1 => x"83",
        2 => x"86",
        3 => x"89",
        4 => x"8C",
        5 => x"8F",
        6 => x"92",
        7 => x"95",
        8 => x"99",
        9 => x"9C",
        10 => x"9F",
        11 => x"A2",
        12 => x"A5",
        13 => x"A8",
        14 => x"AB",
        15 => x"AD",
        16 => x"B0",
        17 => x"B3",
        18 => x"B6",
        19 => x"B9",
        20 => x"BC",
        21 => x"BE",
        22 => x"C1",
        23 => x"C4",
        24 => x"C6",
        25 => x"C9",
        26 => x"CB",
        27 => x"CE",
        28 => x"D0",
        29 => x"D2",
        30 => x"D5",
        31 => x"D7",
        32 => x"D9",
        33 => x"DB",
        34 => x"DD",
        35 => x"DF",
        36 => x"E1",
        37 => x"E3",
        38 => x"E5",
        39 => x"E7",
        40 => x"E8",
        41 => x"EA",
        42 => x"EC",
        43 => x"ED",
        44 => x"EF",
        45 => x"F0",
        46 => x"F1",
        47 => x"F3",
        48 => x"F4",
        49 => x"F5",
        50 => x"F6",
        51 => x"F7",
        52 => x"F8",
        53 => x"F8",
        54 => x"F9",
        55 => x"FA",
        56 => x"FA",
        57 => x"FB",
        58 => x"FB",
        59 => x"FB",
        60 => x"FC",
        61 => x"FC",
        62 => x"FC",
        63 => x"FC",
		others => x"FU"
	);

	signal sinewave : unsigned(sine_signal'length-1 downto 0);
begin

	sinewave <= SINEWAVE_LUT(to_integer(unsigned(counter)))									when counter < QUARTER_TABLE_LEN else					-- 0 - 63
				SINEWAVE_LUT(to_integer(COUNTER_HALF - 1 - unsigned(counter)))				when counter < COUNTER_HALF else						-- 63 - 127
				SINEWAVE_MAX - SINEWAVE_LUT(to_integer(unsigned(counter) - COUNTER_HALF))	when counter < (QUARTER_TABLE_LEN + COUNTER_HALF) else	-- 128 - 191
				SINEWAVE_MAX - SINEWAVE_LUT(to_integer(COUNTER_TOP - unsigned(counter)));															-- 192 - 255
	
	sine_signal <= std_logic_vector(sinewave);

end architecture;