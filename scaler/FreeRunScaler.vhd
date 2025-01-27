library IEEE, mylib;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.math_real.all;

use mylib.defBCT.all;
use mylib.defFreeRunScaler.all;

entity FreeRunScaler is
  generic(
    kNumHitInput        : integer:= 128;
    enDebug             : boolean:= false
  );
  port(
    rst	                : in std_logic;
    cntRst              : in std_logic;
    clk	                : in std_logic;

    -- Module Input --
    hbCount             : in std_logic_vector(kWidthCnt-1 downto 0);
    hbfNum              : in std_logic_vector(kWidthCnt-1 downto 0);
    scrEnIn             : in std_logic_vector(kNumSysInput+kNumHitInput-1 downto 0);
    scrRstOut           : out std_logic;

    scrGates            : in std_logic_vector(kNumScrGate-1 downto 0);

    -- Local bus --
    addrLocalBus        : in LocalAddressType;
    dataLocalBusIn      : in LocalBusInType;
    dataLocalBusOut	    : out LocalBusOutType;
    reLocalBus          : in std_logic;
    weLocalBus          : in std_logic;
    readyLocalBus	      : out std_logic
    );
end FreeRunScaler;

architecture RTL of FreeRunScaler is
  attribute mark_debug        : boolean;

  -- System --
  signal sync_reset           : std_logic;
  signal reset_cnt            : std_logic;
  signal cnt_sync_reset       : std_logic;

  -- internal signal declaration ----------------------------------------
  constant kNumScrBlock       : integer:= kNumExtInfo+kNumSysInput+kNumHitInput;
  constant kNumScrChannel     : integer:= kNumSysInput+kNumHitInput;
  constant kNumScr            : integer:= kNumSysInput+kNumScrGate*kNumHitInput;

  signal reg_header           : std_logic_vector(kWidthCnt-1 downto 0);
  signal reg_hb_count         : std_logic_vector(kWidthCnt-1 downto 0);
  signal reg_hbf              : std_logic_vector(kWidthCnt-1 downto 0);

  type kCntType     is array (kNumScr-1 downto 0) of std_logic_vector(kWidthCnt-1 downto 0);
  type kCntReadType is array (kNumScrChannel-1 downto 0) of std_logic_vector(kWidthCnt-1 downto 0);
  signal scr_counter : kCntType;
  signal reg_scr_counter : kCntReadType;

  function GetOffset(reg_latch_scr : std_logic_vector) return integer is
    variable offset   : integer:= 0;
  begin
    case reg_latch_scr is
      when "001" => offset   := 0;
      when "010" => offset   := kNumHitInput;
      when "100" => offset   := 2*kNumHitInput;
      when others => offset   := 0;
    end case;
    return offset;
  end function;

  signal din_fifo             : std_logic_vector(kWidthCnt-1 downto 0);
  signal dout_fifo            : std_logic_vector(7 downto 0);
  signal we_fifo, re_fifo     : std_logic;
  signal empty_fifo           : std_logic;
  signal rv_fifo              : std_logic;

  COMPONENT scr_fifo
    PORT (
      clk : IN STD_LOGIC;
      rst : IN STD_LOGIC;
      din : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      wr_en : IN STD_LOGIC;
      rd_en : IN STD_LOGIC;
      dout : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      full : OUT STD_LOGIC;
      empty : OUT STD_LOGIC;
      valid : OUT STD_LOGIC;
      wr_rst_busy : OUT STD_LOGIC;
      rd_rst_busy : OUT STD_LOGIC
    );
  END COMPONENT;

  type SCRFillProcessType is (
    Idle, FillHbc, FillHbf, FillValue, Finalize
    );

  signal state_fill         : SCRFillProcessType;

  -- Local bus --
  signal reg_latch_scr      : std_logic_vector(kNumScrGate-1 downto 0);
  signal reg_busy           : std_logic;
  signal reg_cnt_reset      : std_logic_vector(kIndexFifoRst downto kIndexLocalRst);
  signal reg_status         : std_logic_vector(7 downto 0);

  -- Local bus --
  type SCRBusProcessType is (
    Init, Idle, Connect,
    Write, Read,
    ReadFIFO,
    Finalize,
    Done
    );
  signal state_lbus	: SCRBusProcessType;

  -- Debug ------------------------------------------------------------
  attribute mark_debug of   cnt_sync_reset  : signal is enDebug;
  attribute mark_debug of   we_fifo         : signal is enDebug;
  attribute mark_debug of   re_fifo         : signal is enDebug;
  attribute mark_debug of   rv_fifo         : signal is enDebug;
  attribute mark_debug of   empty_fifo      : signal is enDebug;
  attribute mark_debug of   reg_latch_scr   : signal is enDebug;
  attribute mark_debug of   state_fill      : signal is enDebug;
  attribute mark_debug of   state_lbus      : signal is enDebug;
  attribute mark_debug of   reg_busy        : signal is enDebug;

  --attribute mark_debug of   scr_counter     : signal is enDebug;
  --attribute mark_debug of   reg_scr_counter : signal is enDebug;

  attribute use_dsp : string;
  attribute use_dsp of scr_counter  : signal is "yes";

