# ERC

The original Code is written by FerociousBiteEVE on Curseforge - all Credits belong to him

I just fixed 9.0.1 issues (Background and ParentFrame)

This is exclusively fixed to work with LOIHcal.

If you dont work with LOIHCal, change ERC.lua lines 267 and 268 to:
  self.frame:SetPoint("TOPLEFT",CalendarCreateEventFrame,"TOPRIGHT",20,0)
  self.frame:SetPoint("BOTTOMRIGHT",CalendarCreateEventFrame,"BOTTOMRIGHT",400,0)
