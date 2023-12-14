-- Author: qustrolabe
-- This addon is used to scan players and store their data in a database
-- Scan is performed on mouseover of a player in inspect range

-- Default settings values, overwriten by saved variables on db load
local settings = {
    isEnabled = false,
    isVerbose = true,
    scanOpposingFaction = false,
}

-- Create the database frame
local EyeOfWisdomDBFrame = CreateFrame("Frame", "EyeOfWisdomDBFrame", UIParent)
EyeOfWisdomDBFrame:RegisterEvent("ADDON_LOADED")
EyeOfWisdomDBFrame:RegisterEvent("PLAYER_LOGOUT")


-- Debug frame
--
-- Create debug frame
local EOWDebugFrame = CreateFrame("Frame", "EOWDebugFrame", UIParent)
EOWDebugFrame:SetSize(200, 80)
EOWDebugFrame:SetPoint("TOPLEFT", 0, -50)

-- Set dark background
EOWDebugFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
EOWDebugFrame:SetBackdropColor(0, 0, 1, .5)

-- Add text to the debug frame
local debugText = EOWDebugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
debugText:SetText("Eye of Wisdom")
debugText:SetTextColor(1, 1, 1, 1)
debugText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
debugText:SetShadowOffset(1, -1)
debugText:SetShadowColor(0, 0, 0, 1)
debugText:SetPoint("CENTER", EOWDebugFrame, "CENTER", 0, 0)

-- Toggle the addon
local function toggle_addon()
    if settings.isEnabled then
        settings.isEnabled = false
        print("EyeOfWisdom disabled")
    else
        settings.isEnabled = true
        print("EyeOfWisdom enabled")
    end
end

-- Toggle verbose mode
local function toggle_verbose()
    if settings.isVerbose then
        settings.isVerbose = false
        print("EyeOfWisdom verbose mode disabled")
    else
        settings.isVerbose = true
        print("EyeOfWisdom verbose mode enabled")
    end
end

function EyeOfWisdom()
    -- Toggle the addon
    toggle_addon()
end

-- Updates info in the debug frame
-- TODO make it toggleable
-- Be careful with this function, it can cause lag
local function debug_frame()
    if not settings.isEnabled then return end -- If addon is disabled, do nothing

    -- Get scanned players count in EOW database
    local count = 0
    local level_sum = 0
    for k, v in pairs(EyeOfWisdomDB.players) do
        count = count + 1
        level_sum = level_sum + v.level
    end

    local debugOutput = ""

    debugOutput = debugOutput ..
        "Scanned players: " .. count .. "\nAverage level: " .. string.format("%.02f", level_sum / count) .. "\n"

    debugText:SetText(debugOutput)
end
-- local timer = AceTimer:ScheduleRepeatingTimer(debug_frame, 1)
-- TODO make timer toggleable

-- Use OnUpdate instead of AceTimer
local timer = 0
local function onUpdate(self, elapsed)
    timer = timer + elapsed
    if timer > 5 then
        debug_frame()
        timer = 0
    end
end
EOWDebugFrame:SetScript("OnUpdate", onUpdate)


