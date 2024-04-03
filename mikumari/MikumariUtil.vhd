library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_MISC.ALL;
use ieee.numeric_std.all;


library mylib;
use mylib.defBCT.all;
use mylib.defMikumariUtil.all;
use mylib.defLaccp.all;
use mylib.defHeartBeatUnit.all;

entity MikumariUtil is
  generic(
    kNumMikumari  : integer:= 16;
    enDEBUG       : boolean:= false
  );
  port(
    -- System ----------------------------------------------------
    rst               : in std_logic;
    clk               : in std_logic;

    -- CBT status ports --
    cbtLaneUp           : in std_logic_vector(kNumMikumari-1 downto 0);
    tapValueIn          : in TapArrayType(kNumMikumari-1 downto 0);
    bitslipNumIn        : in BitslipArrayType(kNumMikumari-1 downto 0);
    cbtInitOut          : out std_logic_vector(kNumMikumari-1 downto 0);
    tapValueOut         : out TapArrayType(kNumMikumari-1 downto 0);

    -- MIKUMARI Link ports --
    mikuLinkUp          : in std_logic_vector(kNumMikumari-1 downto 0);

    -- LACCP ports --
    laccpUp             : in std_logic_vector(kNumMikumari-1 downto 0);
    partnerIpAddr       : in IpAddrArrayType(kNumMikumari-1 downto 0);
    hbcOffset           : in std_logic_vector(kWidthHbCount-1 downto 0);
    localFineOffset     : in std_logic_vector(kWidthLaccpFineOffset-1 downto 0);
    laccpFineOffset     : in std_logic_vector(kWidthLaccpFineOffset-1 downto 0);
    hbfState            : out std_logic;

    -- Local bus --
    addrLocalBus        : in LocalAddressType;
    dataLocalBusIn      : in LocalBusInType;
    dataLocalBusOut     : out LocalBusOutType;
    reLocalBus          : in std_logic;
    weLocalBus          : in std_logic;
    readyLocalBus       : out std_logic
  );
end MikumariUtil;

architecture RTL of MikumariUtil is
  attribute mark_debug      : boolean;

  -- System --
  signal sync_reset       : std_logic;

  -- Internal signal declaration ---------------------------------
  constant kMaxInput      : integer:= 32;
  signal reg_cbt_lane_up  : std_logic_vector(kMaxInput-1 downto 0);
  signal reg_tap_in       : TapArrayType(kNumMikumari-1 downto 0);
  signal reg_tap_out      : TapArrayType(kNumMikumari-1 downto 0);
  signal reg_bitslip_in   : BitslipArrayType(kNumMikumari-1 downto 0);
  signal reg_cbt_init     : std_logic_vector(kMaxInput-1 downto 0);

  signal reg_mikumari_up  : std_logic_vector(kMaxInput-1 downto 0);

  signal reg_laccp_up     : std_logic_vector(kMaxInput-1 downto 0);
  signal reg_ip_addr      : IpAddrArrayType(kMaxInput-1 downto 0);
  signal reg_hbc_offset   : std_logic_vector(kWidthHbCount-1 downto 0);
  signal reg_local_fine_offset  : std_logic_vector(kWidthLaccpFineOffset-1 downto 0);
  signal reg_laccp_fine_offset  : std_logic_vector(kWidthLaccpFineOffset-1 downto 0);
  signal reg_hbf_state    : std_logic;

  signal reg_index        : unsigned(kWidthIndex-1 downto 0);
  signal num_mikumari     : unsigned(7 downto 0);

  -- bus process --
  signal state_lbus     : BusProcessType;

  -- Debug --

