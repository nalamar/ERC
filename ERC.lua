
ERC = LibStub("AceAddon-3.0"):NewAddon("ERC", "AceConsole-3.0","AceEvent-3.0","AceHook-3.0")

ERC.BUTTON_HEIGHT = 23

local backdrop = {
  -- path to the background texture
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  -- path to the border texture
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  -- true to repeat the background texture to fill the frame, false to scale it
  tile = true,
  -- size (width or height) of the square repeating background tiles (in pixels)
  tileSize = 32,
  -- thickness of edge segments and square size of edge corners (in pixels)
  edgeSize = 32,
  -- distance from the edges of the frame to those of the background texture (in pixels)
  insets = {
    left = 11,
    right = 12,
    top = 12,
    bottom = 11
  }
}

local defaults = {
  profile = {
    fLVL = 120
  }
}

function ERC:OnInitialize()
  self.frame = CreateFrame("Frame","ERCMainFrame",CalendarCreateEventFrame, BackdropTemplateMixin and "BackdropTemplate")
  --self.frame = CreateFrame("Frame","ERCMainFrame",UIParent, BackdropTemplateMixin and "BackdropTemplate")
  self.frame:SetBackdrop(backdrop)
  self.frame:SetBackdropColor(0,0,0,0.95)
  self.lastTimer = 0
  self.overridewipe = false
  self.eventcreator = false
  self.invite_in_progress = false
  self.inviteList = {}
  self.removeList = {}
  self.debug = false
  self.db = LibStub("AceDB-3.0"):New("ERCDB",defaults,true)
  self.options = {
    name = "General",
    type = "group",
    args = {
      filterLVL = {
        name = "Filter Level",
        desc = "Minimum Level to conisider for events",
        type = "range",
        min = 1,
        max = 50,
        step = 1,
        set = function(info,val) self.db.profile.fLVL = val end,
        get = function(info) return self.db.profile.fLVL end,
      }
    }
  }
  LibStub("AceConfig-3.0"):RegisterOptionsTable("ERCOptions", self.options);
  self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ERCOptions", "Easy Raid Calendar");

  self:BuildUI()
  --ERC:Print("OnInitialize()")
  ERC:RegisterChatCommand("erc", "ChatCommand")
end
--CALENDAR_CLOSE_EVENT
function ERC:OnEnable()
  --ERC:Print("OnEnable()")

  self.frame:SetScript("OnEvent", self.OnEvent)
  self.frame:SetScript("OnUpdate",self.FrameOnUpdate)

  self.frame:RegisterEvent("CALENDAR_ACTION_PENDING")
  self.frame:RegisterEvent("CALENDAR_UPDATE_INVITE_LIST")
  self.frame:RegisterEvent("GUILD_ROSTER_UPDATE")
  self.frame:RegisterEvent("CALENDAR_UPDATE_ERROR")

  ERC:RegisterMessage("ERC_INVITE",self.InviteHandler)
  ERC:RegisterMessage("ERC_UNINVITE",self.UninviteHandler)
  ERC:RegisterMessage("ERC_OP_RESULT",self.ResultHandler)
end

function ERC:OnDisable()
  --ERC:Print("OnDisable()")

  self.frame:UnregisterEvent("CALENDAR_ACTION_PENDING")
  self.frame:UnregisterEvent("CALENDAR_UPDATE_INVITE_LIST")
  self.frame:UnregisterEvent("GUILD_ROSTER_UPDATE")
  self.frame:UnregisterEvent("CALENDAR_UPDATE_ERROR")

  ERC:UnregisterMessage("ERC_INVITE")
  ERC:UnregisterMessage("ERC_UNINVITE")
  ERC:UnregisterMessage("ERC_OP_RESULT")
end

function ERC:DPrint(...)
  if self.debug then
    ERC:Print(...)
  end
end

function ERC:ChatCommand(input)
  if not input or input:trim() == "" then
    ERC:Print("Empty command")
  end
  if input:trim() == "debug on" then
    ERC:Print(input)
    self.debug = true
  end
  if input:trim() == "debug off" then
    self.debug = false
    ERC:Print(input)
  end

end

function ERC:InviteHandler(target)
  ERC:DPrint("ERC:InviteHandler() "..tostring(target))
  tinsert(ERC.inviteList,target)
