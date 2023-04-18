-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2022 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Jaroslav Streit <xstrei06 AT stud.fit.vutbr.cz>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

    signal pc_reg   : std_logic_vector(11 downto 0);
    signal pc_inc   : std_logic;
    signal pc_dec   : std_logic;

    signal ptr_reg  : std_logic_vector(11 downto 0);
    signal ptr_inc  : std_logic;
    signal ptr_dec  : std_logic;

    signal cnt_reg  : std_logic_vector(7 downto 0);
    signal cnt_inc  : std_logic;
    signal cnt_dec  : std_logic;

  -- fsm states
    type fsm_state is (
        s_start,
        s_fetch,
        s_decode,
        s_ptr_inc,
        s_ptr_dec,
        s_ptrval_inc,
        s_ptrval_inc2,
        s_ptrval_inc3,
        s_ptrval_dec,
        s_ptrval_dec2,
        s_ptrval_dec3,
        s_while_open,
        s_while_open2,
        s_find_while_end,
        s_find_while_end2,
        s_while_close,
        s_while_close2,
        s_find_while_start,
        s_find_while_start2,
        s_find_while_start3,
        s_dowhile_open,
        s_dowhile_open2,
        s_dowhile_close,
        s_dowhile_close2,
        s_close3,
        s_find_dowhile_start,
        s_find_dowhile_start2,
        s_find_dowhile_start3,
        s_write,
        s_write2,
        s_load,
        s_load2,
        s_load3,
        s_null
    );

    signal state    :  fsm_state := s_start;
    signal n_state  :  fsm_state;

  --multiplexors
    signal mux1_sel  :  std_logic;
    signal mux1_out  :  std_logic_vector(12 downto 0);

    signal mux2_sel  :  std_logic_vector(1 downto 0);
    signal mux2_out  :  std_logic_vector(7 downto 0);



