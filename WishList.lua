SLASH_WISHLIST1 = "/wishlist"
SLASH_WISHLIST2 = "/wl"
local _, ns = ...
local AceComm = LibStub("AceComm-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")

local BROADCAST_INTERVAL = 30
local EXPIRE_SECONDS = 60 * 60 * 24 * 4 -- 4 days
local DEFAULT_LAST_UPDATE = 1735160400 -- Wednesday 12/25 @ 4pm eastern, expires after sunday 12/19 meeting

local WishListFrame = CreateFrame("Frame", "WishListFrame")
local prefix = "WishList"

local localPlayerNeeds = {}
local guildNeeds = {}
local needersByItem = {}

local debug = true
local isShiftPressed = false

local function prettyPrint(msg)
    print("|cffffff00[WishList]|r " .. msg)
end

local function debugPrint(msg)
    if debug then
        prettyPrint("|cff40ff40[Debug]|r " .. msg)
    end
end

local function sendAddonMessage(msg)
    if prefix then
        local msgChannel = "GUILD"
        AceComm:SendCommMessage(prefix, msg, msgChannel)
    end
end

local function broadcast() 
    local serialized = AceSerializer:Serialize(localPlayerNeeds)
    sendAddonMessage(serialized)
end

local function removeExpired(wishlist)
    local t = GetServerTime()
    for k, v in pairs(wishlist) do
        if not v.lastUpdate then
            v.lastUpdate = DEFAULT_LAST_UPDATE
        end
        if t - v.lastUpdate > EXPIRE_SECONDS then
            wishlist[k] = nil
        end
    end
end

local function renewLocalPlayerNeeds()
    local t = GetServerTime()
    for k, v in pairs(localPlayerNeeds) do
        if v then 
            v.lastUpdate = t
        end
    end
end

local function rebuildNeedersByItem()
    needersByItem = {}
    for name, v in pairs(guildNeeds) do
        removeExpired(v)
        for k, item in pairs(v) do
            local needers = needersByItem[string.upper(k)] or {}
            needers[name] = true
            needersByItem[string.upper(k)] = needers
        end
    end
end

local function processMessage(prefix, msg, channel, from)
    local success, deserialized = AceSerializer:Deserialize(msg)
    if success then

        local priorNeeds = guildNeeds[from]

        if next(deserialized) == nil then
            guildNeeds[from] = nil
        else
            -- expire old wishlist items
            removeExpired(deserialized)
            guildNeeds[from] = deserialized
        end

        -- Populate needersByItem
        for k, v in pairs(deserialized) do
            local needers = needersByItem[string.upper(k)] or {}
            needers[from] = true
            needersByItem[string.upper(k)] = needers
        end

        -- check for removed items from wishlist
        if priorNeeds then
            for k, v in pairs(priorNeeds) do
                if not deserialized[k] then
                    local needers = needersByItem[string.upper(k)] or {}
                    needers[from] = nil
                    needersByItem[string.upper(k)] = needers
                end
            end
        end
    else
--        prettyPrint("Couldn't deserialize message")
    end
end

local function getNeeders(itemName)
    return needersByItem[string.upper(itemName)] or {}
end

local function addItem(itemName)
    local t = GetServerTime()
    localPlayerNeeds[string.upper(itemName)] = {itemName = itemName, lastUpdate = t}
end

local function removeItem(itemName)
    localPlayerNeeds[string.upper(itemName)] = nil
end

local function clearItems()
    localPlayerNeeds = {}
end

local function allExpired(wishlist)
    local t = GetServerTime()
    local count = 0
    for k, v in pairs(wishlist) do
        count = count + 1
        if v and v.lastUpdate and t - v.lastUpdate < EXPIRE_SECONDS then
            return false
        end
    end
    return count > 0
end