end

function ERC:UninviteHandler(target)
  ERC:DPrint("ERC:UninviteHandler() "..tostring(target))
  tinsert(ERC.removeList,target)
end

function ERC:ResultHandler(result)
  ERC:DPrint("ERC:ResultHandler() "..tostring(result))
  if result == true then
    ERC.invite_in_progress = false
  end
end

function ERC:FrameOnUpdate(elapsed)
  ERC.lastTimer = ERC.lastTimer + elapsed
  canAdd = C_Calendar.CanAddEvent()
  if ERC.lastTimer > 2.0 and canAdd then
    if not ERC.invite_in_progress then
      if ERC.inviteList ~= nil and tablelength(ERC.inviteList) > 0 then
        local numInvites = C_Calendar.GetNumInvites()
        if numInvites  == 100 then
          if not ERC.frame.statusFrame.NEWEVENT:IsShown() then
            ERC.frame.statusFrame.NEWEVENT:Show()
          end
        else
          if ERC.frame.statusFrame.NEWEVENT:IsShown() then
            ERC.frame.statusFrame.NEWEVENT:Hide()
          end

          invite = table.remove(ERC.inviteList,1)
          ERC:DPrint("FrameOnUpdate() CalendarEventInvite(".. invite ..")")
          local info = C_Calendar.GetEventIndex()
          if info then
            ERC:DPrint("monthOffset: "..info.offsetMonths)
            ERC:DPrint("day: "..info.monthDay)
            ERC:DPrint("index"..info.eventIndex)
          end
          local isinvited = false
          for invidx=1,numInvites do
            local invite_info = C_Calendar.EventGetInvite(invidx)
            if ( Ambiguate(invite,"guild") == invite_info.name or invite == invite_info.name) and not invite_info.inviteIsMine then
              ERC:DPrint("FrameOnUpdate() "..invite.." is already invited.")
              isinvited = true
            end
          end
          if not isinvited then
            C_Calendar.EventInvite(invite)
            self.invite_in_progress = true
          end
        end
        --send invite
      end
      if ERC.removeList ~= nil and tablelength(ERC.removeList) > 0 then
        rem = table.remove(ERC.removeList,1)
        local numInvites = C_Calendar.GetNumInvites()
        for invidx=1,numInvites do
          local invite_info = C_Calendar.EventGetInvite(invidx)
          if ( Ambiguate(rem,"guild") == invite_info.name or rem == invite_info.name) and not invite_info.inviteIsMine then
            ERC:DPrint("FrameOnUpdate() CalendarEventRemoveInvite(".. tostring(invidx) ..")")
            C_Calendar.EventRemoveInvite(invidx)
          end
        end
        self.invite_in_progress = true
      end
      --remove invite
    end
    ERC.lastTimer = 0
  end
  if tablelength(ERC.inviteList) > 0 or tablelength(ERC.removeList) > 0 then
    if not ERC.frame.statusFrame:IsShown() then
      ERC.frame.statusFrame:Show()
    end
    local totaltasks = #ERC.inviteList + #ERC.removeList
    ERC.frame.statusFrame.text:SetText(string.format("Tasks pending %d",totaltasks))
  else
    if ERC.frame.statusFrame:IsShown() then
      ERC.frame.statusFrame:Hide()
    end
  end
end