begin

    pc_cntr: process (RESET, CLK, pc_inc, pc_dec) is 
    begin
        if RESET = '1' then 
            pc_reg <= (others => '0');
        elsif rising_edge(CLK) then
            if pc_inc = '1' then 
                pc_reg <= pc_reg + 1;
            elsif pc_dec = '1' then
                pc_reg <= pc_reg - 1;
            end if;
        end if;
    end process;

    ptr_cntr: process (RESET, CLK, ptr_inc, ptr_dec) is 
    begin
        if RESET = '1' then
            ptr_reg <= (others => '0');
        elsif rising_edge(CLK) then
            if ptr_inc = '1' then
                ptr_reg <= ptr_reg + 1;
            elsif ptr_dec = '1' then
                ptr_reg <= ptr_reg - 1;
            end if;
        end if;
    end process;

    cnt_cntr: process (RESET, CLK, cnt_inc, cnt_dec) is
    begin
        if RESET = '1' then
            cnt_reg <= (others => '0');
        elsif rising_edge(CLK) then
            if cnt_inc = '1' then
                cnt_reg <= cnt_reg + 1;
            elsif cnt_dec = '1' then
                cnt_reg <= cnt_reg - 1;
            end if;
        end if;
    end process;

    mux_1: process (RESET, CLK, mux1_sel) is
    begin
        if RESET = '1' then
            mux1_out <= (others => '0');
        elsif (rising_edge(CLK)) then
            if mux1_sel = '0' then
                mux1_out <= '0' & pc_reg;
            else
                mux1_out <= '1' & ptr_reg;
            end if;
        end if;
    end process;
    DATA_ADDR <= mux1_out;

    mux_2: process (RESET, CLK, mux2_sel) is
    begin
        if RESET = '1' then
            mux2_out <= (others => '0');
        elsif rising_edge(CLK) then
            case mux2_sel is 
                when "00" => 
                    mux2_out <= IN_DATA;
                when "01" =>
                    mux2_out <= DATA_RDATA + 1;
                when "10" => 
                    mux2_out <= DATA_RDATA - 1;
                when others => 
                    mux2_out <= (others => '0');
            end case;
        end if;
    end process;
    DATA_WDATA <= mux2_out;

  -- FSM
    n_state_load: process (RESET, CLK, EN) is
    begin
        if RESET = '1' then
            state <= s_start;
        elsif rising_edge(CLK) then
            if EN = '1' then
                state <= n_state;
            end if;
        end if;
    end process;

    fsm: process (state, OUT_BUSY, IN_VLD, DATA_RDATA, cnt_reg) is
    begin
        pc_inc    <= '0';
        pc_dec    <= '0';
        ptr_inc   <= '0';
        ptr_dec   <= '0';
        cnt_inc   <= '0';
        cnt_dec   <= '0';
        
        DATA_EN   <= '1';
        IN_REQ    <= '0';
        OUT_WE    <= '0';
        DATA_RDWR <= '0';

        mux1_sel <= '0';
        mux2_sel <= "00";

        case state is
            when s_start =>  
                n_state <= s_fetch;
            when s_fetch => 
                n_state <= s_decode;
            when s_decode =>
                case DATA_RDATA is
                    when x"3E" => 
                        pc_inc <= '1';
                        ptr_inc <= '1';
                        n_state <= s_ptr_inc;
                    when x"3C" => 
                        pc_inc <= '1';
                        ptr_dec <= '1';
                        n_state <= s_ptr_dec;
                    when x"2B" => 
                        mux1_sel <= '1';
                        n_state <= s_ptrval_inc;
                    when x"2D" =>
                        mux1_sel <= '1';
                        n_state <= s_ptrval_dec;
                    when x"5B" =>
                        mux1_sel <= '1';
                        n_state <= s_while_open;
                    when x"5D" => 
                        mux1_sel <= '1';
                        n_state <= s_while_close;
                    when x"28" => n_state <= s_dowhile_open;
                    when x"29" => 
                        mux1_sel <= '1';
                        n_state <= s_dowhile_close;
                    when x"2E" => 
                        mux1_sel <= '1';
                        n_state <= s_write;
                    when x"2C" =>
                        IN_REQ <= '1';
                        n_state <= s_load;
                    when x"00" => n_state <= s_null;
                    when others => pc_inc <= '1';
                                   n_state <= s_start; 
                end case;
            when s_ptr_inc => 
                n_state <= s_fetch;
            when s_ptr_dec => 
                n_state <= s_fetch;
            when s_ptrval_inc =>
                DATA_RDWR <= '0';
                n_state <= s_ptrval_inc2;
            when s_ptrval_inc2 =>
                mux1_sel <= '1';
                mux2_sel <= "01";
                pc_inc <= '1';
                n_state <= s_ptrval_inc3;
            when s_ptrval_inc3 =>
                DATA_RDWR <= '1';
                n_state <= s_fetch;
            when s_ptrval_dec =>
                DATA_RDWR <= '0';
                n_state <= s_ptrval_dec2;
            when s_ptrval_dec2 =>
                mux1_sel <= '1';
                mux2_sel <= "10";
                pc_inc <= '1';
                n_state <= s_ptrval_dec3;
            when s_ptrval_dec3 =>
                mux2_sel <= "00";
                DATA_RDWR <= '1';
                n_state <= s_fetch;
            when s_write =>
                mux1_sel <= '1';
                if OUT_BUSY = '1' then
                    n_state <= s_write;
                else
                    pc_inc <= '1';
                    n_state <= s_write2;
                end if;
            when s_write2 =>
                OUT_WE <= '1';
                OUT_DATA <= DATA_RDATA;
                n_state <= s_fetch;
            when s_load =>
                mux1_sel <= '1';
                IN_REQ <= '1';
                if IN_VLD = '1' then
                    pc_inc <= '1';
                    n_state <= s_load2;
                else 
                    n_state <= s_load;
                end if;
            when s_load2 =>
                DATA_RDWR <= '1';
                n_state <= s_fetch;
            
            
            when s_while_open =>
                pc_inc <= '1';
                n_state <= s_while_open2;
            when s_while_open2 =>
                if DATA_RDATA = "00000000" then
                    n_state <= s_find_while_end;
                else
                    n_state <= s_fetch;
                end if;
            when s_find_while_end2 =>
                n_state <= s_find_while_end;
            when s_find_while_end =>
                if DATA_RDATA = x"5D" and cnt_reg = "00000001" then
                    cnt_dec <= '1';
                    n_state <= s_decode;
                elsif DATA_RDATA = x"5B" then
                    cnt_inc <= '1';
                    pc_inc <= '1';
                    n_state <= s_find_while_end2;
                elsif DATA_RDATA = x"5D" then
                    cnt_dec <= '1';
                    pc_inc <= '1';
                    n_state <= s_find_while_end2;
                else   
                    pc_inc <= '1';
                    n_state <= s_find_while_end2;
                end if;                    
            when s_while_close =>
                n_state <= s_while_close2;
            when s_while_close2 => 
                if DATA_RDATA = "00000000" then
                    pc_inc <= '1';
                    n_state <= s_close3;
                else
                    pc_dec <= '1';
                    n_state <= s_find_while_start;
                end if;
            when s_find_while_start =>
                n_state <= s_find_while_start2;
            when s_find_while_start2 =>
                n_state <= s_find_while_start3;
            when s_find_while_start3 =>
                if DATA_RDATA = x"5B" and cnt_reg = "00000000" then
                    n_state <= s_fetch;
                elsif DATA_RDATA = x"5D" then
                    cnt_inc <= '1';
                    pc_dec <= '1';
                    n_state <= s_find_while_start;
                elsif DATA_RDATA = x"5B" then
                    cnt_dec <= '1';
                    pc_dec <= '1';
                    n_state <= s_find_while_start;
                else   
                    pc_dec <= '1';
                    n_state <= s_find_while_start;
                end if;
              
                
            when s_dowhile_open =>
                pc_inc <= '1';
                n_state <= s_dowhile_open2;
            when s_dowhile_open2 =>
                n_state <= s_fetch;               
            when s_dowhile_close =>
                n_state <= s_dowhile_close2;
            when s_dowhile_close2 => 
                if DATA_RDATA = "00000000" then
                    pc_inc <= '1';
                    n_state <= s_close3;
                else
                    pc_dec <= '1';
                    n_state <= s_find_dowhile_start;
                end if;
            when s_close3 =>
                n_state <= s_fetch;
            when s_find_dowhile_start =>
                n_state <= s_find_dowhile_start2;
            when s_find_dowhile_start2 =>
                n_state <= s_find_dowhile_start3;
            when s_find_dowhile_start3 =>
                if DATA_RDATA = x"28" and cnt_reg = "00000000" then
                    n_state <= s_fetch;
                elsif DATA_RDATA = x"29" then
                    cnt_inc <= '1';
                    pc_dec <= '1';
                    n_state <= s_find_dowhile_start;
                elsif DATA_RDATA = x"28" then
                    cnt_dec <= '1';
                    pc_dec <= '1';
                    n_state <= s_find_dowhile_start;
                else
                    pc_dec <= '1';
                    n_state <= s_find_dowhile_start;
                end if; 
            when s_null => n_state <= s_null;
            when others =>
                n_state <= s_fetch;
        end case;
    end process;
end behavioral;

