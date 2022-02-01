library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RAM_controller is
    Port (
        sys_clk    : in std_logic;
        reset      : in std_logic;
        en_44kHz   : in  std_logic;
        
        byte_ready : in  std_logic;
        dataIn     : in  std_logic_vector (7 downto 0);
        dataOut    : out std_logic_vector (7 downto 0);
        read_en    : out std_logic
    );
end entity;

architecture Behavioral of RAM_controller is

    type RAM_type is array (0 to 511) of std_logic_vector(7 downto 0);
    signal RAM0 : RAM_type := (others => (others => '0'));
    signal RAM1 : RAM_type := (others => (others => '0'));

    signal addrIn  : std_logic_vector (8 downto 0);
    signal addrOut : std_logic_vector (8 downto 0);

    signal byte_ready_old : std_logic := '0';   -- to ensure that writing is done on rising edge of byte_ready

    type state_type is ( RST , READ0_WRITE1 , READ1_WRITE0 );  --  RST -> READ1_WRITE0 -> READ0_WRITE1
    signal state : state_type := RST;                          --               ^               |
                                                               --                \ _ _ _ _ _ _ /
begin

    process (sys_clk)
    begin
        if rising_edge(sys_clk) then
            if (reset = '1') then
                state <= RST;
            end if;

            case (state) is
                when RST =>                         -- wait for SD to initialize, when first byte_ready is received go to READ1_WRITE0
                    addrIn <= (others => '0');
                    addrOut <= (others => '0');
                    read_en <= '1';
                    if (byte_ready = '1' and byte_ready_old = '0') then
                        RAM0(to_integer(unsigned(addrIn))) <= dataIn;
                        addrIn <= std_logic_vector(unsigned(addrIn) + 1);
                        read_en <= '0';
                        state <= READ1_WRITE0;
                    end if;

                when READ1_WRITE0 =>                -- read byte by byte the data in RAM1 and put it to the output
                                                    -- write the data byte from the input to the RAM0 when byte_ready is set to 1 (rising edge)
                    -- write to RAM0
                    if (byte_ready = '1' and byte_ready_old = '0') then
                        RAM0(to_integer(unsigned(addrIn))) <= dataIn;
                        addrIn <= std_logic_vector(unsigned(addrIn) + 1);
                        read_en <= '0';
                    end if;

                    -- read from RAM1
                    if (en_44kHz = '1') then        -- output frequency should be the same as the sampling rate of the audio
                        dataOut <= RAM1(to_integer(unsigned(addrOut)));

                        if (addrOut = "111111111") then     -- if addrOut is 511 (we have read RAM1):
                            addrIn <= (others => '0');      
                            addrOut <= (others => '0');     -- reset addresses,
                            read_en <= '1';                 -- ask for new 512 Bytes 
                            state <= READ0_WRITE1;          -- switch states
                        else
                            addrOut <= std_logic_vector(unsigned(addrOut) + 1);
                        end if;
                    end if;

                when READ0_WRITE1 =>                -- read byte by byte the data in RAM0 and put it to the output
                                                    -- write the data byte from the input to the RAM1 when byte_ready is set to 1 (rising edge)
                    -- write to RAM1
                    if (byte_ready = '1' and byte_ready_old = '0') then
                        RAM1(to_integer(unsigned(addrIn))) <= dataIn;
                        addrIn <= std_logic_vector(unsigned(addrIn) + 1);
                        read_en <= '0';
                    end if;

                    -- read from RAM0
                    if (en_44kHz = '1') then        -- output frequency should be the same as the sampling rate of the audio
                        dataOut <= RAM0(to_integer(unsigned(addrOut)));

                        if (addrOut = "111111111") then     -- if addrOut is 511 (we have read RAM0):
                            addrIn <= (others => '0');
                            addrOut <= (others => '0');     -- reset addresses,
                            read_en <= '1';                 -- ask for new 512 Bytes 
                            state <= READ1_WRITE0;          -- switch states
                        else
                            addrOut <= std_logic_vector(unsigned(addrOut) + 1);
                        end if;
                    end if;

                when others =>
            end case;

            byte_ready_old <= byte_ready;
        end if;
    end process;

end Behavioral;
