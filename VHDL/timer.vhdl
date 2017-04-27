library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity timer is
	generic ( N : STD_LOGIC_VECTOR (23 downto 0) := x"FFFFFF");
	--generic ( N : STD_LOGIC_VECTOR (19 downto 0) := x"0000F");
	port (
		clk : in STD_LOGIC;
		reset : in STD_LOGIC;
		d : out STD_LOGIC ;
		T : out STD_LOGIC
	);
end timer;

architecture Behavioral of timer is

	signal n_reg, n_next : STD_LOGIC_VECTOR (23 downto 0);
	signal t_reg, t_next : STD_LOGIC;
	signal d_reg, d_next : STD_LOGIC;
	signal var, var_next : STD_LOGIC;

	-- define states
	type state_type is (idle, S1, S2);
	signal state_reg, state_next : state_type; 
begin

	-- state registers
	process(clk, reset)
	begin
		if reset = '1' then
			state_reg <= idle;
			t_reg <= '0';
			d_reg <= '0';
			var <= '0';
			n_reg <= (others => '0');
		elsif (clk'event and clk = '1') then
			state_reg <= state_next;
			t_reg <= t_next;
			d_reg <= d_next;
			n_reg <= n_next;
			var <= var_next;
		end if;
	end process;

	process (state_reg, n_reg, t_reg, d_reg, var) 
	begin
		state_next <= state_reg;
		n_next <= n_reg;
		t_next <= t_reg;
		d_next <= d_reg;
		var_next <=	var;
		case state_reg is 

			when idle =>
				n_next <= N; 
				var_next <= not var;
				state_next <= S1;

			when S1 =>
				if n_reg = 0 then
					state_next <= S2;
				else
					n_next <= n_reg - '1';
				end if;

			when S2 =>
				t_next <= not t_reg;
				if var = '1' then
					d_next <= not d_reg;
				end if;
				state_next <= idle;

		end case;
	end process;

	T <= t_reg;
	d <= d_reg;

end Behavioral;

