--[[
Copyright 2023 Yazpad
The Deathlog AddOn is distributed under the terms of the GNU General Public License (or the Lesser GPL).
This file is part of Deathlog.

The Deathlog AddOn is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The Deathlog AddOn is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with the Deathlog AddOn. If not, see <http://www.gnu.org/licenses/>.
--]]
local addonName, ns = ...

-- Entry: (event_id, player, time, faction)
ns.distributed_log = ns.lru.new(100)

local last_attack_source = nil
local recent_msg = nil
local general_stats = {}
local log_normal_params = {}
local most_deadly_units = {
	["all"] = { -- server
		["all"] = { -- map_id
			["all"] = {}, -- class_id
		},
	},
}

local most_deadly_units_normalized = {
	["all"] = { -- server
		["all"] = { -- map_id
			["all"] = {}, -- class_id
		},
	},
}

deathlog_data = deathlog_data or {}
deathlog_data_map = deathlog_data_map or {}
deathlog_settings = deathlog_settings or {}

local deathlog_minimap_button_stub = nil
local deathlog_minimap_button_info = {}
local deathlog_minimap_button = LibStub("LibDataBroker-1.1"):NewDataObject(addonName, {
	type = "data source",
	text = addonName,
	icon = "Interface\\TARGETINGFRAME\\UI-TargetingFrame-Skull",
	OnClick = function(self, btn)
		if btn == "LeftButton" then
			deathlogShowMenu(deathlog_data, general_stats, log_normal_params)
		else
			InterfaceAddOnsList_Update()
			InterfaceOptionsFrame_OpenToCategory(addonName)
		end
	end,
	OnTooltipShow = function(tooltip)
		tooltip:AddLine(addonName)
		tooltip:AddLine(Deathlog_L.minimap_btn_left_click)
		tooltip:AddLine(Deathlog_L.minimap_btn_right_click .. GAMEOPTIONS_MENU)
	end,
})
local function initMinimapButton()
	deathlog_minimap_button_stub = LibStub("LibDBIcon-1.0", true)
	if deathlog_minimap_button_stub:IsRegistered("Deathlog") then
		return
	end
	deathlog_minimap_button_stub:Register("Deathlog", deathlog_minimap_button, deathlog_minimap_button_info)

	if deathlog_settings["show_minimap"] ~= nil and deathlog_settings["show_minimap"] == false then
		deathlog_minimap_button_stub:Hide("Deathlog")
	end
end

function Deathlog_LoadFromHardcore()
	if Hardcore_Settings and Hardcore_Settings["death_log_entries"] then
		print("Retrieving deathlog entries...")
		local c = 0
		local new_entries = 0
		if deathlog_data == nil or deathlog_data["legacy"] == nil then
			deathlog_data["legacy"] = {}
		end
		local local_deathlog_fletcher16 = deathlog_fletcher16
		for _, v in ipairs(Hardcore_Settings["death_log_entries"]) do
			c = c + 1
			local checksum = local_deathlog_fletcher16(v["name"], v["guild"], v["level"], v["source_id"])
			local converted_date = deathlogConvertStringDateUnix(v["date"])
			if converted_date then
				if deathlog_data["legacy"][checksum] == nil then
					new_entries = new_entries + 1
				end
				deathlog_data["legacy"][checksum] = {
					["class_id"] = v["class_id"],
					["guild"] = v["guild"],
					["date"] = converted_date,
					["map_pos"] = v["map_pos"],
					["source_id"] = v["source_id"],
					["name"] = v["name"],
					["race_id"] = v["race_id"],
					["level"] = v["level"],
					["map_id"] = v["map_id"],
					["instance_id"] = v["instance_id"],
					["last_words"] = v["last_words"],
				}
			else
				print("failed")
			end
		end
		print("Complete. New entries: " .. new_entries .. ". Scanned: " .. c)
	end
end

local function handleEvent(self, event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		initMinimapButton()
		most_deadly_units["all"]["all"]["all"] = deathlogGetOrdered(general_stats, { "all", "all", "all", nil })
	end
end

local function SlashHandler(msg, editbox)
	if msg == "option" or msg == "options" then
		InterfaceOptionsFrame_Show()
		InterfaceOptionsFrame_OpenToCategory("Deathlog")
	elseif msg == "alert" then
		Deathlog_DeathAlertFakeDeath()
	else
		deathlogShowMenu(deathlog_data, general_stats, log_normal_params)
	end
end

SLASH_DEATHLOG1, SLASH_DEATHLOG2 = "/deathlog", "/dl"
SlashCmdList["DEATHLOG"] = SlashHandler

local deathlog_event_handler = CreateFrame("Frame", "deathlog", nil, "BackdropTemplate")
deathlog_event_handler:RegisterEvent("PLAYER_ENTERING_WORLD")

deathlog_event_handler:SetScript("OnEvent", handleEvent)

local LSM30 = LibStub("LibSharedMedia-3.0", true)
local options = {
	name = "Deathlog",
	handler = Hardcore,
	type = "group",
	args = {
		load_from_hc = {
			type = "execute",
			name = "Import deathlog from hardcore",
			desc = "Import deathlog from hardcore. This will append entries.",
			width = 1.3,
			func = function()
				Deathlog_LoadFromHardcore()
			end,
		},
		clear_cache_button = {
			type = "execute",
			name = "Clear cache",
			desc = "WARNING: This will remove deathlog data.  Do this if your log is getting too long.  The data is stored at _classic_era_/WTF/Account/<your_account_name>/SavedVariables/Deathlog.lua.  Reload after doing this.",
			width = 1.3,
			func = function()
				deathlog_data = {}
				deathlog_data_map = {}
			end,
		},
		require_validation = {
			type = "toggle",
			name = "Allow guildless death logging",
			desc = "Toggle guildless death logging.  Guild-based death logging requires validation from guildmates to validate.  Guildless logging allows deaths to get logged without being validated.",
			width = 1.3,
			get = function()
				if deathlog_settings["deathless_logging"] == nil then
					deathlog_settings["deathless_logging"] = true
				end
				return deathlog_settings["deathless_logging"]
			end,
			set = function()
				deathlog_settings["deathless_logging"] = not deathlog_settings["deathless_logging"]
			end,
		},
		show_minimap_button = {
			type = "toggle",
			name = "Show minimap button",
			desc = "Toggles whether the minimap is visible.",
			width = 1.3,
			get = function()
				if deathlog_settings["show_minimap"] == nil then
					deathlog_settings["show_minimap"] = true
				end
				return deathlog_settings["show_minimap"]
			end,
			set = function()
				deathlog_settings["show_minimap"] = not deathlog_settings["show_minimap"]

				if deathlog_settings["show_minimap"] then
					deathlog_minimap_button_stub:Show("Deathlog")
				else
					deathlog_minimap_button_stub:Hide("Deathlog")
				end
			end,
		},
		colored_tooltips = {
			type = "toggle",
			name = "Colored tooltips",
			desc = "Toggles whether tooltips have colored fields.",
			width = 1.3,
			get = function()
				if deathlog_settings["colored_tooltips"] == nil then
					deathlog_settings["colored_tooltips"] = false
				end
				return deathlog_settings["colored_tooltips"]
			end,
			set = function()
				deathlog_settings["colored_tooltips"] = not deathlog_settings["colored_tooltips"]
			end,
		},
	},
}

LibStub("AceConfig-3.0"):RegisterOptionsTable("Deathlog", options)
optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Deathlog", "Deathlog", nil)