function ERC:OnEvent(event, ...)
  if event == "CALENDAR_ACTION_PENDING" then
    arg1 = ...
    if arg1 == false then
      ERC:DPrint("OnEvent() CALENDAR_ACTION_PENDING .. Loaded")
      local info = C_Calendar.GetEventIndex()
      local e_info = C_Calendar.GetEventInfo();
      if e_info then
        ERC:DPrint(string.format("title: %s Type: %d", e_info.title or "[No Title]",e_info.eventType))
      end
      if info then
        ERC:DPrint(string.format("%d/%d %d",info.offsetMonths, info.monthDay, info.eventIndex))
      end
    else
      ERC:DPrint("OnEvent() CALENDAR_ACTION_PENDING .. Loading...")
    end
    ERC:UpdateWorkingList()
  end
  if event == "GUILD_ROSTER_UPDATE" then
    arg1 = ...
    if arg1 == true then
      ERC:DPrint("OnEvent() GUILD_ROSTER_UPDATE (CHANGE)")
      ERC:UpdateWorkingList()
    else
      ERC:DPrint("OnEvent() GUILD_ROSTER_UPDATE (On/Off)")
    end
  end
  if event == "CALENDAR_UPDATE_INVITE_LIST" then
    arg1 = ...
    if arg1 == true then
      ERC:DPrint("OnEvent() CALENDAR_UPDATE_INVITE_LIST (CHANGE)")
      --clear invite and remove lists
      if ERC.inviteList ~= nil and self.overridewipe == false then
        ERC:DPrint("OnEvent() CALENDAR_UPDATE_INVITE_LIST (CHANGE) - WIPE inviteList")
        wipe(ERC.inviteList)
      end
      if ERC.removeList ~= nil and self.overridewipe == false then
        ERC:DPrint("OnEvent() CALENDAR_UPDATE_INVITE_LIST (CHANGE) - WIPE removeList")
        wipe(ERC.removeList)
      end
    else
      ERC:DPrint("OnEvent() CALENDAR_UPDATE_INVITE_LIST (On/Off)")
      if self.invite_in_progress then
        ERC:SendMessage("ERC_OP_RESULT",true)
      end
    end
    ERC:UpdateWorkingList()
  end
  if event == "CALENDAR_UPDATE_ERROR" then
    ERC:SendMessage("ERC_OP_RESULT",false)
    ERC:UpdateWorkingList()
  end
end

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end



