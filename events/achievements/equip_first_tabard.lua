local addonName, ns = ...

local _event = CreateFrame("Frame")
ns.event["EquipFirstTabard"] = _event

-- General info
_event.name = "EquipFirstTabard"
_event.type = "Achievement"
_event.subtype = "GeneralAchievement"
_event.title = "Equip your Guild Tabard"
_event.icon_path = ""
_event.pts = 1
_event.description = "|cffddddddEquip your first guild tabard.|r"

-- Aggregation
_event.aggregrate = function(distributed_log, event_log)
	local race_name = ns.id_race[event_log[2]]
	distributed_log.points[race_name] = distributed_log.points[race_name] + _event.pts
end

-- Register Definitions
local sent = false
local _equip_first_rare_event_handler = CreateFrame("Frame")
_equip_first_rare_event_handler:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
_equip_first_rare_event_handler:SetScript("OnEvent", function(self, e, slot, filled)
	if sent == true then
		return
	end

	if filled == false then
		local _item_id = GetInventoryItemID("player", slot)
		if _item_id == 5976 then
			ns.triggerEvent(_event.name)
			sent = true
		end
	end
end)
