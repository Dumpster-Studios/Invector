-- Invector, License MIT, Author Jordach
invector.karts = {}

function invector.functions.register_kart(name, def)
    invector.karts[name] = def
    minetest.register_entity("invector:"..name, def)
end

-- This is fixed in code due to this not being a multiplayer release.
minetest.register_on_joinplayer(function(player)
	solarsail.player.set_model(player, "invector:sam2", {x=0, y=159}, 60,
			invector.karts.sam2._geo, invector.karts.sam2._geo3r, "",
            invector.karts.sam2._prel, invector.karts.sam2._prot)
end)