begin
  -- ======================================================================
  --                                 body
  -- ======================================================================

  hbfState      <= reg_hbf_state;
  num_mikumari  <= to_unsigned(kNumMikumari, num_mikumari'length);

  u_buf : process(clk)
  begin
    if(clk'event and clk = '1') then
      for i in 0 to kNumMikumari-1 loop
        reg_cbt_lane_up(i)  <= cbtLaneUp(i);
        reg_tap_in(i)       <= tapValueIn(i);
        reg_bitslip_in(i)   <= bitslipNumIn(i);

        reg_mikumari_up(i)  <= mikuLinkUp(i);

        reg_laccp_up(i)     <= laccpUp(i);
        reg_ip_addr(i)      <= partnerIpAddr(i);

        cbtInitOut(i)       <= reg_cbt_init(i);
        tapValueOut(i)      <= reg_tap_out(i);

      end loop;

      reg_hbc_offset        <= hbcOffset;
      reg_local_fine_offset <= localFineOffset;
      reg_laccp_fine_offset <= laccpFineOffset;
    end if;
  end process;

  -- bus process -------------------------------------------------------------
  u_BusProcess : process(clk, sync_reset)
  begin
    if(clk'event and clk = '1') then
      if(sync_reset = '1') then
        reg_tap_out   <= (others => (others => '0'));
        reg_cbt_init  <= (others => '0');
        reg_hbf_state <= '0';
        reg_index     <= (others => '0');

        state_lbus        <= Init;
      else
        case state_lbus is
          when Init =>
            dataLocalBusOut     <= x"00";
            readyLocalBus       <= '0';
            state_lbus          <= Idle;

          when Idle =>
            readyLocalBus    <= '0';
            if(weLocalBus = '1' or reLocalBus = '1') then
              state_lbus    <= Connect;
            end if;

          when Connect =>
            if(weLocalBus = '1') then
              state_lbus    <= Write;
            else
              state_lbus    <= Read;
            end if;

          when Write =>
            if(addrLocalBus(kNonMultiByte'range) = kCbtTapValueOut(kNonMultiByte'range)) then
              reg_tap_out(to_integer(reg_index))  <= dataLocalBusIn(kPosTap'range);

            elsif(addrLocalBus(kNonMultiByte'range) = kCbtInit(kNonMultiByte'range)) then
              case addrLocalBus(kMultiByte'range) is
                when k1stByte =>
                  reg_cbt_init(7 downto 0)    <= dataLocalBusIn;
                when k2ndByte =>
                  reg_cbt_init(15 downto 8)   <= dataLocalBusIn;
                when k3rdByte =>
                  reg_cbt_init(23 downto 16)  <= dataLocalBusIn;
                when k4thByte =>
                  reg_cbt_init(31 downto 24)  <= dataLocalBusIn;
                when others =>
                  null;
              end case;

            elsif(addrLocalBus(kNonMultiByte'range) = kHbfState(kNonMultiByte'range)) then
              reg_hbf_state  <= dataLocalBusIn(0);

            elsif(addrLocalBus(kNonMultiByte'range) = kRegIndex(kNonMultiByte'range)) then
              reg_index <= unsigned(dataLocalBusIn(kWidthIndex-1 downto 0));

            else
              null;
            end if;
            state_lbus      <= Done;

          when Read =>
            if(addrLocalBus(kNonMultiByte'range) = kCbtLaneUp(kNonMultiByte'range)) then
              case addrLocalBus(kMultiByte'range) is
                when k1stByte =>
                  dataLocalBusOut   <= reg_cbt_lane_up(7 downto 0);
                when k2ndByte =>
                  dataLocalBusOut   <= reg_cbt_lane_up(15 downto 8);
                when k3rdByte =>
                  dataLocalBusOut   <= reg_cbt_lane_up(23 downto 16);
                when k4thByte =>
                  dataLocalBusOut   <= reg_cbt_lane_up(31 downto 24);
                when others =>
                  null;
              end case;

            elsif(addrLocalBus(kNonMultiByte'range) = kCbtTapValueIn(kNonMultiByte'range)) then
              dataLocalBusOut <= (kPosTap'range => reg_tap_in(to_integer(reg_index)), others => '0');

            elsif(addrLocalBus(kNonMultiByte'range) = kCbtBitSlipIn(kNonMultiByte'range)) then
              dataLocalBusOut <= (kPosBitslip'range => reg_bitslip_in(to_integer(reg_index)), others => '0');


            elsif(addrLocalBus(kNonMultiByte'range) = kMikumariUp(kNonMultiByte'range)) then
              case addrLocalBus(kMultiByte'range) is
                when k1stByte =>
                  dataLocalBusOut   <= reg_mikumari_up(7 downto 0);
                when k2ndByte =>
                  dataLocalBusOut   <= reg_mikumari_up(15 downto 8);
                when k3rdByte =>
                  dataLocalBusOut   <= reg_mikumari_up(23 downto 16);
                when k4thByte =>
                  dataLocalBusOut   <= reg_mikumari_up(31 downto 24);
                when others =>
                  null;
              end case;

            elsif(addrLocalBus(kNonMultiByte'range) = kLaccpUp(kNonMultiByte'range)) then
              case addrLocalBus(kMultiByte'range) is
                when k1stByte =>
                  dataLocalBusOut   <= reg_laccp_up(7 downto 0);
                when k2ndByte =>
                  dataLocalBusOut   <= reg_laccp_up(15 downto 8);
                when k3rdByte =>
                  dataLocalBusOut   <= reg_laccp_up(23 downto 16);
                when k4thByte =>
                  dataLocalBusOut   <= reg_laccp_up(31 downto 24);
                when others =>
                  null;
              end case;

            elsif(addrLocalBus(kNonMultiByte'range) = kPartnerIpAddr(kNonMultiByte'range)) then
              case addrLocalBus(kMultiByte'range) is
                when k1stByte =>
                  dataLocalBusOut   <= reg_ip_addr(to_integer(reg_index))(7 downto 0);
                when k2ndByte =>
                  dataLocalBusOut   <= reg_ip_addr(to_integer(reg_index))(15 downto 8);
                when k3rdByte =>
                  dataLocalBusOut   <= reg_ip_addr(to_integer(reg_index))(23 downto 16);
                when k4thByte =>
                  dataLocalBusOut   <= reg_ip_addr(to_integer(reg_index))(31 downto 24);
                when others =>
                  null;
              end case;

            elsif(addrLocalBus(kNonMultiByte'range) = kHbcOffset(kNonMultiByte'range)) then
              case addrLocalBus(kMultiByte'range) is
                when k1stByte =>
                  dataLocalBusOut   <= reg_hbc_offset(7 downto 0);
                when k2ndByte =>
                  dataLocalBusOut   <= reg_hbc_offset(15 downto 8);
                when others =>
                  null;
              end case;

            elsif(addrLocalBus(kNonMultiByte'range) = kLocalFineOffset(kNonMultiByte'range)) then
              case addrLocalBus(kMultiByte'range) is
                when k1stByte =>
                  dataLocalBusOut   <= reg_local_fine_offset(7 downto 0);
                when k2ndByte =>
                  dataLocalBusOut   <= reg_local_fine_offset(15 downto 8);
                when others =>
                  null;
              end case;

            elsif(addrLocalBus(kNonMultiByte'range) = kLaccpFineOffset(kNonMultiByte'range)) then
              case addrLocalBus(kMultiByte'range) is
                when k1stByte =>
                  dataLocalBusOut   <= reg_laccp_fine_offset(7 downto 0);
                when k2ndByte =>
                  dataLocalBusOut   <= reg_laccp_fine_offset(15 downto 8);
                when others =>
                  null;
              end case;

            elsif(addrLocalBus(kNonMultiByte'range) = kHbfState(kNonMultiByte'range)) then
              dataLocalBusOut <= (0 => reg_hbf_state, others => '0');

            elsif(addrLocalBus(kNonMultiByte'range) = kRegIndex(kNonMultiByte'range)) then
              dataLocalBusOut <= (reg_index'range => std_logic_vector(reg_index), others => '0');

            elsif(addrLocalBus(kNonMultiByte'range) = kNumLinks(kNonMultiByte'range)) then
              dataLocalBusOut <= std_logic_vector(num_mikumari);

            else
              null;
            end if;
            state_lbus    <= Done;

          when Done =>
            readyLocalBus <= '1';
            if(weLocalBus = '0' and reLocalBus = '0') then
              state_lbus  <= Idle;
            end if;

          -- probably this is error --
          when others =>
            state_lbus    <= Init;
        end case;
      end if;
    end if;
  end process u_BusProcess;


  -- Reset sequence --
  u_reset_gen_sys   : entity mylib.ResetGen
    port map(rst, clk, sync_reset);

end RTL;
