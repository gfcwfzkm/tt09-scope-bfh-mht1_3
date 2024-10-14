library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity uart_tx_tb is
end entity uart_tx_tb;

architecture rtl of uart_tx_tb is
	constant F_CLK : positive := 25_000_000; --! FPGA clock frequency in Hz
	constant CLK_PERIOD : time := 1 sec / F_CLK;
	constant CLK_H_PERIOD : time := CLK_PERIOD / 2;
	
	signal tb_finished : boolean := false;
	signal tb_clk : std_logic := '0';
	signal tb_reset : std_logic := '1';
	signal tb_data_to_send : std_logic_vector(7 downto 0) := (others => '0');
	signal tb_start_sending : std_logic := '0';
	signal tb_busy : std_logic;
	signal tb_tx : std_logic;
begin

	uart_tx_inst : entity work.uart_tx
  		generic map (
    		CLK_FREQ => F_CLK,
    		BAUD_RATE => 9600
  		)
  		port map (
    		clk => tb_clk,
    		reset => tb_reset,
    		data_to_send => tb_data_to_send,
    		start_sending => tb_start_sending,
    		busy => tb_busy,
    		tx => tb_tx
  	);


	tb_clk <= not tb_clk after CLK_H_PERIOD when not tb_finished else '0';

	STIMULI : process

	begin
		wait for 10 ns;
		tb_reset <= '0';
		wait until falling_edge(tb_clk);

		tb_data_to_send <= "01010101";
		tb_start_sending <= '1';
		wait until falling_edge(tb_clk);
		tb_start_sending <= '0';
		wait until tb_busy = '0';
		wait until falling_edge(tb_clk);
		tb_data_to_send <= "10101010";
		tb_start_sending <= '1';
		wait until falling_edge(tb_clk);
		tb_start_sending <= '0';
		wait until tb_busy = '0';

		tb_finished <= true;
		wait;
	end process STIMULI;

end architecture;