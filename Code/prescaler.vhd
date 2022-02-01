library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity prescaler is
    
    Port ( sys_clk   : in STD_LOGIC;       -- 100MHz
           reset     : in STD_LOGIC;
           en_25MHz  : out STD_LOGIC;      --  25MHz (for SPI commands)
           en_44kHz  : out STD_LOGIC;      --  44kHz (for RAM output)
           en_800kHz : out STD_LOGIC);     --  800kHz (for SD_read initialization clock)
           
end entity;

architecture Behavioral of prescaler is

signal counter_25MHz : unsigned (1 downto 0) := (others => '0');
signal counter_44kHz : unsigned (11 downto 0) := (others => '0');
signal counter_800kHz  : unsigned (6 downto 0) := (others => '0');


begin

    process (sys_clk)
    begin
        if rising_edge(sys_clk) then
            if reset = '1' then
                counter_25MHz <= (others => '0');
                counter_44kHz <= (others => '0');
                counter_800kHz <= (others => '0');
                en_25MHz <= '0';
                en_44kHz <= '0';
                en_800kHz <= '0';
            else
                if counter_25MHz = 3 then                   -- 25MHz
                    en_25MHz <= '1';
                    counter_25MHz <= (others => '0');
                else
                    en_25MHz <= '0';
                    counter_25MHz <= counter_25MHz + 1;
                end if;
                
                if counter_44kHz = 2267 then                -- 44kHz
                    en_44kHz <= '1';
                    counter_44kHz <= (others => '0');
                else
                    en_44kHz <= '0';
                    counter_44kHz <= counter_44kHz + 1;
                end if;
                
                if counter_800kHz = 124 then                -- 800kHz
                    en_800kHz <= '1';
                    counter_800kHz <= (others => '0');
                else
                    en_800kHz <= '0';
                    counter_800kHz <= counter_800kHz + 1;
                end if;
            end if;
        end if;
    end process;


end Behavioral;
