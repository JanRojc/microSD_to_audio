library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity PCM_to_audio is
  
    Port ( sys_clk   : in STD_LOGIC;
           reset     : in STD_LOGIC;
           PCM_data  : in STD_LOGIC_VECTOR (7 downto 0);  -- should change with frequency: 44 100Hz
           pwm_audio : out STD_LOGIC);
   
end entity;

architecture Behavioral of PCM_to_audio is

-- Out signal
signal pwm : std_logic := '0';
-- Counter
signal counter : unsigned (7 downto 0) := (others => '0');
-- Compare signal
signal compare : unsigned (7 downto 0) := (others => '0');

begin
    -- output
    pwm_audio <= '0' when pwm = '0' else 'Z';   -- output
    
    -- convert (PCM -> PWM), counter
    process (sys_clk)
    begin
        if rising_edge(sys_clk) then
            if reset = '1' or counter = 0 then
                -- read data
                compare <= unsigned(PCM_data);
                counter <= counter + 1;
            elsif counter = 255 then
                -- reset counter
                counter <= (others => '0');
            else
                if counter < compare then
                    pwm <= '1';
                else
                    pwm <= '0';
                end if;
                counter <= counter + 1;
            end if;
        end if;
    end process;

end Behavioral;