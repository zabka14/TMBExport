-- TMBExport UI Module
local FRAME_WIDTH = 1100
local FRAME_HEIGHT = 600
local ROW_HEIGHT = 20
local HEADER_HEIGHT = 24

local mainFrame = nil
local currentRaid = nil
local currentRoster = nil
local currentBoss = nil
local contentRows = {}
local bossButtons = {}
local importFrame = nil
local settingsFrame = nil
local expandedItems = {}  -- key: bossName .. "#" .. itemId -> true if expanded

-- Hidden frame used as a garbage parent for recycled UI elements
local recycleBin = CreateFrame("Frame")
recycleBin:Hide()

-- ============================================================
-- Utility
-- ============================================================
local function GetClassColor(class)
    local c = TMBExport.CLASS_COLORS[class]
    if c then
        return c.r, c.g, c.b
    end
    return 1, 1, 1
end

local function CreateItemLink(itemId, itemName)
    if itemId and itemId > 0 then
        return "|cffffffff|Hitem:" .. itemId .. ":0:0:0:0:0:0:0|h[" .. itemName .. "]|h|r"
    end
    return itemName
end

-- Refresh the roster dropdown to reflect current data
local function RefreshRosterDropdown()
    if not mainFrame or not mainFrame.rosterDropdown then return end
    local rosters = TMBExport:GetRosters()
    local dropdown = mainFrame.rosterDropdown

    -- If current roster is no longer valid, reset
    if currentRoster then
        local found = false
        for _, r in ipairs(rosters) do
            if r == currentRoster then found = true; break end
        end
        if not found then
            currentRoster = rosters[1] or nil
        end
    elseif #rosters > 0 then
        currentRoster = rosters[1]
    end

    UIDropDownMenu_SetText(dropdown, currentRoster or "No data")
end

-- ============================================================
-- Import Dialog
-- ============================================================
local function CreateImportFrame()
    if importFrame then return importFrame end

    importFrame = CreateFrame("Frame", "TMBExportImportFrame", UIParent, "BackdropTemplate")
    importFrame:SetSize(500, 400)
    importFrame:SetPoint("CENTER")
    importFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 8, right = 8, top = 8, bottom = 8},
    })
    importFrame:SetMovable(true)
    importFrame:EnableMouse(true)
    importFrame:RegisterForDrag("LeftButton")
    importFrame:SetScript("OnDragStart", importFrame.StartMoving)
    importFrame:SetScript("OnDragStop", importFrame.StopMovingOrSizing)
    importFrame:SetFrameStrata("DIALOG")
    importFrame:Hide()

    -- Title
    local title = importFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Import TMB Wishlist CSV")

    -- Info text
    local info = importFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    info:SetPoint("TOPLEFT", 20, -42)
    info:SetText("Paste your ThatsMyBis CSV export below. Rosters will be detected automatically.")
    info:SetTextColor(0.7, 0.7, 0.7)

    -- Scroll frame with edit box for CSV paste
    local scrollFrame = CreateFrame("ScrollFrame", "TMBExportImportScroll", importFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -60)
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, 60)

    local editBox = CreateFrame("EditBox", "TMBExportImportEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(scrollFrame:GetWidth() or 420)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scrollFrame:SetScrollChild(editBox)

    scrollFrame:SetScript("OnSizeChanged", function(self, w)
        editBox:SetWidth(w)
    end)

    -- Import button
    local importBtn = CreateFrame("Button", nil, importFrame, "GameMenuButtonTemplate")
    importBtn:SetSize(120, 25)
    importBtn:SetPoint("BOTTOMRIGHT", -100, 20)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", function()
        local csvText = editBox:GetText()
        if csvText and csvText ~= "" then
            local entries = TMBExport:ParseCSV(csvText)
            if #entries > 0 then
                TMBExport:ImportData(entries)
                editBox:SetText("")
                importFrame:Hide()
                if mainFrame and mainFrame:IsShown() then
                    RefreshRosterDropdown()
                    TMBExport:RefreshBossButtons()
                    TMBExport:RefreshDisplay()
                end
            else
                print("|cff00ccffTMBExport|r: No valid wishlist entries found in CSV.")
            end
        end
    end)

    -- Cancel button
    local cancelBtn = CreateFrame("Button", nil, importFrame, "GameMenuButtonTemplate")
    cancelBtn:SetSize(100, 25)
    cancelBtn:SetPoint("BOTTOMLEFT", 20, 20)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function()
        editBox:SetText("")
        importFrame:Hide()
    end)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, importFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    importFrame.editBox = editBox

    return importFrame