function ERC:BuildUI()
  self.frame:SetPoint("TOPLEFT",CalendarCreateEventFrame,"TOPRIGHT",360,0)
  self.frame:SetPoint("BOTTOMRIGHT",CalendarCreateEventFrame,"BOTTOMRIGHT",750,0)

  -- scrollframe is the mousewheel'able area where buttons will be drawn
  self.frame.scrollFrame = CreateFrame("ScrollFrame","ERCMainFrameScrollFrame",self.frame,"HybridScrollFrameTemplate")
  self.frame.scrollFrame:SetPoint("TOPLEFT",12,-8)
  self.frame.scrollFrame:SetPoint("BOTTOMRIGHT",-30,8)
  --self.frame.scrollFrame:SetAllPoints(true)

  -- scrollbar is just to the right of the scrollframe
  self.frame.scrollBar = CreateFrame("Slider","ERCMainFrameScrollFrameScrollBar",self.frame.scrollFrame,"HybridScrollBarTemplate")
  --self.frame.scrollBar:SetPoint("TOPLEFT",0,-8)
  --self.frame.scrollBar:SetPoint("BOTTOMRIGHT",-30,8)

  -- HybridScrollFrame creation
  self.frame.scrollFrame.stepSize = ERC.BUTTON_HEIGHT -- jump by 4 buttons on mousewheel
  self.frame.scrollFrame.update = Update
  HybridScrollFrame_CreateButtons(self.frame.scrollFrame,"ERCMainFrameTemplate",0,-2,"TOPLEFT","TOPLEFT",0,2,"TOP","BOTTOM")

  self.frame.statusFrame = CreateFrame("Frame","ERCMainFrameStatus",self.frame,"TooltipBorderedFrameTemplate")
  self.frame.statusFrame:SetPoint("TOPLEFT",ERCMainFrame,"BOTTOMLEFT",0,0)
  self.frame.statusFrame:SetPoint("BOTTOMRIGHT",ERCMainFrame,"BOTTOMRIGHT",0,-35)
  self.frame.statusFrame.text = self.frame.statusFrame:CreateFontString(nil,"BACKGROUND","GameFontNormal")
  self.frame.statusFrame.text:SetAllPoints()
  self.frame.statusFrame.text:SetPoint("CENTER",0,0)
  self.frame.statusFrame.STOPBUTTON = CreateFrame("Button","ERCMainFrameStatusSTOP",self.frame.statusFrame,"UIPanelButtonTemplate")
  self.frame.statusFrame.STOPBUTTON:SetPoint("LEFT",self.frame.statusFrame,"RIGHT",-105,0)
  self.frame.statusFrame.STOPBUTTON:SetPoint("RIGHT",self.frame.statusFrame,"RIGHT",-15,0)
  self.frame.statusFrame.STOPBUTTON:SetText("Cancel Tasks")
  self.frame.statusFrame.STOPBUTTON:Show()
  self.frame.statusFrame.STOPBUTTON:SetScript("OnClick", function ()
    wipe(self.inviteList)
    wipe(self.removeList)
  end)
  self.frame.statusFrame.NEWEVENT = CreateFrame("Button","ERCMainFrameStatusNEWEVENT",self.frame.statusFrame,"UIPanelButtonTemplate")
  self.frame.statusFrame.NEWEVENT:SetPoint("LEFT",self.frame.statusFrame,"LEFT",15,0)
  self.frame.statusFrame.NEWEVENT:SetPoint("RIGHT",self.frame.statusFrame,"LEFT",105,0)
  self.frame.statusFrame.NEWEVENT:SetText("New Event")
  self.frame.statusFrame.NEWEVENT:Hide()
  self.frame.statusFrame.NEWEVENT:SetScript("OnClick", function ()
    local einfo = C_Calendar.GetEventInfo()
    local info = C_Calendar.GetEventIndex()
    ERC.newevent = { title=title.."+" , description=einfo.description , eventType=einfo.eventType , textureIndex=einfo.textureIndex , hour=einfo.time.hour,minute=einfo.time.minute,month=einfo.time.month,day=einfo.time.monthDay,year=einfo.time.year}
    if info.eventIndex == 0 then
      C_Calendar.AddEvent()
      C_Timer.After(4, function ()
        ERC:DPrint("Creating New Event:")
        ERC:DPrint("Title: "..ERC.newevent.title)
        ERC:DPrint("Description: "..ERC.newevent.description)
        ERC:DPrint("eventType: "..ERC.newevent.eventType)
        ERC:DPrint("textureIndex: "..ERC.newevent.textureIndex)
        ERC:DPrint("calendarType: "..einfo.calendarType)
        ERC:DPrint("weekday: "..einfo.time.weekday)
        ERC:DPrint("month: "..ERC.newevent.month)
        ERC:DPrint("day: "..ERC.newevent.day)
        ERC:DPrint("year: "..ERC.newevent.year)
        ERC:DPrint("hour: "..ERC.newevent.hour)
        ERC:DPrint("minute: "..ERC.newevent.minute)

        ERC.overridewipe = true
        ERC.frame.statusFrame.text:SetText("Creating Event PLEASE wait!")
        C_Calendar.CloseEvent();
        CalendarFrame_HideEventFrame();
        C_Calendar.CreatePlayerEvent();
        CalendarCreateEventFrame.mode = "create";
        CalendarCreateEventFrame.dayButton = _G["CalendarDayButton"..ERC.newevent.day]
        CalendarFrame_ShowEventFrame(CalendarCreateEventFrame);
        C_Timer.After(3,function()
          C_Calendar.EventSetDate(ERC.newevent.month,ERC.newevent.day,ERC.newevent.year)
          C_Calendar.EventSetTime(ERC.newevent.hour,ERC.newevent.minute)
          C_Calendar.EventSetTitle(ERC.newevent.title)
          C_Calendar.EventSetDescription(ERC.newevent.description)
          C_Calendar.EventSetType(ERC.newevent.eventType)
          if eventType == 1 or eventType == 2 then
            C_Calendar.EventSetTextureID(ERC.newevent.textureIndex)
          end
          ERC.newevent = {}
        end)
        ERC.overridewipe = false
      end)
    else
      ERC:DPrint("Creating New Event:")
      ERC:DPrint("Title: "..ERC.newevent.title)
      ERC:DPrint("Description: "..ERC.newevent.description)
      ERC:DPrint("eventType: "..ERC.newevent.eventType)
      ERC:DPrint("textureIndex: "..ERC.newevent.textureIndex)
      ERC:DPrint("calendarType: "..einfo.calendarType)
      ERC:DPrint("weekday: "..einfo.time.weekday)
      ERC:DPrint("month: "..ERC.newevent.month)
      ERC:DPrint("day: "..ERC.newevent.day)
      ERC:DPrint("year: "..ERC.newevent.year)
      ERC:DPrint("hour: "..ERC.newevent.hour)
      ERC:DPrint("minute: "..ERC.newevent.minute)

      C_Calendar.UpdateEvent()

      ERC.overridewipe = true
      ERC.frame.statusFrame.text:SetText("Creating Event PLEASE wait!")
      C_Calendar.CloseEvent();
      CalendarFrame_HideEventFrame();
      C_Calendar.CreatePlayerEvent();
      CalendarCreateEventFrame.mode = "create";
      CalendarCreateEventFrame.dayButton = _G["CalendarDayButton"..ERC.newevent.day]
      CalendarFrame_ShowEventFrame(CalendarCreateEventFrame);
      C_Timer.After(3,function()
        C_Calendar.EventSetDate(ERC.newevent.month,ERC.newevent.day,ERC.newevent.year)
        C_Calendar.EventSetTime(ERC.newevent.hour,ERC.newevent.minute)
        C_Calendar.EventSetTitle(ERC.newevent.title)
        C_Calendar.EventSetDescription(ERC.newevent.description)
        C_Calendar.EventSetType(ERC.newevent.eventType)
        if eventType == 1 or eventType == 2 then
          C_Calendar.EventSetTextureID(ERC.newevent.textureIndex)
        end
        ERC.newevent = {}
      end)
      ERC.overridewipe = false
    end
  end)
  self.frame.statusFrame:Hide()
  -- collapsable bits
  self.workingList = {} -- array of button content
  self.workingHeadersOpen = {} -- table indexed by header name of heads open

  self:UpdateWorkingList() -- update display
