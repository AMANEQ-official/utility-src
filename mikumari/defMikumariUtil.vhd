library ieee, mylib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use mylib.defBCT.all;
use mylib.defCDCM.all;
use mylib.defHeartBeatUnit.all;
use mylib.defLACCP.all;

package defMikumariUtil is

  constant kWidthIndex            : integer:= 5;
  constant kPosTap                : std_logic_vector(kWidthTap-1 downto 0):= (others => '0');
  constant kPosBitslip            : std_logic_vector(kWidthBitSlipNum-1 downto 0):= (others => '0');

  type TapArrayType        is array(natural range <>) of std_logic_vector(kWidthTap-1 downto 0);
  type BitslipArrayType    is array(natural range <>) of std_logic_vector(kWidthBitSlipNum-1 downto 0);
  type SerdesOfsArrayType  is array(natural range <>) of signed(kWidthSerdesOffset-1 downto 0);
  type IpAddrArrayType     is array(natural range <>) of std_logic_vector(31 downto 0);
  --type HbcOffsetArrayType  is array(natural range <>) of std_logic_vector(kWidthHbCount-1 downto 0);
  --type FineOffsetArrayType is array(natural range <>) of std_logic_vector(kWidthLaccpFineOffset-1 downto 0);

  -- Local Address --------------------------------------------------------
  constant kCbtLaneUp             : LocalAddressType := x"000"; -- R,   [31:0],
  constant kCbtTapValueIn         : LocalAddressType := x"010"; -- R,   [4:0],
  constant kCbtTapValueOut        : LocalAddressType := x"020"; -- W,   [4:0],
  constant kCbtBitSlipIn          : LocalAddressType := x"030"; -- R,   [3:0],
  constant kCbtInit               : LocalAddressType := x"040"; -- W,   [31:0],

  constant kMikumariUp            : LocalAddressType := x"050"; -- R,   [31:0],

  constant kLaccpUp               : LocalAddressType := x"060"; -- R,   [31:0],
  constant kPartnerIpAddr         : LocalAddressType := x"070"; -- R,   [31:0],
  constant kHbcOffset             : LocalAddressType := x"080"; -- R,   [15:0],
  constant kFineOffset            : LocalAddressType := x"090"; -- R,   [15:0],
  constant kHbfState              : LocalAddressType := x"0A0"; -- W/R  [0:0],

  constant kRegIndex              : LocalAddressType := x"100"; -- W/R, [5:0], Select w/r channel

  end package defMikumariUtil;
