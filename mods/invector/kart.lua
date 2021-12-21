-- Invector, License MIT, Author Jordach
invector.karts = {}

function invector.functions.register_kart(name, def)
	invector.karts[name] = def
	minetest.register_entity("invector:"..name, def)
end