-- TMBExport - ThatsMyBis Wishlist Viewer for TBC Classic
TMBExport = {}
TMBExport.version = "1.0.0"

-- Raid list for TBC
TMBExport.RAIDS = {
    "Karazhan",
    "Gruul's Lair",
    "Magtheridon's Lair",
    "Serpentshrine Cavern",
    "Tempest Keep",
    "Hyjal Summit",
    "Black Temple",
    "Zul'Aman",
    "Sunwell Plateau",
}

-- Class colors (WoW TBC)
TMBExport.CLASS_COLORS = {
    ["Warrior"]     = {r = 0.78, g = 0.61, b = 0.43},
    ["Paladin"]     = {r = 0.96, g = 0.55, b = 0.73},
    ["Hunter"]      = {r = 0.67, g = 0.83, b = 0.45},
    ["Rogue"]       = {r = 1.00, g = 0.96, b = 0.41},
    ["Priest"]      = {r = 1.00, g = 1.00, b = 1.00},
    ["Shaman"]      = {r = 0.00, g = 0.44, b = 0.87},
    ["Mage"]        = {r = 0.25, g = 0.78, b = 0.92},
    ["Warlock"]     = {r = 0.53, g = 0.53, b = 0.93},
    ["Druid"]       = {r = 1.00, g = 0.49, b = 0.04},
}

-- Default DB structure
local function GetDefaultDB()
    return {
        wishlists = {},  -- flat list of all entries, each has a raid_group_name field
        minimapPos = 220, -- angle in degrees for minimap button position
        settings = {
            usePriority = true,
            showTooltip = true,
        },
    }
end

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "TMBExport" then
        if not TMBExportDB then
            TMBExportDB = GetDefaultDB()
        end
        if not TMBExportDB.wishlists then
            TMBExportDB.wishlists = {}
        end
        if not TMBExportDB.minimapPos then
            TMBExportDB.minimapPos = 220
        end
        if not TMBExportDB.settings then
            TMBExportDB.settings = { usePriority = true, showTooltip = true }
        end
        if TMBExportDB.settings.usePriority == nil then
            TMBExportDB.settings.usePriority = true
        end
        if TMBExportDB.settings.showTooltip == nil then
            TMBExportDB.settings.showTooltip = true
        end

        TMBExport.db = TMBExportDB
        TMBExport:CreateMinimapButton()

        print("|cff00ccffTMBExport|r v" .. TMBExport.version .. " loaded. Type |cff00ccff/tmb|r to open.")
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Slash commands
SLASH_TMBEXPORT1 = "/tmb"
SLASH_TMBEXPORT2 = "/tmbexport"
SlashCmdList["TMBEXPORT"] = function(msg)
    if TMBExport.ToggleMainFrame then
        TMBExport.ToggleMainFrame()
    end
end

-- Get the list of unique rosters found in imported data
function TMBExport:GetRosters()
    local rosters = {}
    local seen = {}
    for _, entry in ipairs(self.db.wishlists) do
        local name = entry.raid_group_name or ""
        if name ~= "" and not seen[name] then
            seen[name] = true
            table.insert(rosters, name)
        end
    end
    table.sort(rosters)
    return rosters
end

-- Utility: get unique bosses for a raid in the current roster data
function TMBExport:GetBossesForRaid(roster, raidName)
    local bosses = {}
    local seen = {}
    for _, entry in ipairs(self.db.wishlists) do
        if entry.raid_group_name == roster and entry.instance_name == raidName
           and entry.source_name and entry.source_name ~= "" then
            if not seen[entry.source_name] then
                seen[entry.source_name] = true
                table.insert(bosses, entry.source_name)
            end
        end
    end
    table.sort(bosses)
    return bosses
end

-- Utility: get wishlist entries for a specific boss
function TMBExport:GetWishlistForBoss(roster, raidName, bossName)
    local results = {}
    for _, entry in ipairs(self.db.wishlists) do
        if entry.raid_group_name == roster and entry.instance_name == raidName
           and entry.source_name == bossName then
            table.insert(results, entry)
        end
    end

    -- Sort by item, then by character, then sort_order
    table.sort(results, function(a, b)
        if a.item_name == b.item_name then
            if a.character_name == b.character_name then
                return (a.sort_order or 99) < (b.sort_order or 99)
            end
            return a.character_name < b.character_name
        end
        return a.item_name < b.item_name
    end)

    return results
end

-- Lookup: get all characters who have a given item_id in their wishlist
-- Returns a sorted list of { character_name, character_class, sort_order, raid_group_name, is_offspec, received_at }
function TMBExport:GetWishlistByItemId(itemId)
    local results = {}
    for _, entry in ipairs(self.db.wishlists) do
        if entry.item_id == itemId then
            table.insert(results, entry)
        end
    end
    -- Sort by roster, then sort_order
    table.sort(results, function(a, b)
        if a.raid_group_name == b.raid_group_name then
            if a.character_name == b.character_name then
                return (a.sort_order or 99) < (b.sort_order or 99)
            end
            return a.character_name < b.character_name
        end
        return a.raid_group_name < b.raid_group_name
    end)
    return results
end

-- Import parsed CSV data (replaces all existing data)
function TMBExport:ImportData(entries)
    local remapped = 0
    if self.RemapTierPieces then
        remapped = self:RemapTierPieces(entries)
    end

    self.db.wishlists = entries

    local rosters = self:GetRosters()
    local rosterList = table.concat(rosters, ", ")
    print("|cff00ccffTMBExport|r: Imported " .. #entries .. " wishlist entries.")
    if remapped > 0 then
        print("|cff00ccffTMBExport|r: Remapped " .. remapped .. " tier set pieces to their tokens.")
    end
    if #rosters > 0 then
        print("|cff00ccffTMBExport|r: Rosters found: " .. rosterList)
    end
end

-- Clear all data
function TMBExport:ClearAllData()
    self.db.wishlists = {}
    print("|cff00ccffTMBExport|r: All data cleared.")
end

-- Minimap button via LibDBIcon
function TMBExport:CreateMinimapButton()
    local LDB = LibStub("LibDataBroker-1.1")
    local LDBIcon = LibStub("LibDBIcon-1.0")

    local dataBroker = LDB:NewDataObject("TMBExport", {
        type = "launcher",
        text = "TMBExport",
        icon = "Interface\\AddOns\\TMBExport\\icon",
        OnClick = function(_, button)
            if button == "LeftButton" and TMBExport.ToggleMainFrame then
                TMBExport.ToggleMainFrame()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("TMBExport", 0, 0.8, 1)
            tooltip:AddLine("Click to open wishlist viewer", 1, 1, 1)
        end,
    })

    if not self.db.minimap then
        self.db.minimap = { hide = false }
    end

    LDBIcon:Register("TMBExport", dataBroker, self.db.minimap)
end