end

-- ============================================================
-- Settings Dialog
-- ============================================================
local function CreateSettingsFrame()
    if settingsFrame then return settingsFrame end

    settingsFrame = CreateFrame("Frame", "TMBExportSettingsFrame", UIParent, "BackdropTemplate")
    settingsFrame:SetSize(380, 320)
    settingsFrame:SetPoint("CENTER")
    settingsFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 8, right = 8, top = 8, bottom = 8},
    })
    settingsFrame:SetMovable(true)
    settingsFrame:EnableMouse(true)
    settingsFrame:RegisterForDrag("LeftButton")
    settingsFrame:SetScript("OnDragStart", settingsFrame.StartMoving)
    settingsFrame:SetScript("OnDragStop", settingsFrame.StopMovingOrSizing)
    settingsFrame:SetFrameStrata("DIALOG")
    settingsFrame:Hide()

    local title = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("TMBExport - Settings")

    local closeBtn = CreateFrame("Button", nil, settingsFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    -- Priority checkbox
    local priorityCheck = CreateFrame("CheckButton", "TMBExportPriorityCheck", settingsFrame, "UICheckButtonTemplate")
    priorityCheck:SetPoint("TOPLEFT", 20, -55)
    _G[priorityCheck:GetName() .. "Text"]:SetText("Use priority system")

    local desc = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", 40, -85)
    desc:SetPoint("RIGHT", settingsFrame, "RIGHT", -20, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("When enabled, characters are sorted by their priority and the priority number is shown after each name in parentheses.")
    desc:SetTextColor(0.7, 0.7, 0.7)

    priorityCheck:SetScript("OnClick", function(self)
        if not TMBExport.db.settings then
            TMBExport.db.settings = {}
        end
        TMBExport.db.settings.usePriority = self:GetChecked() and true or false
        if mainFrame and mainFrame:IsShown() then
            TMBExport:RefreshDisplay()
        end
    end)

    -- Tooltip checkbox
    local tooltipCheck = CreateFrame("CheckButton", "TMBExportTooltipCheck", settingsFrame, "UICheckButtonTemplate")
    tooltipCheck:SetPoint("TOPLEFT", 20, -150)
    _G[tooltipCheck:GetName() .. "Text"]:SetText("Show wishlist info in item tooltips")

    local tooltipDesc = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tooltipDesc:SetPoint("TOPLEFT", 40, -180)
    tooltipDesc:SetPoint("RIGHT", settingsFrame, "RIGHT", -20, 0)
    tooltipDesc:SetJustifyH("LEFT")
    tooltipDesc:SetText("When enabled, hovering an item displays the list of characters who have it in their wishlist.")
    tooltipDesc:SetTextColor(0.7, 0.7, 0.7)

    tooltipCheck:SetScript("OnClick", function(self)
        if not TMBExport.db.settings then
            TMBExport.db.settings = {}
        end
        TMBExport.db.settings.showTooltip = self:GetChecked() and true or false
    end)

    -- Close button at bottom
    local okBtn = CreateFrame("Button", nil, settingsFrame, "GameMenuButtonTemplate")
    okBtn:SetSize(100, 25)
    okBtn:SetPoint("BOTTOM", 0, 20)
    okBtn:SetText("Close")
    okBtn:SetScript("OnClick", function()
        settingsFrame:Hide()
    end)

    settingsFrame.priorityCheck = priorityCheck
    settingsFrame.tooltipCheck = tooltipCheck

    settingsFrame:SetScript("OnShow", function(self)
        local s = TMBExport.db and TMBExport.db.settings or {}
        self.priorityCheck:SetChecked(s.usePriority and true or false)
        self.tooltipCheck:SetChecked(s.showTooltip ~= false)
    end)

    return settingsFrame
end

-- ============================================================
-- Main Frame
-- ============================================================
local function CreateMainFrame()
    if mainFrame then return mainFrame end

    mainFrame = CreateFrame("Frame", "TMBExportMainFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 8, right = 8, top = 8, bottom = 8},
    })
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:Hide()

    table.insert(UISpecialFrames, "TMBExportMainFrame")

    -- Title
    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("|cff00ccffThat's My Bis Export|r - Wishlist Viewer")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    -- ========== Left Panel: Raid Selection ==========
    local raidLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    raidLabel:SetPoint("TOPLEFT", 20, -45)
    raidLabel:SetText("Raid:")

    local raidButtons = {}
    for i, raidName in ipairs(TMBExport.RAIDS) do
        local btn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
        btn:SetSize(180, 22)
        btn:SetPoint("TOPLEFT", 15, -60 - (i - 1) * 25)
        btn:SetText(raidName)
        btn:SetScript("OnClick", function()
            currentRaid = raidName
            currentBoss = nil
            for _, b in ipairs(raidButtons) do
                b:UnlockHighlight()
            end
            btn:LockHighlight()
            TMBExport:RefreshBossButtons()
            TMBExport:RefreshDisplay()
        end)
        table.insert(raidButtons, btn)
    end

    -- ========== Left Panel: Boss Selection (below raids) ==========
    local bossLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bossLabel:SetPoint("TOPLEFT", 20, -60 - #TMBExport.RAIDS * 25 - 10)
    bossLabel:SetText("Boss:")
    mainFrame.bossLabel = bossLabel

    local bossScrollFrame = CreateFrame("ScrollFrame", "TMBExportBossScroll", mainFrame, "UIPanelScrollFrameTemplate")
    bossScrollFrame:SetPoint("TOPLEFT", 15, -60 - #TMBExport.RAIDS * 25 - 28)
    bossScrollFrame:SetPoint("BOTTOMLEFT", 15, 15)
    bossScrollFrame:SetWidth(160)

    local bossScrollChild = CreateFrame("Frame", nil, bossScrollFrame)
    bossScrollChild:SetWidth(155)
    bossScrollFrame:SetScrollChild(bossScrollChild)

    mainFrame.bossScrollChild = bossScrollChild
    mainFrame.bossLabel = bossLabel

    -- ========== Top Right: Roster Dropdown + Import Button ==========
    local rosterLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rosterLabel:SetPoint("TOPLEFT", 210, -45)
    rosterLabel:SetText("Roster:")

    local rosterDropdown = CreateFrame("Frame", "TMBExportRosterDropdown", mainFrame, "UIDropDownMenuTemplate")
    rosterDropdown:SetPoint("LEFT", rosterLabel, "RIGHT", -5, -2)

    local function InitMainRosterDropdown(self, level)
        local rosters = TMBExport:GetRosters()
        if #rosters == 0 then
            local info = UIDropDownMenu_CreateInfo()
            info.text = "No data"
            info.disabled = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
            return
        end
        for _, roster in ipairs(rosters) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = roster
            info.func = function()
                currentRoster = roster
                currentBoss = nil
                UIDropDownMenu_SetText(rosterDropdown, roster)
                TMBExport:RefreshBossButtons()
                TMBExport:RefreshDisplay()
            end
            info.checked = (roster == currentRoster)
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_SetWidth(rosterDropdown, 120)
    UIDropDownMenu_SetText(rosterDropdown, "No data")
    UIDropDownMenu_Initialize(rosterDropdown, InitMainRosterDropdown)

    -- Import button
    local importBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    importBtn:SetSize(140, 25)
    importBtn:SetPoint("TOPRIGHT", -20, -43)
    importBtn:SetText("Import CSV")
    importBtn:SetScript("OnClick", function()
        local f = CreateImportFrame()
        f:Show()
        f.editBox:SetFocus()
    end)

    -- Clear button
    local clearBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    clearBtn:SetSize(140, 25)
    clearBtn:SetPoint("RIGHT", importBtn, "LEFT", -5, 0)
    clearBtn:SetText("Clear All Data")
    clearBtn:SetScript("OnClick", function()
        StaticPopup_Show("TMBEXPORT_CONFIRM_CLEAR")
    end)

    -- Settings button
    local settingsBtn = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    settingsBtn:SetSize(100, 25)
    settingsBtn:SetPoint("RIGHT", clearBtn, "LEFT", -5, 0)
    settingsBtn:SetText("Settings")
    settingsBtn:SetScript("OnClick", function()
        local f = CreateSettingsFrame()
        if f:IsShown() then
            f:Hide()
        else
            f:Show()
        end
    end)

    StaticPopupDialogs["TMBEXPORT_CONFIRM_CLEAR"] = {
        text = "Clear all imported wishlist data?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            TMBExport:ClearAllData()
            currentRoster = nil
            currentBoss = nil
            RefreshRosterDropdown()
            TMBExport:RefreshBossButtons()
            TMBExport:RefreshDisplay()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    -- ========== Content Area: Scrollable List ==========
    local contentArea = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    contentArea:SetPoint("TOPLEFT", 210, -75)
    contentArea:SetPoint("BOTTOMRIGHT", -15, 15)
    contentArea:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4},
    })
    contentArea:SetBackdropColor(0, 0, 0, 0.7)

    local scrollFrame = CreateFrame("ScrollFrame", "TMBExportContentScroll", contentArea, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() or 540)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:SetScript("OnSizeChanged", function(self, w)
        scrollChild:SetWidth(w)
    end)

    mainFrame.scrollChild = scrollChild
    mainFrame.raidButtons = raidButtons
    mainFrame.rosterDropdown = rosterDropdown

    return mainFrame
end

-- ============================================================
-- Refresh Boss Buttons
-- ============================================================
function TMBExport:RefreshBossButtons()
    if not mainFrame then return end
    local scrollChild = mainFrame.bossScrollChild

    -- Clear old boss buttons
    for _, btn in ipairs(bossButtons) do
        btn:ClearAllPoints()
        btn:SetParent(recycleBin)
        btn:Hide()
    end
    bossButtons = {}

    if not currentRaid or not currentRoster then
        mainFrame.bossLabel:Hide()
        return
    end

    local bosses = self:GetBossesForRaid(currentRoster, currentRaid)
    if #bosses == 0 then
        mainFrame.bossLabel:Hide()
        return
    end

    mainFrame.bossLabel:Show()

    -- "All bosses" button
    local allBtn = CreateFrame("Button", nil, scrollChild, "GameMenuButtonTemplate")
    allBtn:SetSize(155, 20)
    allBtn:SetPoint("TOPLEFT", 0, 0)
    allBtn:SetText("All bosses")
    allBtn:SetNormalFontObject(GameFontNormalSmall)
    allBtn:SetHighlightFontObject(GameFontHighlightSmall)
    if not currentBoss then
        allBtn:LockHighlight()
    end
    allBtn:SetScript("OnClick", function()
        currentBoss = nil
        for _, b in ipairs(bossButtons) do
            b:UnlockHighlight()
        end
        allBtn:LockHighlight()
        TMBExport:RefreshDisplay()
    end)
    table.insert(bossButtons, allBtn)

    for i, bossName in ipairs(bosses) do
        local btn = CreateFrame("Button", nil, scrollChild, "GameMenuButtonTemplate")
        btn:SetSize(155, 20)
        btn:SetPoint("TOPLEFT", 0, -i * 22)
        btn:SetText(bossName)
        btn:SetNormalFontObject(GameFontNormalSmall)
        btn:SetHighlightFontObject(GameFontHighlightSmall)
        if currentBoss == bossName then
            btn:LockHighlight()
        end
        btn:SetScript("OnClick", function()
            currentBoss = bossName
            for _, b in ipairs(bossButtons) do
                b:UnlockHighlight()
            end
            btn:LockHighlight()
            TMBExport:RefreshDisplay()
        end)
        table.insert(bossButtons, btn)
    end

    scrollChild:SetHeight((#bosses + 1) * 22)
end

-- ============================================================
-- Refresh Content Display
-- ============================================================
function TMBExport:RefreshDisplay()
    if not mainFrame or not mainFrame:IsShown() then return end

    local scrollChild = mainFrame.scrollChild

    -- Clear existing content
    for _, row in ipairs(contentRows) do
        row:ClearAllPoints()
        row:SetParent(recycleBin)
        row:Hide()
    end
    contentRows = {}

    if not currentRoster then
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(scrollChild:GetWidth(), 30)
        row:SetPoint("TOPLEFT", 0, 0)
        local msg = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        msg:SetPoint("TOPLEFT", 10, -10)
        msg:SetText("No data imported yet. Use 'Import CSV' to load wishlist data.")
        table.insert(contentRows, row)
        scrollChild:SetHeight(40)
        return
    end

    if not currentRaid then
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(scrollChild:GetWidth(), 30)
        row:SetPoint("TOPLEFT", 0, 0)
        local msg = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        msg:SetPoint("TOPLEFT", 10, -10)
        msg:SetText("Select a raid from the list on the left.")
        table.insert(contentRows, row)
        scrollChild:SetHeight(40)
        return
    end

    local allBosses = self:GetBossesForRaid(currentRoster, currentRaid)
    local bosses
    if currentBoss then
        bosses = {currentBoss}
    else
        bosses = allBosses
    end

    if #allBosses == 0 then
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(scrollChild:GetWidth(), 50)
        row:SetPoint("TOPLEFT", 0, 0)
        local msg = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        msg:SetPoint("TOPLEFT", 10, -10)
        msg:SetText("No wishlist data for " .. currentRaid .. " in " .. currentRoster .. ".")
        msg:SetJustifyH("LEFT")
        table.insert(contentRows, row)
        scrollChild:SetHeight(60)
        return
    end

    local yOffset = 0
    local contentWidth = scrollChild:GetWidth() - 10

    -- Column headers (once at the top)
    local colHeader = CreateFrame("Frame", nil, scrollChild)
    colHeader:SetSize(contentWidth, ROW_HEIGHT)
    colHeader:SetPoint("TOPLEFT", 5, 0)
    table.insert(contentRows, colHeader)

    local col1 = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    col1:SetPoint("LEFT", 28, 0)
    col1:SetWidth(220)
    col1:SetJustifyH("LEFT")
    col1:SetText("|cffAAAAAAItem|r")

    local col2 = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    col2:SetPoint("LEFT", 250, 0)
    col2:SetWidth(350)
    col2:SetJustifyH("LEFT")
    col2:SetText("|cffAAAAAAPlayers|r")

    yOffset = yOffset + ROW_HEIGHT + 2

    for _, bossName in ipairs(bosses) do
        -- Boss header
        local header = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
        header:SetSize(contentWidth, HEADER_HEIGHT)
        header:SetPoint("TOPLEFT", 5, -yOffset)
        header:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        })
        header:SetBackdropColor(0.2, 0.2, 0.6, 0.8)
        table.insert(contentRows, header)

        local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        headerText:SetPoint("LEFT", 8, 0)
        headerText:SetText("|cffFFD100" .. bossName .. "|r")

        yOffset = yOffset + HEADER_HEIGHT + 2

        -- Get items for this boss and group by item
        local entries = self:GetWishlistForBoss(currentRoster, currentRaid, bossName)

        -- Group entries by item_id
        local itemOrder = {}
        local itemGroups = {}
        for _, entry in ipairs(entries) do
            local key = entry.item_id
            if not itemGroups[key] then
                itemGroups[key] = { item_name = entry.item_name, item_id = entry.item_id, players = {} }
                table.insert(itemOrder, key)
            end
            table.insert(itemGroups[key].players, entry)
        end

        for _, itemKey in ipairs(itemOrder) do
            local group = itemGroups[itemKey]

            local row = CreateFrame("Frame", nil, scrollChild)
            row:SetSize(contentWidth, ROW_HEIGHT)
            row:SetPoint("TOPLEFT", 5, -yOffset)
            table.insert(contentRows, row)

            -- Alternating background
            if #contentRows % 2 == 0 then
                local bg = row:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0.15, 0.15, 0.15, 0.5)
            end

            -- Expand/collapse button
            local expandKey = bossName .. "#" .. tostring(group.item_id)
            local isExpanded = expandedItems[expandKey] or false

            local expandBtn = CreateFrame("Button", nil, row)
            expandBtn:SetPoint("LEFT", 6, 0)
            expandBtn:SetSize(16, 16)
            local expandText = expandBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            expandText:SetPoint("CENTER", 0, 0)
            expandText:SetText(isExpanded and "|cffFFD100-|r" or "|cffFFD100+|r")
            expandBtn:SetScript("OnClick", function()
                expandedItems[expandKey] = not expandedItems[expandKey]
                TMBExport:RefreshDisplay()
            end)

            -- Item name (clickable with tooltip)
            local itemBtn = CreateFrame("Button", nil, row)
            itemBtn:SetPoint("LEFT", 28, 0)
            itemBtn:SetSize(220, ROW_HEIGHT)

            local itemText = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            itemText:SetPoint("LEFT", 0, 0)
            itemText:SetWidth(220)
            itemText:SetJustifyH("LEFT")
            itemText:SetText("|cffffffff" .. group.item_name .. "|r")

            local itemId = group.item_id
            if itemId and itemId > 0 then
                itemBtn:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink("item:" .. itemId)
                    GameTooltip:Show()
                end)
                itemBtn:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
                itemBtn:SetScript("OnClick", function()
                    if IsShiftKeyDown() then
                        local link = CreateItemLink(itemId, group.item_name)
                        ChatEdit_InsertLink(link)
                    end
                end)
            end

            -- Players list (class-colored, comma-separated)
            local usePriority = TMBExport.db and TMBExport.db.settings and TMBExport.db.settings.usePriority
            if usePriority then
                table.sort(group.players, function(a, b)
                    local pa = tonumber(a.sort_order) or 99
                    local pb = tonumber(b.sort_order) or 99
                    if pa == pb then
                        return (a.character_name or "") < (b.character_name or "")
                    end
                    return pa < pb
                end)
            end

            local names = {}
            for _, player in ipairs(group.players) do
                local r, g, b = GetClassColor(player.character_class)
                local colorHex = string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
                local name = colorHex .. player.character_name .. "|r"
                if usePriority and player.sort_order then
                    name = name .. "|cffAAAAAA(" .. player.sort_order .. ")|r"
                end
                if player.is_offspec then
                    name = name .. "|cffFF8800(OS)|r"
                end
                if player.received_at and player.received_at ~= "" then
                    name = name .. "|cff888888(recv)|r"
                end
                table.insert(names, name)
            end

            local playersText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            playersText:SetPoint("LEFT", 250, 0)
            playersText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
            playersText:SetJustifyH("LEFT")
            playersText:SetText(table.concat(names, ", "))

            yOffset = yOffset + ROW_HEIGHT

            -- Expanded details table
            if isExpanded then
                local detailHeight = ROW_HEIGHT
                local detail = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
                detail:SetSize(contentWidth - 30, detailHeight)
                detail:SetPoint("TOPLEFT", 35, -yOffset)
                detail:SetBackdrop({
                    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                })
                detail:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
                table.insert(contentRows, detail)

                -- Column layout: Player(160) Prio(40) OS(30) Note(220) ItemPrioNote(rest)
                local cols = {
                    { x = 6,   w = 160, label = "Player" },
                    { x = 170, w = 40,  label = "Prio" },
                    { x = 215, w = 30,  label = "OS" },
                    { x = 250, w = 220, label = "Note" },
                    { x = 475, w = 280, label = "Item Prio Note" },
                }
                for _, c in ipairs(cols) do
                    local h = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    h:SetPoint("TOPLEFT", c.x, -2)
                    h:SetWidth(c.w)
                    h:SetJustifyH("LEFT")
                    h:SetText("|cffAAAAAA" .. c.label .. "|r")
                end

                local rowY = ROW_HEIGHT
                for _, player in ipairs(group.players) do
                    local r, g, bb = GetClassColor(player.character_class)
                    local colorHex = string.format("|cff%02x%02x%02x", r * 255, g * 255, bb * 255)

                    local function dim(s)
                        if not s or s == "" then return "|cff666666-|r" end
                        return s
                    end

                    local values = {
                        colorHex .. (player.character_name or "") .. "|r",
                        tostring(player.sort_order or "-"),
                        player.is_offspec and "|cffFF8800Yes|r" or "|cff666666-|r",
                        dim(player.note),
                        dim(player.item_prio_note),
                    }

                    for i, c in ipairs(cols) do
                        local fs = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                        fs:SetPoint("TOPLEFT", c.x, -rowY)
                        fs:SetWidth(c.w)
                        fs:SetJustifyH("LEFT")
                        fs:SetWordWrap(true)
                        fs:SetText(values[i])
                    end
                    rowY = rowY + ROW_HEIGHT
                end

                detail:SetHeight(rowY + 4)
                yOffset = yOffset + rowY + 6
            end
        end

        -- Spacing between bosses
        yOffset = yOffset + 8
    end

    scrollChild:SetHeight(yOffset + 20)
