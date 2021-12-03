-- SolarSail Engine Control Handler:
-- Author: Jordach
-- License: Reserved

--[[ solarsail.controls.focus[player_name]
	Valid values, should be read only (but set by a authoritive script):

	"talk" all controls are used to handle talking to NPCs, ie dialog options
	"world" all controls are used to control the player when in the world
	"menu" all controls are used to change the cursor in a menu
	"battle" all controls are used to handle battle, behaves like "menu"
	"cutscene" all controls aren't used, but pressing jump can skip things

--]]
solarsail.controls.focus = {}

--[[ solarsail.controls.player[player_name]
	Read only:
	Gets the player:get_player_control() result for [player_name]
]]--
solarsail.controls.player = {}

local function update_controls()
	for _, player in ipairs(minetest.get_connected_players()) do
		solarsail.controls.player[player:get_player_name()] = player:get_player_control()
	end
	minetest.after(0.03, update_controls)
end

minetest.register_on_joinplayer(function(player)
	solarsail.controls.focus[player:get_player_name()] = "world"
end)

minetest.after(0.03, update_controls)