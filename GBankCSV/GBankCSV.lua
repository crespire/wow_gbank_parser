local ItemsPerTab = 98

local SavedItems = {}
local SavedItemsIDs = {}
local SavedItemCounts = {}
local LastGoldCheck
local ElvUILoaded = false

--event handling frame to make sure saved variables load and save properly
local eventFrame = CreateFrame("Frame", "EventFrame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("PLAYER_LOGOUT")

function eventParse(self, event, arg1)
  if (event == "ADDON_LOADED") then
    LastGoldCheck = _G.LastGoldCheck
    --check for elvui
    if (IsAddOnLoaded("ElvUI")) then
      ElvUILoaded = true
    end
    createButtons()
    EventFrame:UnregisterEvent("ADDON_LOADED")
  elseif (event == "PLAYER_LOGOUT") then
    _G.LastGoldCheck = LastGoldCheck
  end
end

EventFrame:SetScript("OnEvent", eventParse)

SLASH_GUILDBANKAUDIT1 = "/guildbankaudit"
SLASH_GUILDBANKAUDIT2 = "/gba"
SLASH_GUILDBANKAUDIT3 = "/gbank"

-- process chat commands
function SlashCmdList.GUILDBANKAUDIT(cmd, editbox)
  local request, arg = strsplit(' ', cmd)
  request = request.lower(request)
  if request == "all" then
    GetGBAFrame(scanBank())
  elseif request  == "tab" then
    GetGBAFrame(scanTab())
  elseif request == "money" then
    GetGBAFrame(getMoneyLog())
  elseif request  == "help" then
    printHelp()
  elseif request == "bugged" then
    GetGBAFrame(printBugInfo())
  else
    printHelp()
  end
end

-- display help in player's chat window
function printHelp()
  print("----- |cff26c426Guild Bank Audit Options|r -----")
  print("Type the slash command followed by one of the options below -> '/gba command'")
  print("|cff5fe65dall|r", " - Scans your entire guild bank. |cffc21e1eYou must click on each tab in your guild bank before running this command.|r")
  print("|cff5fe65dtab|r", " - Scans the current tab open in your guild bank.")
  print("|cff5fe65dmoney|r", " - Scans current gold and displays a difference between current and last scan. Will also display the money log if its been loaded.")
  print("|cff5fe65dhelp|r", " - Displays this information here.")
  print("|cff5fe65dbugged|r", " - Get the link to report any bugs.")
  print("------------------------------------")
end

--scans the current tab the player is looking at
function scanTab()
  wipe(SavedItems)
  wipe(SavedItemCounts)
  local tableCount = 0
  local outText = ''
  local currentTab = GetCurrentGuildBankTab()
  for i = 1, ItemsPerTab, 1 do
    local itemTex, itemCount, itemLocked, itemFiltered, itemQuality = GetGuildBankItemInfo(currentTab, i)
    local itemLink = GetGuildBankItemLink(currentTab, i)
    if itemLink ~= nil then
      local cleanName = cleanString(itemLink)
	  local itemID = tonumber(strmatch(itemLink, "item:(%d+):"))
      if (checkTable(SavedItems, cleanName) ~= true) then
		tinsert(SavedItems, cleanName)
        tinsert(SavedItemsIDs, itemID)
        tinsert(SavedItemCounts, itemCount)
        tableCount = tableCount + 1
      else
        SavedItemCounts[searchTable(SavedItems, cleanName)] = SavedItemCounts[searchTable(SavedItems, cleanName)] + itemCount
      end
    end
  end

  local  outLength = getTableLength(SavedItems)
  for i = 1, outLength, 1 do
    outText = outText .. SavedItems[i] .. ',' .. SavedItemsIDs[i] .. ',' .. SavedItemCounts[i] .. '\n'
  end
  print("|cff26c426Guild Bank Tab Audit Complete!|r")
  return outText
end

-- scans entire loaded guild bank (cannot load bank for you)
function scanBank()
  wipe(SavedItems)
  wipe(SavedItemCounts)
  local tableCount = 0
  local outText = ''
  local numTabs = GetNumGuildBankTabs()
  for i = 1, numTabs, 1 do
    for k = 1, ItemsPerTab, 1 do
      local itemTex, itemCount, itemLocked, itemFiltered, itemQuality = GetGuildBankItemInfo(i, k)
      local itemLink = GetGuildBankItemLink(i, k)
      if itemLink ~= nil then
        local cleanName = cleanString(itemLink)
		local itemID = tonumber(strmatch(itemLink, "item:(%d+):"))
        if (checkTable(SavedItems, cleanName) ~= true) then
		  tinsert(SavedItems, cleanName)
          tinsert(SavedItemsIDs, itemID)
          tinsert(SavedItemCounts, itemCount)
          tableCount = tableCount + 1
        else
          SavedItemCounts[searchTable(SavedItems, cleanName)] = SavedItemCounts[searchTable(SavedItems, cleanName)] + itemCount
        end
      end
    end
  end
  local  outLength = getTableLength(SavedItems)
  for i = 1, outLength, 1 do
    outText = outText .. SavedItems[i] .. ',' .. SavedItemsIDs[i] .. ',' .. SavedItemCounts[i] .. '\n'
  end
  print("|cff26c426Guild Bank Audit Complete!|r")
  return outText
end

--grabs the money log info
function getMoneyLog()
  local outText = ''
  local numTabs = GetNumGuildBankTabs()
  local guildBankMoney = GetGuildBankMoney()
  local moneyDifference = 0

  if LastGoldCheck == nil then
    LastGoldCheck = guildBankMoney
  end

  local cleanGuildBankMoney = GetCoinText(guildBankMoney, ", ")
  outText = outText .. "Current: " .. cleanGuildBankMoney .. "\n"

  if guildBankMoney ~= LastGoldCheck then
    local bitString
    if guildBankMoney > LastGoldCheck then
      moneyDifference = guildBankMoney - LastGoldCheck
      bitString = '+'
    end
    if guildBankMoney < LastGoldCheck then
      moneyDifference = LastGoldCheck - guildBankMoney
      bitString = '-'
    end
    moneyDifference = GetCoinText(moneyDifference, ", ")
    outText = outText .. "Difference from last audit: " .. bitString .. moneyDifference .. "\n"
  else
    outText = outText .. "Difference from last audit: 0" .. "\n"
  end

  QueryGuildBankLog(numTabs + 1)
  local numMoneyTransactions = GetNumGuildBankMoneyTransactions()
  local tableCount = 0
  for i = numMoneyTransactions, 1, -1 do
    local typeString, player, amount, dateYear, dateMonth, dateDay, dateHour = GetGuildBankMoneyTransaction(i)
    amount = GetCoinText(amount, ", ")

    if typeString == 'buyTab' then
      typeString = 'buys tab'
    elseif typeString == 'depositSummary' then
      typeString = 'Challenge reward deposit'
    elseif typeString == 'repair' then
      typeString = 'repaired for'
    elseif typeString == 'deposit' then
      typeString = 'deposited'
    elseif typeString == 'withdraw' then
      typeString = 'withdrew'
    end

    if player ~= nil then
      outText = outText .. player .. " " .. typeString .. " " .. amount .. " "
    else
      outText = outText .. typeString .. " " .. amount .. " "
    end

    if (dateYear == 0) and (dateMonth == 0) and (dateDay == 0) then
      if dateHour == 0 then
        outText = outText .. " less than an hour ago" .. "\n"
      else
        outText = outText .. dateHour .. " hours ago" .. "\n"
      end
    elseif (dateYear == 0) and (dateMonth == 0) then
      if dateDay > 1 then
        outText = outText .. dateDay .. " days ago" .. "\n"
      else
        outText = outText .. dateDay .. " day ago" .. "\n"
      end
    elseif (dateYear == 0) then
      if dateMonth > 1 then
        outText = outText .. dateMonth .. " months ago" .. "\n"
      else
        outText = outText .. dateMonth .. " month ago" .. "\n"
      end
    else
      if  dateYear > 1 then
        outText = outText .. dateYear .. " years ago" .. "\n"
      else
        outText = outText .. dateYear .. " year ago" .. "\n"
      end
    end
  end

  LastGoldCheck = guildBankMoney
  print("|cff26c426Guild Money Log Audit Complete!|r")
  return outText
end
---------------------------------------------
--                UTILITY                  --
---------------------------------------------

--clean up item strings because theyre nasty
function cleanString(itemName)
  local _, newItemName = strsplit("[", itemName)
  local clean, _ = strsplit("]", newItemName)
  return clean
end

--get length of given table
function getTableLength(table)
  local outNumber = 0
  for _ in pairs(table) do
    outNumber = outNumber + 1
  end
  return outNumber
end

--check if element exists in given table
function checkTable(table, element)
  for _, value in pairs(table) do
    if (value == element) then
      return true
    end
  end
  return false
end

--search for the position of given element within table
function searchTable(table, element)
  for pos, value in pairs(table) do
    if (value == element) then
      return pos
    end
  end
end

function getItemID(link)
  local _, _, Color, Ltype, Id, Enchant, Gem1, Gem2, Gem3, Gem4, Suffix, Unique, LinkLvl, Name = string.find(link, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*):?(%-?%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
  return Id
end

---------------------------------------------
--             FRAME INIT                  --
---------------------------------------------

-- create buttons on guild bank ui
function createButtons()
  local buttonFrame = CreateFrame("Button", "ScanButtonFrame", GuildBankFrame, "UIPanelButtonTemplate")
  if ElvUILoaded == true then
    buttonFrame:StripTextures()
  end
  buttonFrame:SetPoint("TOPLEFT", 25, -41)
  buttonFrame:SetFrameLevel(4)

  buttonFrame.ScanAll = CreateFrame("Button", "ScanAllButton", buttonFrame, "UIPanelButtonTemplate")
  buttonFrame.ScanAll:SetSize(87, 22)
  buttonFrame.ScanAll:SetText("Scan All")
  buttonFrame.ScanAll:SetPoint("BOTTOMLEFT", buttonFrame)
  buttonFrame.ScanAll:RegisterForClicks("LeftButtonUp")
  buttonFrame.ScanAll:SetScript("OnClick", function() GetGBAFrame(scanBank()) end)
  if ElvUILoaded == true then
    buttonFrame.ScanAll:StyleButton()
    buttonFrame.ScanAll:SetTemplate(nil, true)
  end
  buttonFrame.ScanAll:SetFrameLevel(4)

  buttonFrame.ScanTab = CreateFrame("Button", "ScanTabButton", buttonFrame, "UIPanelButtonTemplate")
  buttonFrame.ScanTab:SetSize(87, 22)
  buttonFrame.ScanTab:SetText("Scan Tab")
  buttonFrame.ScanTab:SetPoint("BOTTOMLEFT", buttonFrame.ScanAll, "BOTTOMRIGHT")
  buttonFrame.ScanTab:RegisterForClicks("LeftButtonUp")
  buttonFrame.ScanTab:SetScript("OnClick", function() GetGBAFrame(scanTab()) end)
  if ElvUILoaded == true then
    buttonFrame.ScanTab:StyleButton()
    buttonFrame.ScanTab:SetTemplate(nil, true)
  end
  buttonFrame.ScanTab:SetFrameLevel(4)

  buttonFrame.ScanMoney = CreateFrame("Button", "ScanMoneyButton", buttonFrame, "UIPanelButtonTemplate")
  buttonFrame.ScanMoney:SetSize(87, 22)
  buttonFrame.ScanMoney:SetText("Scan Money")
  buttonFrame.ScanMoney:SetPoint("BOTTOMLEFT", buttonFrame.ScanTab, "BOTTOMRIGHT")
  buttonFrame.ScanMoney:RegisterForClicks("LeftButtonUp")
  buttonFrame.ScanMoney:SetScript("OnClick", function() GetGBAFrame(getMoneyLog()) end)
  if ElvUILoaded == true then
    buttonFrame.ScanMoney:StyleButton()
    buttonFrame.ScanMoney:SetTemplate(nil, true)
  end
  buttonFrame.ScanMoney:SetFrameLevel(4)
end

-- create the output frame
function GetGBAFrame(input)
  if not GBAFrame then
    local frame = CreateFrame("Frame", "GBAFrame", UIParent, "DialogBoxFrame")
    frame:SetPoint("CENTER")
    frame:SetSize(500, 500)
    frame:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\PVPFrame\\UI-Character-PVP-Highlight",
      edgeSize = 16,
      insets = {left = 8, right = 8, top = 8, bottom = 8}
    })
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetScript("OnMouseDown", function (self, button)
      if button == "LeftButton" then
        self:StartMoving()
      end
    end)
    frame:SetScript("OnMouseUp", function(self, button)
      self:StopMovingOrSizing()
    end)

    local scrollFrame = CreateFrame("ScrollFrame", "GBAScroll", GBAFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("LEFT", 16, 0)
    scrollFrame:SetPoint("Right", -32, 0)
    scrollFrame:SetPoint("TOP", 0, -32)
    scrollFrame:SetPoint("BOTTOM", GBAFrameButton, "TOP", 0, 0)

    local editFrame = CreateFrame("EditBox", "GBAEdit", GBAScroll)
    editFrame:SetSize(scrollFrame:GetSize())
    editFrame:SetMultiLine(true)
    editFrame:SetAutoFocus(true)
    editFrame:SetFontObject("ChatFontNormal")
    editFrame:SetScript("OnEscapePressed", function() frame:Hide() end)
    scrollFrame:SetScrollChild(editFrame)
  end
  GBAEdit:SetText(input)
  GBAEdit:HighlightText()
  GBAFrame:Show()
end

--display issue tracker for bug reporting
function printBugInfo()
  local outText = 'https://github.com/ToastyDev/GuildBankAudit/issues'
  return outText
end