local ticker
local function OnEvent(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        local isLogin, isReload = ...
        if isLogin or isReload then
            AceComm:RegisterComm(prefix, processMessage)
            broadcast()
            ticker = C_Timer.NewTicker(BROADCAST_INTERVAL, function() 
                broadcast()
            end)
        end
    elseif event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "OnlyFangs" then
            if not WishList_Saved then
                WishList_Saved = {}
            end
            localPlayerNeeds = WishList_Saved.localPlayerNeeds or {}
            guildNeeds = WishList_Saved.guildNeeds or {}
            rebuildNeedersByItem()
            C_Timer.After(5, function()
                if allExpired(localPlayerNeeds) then
                    prettyPrint("All the items on your wishlist have expired. Modify your wishlist or type |cff00ff00/wl renew|r to refresh.")
                end
            end)
        end
    elseif event == "PLAYER_LOGOUT" then
        WishList_Saved = {}
        WishList_Saved.localPlayerNeeds = localPlayerNeeds
        WishList_Saved.guildNeeds = guildNeeds
    elseif event == "MODIFIER_STATE_CHANGED" then
        key, down = ...
        isShiftPressed = (key == "LSHIFT" or key == "RSHIFT") and down == 1
    end
end



WishListFrame:RegisterEvent("CHAT_MSG_ADDON")
WishListFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
WishListFrame:RegisterEvent("ADDON_LOADED")
WishListFrame:RegisterEvent("PLAYER_LOGOUT")
WishListFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
WishListFrame:SetScript("OnEvent", OnEvent)
WishListFrame:SetScript("OnUpdate", OnUpdate)

WishList = {}
function WishList:SetFromText(text)
    clearItems()
    for token in string.gmatch(text, "[^\r\n]+") do
        if string.len(token) > 0 then
            addItem(token)
        end
    end
    broadcast()
end

function WishList:GetText()
    local text = ""
    for k, v in pairs(localPlayerNeeds) do
        text = text .. v.itemName .. "\n"
    end
    return text
end

function WishList:WhoNeeds(text)
    return getNeeders(text)
end

function WishList:ListAll()
    prettyPrint("All wish lists:")
    for k, v in pairs(guildNeeds) do
        print(k)
        for _, item in pairs(v) do
            print(" - " .. item.itemName)
        end
    end
end

function WishList:Rebuild()
    rebuildNeedersByItem()
end

function WishList:ListForCharacter(name)
    local list = guildNeeds[name]
    return list or {}
end

function WishList:Renew()
    renewLocalPlayerNeeds()
    broadcast()
end

local function SlashCommandHandler(msg)
    if string.sub(msg, 1, 4) == "add " then
        local item = string.sub(msg, 5)
        if string.len(item) > 0 then
            addItem(item)
            prettyPrint("Added '" .. item .. "' to needed items")
        end        
        broadcast()
    elseif string.sub(msg, 1, 7) == "remove " then
        local item = string.sub(msg, 8)
        if string.len(item) > 0 then
            removeItem(item)
            prettyPrint("Removed '" .. item .. "' from needed items")
        end
        broadcast()
    elseif string.sub(msg, 1, 5) == "clear" then
        clearItems()
        broadcast()
        prettyPrint("Cleared your list of needed items")
    elseif string.sub(msg, 1, 7) == "listall" then
        WishList:ListAll()
    elseif string.sub(msg, 1, 4) == "list" then
        prettyPrint("Needed items:")
        for k, v in pairs(localPlayerNeeds) do
            print(" - " .. v.itemName)
        end
    elseif string.sub(msg, 1, 9) == "whoneeds " then
        local item = string.sub(msg, 10)
        if string.len(item) > 0 then
            prettyPrint("Needers for '" .. item .. "':")
            local needers = getNeeders(item)
            local i = 0
            for k, v in pairs(needers) do
                i = i + 1
                print(" - " .. k)
            end

            if i == 0 then
                print("No needers for '" .. item .. "'.")
            end
        end
    elseif string.sub(msg, 1, 4) == "help" then
        prettyPrint("Available commands:")
        print("|cffffff00/wl help|r print this message")
        print("|cffffff00/wl add itemName|r add itemName to your list of needed items")
        print("|cffffff00/wl remove itemName|r remove itemName from your list of needed items")
        print("|cffffff00/wl clear|r remove all items from your list of needed items")
        print("|cffffff00/wl list|r print your list of needed items")
        print("|cffffff00/wl whoneeds itemName|r print a list of guild members that need itemName")
    elseif string.sub(msg, 1, 5) == "renew" then
        WishList:Renew()
        prettyPrint("Wishlist item experations reset.")
    else
        prettyPrint("Unrecognized command: " .. msg)
    end
end

GameTooltip:HookScript("OnTooltipSetItem", function(tooltip, ...)
    local name = tooltip:GetItem()
    --Add the name and path of the item's texture
    if not name then return end
    local needers = getNeeders(name)
    local count = 0
    for k,v in pairs(needers) do count = count + 1 end

    local max = 5
    if count >= 1 then
        tooltip:AddLine("|cffff4040<OF>|r |cffffff00Needed By:|r")
        local i = 0
        for k, v in pairs(needers) do
            i = i + 1
            if i < max or count == max or isShiftPressed then
            	local _race_icon = ""
            	if OnlyFangsRaceInWishList and OnlyFangsRaceInWishList == 1 then _race_icon = ns.getRaceIconString(k) end
                tooltip:AddLine("  " .. _race_icon .. "|cff3ce13f" .. k .. "|r")
            else
                local extra = count - max + 1
                tooltip:AddLine("  |cffbbbbbb+ " .. tostring(extra) .. " more (hold shift)|r")
                break
            end
        end
        --Repaint tooltip with newly added lines
        tooltip:Show()
    end
  end)

SlashCmdList["WISHLIST"] = SlashCommandHandler
