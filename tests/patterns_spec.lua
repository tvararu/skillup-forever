-- Run from the repository root: luajit tests/patterns_spec.lua
-- The Patterns page's list: every recipe of a profession, where each is learnt, and what is queued.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local LEATHERWORKING = 165
local BOOTS, PANTS = 2149, 2153
local BELT, GLOVES, JERKIN = 1255138, 1255126, 1301457
local NIGHTCLAW = 2758

local c = Client.load({ auctionator = false })
c.level = 60
c.professions = { { name = "Leatherworking", id = LEATHERWORKING, rank = 1, max = 150 } }
c.known[BOOTS] = true
local standing = 4
c.G.GetFactionInfoByID = function(factionID)
	if factionID == NIGHTCLAW then
		return "Nightclaw Druids", "", standing
	end
end
local ns = c.ns

local function Leatherworking(skill)
	return {
		skillLine = LEATHERWORKING,
		name = "Leatherworking",
		base = skill,
		modifier = 0,
		skill = skill,
		max = 150,
	}
end

local function Find(entries, recipeID)
	for _, entry in ipairs(entries) do
		if entry.recipeID == recipeID then
			return entry
		end
	end
end

local entries = ns.Patterns(Leatherworking(70))
equal(#entries > 100, true, "every Leatherworking recipe is listed")
for index = 2, #entries do
	assert(entries[index - 1].skill <= entries[index].skill, "the list is in learn-skill order")
end
local boots, belt, gloves, jerkin = Find(entries, BOOTS), Find(entries, BELT), Find(entries, GLOVES), Find(entries, JERKIN)
equal(boots.state, "known", "a learned recipe is known")
equal(boots.source, "basic", "one taught with the profession is basic")
equal(Find(entries, PANTS).source, "trainer", "a trainer's recipe says so")
equal(belt.source, "favor", "a Merchant's Favor pattern says so")
equal(belt.favor, 30, "with its Favor price")
equal(belt.bop, true, "and that what it makes binds on pickup")
equal(belt.skill, 60, "it is learnt at 60")
equal(belt.state, "learnable", "and can be learnt at 70")
equal(gloves.state, "missing", "a pattern learnt at 75 cannot be at 70")
equal(jerkin.source, "rep", "a reputation pattern says so")
equal(jerkin.state, "missing", "and cannot be learnt below the standing it asks")
standing = 5
equal(Find(ns.Patterns(Leatherworking(70)), JERKIN).state, "learnable", "it can once that standing is reached")

local function Ids(list)
	local ids = {}
	for _, entry in ipairs(list) do
		ids[entry.recipeID] = true
	end
	return ids
end
local known = Ids(ns.FilterPatterns(entries, { show = "known" }))
equal(known[BOOTS] and not known[BELT], true, "the known filter keeps learned recipes only")
local learnable = Ids(ns.FilterPatterns(entries, { show = "learnable" }))
equal(learnable[BELT] and not learnable[GLOVES] and not learnable[BOOTS], true, "learnable now is neither known nor ahead")
local missing = Ids(ns.FilterPatterns(entries, { show = "missing" }))
equal(missing[GLOVES] and missing[BELT] and not missing[BOOTS], true, "missing is every recipe not learned")
local favor = Ids(ns.FilterPatterns(entries, { source = "favor" }))
equal(favor[BELT] and not favor[BOOTS], true, "a source filter keeps that source only")
local found = ns.FilterPatterns(entries, { search = "stormrider" })
equal(#found, 9, "a search matches names, ignoring case")

local set = ns.PatternSet(Leatherworking(70), BELT)
equal(#set, 9, "the Stormrider's set is the nine Stormrider's recipes")
equal(ns.PatternSet(Leatherworking(70), BOOTS), nil, "a recipe with no set name has no set")
ns.QueueSet(Leatherworking(70), BELT)
equal(#ns.QueuedCrafts(LEATHERWORKING), 9, "queueing a set queues one of each")
equal(Find(ns.Patterns(Leatherworking(70)), GLOVES).queued, 1, "and the list shows what is queued")

Client.report("patterns_spec")