-- =============================== body ===============================
begin

  scrRstOut <= reg_cnt_reset(kIndexGolobalRst);
  reset_cnt <= cntRst or reg_cnt_reset(kIndexLocalRst);

  -- External information ----------------------------------------------------------
  u_exinfo : process(clk)
  begin
    if(clk'event and clk = '1') then
      if(unsigned(reg_latch_scr) /= 0) then
        reg_hb_count  <= hbCount;
        reg_hbf       <= hbfNum;
      end if;
    end if;
  end process;

  -- Scaler instance ---------------------------------------------------------------
  gen_scr0 : for i in kNumHitInput to kNumHitInput+kNumSysInput-1 generate

  begin
    process(clk)
    begin
      if(clk'event and clk = '1') then
        if(cnt_sync_reset = '1') then
          scr_counter(i+2*kNumHitInput)  <= (others => '0');
        else
          if(scrEnIn(i) = '1') then
            scr_counter(i+2*kNumHitInput)  <= std_logic_vector(unsigned(scr_counter(i+2*kNumHitInput)) +1);
          end if;
        end if;
      end if;
    end process;

    process(clk)
    begin
      if(clk'event and clk = '1') then
        if(unsigned(reg_latch_scr) /= 0) then
          reg_scr_counter(i)  <= scr_counter(i+2*kNumHitInput);
        end if;
      end if;
    end process;
  end generate;

  --gen_scr1 : for i in kNumSysInput to kNumScrChannel-1 generate
  gen_scr1 : for i in 0 to kNumHitInput-1 generate

  begin
    process(clk)
    begin
      if(cnt_sync_reset = '1') then
        scr_counter(i)                  <= (others => '0');
        scr_counter(i+kNumHitInput)     <= (others => '0');
        scr_counter(i+2*kNumHitInput)   <= (others => '0');
--        scr_counter(i+3*kNumHitInput)   <= (others => '0');
      elsif(clk'event and clk = '1') then
        if(scrEnIn(i) = '1' and scrGates(0) = '1') then
          scr_counter(i)  <= std_logic_vector(unsigned(scr_counter(i)) +1);
        end if;

        if(scrEnIn(i) = '1' and scrGates(1) = '1') then
          scr_counter(i+kNumHitInput)  <= std_logic_vector(unsigned(scr_counter(i+kNumHitInput)) +1);
        end if;

        if(scrEnIn(i) = '1' and scrGates(2) = '1') then
          scr_counter(i+2*kNumHitInput)  <= std_logic_vector(unsigned(scr_counter(i+2*kNumHitInput)) +1);
        end if;

--        if(scrEnIn(i) = '1' and scrGates(3) = '1') then
--          scr_counter(i+3*kNumHitInput)  <= std_logic_vector(unsigned(scr_counter(i+3*kNumHitInput)) +1);
--        end if;
      end if;
    end process;

    process(clk)
    begin
      if(clk'event and clk = '1') then
        if(unsigned(reg_latch_scr) /= 0) then
          reg_scr_counter(i)  <= scr_counter(i + GetOffset(reg_latch_scr));
        end if;
      end if;
    end process;
  end generate;

  u_scr_fill : process(clk)
    variable index  : integer range 0 to kNumScrChannel:= 0;
  begin
    if(clk'event and clk = '1') then
      if(sync_reset = '1') then
        reg_busy    <= '0';
        state_fill  <= Idle;
      else
        case state_fill is
          when Idle =>
            we_fifo   <= '0';
            if(unsigned(reg_latch_scr) /= 0) then
              reg_busy    <= '1';
              --reg_header  <= X"FF04000" & "00" & reg_latch_scr(2 downto 1);
              index       := kNumScrChannel-1;
              state_fill  <= FillHbc;
            end if;

--          when FillHeader =>
--            we_fifo     <= '1';
--            din_fifo    <= reg_header(7 downto 0) & reg_header(15 downto 8) & reg_header(23 downto 16) & reg_header(31 downto 24);
--            state_fill  <= FillHbc;

          when FillHbc =>
            we_fifo     <= '1';
            din_fifo    <= reg_hb_count(7 downto 0) & reg_hb_count(15 downto 8) & reg_hb_count(23 downto 16) & reg_hb_count(31 downto 24);
            state_fill  <= FillHbf;

          when FillHbf =>
            we_fifo     <= '1';
            din_fifo    <= reg_hbf(7 downto 0) & reg_hbf(15 downto 8) & reg_hbf(23 downto 16) & reg_hbf(31 downto 24);
            state_fill  <= FillValue;

          when FillValue =>
            we_fifo   <= '1';
            din_fifo  <= reg_scr_counter(index)(7 downto 0) & reg_scr_counter(index)(15 downto 8) & reg_scr_counter(index)(23 downto 16) & reg_scr_counter(index)(31 downto 24);

            if(index = 0) then
              state_fill  <= Finalize;
            else
              index   := index -1;
            end if;

          when Finalize =>
            reg_busy    <= '0';
            we_fifo     <= '0';
            state_fill  <= Idle;

        end case;
      end if;
    end if;
  end process;

  u_fifo : scr_fifo
    port map (
      clk     => clk,
      rst     => sync_reset,
      din     => din_fifo,
      wr_en   => we_fifo,
      rd_en   => re_fifo,
      dout    => dout_fifo,
      full    => open,
      empty   => empty_fifo,
      valid   => rv_fifo,
      wr_rst_busy => open,
      rd_rst_busy => open
    );

  reg_status  <= (kIndexFifoEmpty => empty_fifo, others => '0');

  -- Bus process ------------------------------------------------------------------
  u_BusProcess : process(clk)
  begin
    if(clk'event and clk = '1') then
      if(sync_reset = '1') then
        reg_cnt_reset <= (others => '0');
        reg_latch_scr <= (others => '0');

        state_lbus	<= Init;
      else
        case state_lbus is
          when Init =>
            dataLocalBusOut       <= x"00";
            readyLocalBus		<= '0';
            state_lbus		<= Idle;

          when Idle =>
            readyLocalBus	<= '0';
            if(weLocalBus = '1' or reLocalBus = '1') then
              state_lbus	<= Connect;
            end if;

          when Connect =>
            if(weLocalBus = '1') then
              state_lbus	<= Write;
            else
              state_lbus	<= Read;
            end if;

          when Write =>
            case addrLocalBus(kNonMultiByte'range) is
              when kCntReset(kNonMultiByte'range) =>
                reg_cnt_reset	<= dataLocalBusIn(kIndexFifoRst downto kIndexLocalRst);
              when others => null;
            end case;
            state_lbus	<= Finalize;

          when Read =>
            case addrLocalBus(kNonMultiByte'range) is
              when kLatchSrc(kNonMultiByte'range) =>
                if(reg_busy = '1') then
                  reg_latch_scr   <= (others => '0');
                  dataLocalBusOut <= "00000000";
                else
                  if(addrLocalBus(kMultiByte'range) = k1stByte) then
                    reg_latch_scr   <= "001";
                  elsif(addrLocalBus(kMultiByte'range) = k2ndByte) then
                    reg_latch_scr   <= "010";
                  elsif(addrLocalBus(kMultiByte'range) = k3rdByte) then
                    reg_latch_scr   <= "100";
                  else
                    reg_latch_scr   <= "001";
                  end if;

                  dataLocalBusOut <= "00000001";
                end if;
                state_lbus	<= Finalize;

              when kNumCh(kNonMultiByte'range) =>
                dataLocalBusOut <= std_logic_vector(to_unsigned(kNumScrBlock, 8));
                state_lbus	    <= Finalize;

              when kStatus(kNonMultiByte'range) =>
                dataLocalBusOut <= reg_status;
                state_lbus	    <= Finalize;

              when kReadFIFO(kNonMultiByte'range) =>
                if(empty_fifo = '1') then
                  dataLocalBusOut   <= X"ee";
                  state_lbus        <= Finalize;
                else
                  re_fifo           <= '1';
                  state_lbus	      <= ReadFIFO;
                end if;

              when others =>
                dataLocalBusOut <= x"ff";
                state_lbus	<= Finalize;
            end case;

          when ReadFIFO =>
            re_fifo <= '0';
            if(rv_fifo = '1') then
              dataLocalBusOut   <= dout_fifo;
              state_lbus        <= Finalize;
            end if;

          when Finalize =>
            reg_cnt_reset <= (others => '0');
            reg_latch_scr <= (others => '0');
            state_lbus    <= Done;

          when Done =>
            readyLocalBus	<= '1';
            if(weLocalBus = '0' and reLocalBus = '0') then
              state_lbus	<= Idle;
            end if;

          -- probably this is error --
          when others =>
            state_lbus	<= Init;
        end case;
      end if;
    end if;
  end process u_BusProcess;

  -- Reset sequence --
  u_reset_gen   : entity mylib.ResetGen
    port map(rst or reg_cnt_reset(kIndexFifoRst), clk, sync_reset);

  u_reset_gen_cnt   : entity mylib.ResetGen
    port map(reset_cnt, clk, cnt_sync_reset);

end RTL;

