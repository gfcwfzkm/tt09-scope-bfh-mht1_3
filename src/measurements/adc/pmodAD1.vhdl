library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity pmodAD1 is
	port (
		clk   : in std_logic;
		reset : in std_logic;
		
		-- Control & Data
		start	: in std_logic;
		busy	: out std_logic;
		data	: out std_logic_vector(7 downto 0);

		-- SPI
		sclk	: out std_logic;
		miso	: in std_logic;
		cs_n	: out std_logic
	);
end entity pmodAD1;

architecture rtl of pmodAD1 is
	type state_type is (IDLE, SHIFT, DONE);
	signal state_reg, state_next : state_type;

	signal shift_reg, shift_next : std_logic_vector(7 downto 0);
	signal cnt_reg, cnt_next : unsigned(3 downto 0);
	signal sclk_reg, sclk_next : std_logic;
begin

	sclk <= sclk_reg;
	cs_n <= '0' when state_reg = SHIFT else '1';
	busy <= '1' when state_reg /= IDLE else '0';
	data <= shift_reg;

	CLKREG : process (clk, reset) is
	begin
		if reset = '1' then
			state_reg <= IDLE;
			shift_reg <= (others => '0');
			cnt_reg <= (others => '0');
			sclk_reg <= '1';
		elsif rising_edge(clk) then
			state_reg <= state_next;
			shift_reg <= shift_next;
			cnt_reg <= cnt_next;
			sclk_reg <= sclk_next;
		end if;
	end process CLKREG;
	
	FSM : process (state_reg, cnt_reg, sclk_reg, shift_reg, miso, start) is
	begin
		state_next <= state_reg;
		shift_next <= shift_reg;
		cnt_next <= cnt_reg;
		sclk_next <= sclk_reg;
		data <= shift_reg;
		
		case state_reg is
			when IDLE =>
				if start = '1' then
					state_next <= SHIFT;
					shift_next <= (others => '0');
					cnt_next <= "1111";
				end if;
			when SHIFT =>
				sclk_next <= not sclk_reg;

				if cnt_reg >= 4 then
					shift_next(0) <= miso;
				end if;

				if sclk_reg = '0' then
					if cnt_reg = 0 then
						state_next <= DONE;
					else
						cnt_next <= cnt_reg - 1;
						if cnt_reg >= 5 and cnt_reg <= 11 then
							shift_next(7 downto 1) <= shift_reg(6 downto 0);
						end if;
					end if;
				end if;
			when DONE =>
				state_next <= IDLE;
				sclk_next <= '1';
		end case;
	end process FSM;

end architecture;