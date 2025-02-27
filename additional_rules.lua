local addonName, ns = ...
local rule_event_handler = nil
rule_event_handler = CreateFrame("frame")

local REALM_NAME = GetRealmName()
REALM_NAME = REALM_NAME:gsub("%s+", "")

local mail_button = {}

local in_guild = function(_n)
	if OnlyFangsStreamerMap[_n .. "-" .. REALM_NAME] ~= nil then
		return true
	end
	for g_idx = 1, GetNumGuildMembers() do
		member_name, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ = GetGuildRosterInfo(g_idx)
		local player_name_short = string.split("-", member_name)
		if player_name_short == _n then
			return true
		end
	end
	return false
end

local on_mail_show = function()
	if CanEditOfficerNote() == false then
		C_Timer.NewTicker(0.2, function(self)
			if _G["MailFrame"]:IsVisible() == false then
				self:Cancel()
			end
			for i = 1, 7 do
				local _, _, _name = GetInboxHeaderInfo(i)
				if _name == nil or in_guild(_name) then
					_G["MailItem" .. tostring(i)]:SetAlpha(1.0)
					_G["MailItem" .. tostring(i)]:EnableMouse(1)
					_G["MailItem" .. tostring(i) .. "Button"]:Enable()
				else
					-- print("Returning mail from: ", _name)
					ReturnInboxItem(i)
					return
				end
			end
		end)
	else
		print("Officer's mail is not blocked.")
	end
end

rule_event_handler:RegisterEvent("MAIL_SHOW")
rule_event_handler:RegisterEvent("MAIL_INBOX_UPDATE")
rule_event_handler:RegisterEvent("AUCTION_HOUSE_SHOW")

rule_event_handler:SetScript("OnEvent", function(self, event, ...)
	if event == "MAIL_SHOW" or event == "MAIL_INBOX_UPDATE" then
		on_mail_show()
	elseif event == "AUCTION_HOUSE_SHOW" then
		if CanEditOfficerNote() == false then
			CloseAuctionHouse()
			print("|cFFFF0000[OnlyFangs] BLOCKED:|r You may not trade outside of the guild.")
		end
	end
end)

local function notReceivingItems()
	local _money = GetTargetTradeMoney()
	if _money ~= 0 then
		print("|cFFFF0000[OnlyFangs] BLOCKED:|r You may not receive gold from outside of the guild.")
		return false
	end
	for i = 1, 6 do
		local _item_name, texture, quantity, quality, isUsable, enchant = GetTradeTargetItemInfo(i)
		if _item_name then
			print("|cFFFF0000[OnlyFangs] BLOCKED:|r You may not receive items from outside of the guild.")
			return false
		end
	end

	local _item_name, texture, quantity, quality, isUsable, enchant = GetTradePlayerItemInfo(7)
	if _item_name then
		print("|cFFFF0000[OnlyFangs] BLOCKED:|r You may not receive enchants from outside of the guild.")
		return false
	end
	return true
end

TradeFrameTradeButton:SetScript("OnClick", function()
	local target_trader = TradeFrameRecipientNameText:GetText()
	if in_guild(target_trader) or notReceivingItems() or CanEditOfficerNote() then
		AcceptTrade()
	else
		print("|cFFFF0000[OnlyFangs] BLOCKED:|r You may not trade outside of the guild.")
	end
end)

-- local handler = CreateFrame("frame")
-- handler:RegisterEvent("UNIT_TARGET")
--
-- handler:SetScript("OnEvent", function(self, event, ...)
-- 	print(in_guild(UnitName("target")))
-- end)

C_Timer.NewTicker(60, function(self)
	for i = 1, 40 do
		local buff_name, _, _, _, _, _, _, _, _, _, _ = UnitBuff("player", i)
		if buff_name == nil then
			return
		end
		if buff_name == "Spirit of Zandalar" then
			CancelUnitBuff("player", i)
			print("OnlyFangs: Removing buff " .. buff_name .. ".")
		end
	end
end)
