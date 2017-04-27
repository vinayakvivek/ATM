library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

--entity read_multiple_data_bytes is
--	port (clk : in  STD_LOGIC;
--		  reset : in STD_LOGIC;
--		  data_in : in  STD_LOGIC_VECTOR (7 downto 0);
--		  next_data : in  STD_LOGIC;
--		  done : out STD_LOGIC;
--		  data_read : out  STD_LOGIC_VECTOR (63 downto 0));
--end read_multiple_data_bytes;

--architecture Behavioral of read_multiple_data_bytes is
--	signal count : std_logic_vector(3 downto 0) := (others => '0');

--	--signal n_reg, n_next : STD_LOGIC_VECTOR (3 downto 0);
--	--signal data_reg, data_next : STD_LOGIC_VECTOR (63 downto 0);

--	--type state_type is (idle, S1, S2);
--	--signal state_reg, state_next : state_type; 
--begin

--	---- state registers
--	--process(clk, reset)
--	--begin
--	--	if reset = '1' then
--	--		state_reg <= idle;
--	--		n_reg <= (others => '0');
--	--		data_reg <= (others => '0');
--	--	elsif (clk'event and clk = '1') then
--	--		state_reg <= state_next;
--	--		n_reg <= n_next;
--	--		data_reg <= data_next;
--	--	end if;
--	--end process;
	
--	--read : process(next_data, data_in, state_reg, n_reg, data_reg) is		
--	--begin
--	--	state_next <= state_reg;
--	--	n_next <= n_reg;
--	--	data_next <= data_reg;

--	--	case state_reg is 

--	--		when idle =>
--	--			n_next <= "0111"; 
--	--			data_next <= (others => '0');
--	--			state_next <= S1;

--	--		when S1 =>
--	--			if n_reg = 0 then
--	--				state_next <= S2;
--	--			else
--	--				--if (rising_edge(next_data)) then
--	--					n_next <= n_reg - '1';
--	--					--data_next(to_integer(unsigned(n_reg))*8 + 7 downto to_integer(unsigned(n_reg))*8) <= data_in;
--	--				--end if;
--	--			end if;

--	--		when S2 =>
--	--			done <= '1';
--	--	end case;


--	--end process;

--	--data_read <= data_reg;

--	read : process(reset, next_data) is		
--	begin
--		if reset = '1' then
--			count <= "0000";
--			data_read <= (others => '0');
--		elsif rising_edge(next_data) then
--			data_read(to_integer(unsigned(count))*8 + 7 downto to_integer(unsigned(count))*8) <= data_in;
--			count <= count + '1';
--		end if;

--		if (count = 8) then
--			done <= '1';
--		end if;
--	end process;

--end Behavioral;



entity read_multiple_data_bytes is
    port (clk : in  STD_LOGIC;
          reset : in STD_LOGIC;
          data_in : in  STD_LOGIC_VECTOR (7 downto 0);
          next_data : in  STD_LOGIC;
          read_count : out STD_LOGIC_VECTOR(2 downto 0);
          done : out STD_LOGIC;
          done_button : in STD_LOGIC;
          data_read : out  STD_LOGIC_VECTOR (63 downto 0));
end read_multiple_data_bytes;

architecture Behavioral of read_multiple_data_bytes is
    signal count : std_logic_vector(2 downto 0) := (others => '0');
begin
    read : process(clk, next_data, reset, data_in, count, done_button) is        
    begin
        if reset = '1' OR done_button = '1' then
            count <= "000";
            done <= '0';
            data_read <= (others => '0');
        elsif rising_edge(next_data) then
            data_read(to_integer(unsigned(count))*8 + 7 downto to_integer(unsigned(count))*8) <= data_in;
            if count = "111" then 
                done <= '1';
            end if;
            count <= count + '1';
        end if;
    end process;

    read_count <= count;

end Behavioral;

