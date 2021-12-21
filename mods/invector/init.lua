-- Invector, License MIT, Author Jordach

-- Disable the hand if in survival mode or play game mode, while
-- creative mode acts as the built in track editor
if not minetest.settings:get_bool("creative_mode") then
	minetest.override_item("", {
		wield_scale = {x=1,y=1,z=1},
		wield_image = "transparent.png",
		range = 1,
		tool_capabilities = {
			full_punch_interval = 1,
			max_drop_level = 0,
			groupcaps = {},
			damage_groups = {},
		}
	})
else
	minetest.override_item("", {
		wield_scale = {x=1,y=1,z=1},
		range = 5,
		tool_capabilities = {
			full_punch_interval = 1,
			max_drop_level = 0,
			groupcaps = {
				debug = {times={[1]=0.125,[2]=0.125/2,[3]=0.125/4}, uses=0},
				invector = {times={[1]=0.125,[2]=0.125/2,[3]=0.125/4}, uses=0},
			},
			damage_groups = {},
		}
	})

	-- Unlimited node placement
	minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack)
		if placer and placer:is_player() then
			return minetest.is_creative_enabled(placer:get_player_name())
		end
	end)

	function minetest.handle_node_drops(pos, drops, digger)
		local inv = digger:get_inventory()
		if inv then
			for _, item in ipairs(drops) do
				if not inv:contains_item("main", item, true) then
					inv:add_item("main", item)
				end
			end
		end
	end
end

invector = {}
invector.functions = {}

invector.path = minetest.get_modpath("invector")

local function exec(file)
	dofile(invector.path.."/"..file..".lua")
end

exec("ai")
exec("blocks")
exec("eternity_blocks")
exec("item")
exec("game")
exec("kart")
exec("karts/kart")
exec("tracks/test_track")