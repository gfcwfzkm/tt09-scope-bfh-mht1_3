library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity settings is
	port (
		clk   : in std_logic;
		reset : in std_logic;
		
		sample_inputs : in std_logic;

		buttons : in std_logic_vector(3 downto 0);
		switches : in std_logic_vector(1 downto 0);

		trigger_start : out std_logic;

		chAmplitude : out signed(2 downto 0);
		chOffset : out unsigned(4 downto 0);
		triggerXPos : out unsigned(3 downto 0);
		triggerYPos : out unsigned(4 downto 0);
		timebase : out unsigned(3 downto 0);
		memoryShift : out signed(7 downto 0)
	);
end entity settings;

architecture rtl of settings is
	component debouncer
		port (
		  	clk : in std_logic;
		  	reset : in std_logic;
		  	in_raw : in std_logic;
		  	deb_en : in std_logic;
		  	debounced : out std_logic;
		  	released : out std_logic;
		  	pressed : out std_logic
		);
	end component;

	constant AMPLITUDE_DEFAULT : signed(2 downto 0)	:= to_signed(0,	chAmplitude'length);
	constant AMPLITUDE_MIN : signed(2 downto 0)		:= to_signed(-2,	chAmplitude'length);
	constant AMPLITUDE_MAX : signed(2 downto 0)		:= to_signed(2,		chAmplitude'length);
	constant OFFSET_DEFAULT : unsigned(4 downto 0)	:= to_unsigned(4,	chOffset'length);
	constant OFFSET_MAX : unsigned(4 downto 0)		:= to_unsigned(19,	chOffset'length);
	constant OFFSET_MIN : unsigned(4 downto 0)		:= to_unsigned(0,	chOffset'length);
	constant TRIGGER_X_DEFAULT : unsigned(3 downto 0)	:= to_unsigned(8,	triggerXPos'length);
	constant TRIGGER_X_MAX : unsigned(3 downto 0)	:= to_unsigned(15,	triggerXPos'length);
	constant TRIGGER_X_MIN : unsigned(3 downto 0)	:= to_unsigned(0,	triggerXPos'length);
	constant TRIGGER_Y_DEFAULT : unsigned(4 downto 0)	:= to_unsigned(3,	triggerYPos'length);
	constant TRIGGER_Y_MAX : unsigned(4 downto 0)	:= to_unsigned(19,	triggerYPos'length);
	constant TRIGGER_Y_MIN : unsigned(4 downto 0)	:= to_unsigned(0,	triggerYPos'length);
	constant TIMEBASE_DEFAULT : unsigned(3 downto 0)	:= to_unsigned(0,	timebase'length);
	constant TIMEBASE_MAX : unsigned(3 downto 0)	:= to_unsigned(15,	timebase'length);
	constant TIMEBASE_MIN : unsigned(3 downto 0)	:= to_unsigned(0,	timebase'length);
	constant MEMORY_SHIFT_DEFAULT : signed(7 downto 0)	:= to_signed(0,	memoryShift'length);
	constant MEMORY_SHIFT_MAX : signed(7 downto 0)	:= to_signed(127,	memoryShift'length);
	constant MEMORY_SHIFT_MIN : signed(7 downto 0)	:= to_signed(-127,	memoryShift'length);

	signal debounced_buttons_pressed : std_logic_vector(3 downto 0);
	signal debounced_switches : std_logic_vector(1 downto 0);

	signal chAmplitude_reg, chAmplitude_next : signed(chAmplitude'length-1 downto 0);
	signal chOffset_reg, chOffset_next : unsigned(chOffset'length-1 downto 0);
	signal triggerXPos_reg, triggerXPos_next : unsigned(triggerXPos'length-1 downto 0);
	signal triggerYPos_reg, triggerYPos_next : unsigned(triggerYPos'length-1 downto 0);
	signal timebase_reg, timebase_next : unsigned(timebase'length-1 downto 0);
	signal memoryShift_reg, memoryShift_next : signed(memoryShift'length-1 downto 0);
begin

	CLKREG : process(clk, reset) is
	begin
		if reset = '1' then
			chAmplitude_reg <= AMPLITUDE_DEFAULT;
			chOffset_reg <=OFFSET_DEFAULT;
			triggerXPos_reg <= TRIGGER_X_DEFAULT;
			triggerYPos_reg <= TRIGGER_Y_DEFAULT;
			timebase_reg <= TIMEBASE_DEFAULT;
			memoryShift_reg <= MEMORY_SHIFT_DEFAULT;
		elsif rising_edge(clk) then
			chAmplitude_reg <= chAmplitude_next;
			chOffset_reg <= chOffset_next;
			triggerXPos_reg <= triggerXPos_next;
			triggerYPos_reg <= triggerYPos_next;
			timebase_reg <= timebase_next;
			memoryShift_reg <= memoryShift_next;
		end if;
	end process CLKREG;

	NSL : process(debounced_buttons_pressed, debounced_switches, chAmplitude_reg, chOffset_reg,
				  triggerXPos_reg, triggerYPos_reg, timebase_reg, memoryShift_reg) is
	begin
		chAmplitude_next <= chAmplitude_reg;
		chOffset_next <= chOffset_reg;
		triggerXPos_next <= triggerXPos_reg;
		triggerYPos_next <= triggerYPos_reg;
		timebase_next <= timebase_reg;
		memoryShift_next <= memoryShift_reg;
		trigger_start <= '0';

		case debounced_switches is
			when "00" =>
				if debounced_buttons_pressed(0) = '1' then
					-- Button 0: Trigger up
					if triggerYPos_reg /= TRIGGER_Y_MAX then
						triggerYPos_next <= triggerYPos_reg + 1;
					end if;
				elsif debounced_buttons_pressed(1) = '1' then
					-- Button 1: Trigger down
					if triggerYPos_reg /= TRIGGER_Y_MIN then
						triggerYPos_next <= triggerYPos_reg - 1;
					end if;
				elsif debounced_buttons_pressed(2) = '1' then
					-- Button 2: Trigger left
					if triggerXPos_reg /= TRIGGER_X_MAX then
						triggerXPos_next <= triggerXPos_reg + 1;
					end if;
				elsif debounced_buttons_pressed(3) = '1' then
					-- Button 3: Trigger right
					if triggerXPos_reg /= TRIGGER_X_MIN then
						triggerXPos_next <= triggerXPos_reg - 1;
					end if;
				end if;
			when "01" =>
				if debounced_buttons_pressed(0) = '1' then
					-- Button 0: Zoom in
					if chAmplitude_reg /= AMPLITUDE_MAX then
						chAmplitude_next <= chAmplitude_reg + 1;
					end if;
				elsif debounced_buttons_pressed(1) = '1' then
					-- Button 1: Zoom out
					if chAmplitude_reg /= AMPLITUDE_MIN then
						chAmplitude_next <= chAmplitude_reg - 1;
					end if;
				elsif debounced_buttons_pressed(2) = '1' then
					-- Button 2: Offset up
					if chOffset_reg /= OFFSET_MAX then
						chOffset_next <= chOffset_reg + 1;
					end if;
				elsif debounced_buttons_pressed(3) = '1' then
					-- Button 3: Offset down
					if chOffset_reg /= OFFSET_MIN then
						chOffset_next <= chOffset_reg - 1;
					end if;
				end if;
			when "10" =>
				if debounced_buttons_pressed(0) = '1' then
					-- Button 0: Timebase up
					if timebase_reg /= TIMEBASE_MAX then
						timebase_next <= timebase_reg + 1;
					end if;
				elsif debounced_buttons_pressed(1) = '1' then
					-- Button 1: Timebase down
					if timebase_reg /= TIMEBASE_MIN then
						timebase_next <= timebase_reg - 1;
					end if;
				elsif debounced_buttons_pressed(2) = '1' then
					-- Button 2: Memory shift up/right
					if memoryShift_reg /= MEMORY_SHIFT_MAX then
						memoryShift_next <= memoryShift_reg + 1;
					end if;
				elsif debounced_buttons_pressed(3) = '1' then
					-- Button 3: Memory shift down/left
					if memoryShift_reg /= MEMORY_SHIFT_MIN then
						memoryShift_next <= memoryShift_reg - 1;
					end if;
				end if;
			when "11" =>
				if debounced_buttons_pressed(0) = '1' then
					-- Trigger Start / Stop
					trigger_start <= '1';
				end if;
			when others =>
				null;
		end case;
	end process NSL;

	-- Output the register values
	chAmplitude <= chAmplitude_reg;
	chOffset <= chOffset_reg;
	triggerXPos <= triggerXPos_reg;
	triggerYPos <= triggerYPos_reg;
	timebase <= timebase_reg;
	memoryShift <= memoryShift_reg;

	BUTTON_DEBOUNCER : for i in 0 to 3 generate
		DEBOUNCE_BUTTONS : debouncer
		port map (
			clk => clk,
			reset => reset,
			in_raw => buttons(i),
			deb_en => sample_inputs,
			debounced => open,
			released => open,
			pressed => debounced_buttons_pressed(i)
		);
	end generate;

	SWITCH_DEBOUNCER : for i in 0 to 1 generate
		DEBOUNCE_SWITCHES : debouncer
		port map (
			clk => clk,
			reset => reset,
			in_raw => switches(i),
			deb_en => sample_inputs,
			debounced => debounced_switches(i),
			released => open,
			pressed => open
		);
	end generate;

end architecture;