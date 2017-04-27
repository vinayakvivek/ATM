library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.ALL;

entity decrypter is
	port (clk: in STD_LOGIC;
        reset : in  STD_LOGIC;
		ciphertext: in STD_LOGIC_VECTOR (63 downto 0);
		start: in STD_LOGIC;
		plaintext: out STD_LOGIC_VECTOR (63 downto 0);
		done_button: in STD_LOGIC;
		done: out STD_LOGIC);
end decrypter;

architecture Behavioral of decrypter is
	constant delta : std_logic_vector(31 downto 0) := x"9e3779b9";
	constant k0 : std_logic_vector(31 downto 0 ) := x"2927c18c";
	constant k1 : std_logic_vector(31 downto 0 ) := x"75f8c48f";
	constant k2 : std_logic_vector(31 downto 0 ) := x"43fd99f7";
	constant k3 : std_logic_vector(31 downto 0 ) := x"ff0f7457";

	signal v0_reg, v0_next : std_logic_vector(31 downto 0);
	signal v1_reg, v1_next : std_logic_vector(31 downto 0);
	signal sum_reg, sum_next : std_logic_vector(31 downto 0);
	signal n_reg, n_next : std_logic_vector(5 downto 0);

	-- define states
	type state_type is (idle, S1, S2, T1, T2, T3);
	signal state_reg, state_next : state_type;
begin

	process(clk, reset)
	begin
		if reset = '1' then
			state_reg <= idle;
			v0_reg <= (others => '0');
			v1_reg <= (others => '0');
			sum_reg <= (others => '0');
			n_reg <= (others => '0');
		elsif (clk'event and clk = '1') then
			state_reg <= state_next;
			v0_reg <= v0_next;
			v1_reg <= v1_next;
			sum_reg <= sum_next;
			n_reg <= n_next;
		end if;
	end process;


	decrypt : process(state_reg, n_reg, v0_reg, v1_reg, sum_reg, start, ciphertext, done_button) is		
	begin 
		done <= '1';
		state_next <= state_reg;
		v0_next <= v0_reg;
		v1_next <= v1_reg;
		sum_next <= sum_reg;
		n_next <= n_reg;

		case state_reg is
			when idle =>
				if start = '1' then
					v0_next <= ciphertext(31 downto 0);
					v1_next <= ciphertext(63 downto 32);
					sum_next <= x"C6EF3720";
					n_next <= "100000";
					state_next <= S1;
					done <= '0';
				end if;

			when S1 => 	-- loop head
				done <= '0';
				if n_reg = 0 then						
					state_next <= S2;							
				else 
					n_next <= n_reg - 1;
					state_next <= T1;
				end if;

			when S2 => 	
				done <= '1';
				if (done_button = '1') then
					state_next <= idle;				
				end if;

			when T1 => 	
				done <= '0';
				v1_next <= v1_reg - (((v0_reg(27 downto 0) & "0000") + k2) xor (v0_reg + sum_reg) xor (("00000" & v0_reg(31 downto 5)) + k3));
				state_next <= T2;

			when T2 => 	
				done <= '0';
				v0_next <= v0_reg - (((v1_reg(27 downto 0) & "0000") + k0) xor (v1_reg + sum_reg) xor (("00000" & v1_reg(31 downto 5)) + k1)); 
				state_next <= T3; 

			when T3 => 	
				done <= '0';
				sum_next <= sum_reg - delta;
				state_next <= S1;	-- go to loop head
		end case;
	end process;

	plaintext(31 downto 0) <= v0_reg;
	plaintext(63 downto 32) <= v1_reg;

end Behavioral;