end

-- called from template's header button <OnClick> handler
function ERC:HeaderOnClick()
  ERC:DPrint("Header "..self:GetID().." Clicked ["..ERC.workingList[self:GetID()].truename.."]")
  local command = ERC.workingList[self:GetID()].truename

  -- toggle whether header expanded or not
  ERC.workingHeadersOpen[command] = not ERC.workingHeadersOpen[command]
  ERC:UpdateWorkingList()
end

function allofrank(rrank)
  C_GuildInfo.GuildRoster()
  local numGuildMembers, numOnline, numOnlineAndMobile = GetNumGuildMembers()
  rmmap = {}
  for z=1,numGuildMembers do
    local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName,  achievementPoints, achievementRank, isMobile = GetGuildRosterInfo(z);
    if rrank == rank and level >= ERC.db.profile.fLVL then
      rmmap[name] = false
    end
  end
  return rmmap
end

function ERC:HeaderOnInviteAll()
  ERC:DPrint("Header "..self.rank.." [Invite ALL] Clicked")
  local invited = {}
  local info = C_Calendar.GetEventIndex()
  members = allofrank(self.rank)
  local numInvites = C_Calendar.GetNumInvites()
  for invidx=1,numInvites do
    local invite_info = C_Calendar.EventGetInvite(invidx)
    tinsert(invited,invite_info.name)
  end
  for k,v in pairs(members) do
    if tContains(invited,Ambiguate(k,"guild")) or tContains(invited,k) then
      ERC:DPrint("HeaderOnInviteAll() "..k.." is already invited")
    else
      ERC:DPrint("HeaderOnInviteAll() "..k.." inviting...")
      ERC:SendMessage("ERC_INVITE",k)
      --CalendarEventInvite(k)
    end
  end
end

function ERC:HeaderOnRemoveAll()
  ERC:DPrint("Header "..self.rank.." [Remove ALL] Clicked")
  local info = C_Calendar.GetEventIndex()
  members = allofrank(self.rank)
  local numInvites = C_Calendar.GetNumInvites()
  for invidx=1,numInvites do
    local invite_info = C_Calendar.EventGetInvite(invidx)
    ERC:DPrint("HeaderOnRemoveAll() Index:"..invidx.." name:"..invite_info.name)
    if not invite_info.inviteIsMine then
      for k,v in pairs(members) do
        if Ambiguate(k,"guild") == invite_info.name then
          ERC:DPrint("HeaderOnRemoveAll() "..invite_info.name.." scheduled for remove")
          ERC:SendMessage("ERC_UNINVITE",invite_info.name)
        end
      end
    end
  end
end

