library ieee, mylib;
use ieee.std_logic_1164.all;
use mylib.defBCT.all;

package defFreeRunScaler is
  constant kWidthCnt              : integer:= 32;

  -- External information --
  constant kNumExtInfo            : integer:= 2;

  -- Systerm information --
  constant kNumSysInput           : integer:= 8;

  constant kIndexRealTime         : integer:= 0;
  constant kIndexDaqRunTime       : integer:= 1;
  constant kIndexTotalThrotTime   : integer:= 2;
  constant kIndexInThrot1Time     : integer:= 3;
  constant kIndexInThrot2Time     : integer:= 4;
  constant kIndexOutThrotTime     : integer:= 5;
  constant kIndexHbfThrotTime     : integer:= 6;
  constant kIndexMikuError        : integer:= 7;

  -- Structure --
  -- Heartbeat count        (1)
  -- Heartbeat frame number (1)
  -- System input           (8)
  -- Hit scaler             (N)

  function swap_vect(vect_in : in std_logic_vector) return std_logic_vector;

  -- Local Address  -------------------------------------------------------
  constant kCntReset              : LocalAddressType := x"000"; -- W, [1:0], assert counter reset
  constant kIndexLocalRst         : integer:= 0;
  constant kIndexGolobalRst       : integer:= 1;
  constant kLatchSrc              : LocalAddressType := x"010"; -- R, [0:0], read busy state and assert latch_scr signal
  constant kNumCh                 : LocalAddressType := x"020"; -- R, [7:0], # of scaler channel
  constant kReadFIFO              : LocalAddressType := x"100"; -- R, [7:0], Read FIFO data

end package defFreeRunScaler;

-- ----------------------------------------------------------------------------------
-- Package body
-- ----------------------------------------------------------------------------------
package body defFreeRunScaler is

  function swap_vect(vect_in : in std_logic_vector) return std_logic_vector is
    variable vect_out   : std_logic_vector(vect_in'range);
  begin
    for i in vect_in'range loop
      vect_out(i)   := vect_in(vect_in'high - i + vect_in'low);
    end loop;

    return vect_out;
  end function;

end package body defFreeRunScaler;