end

-- ============================================================
-- Toggle
-- ============================================================
-- ============================================================
-- Tooltip Hook: show wishlist info in the item tooltip
-- ============================================================
local function OnTooltipSetItem(tooltip)
    if not TMBExport.db or not TMBExport.db.wishlists or #TMBExport.db.wishlists == 0 then
        return
    end
    if TMBExport.db.settings and TMBExport.db.settings.showTooltip == false then
        return
    end

    local _, itemLink = tooltip:GetItem()
    if not itemLink then return end

    local itemId = tonumber(itemLink:match("item:(%d+)"))
    if not itemId then return end

    local entries = TMBExport:GetWishlistByItemId(itemId)
    if #entries == 0 then return end

    tooltip:AddLine(" ")
    tooltip:AddLine("TMB Wishlist", 0, 0.8, 1)

    -- Group entries by roster
    local rosterOrder = {}
    local rosterEntries = {}
    for _, entry in ipairs(entries) do
        local roster = entry.raid_group_name
        if not rosterEntries[roster] then
            rosterEntries[roster] = {}
            table.insert(rosterOrder, roster)
        end
        table.insert(rosterEntries[roster], entry)
    end

    local usePriority = TMBExport.db and TMBExport.db.settings and TMBExport.db.settings.usePriority

    for _, roster in ipairs(rosterOrder) do
        local rosterList = rosterEntries[roster]

        if usePriority then
            table.sort(rosterList, function(a, b)
                local pa = tonumber(a.sort_order) or 99
                local pb = tonumber(b.sort_order) or 99
                if pa == pb then
                    return (a.character_name or "") < (b.character_name or "")
                end
                return pa < pb
            end)
        end

        -- Build a comma-separated line with class-colored names
        local names = {}
        for _, entry in ipairs(rosterList) do
            local r, g, b = GetClassColor(entry.character_class)
            local colorHex = string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
            local name = colorHex .. entry.character_name .. "|r"
            if usePriority and entry.sort_order then
                name = name .. "|cffAAAAAA(" .. entry.sort_order .. ")|r"
            end
            if entry.is_offspec then
                name = name .. "|cffFF8800(OS)|r"
            end
            if entry.received_at and entry.received_at ~= "" then
                name = name .. "|cff888888(recv)|r"
            end
            table.insert(names, name)
        end

        tooltip:AddLine("|cffFFD100[" .. roster .. "]|r " .. table.concat(names, ", "), 1, 1, 1, true)
    end

    tooltip:Show()
end

GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
ShoppingTooltip1:HookScript("OnTooltipSetItem", OnTooltipSetItem)
ShoppingTooltip2:HookScript("OnTooltipSetItem", OnTooltipSetItem)

-- ============================================================
-- Toggle
-- ============================================================
function TMBExport.ToggleMainFrame()
    local frame = CreateMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        RefreshRosterDropdown()
        TMBExport:RefreshBossButtons()
        frame:Show()
        TMBExport:RefreshDisplay()
    end
end
