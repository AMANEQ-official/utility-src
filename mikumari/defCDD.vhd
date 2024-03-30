library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library mylib;

package defCDD is

  constant kNumCdcm           : integer:= 16;

  -- mikumari
  function TxCddIoStd(index: integer)        return string;
  function RxCddIoStd(index: integer)        return string;
  function GetCddIoGroup(index: integer)     return string;
  function GetCddTxPolarity(index: integer)  return boolean;

end package defCDD;

package body defCDD is

  function TxCddIoStd(index: integer) return string is
  begin
    case index is
      when 0  => return("LVDS_25");
      when 1  => return("LVDS_25");
      when 2  => return("LVDS_25");
      when 3  => return("LVDS_25");
      when 4  => return("LVDS_25");
      when 5  => return("LVDS_25");
      when 6  => return("LVDS_25");
      when 7  => return("LVDS_25");
      when 8  => return("LVDS_25");
      when 9  => return("LVDS_25");
      when 10 => return("LVDS_25");
      when 11 => return("LVDS_25");
      when 12 => return("LVDS_25");
      when 13 => return("LVDS_25");
      when 14 => return("LVDS");
      when 15 => return("LVDS");
    end case;
  end function;

  function RxCddIoStd(index: integer) return string is
  begin
    case index is
      when 0  => return("LVDS_25");
      when 1  => return("LVDS_25");
      when 2  => return("LVDS_25");
      when 3  => return("LVDS_25");
      when 4  => return("LVDS_25");
      when 5  => return("LVDS_25");
      when 6  => return("LVDS_25");
      when 7  => return("LVDS_25");
      when 8  => return("LVDS_25");
      when 9  => return("LVDS_25");
      when 10 => return("LVDS_25");
      when 11 => return("LVDS_25");
      when 12 => return("LVDS_25");
      when 13 => return("LVDS");
      when 14 => return("LVDS");
      when 15 => return("LVDS");
    end case;
  end function;

  function GetCddIoGroup(index: integer) return string is
  begin
    case index is
      when 0  => return("idelay_1");
      when 1  => return("idelay_1");
      when 2  => return("idelay_1");
      when 3  => return("idelay_1");
      when 4  => return("idelay_1");
      when 5  => return("idelay_2");
      when 6  => return("idelay_2");
      when 7  => return("idelay_2");
      when 8  => return("idelay_3");
      when 9  => return("idelay_3");
      when 10 => return("idelay_3");
      when 11 => return("idelay_3");
      when 12 => return("idelay_3");
      when 13 => return("idelay_4");
      when 14 => return("idelay_4");
      when 15 => return("idelay_4");
    end case;
  end function;

  function GetCddTxPolarity(index: integer) return boolean is
  begin
    case index is
      when 0  => return true;
      when 1  => return true;
      when 2  => return true;
      when 3  => return true;
      when 4  => return true;
      when 5  => return true;
      when 6  => return true;
      when 7  => return true;
      when 8  => return true;
      when 9  => return false;
      when 10 => return false;
      when 11 => return true;
      when 12 => return true;
      when 13 => return false;
      when 14 => return true;
      when 15 => return false;
    end case;
  end function;


end package body defCDD;
