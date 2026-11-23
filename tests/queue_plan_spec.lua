-- Run from the repository root: luajit tests/queue_plan_spec.lua
-- Queued crafts: the route makes a set of patterns on the way to its target, and shops for them.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local LEATHERWORKING = 165
local LIGHT_LEATHER, COARSE_LEATHER, COARSE_THREAD, FINE_THREAD, CURED_LIGHT_HIDE = 2318, 2319, 2320, 2321, 4231
local KNOWN = { 2149, 2153, 2158, 2159, 2160, 2166 }
local BELT, GLOVES, BOOTS = 1255138, 1255126, 1255117
local BELT_PATTERN, GLOVES_PATTERN, BOOTS_PATTERN = 252769, 252781, 252790
local SET_REAGENT = 249427

local c = Client.load({ auctionator = false })
c.level = 60
c.player.faction = "Alliance"
c.professions = { { name = "Leatherworking", id = LEATHERWORKING, rank = 1, max = 150 } }
for _, recipeID in ipairs(KNOWN) do
	c.known[recipeID] = true
end
for itemID, price in pairs({
	[LIGHT_LEATHER] = 20,
	[COARSE_LEATHER] = 1,
	[COARSE_THREAD] = 1,
	[FINE_THREAD] = 1,
	[CURED_LIGHT_HIDE] = 1,
	[249409] = 5,
	[SET_REAGENT] = 7,
	[BELT_PATTERN] = 300,
	[GLOVES_PATTERN] = 400,
}) do
	c.ns.db.vendor[itemID] = price
end
c.ns.Changed("prices")
local ns = c.ns

local function Leatherworking()
	return { skillLine = LEATHERWORKING, name = "Leatherworking", base = 35, modifier = 0, skill = 35, max = 150 }
end

local function Plan(target)
	ns.db.routeTargets[LEATHERWORKING] = target
	ns.Changed("target")
	return ns.PlanRoute(Leatherworking())
end

local function Fixed(plan, recipeID)
	for _, craft in ipairs(plan.crafts) do
		if craft.fixed and craft.recipeID == recipeID then
			return craft
		end
	end
end

local function Trained(plan, recipeID)
	for _, step in ipairs(plan.training) do
		if step.recipeID == recipeID then
			return step
		end
	end
end

local plain = Plan(100)
equal(Fixed(plain, BELT), nil, "nothing is queued")

ns.QueueCraft(BELT, 1)
ns.QueueCraft(GLOVES, 2)
local plan = Plan(100)
local belt, gloves = Fixed(plan, BELT), Fixed(plan, GLOVES)
equal(belt and belt.crafts, 1, "the belt is made once")
equal(gloves and gloves.crafts, 2, "the gloves twice")
equal(belt.from, 60, "the belt where its pattern can first be used")
equal(gloves.from >= 75, true, "the gloves no earlier than theirs")
equal(plan.reached, 100, "the route still reaches its target")
equal(Trained(plan, BELT) and Trained(plan, BELT).fee, 300, "the belt pattern is bought")
equal(Trained(plan, GLOVES) and Trained(plan, GLOVES).fee, 400, "the gloves pattern is bought")
equal(plan.cost > plain.cost, true, "the queue costs more than the plain route")
equal(#plan.queued, 2, "the plan lists the queue")
equal(plan.queued[1].placed, true, "the belt was placed")
equal(plan.queued[1].at, 60, "where it was placed, in base skill")

local reagent
for _, item in ipairs(ns.RouteReagents(plan)) do
	if item.itemID == SET_REAGENT then
		reagent = item
	end
end
-- Belt 2, gloves 2 each: 2 + 2 * 2.
equal(reagent and reagent.need, 6, "the shopping list carries the queued crafts' reagents")

ns.QueueCraft(BOOTS, 1)
local raised = Plan(80)
equal(raised.target, 85, "a queued pattern learnt past the target raises it")
equal(raised.queued[3].placed, true, "and is made there")
equal(Fixed(raised, BOOTS) ~= nil, true, "the boots are on the route")
equal(Trained(raised, BOOTS) ~= nil, true, "a pattern with no seen price is still learnt")
equal(raised.queued[3].unpriced, true, "and is flagged as unpriced")

-- A grey queued craft gains nothing but is still a step the route can walk.
equal(ns.RouteFollowable(raised), true, "a route with queued crafts can be followed")
Plan(80)
ns.Changed("prices")
local again = Plan(80)
equal(Fixed(again, BOOTS) and Fixed(again, BOOTS).crafts, 1, "a followed route keeps the queued count")

ns.ClearQueue()
equal(Fixed(Plan(100), BELT), nil, "clearing the queue replans without it")

Client.report("queue_plan_spec")