local function observe_player(self, ...)
    if not settings.isEnabled then return end

    local unitName, unitId = self:GetUnit()

    -- Check if the unit is a mouseover
    if unitId ~= "mouseover" then return end

    -- Check if the unit is a player
    if not UnitIsPlayer(unitId) then return end

    -- Check what faction the player is in
    local faction = UnitFactionGroup(unitId)

    -- If player is in opposing faction
    if faction ~= nil and faction ~= UnitFactionGroup("player") and not settings.scanOpposingFaction then
        if settings.isVerbose then
            print("Opposing faction player detected, skipping")
        end
        return
    end

    -- If can inspect
    local canInspect = CanInspect(unitId)

    local playerData = {
        name = unitName,
        level = UnitLevel(unitId),
        class = UnitClass(unitId),
        guild = GetGuildInfo(unitId),
        faction = faction,
        inventorySlots = {},
    }

    if canInspect then
        -- Inspect the player
        NotifyInspect(unitId)
        playerData.inventorySlots = {
            head = GetInventoryItemID(unitId, 1),
            neck = GetInventoryItemID(unitId, 2),
            shoulder = GetInventoryItemID(unitId, 3),
            shirt = GetInventoryItemID(unitId, 4),
            chest = GetInventoryItemID(unitId, 5),
            waist = GetInventoryItemID(unitId, 6),
            legs = GetInventoryItemID(unitId, 7),
            feet = GetInventoryItemID(unitId, 8),
            wrist = GetInventoryItemID(unitId, 9),
            hands = GetInventoryItemID(unitId, 10),
            finger1 = GetInventoryItemID(unitId, 11),
            finger2 = GetInventoryItemID(unitId, 12),
            trinket1 = GetInventoryItemID(unitId, 13),
            trinket2 = GetInventoryItemID(unitId, 14),
            back = GetInventoryItemID(unitId, 15),

            mainHand = GetInventoryItemID(unitId, 16),
            offHand = GetInventoryItemID(unitId, 17),
            ranged = GetInventoryItemID(unitId, 18),

            tabard = GetInventoryItemID(unitId, 19),
        }
    end

    -- If EyeOfWisdomDB loaded
    if EyeOfWisdomDB ~= nil then
        -- If player is not in the database
        if EyeOfWisdomDB.players[playerData.name] == nil then
            -- Add player to the database
            EyeOfWisdomDB.players[playerData.name] = playerData
            if settings.isVerbose then
                print("Added " .. playerData.name .. " to the database")
            end
        else
            -- If player is in the database
            -- Check if playerData is equal to the one in the database
            local playerDataInDB = EyeOfWisdomDB.players[playerData.name]

            -- Recursively compare tables
            -- Take in count if inventorySlots is nil or empty
            local function compare_tables(t1, t2)
                if t1 == nil and t2 == nil then
                    return true
                elseif t1 == nil or t2 == nil then
                    return false
                end

                for k, v in pairs(t1) do
                    if type(v) == "table" then
                        if not compare_tables(v, t2[k]) then
                            return false
                        end
                    else
                        if v ~= t2[k] then
                            return false
                        end
                    end
                end

                return true
            end

            if compare_tables(playerData, playerDataInDB) then
                if settings.isVerbose then
                    print("Player: " .. playerData.name .. " is already in the database and is up to date")
                end
            else
                -- If playerData is not equal to the one in the database
                -- Update the playerData in the database
                EyeOfWisdomDB.players[playerData.name] = playerData
                if settings.isVerbose then
                    print("Updated " .. playerData.name .. " in the database")
                end
            end
        end
    end
end

-- Display scanned players list
local function list_scanned()
    local output = ""

    for k, v in pairs(EyeOfWisdomDB.players) do
        output = output .. v.name .. "_" .. v.level .. ","
    end

    print(output)
end

-- Hook the tooltip
-- so that on mouseover, the player data is printed
GameTooltip:HookScript("OnTooltipSetUnit", observe_player)

-- Function to get specific player data in chat
local function get_player(name)
    if EyeOfWisdomDB.players[name] ~= nil then
        local playerData = EyeOfWisdomDB.players[name]
        print("Name: " .. playerData.name)
        print("Level: " .. playerData.level)

        -- Color class by class color
        local classColor = RAID_CLASS_COLORS[playerData.class:upper()] or { r = 1, g = 1, b = 1 } -- Default to white
        -- Use \124 instead of | to avoid chat frame error
        print("Class: \124cff" ..
        string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255) ..
        playerData.class .. "\124r")

        -- /run print(string.format("%02x%02x%02x", 1, 1, 1))

        if playerData.guild ~= nil then
            print("Guild: " .. playerData.guild)
        end
        
        -- If inventorySlots is not empty
        if next(playerData.inventorySlots) ~= nil then
            print("Inventory slots:")
            for k, v in pairs(playerData.inventorySlots) do
                -- Print clickable item text in chat
                local itemLink = select(2, GetItemInfo(v))

                if itemLink ~= nil then
                    print(k .. ": " .. itemLink)
                else
                    print(k .. ": " .. v)
                end
            end
        else
            print("Inventory slots: empty")
        end
    else
        print("Player not found")
    end
end

-- Get 10 most popular items in the database
local function top_items()
    -- Scan all players in the database adding their items to a table with count of occurences

    print("Printing top 10 most popular items:")

    local items = {} -- ID -> count

    for k, v in pairs(EyeOfWisdomDB.players) do
        for k2, v2 in pairs(v.inventorySlots) do
            if items[v2] == nil then
                items[v2] = 1
            else
                items[v2] = items[v2] + 1
            end
        end
    end

    -- Sort the table by count
    local sortedItems = {}
    for k, v in pairs(items) do
        table.insert(sortedItems, { id = k, count = v })
    end

    table.sort(sortedItems, function(a, b) return a.count > b.count end)

    -- Print the top 10 items
    for i = 1, 10 do
        local item = sortedItems[i]

        -- Print clickable item text in chat
        local itemLink = select(2, GetItemInfo(item.id))

        if itemLink ~= nil then
            print(itemLink .. " - " .. item.count)
        else
            print("Item not found:" .. item.id .. " - " .. item.count)
        end
    end