function ERC:DetailOnInvite()
  ERC:DPrint("Detail "..self.target.." [Invite] Clicked")
  local info = C_Calendar.GetEventIndex()
  ERC:SendMessage("ERC_INVITE",self.target)
  --CalendarEventInvite(self.target)
end

function ERC:DetailOnRemove()
  ERC:DPrint("Detail "..self.target.." [Remove] Clicked")
  local info = C_Calendar.GetEventIndex()
  ERC:SendMessage("ERC_UNINVITE",self.target)
  --CalendarEventRemoveInvite(self.target)
end

function ERC:UpdateWorkingList()
  ERC:DPrint("UpdateWorkingList()")
  wipe(self.workingList)
  C_GuildInfo.GuildRoster()
  local rmmap = {}
  local numGuildMembers, numOnline, numOnlineAndMobile = GetNumGuildMembers()
  for z=1,numGuildMembers do
    local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName,  achievementPoints, achievementRank, isMobile = GetGuildRosterInfo(z);
    if rmmap[rankIndex+1] == nil then
      rmmap[rankIndex+1] = {}
    end
    if level >= self.db.profile.fLVL then
      tinsert(rmmap[rankIndex+1],z,{name=name,rname=rank,shortname=Ambiguate(name,"guild"),color=RAID_CLASS_COLORS[classFileName]})
      --rmmap[rankIndex+1][z] = {name=name,shortname=Ambiguate(name,"guild"),color=RAID_CLASS_COLORS[classFileName]}
    end
  end
  for k,v in pairs(rmmap) do
    local rname = GuildControlGetRankName(k)
    local bigname = string.format("%s (%d)",rname,tablelength(allofrank(rname)))
    tinsert(self.workingList,{rank=k,truename=rname,name=bigname,header=true,invited=false})
    if self.workingHeadersOpen[rname] then
      for i,g in pairs(v) do
        tinsert(self.workingList,{rank=k,idx=i,name=g.name,shortname=g.shortname,color=g.color,header=false,invited=false})
      end
    end
  end
  local numInvites = C_Calendar.GetNumInvites()
  for invidx=1,numInvites do
    local invite_info = C_Calendar.EventGetInvite(invidx)
    for k,v in pairs(self.workingList) do
      if v.header == false and ( v.name == invite_info.name or v.shortname == invite_info.name ) then
        self.workingList[k].invited = true
      end
    end
  end
  if not self.frame or not self.frame.scrollFrame then
    return
  end
  Update()
end

function Update(...)
  ERC:DPrint("Update(...)")
  local self = self or ERC
  if not self.frame then
    return
  end
  local offset = HybridScrollFrame_GetOffset(self.frame.scrollFrame)
  local buttons = self.frame.scrollFrame.buttons
  for i=1, #buttons do
    local index = i + offset
    local button = buttons[i]
    button:Hide()
    if index <= tablelength(self.workingList) then
      button:SetID(index)
      local item = self.workingList[index]
      if item.header then
        button.header.text:SetText(item.name)
        button.header.key1:SetText("Invite All")
        button.header.key1.rank = item.truename
        button.header.key2:SetText("Remove All")
        button.header.key2.rank = item.truename
        if self.workingHeadersOpen[item.truename] then
          button.header.expandIcon:SetTexCoord(0.5625,1,0,0.4375) -- minus sign
        else
          button.header.expandIcon:SetTexCoord(0,0.4375,0,0.4375) -- plus sign
        end
        button.detail:Hide()
        button.header:Show()
      else
        local class, classFileName = UnitClass(item.name)
        button.detail.text:SetText(item.name)
        button.detail.text:SetTextColor(item.color.r,item.color.g,item.color.b,1)
        if item.invited == true then
          button.detail.key1:Disable()
          button.detail.key2:Enable()
        else
          button.detail.key1:Enable()
          button.detail.key2:Disable()
        end
        button.detail.key1:SetText("Invite")
        button.detail.key1.target = item.name
        button.detail.key2:SetText("Remove")
        button.detail.key2.target = item.name
        button.header:Hide()
        button.detail:Show()
      end
      button:Show()
    end
  end
  HybridScrollFrame_Update(self.frame.scrollFrame, ERC.BUTTON_HEIGHT*#self.workingList, ERC.BUTTON_HEIGHT)
end