end

-- Top classes
local function top_classes()
    -- Scan all players in the database counting occurences of each class

    print("Printing top classes:")

    local classes = {} -- Class -> count

    for k, v in pairs(EyeOfWisdomDB.players) do
        if classes[v.class] == nil then
            classes[v.class] = 1
        else
            classes[v.class] = classes[v.class] + 1
        end
    end

    -- Sort the table by count
    local sortedClasses = {}
    for k, v in pairs(classes) do
        table.insert(sortedClasses, { class = k, count = v })
    end

    table.sort(sortedClasses, function(a, b) return a.count > b.count end)

    -- Print sorted classes
    for k, v in pairs(sortedClasses) do
        print(v.class .. " - " .. v.count)
    end
end

-- Print memory usage
local function memory_usage()
    UpdateAddOnMemoryUsage()
    local mem = GetAddOnMemoryUsage("EyeOfWisdom")
    print("Memory usage: " .. string.format("%.02f", mem) .. " KB")

    -- Total scanned players
    local count = 0
    for k, v in pairs(EyeOfWisdomDB.players) do
        count = count + 1
    end
    print("Scanned players: " .. count)
end


function EyeOfWisdomDBFrame:OnEvent(event, arg1)
    if event == "ADDON_LOADED" and arg1 == "EyeOfWisdom" then
        if EyeOfWisdomDB == nil then
            EyeOfWisdomDB = {}
        end
        if EyeOfWisdomDB.players == nil then
            EyeOfWisdomDB.players = {}
        end
        if EyeOfWisdomDB.settings == nil then
            EyeOfWisdomDB.settings = {}
            -- local s = EyeOfWisdomDB.settings
            -- if s.isEnabled == nil then s.isEnabled = false end
            -- if s.isVerbose == nil then s.isVerbose = true end

            -- Iterate over local settings and set them to default if they are nil in saved variables
            for k, v in pairs(settings) do
                if EyeOfWisdomDB.settings[k] == nil then
                    EyeOfWisdomDB.settings[k] = v
                end
            end
        end

        -- Override settings with saved variables
        settings = EyeOfWisdomDB.settings

        print("EyeOfWisdom loaded")
    elseif event == "PLAYER_LOGOUT" then
        -- EyeOfWisdomDB.players = scannedPlayers
    end
end

EyeOfWisdomDBFrame:SetScript("OnEvent", EyeOfWisdomDBFrame.OnEvent)

-- Chat commands handler e.g. /eow toggle
function EyeOfWisdomCmd(msg, editbox)
    local _, _, cmd, args = string.find(msg, "%s?(%w+)%s?(.*)")

    if cmd == "toggle" then
        toggle_addon()
    elseif cmd == "list" then
        list_scanned()
    elseif cmd == "cleardb" then
        EyeOfWisdomDB.players = {}
        print("EyeOfWisdom database cleared")
    elseif cmd == "show" then
        print("Unimplemented yet") -- TODO
    elseif cmd == "debug" then
        -- Toggle debug frame
        if EOWDebugFrame:IsShown() then
            print("EyeOfWisdom debug frame hidden")
            EOWDebugFrame:Hide()
        else
            print("EyeOfWisdom debug frame shown")
            EOWDebugFrame:Show()
        end
    elseif cmd == "get" then
        local name = args
        if name == nil then
            print("Please specify a player name")
        else
            get_player(name)
        end
    elseif cmd == "topitems" then
        top_items()
    elseif cmd == "mem" then
        memory_usage()
    elseif cmd == "verbose" then
        toggle_verbose()
    elseif cmd == "topclasses" then
        top_classes()
    else
        print("EyeOfWisdom commands:")
        print("/eow toggle - Toggle the addon")
        print("/eow list - List all scanned players")
        print("/eow cleardb - Clear the database")
        print("/eow show - Show the list of scanned players")
        print("/eow debug - Show the debug frame")
        print("/eow get <name> - Get player data")
        print("/eow topitems - Get top 10 most popular items")
        print("/eow mem - Get memory usage")
        print("/eow verbose - Toggle verbose mode")
        print("/eow topclasses - Get top classes")
    end
end

SLASH_EOW1 = "/eow"
SLASH_EOW2 = "/eyeofwisdom"
SlashCmdList["EOW"] = EyeOfWisdomCmd
