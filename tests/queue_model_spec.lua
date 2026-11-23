-- Run from the repository root: luajit tests/queue_model_spec.lua
local ns = {}
assert(loadfile("Core/Model.lua"))("SkillUpForever", ns)
local Model = ns.Model
local checks = 0

local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local orange = { 50, 70, 80, 90 }
equal(Model.PointsFromCrafts(orange, 50, 5, 1), 5, "orange crafts each gain a point")
equal(Model.PointsFromCrafts(orange, 50, 5, 2), 10, "orange crafts gain their skill-ups")
equal(Model.PointsFromCrafts(orange, 90, 5, 1), 0, "grey crafts gain nothing")
equal(Model.PointsFromCrafts({ 50, 90, 90, 90 }, 88, 5, 1), 2, "crafts stop gaining at grey")
equal(Model.PointsFromCrafts(orange, 50, 0, 1), 0, "no crafts gain nothing")

local yellow = { 1, 10, 15, 20 }
local points = Model.PointsFromCrafts(yellow, 10, 10, 1)
equal(points > 0 and points < 10, true, "yellow crafts gain fewer points than crafts")
equal(
	Model.CompletionChance(yellow, 10, 10 + points, 1, 10) >= Model.ROUTE_CONFIDENCE,
	true,
	"the points are reached at the route's confidence"
)
equal(
	Model.CompletionChance(yellow, 10, 10 + points + 1, 1, 10) < Model.ROUTE_CONFIDENCE,
	true,
	"one more point is not"
)

local cheap = { recipeID = 1, thresholds = { 1, 100, 120, 140 }, netCost = 10, reagentCost = 10 }
local set = { recipeID = 2, thresholds = { 30, 50, 60, 70 }, netCost = 500, reagentCost = 500 }
local snapshot = {
	skill = 1,
	target = 60,
	recipes = { cheap, set },
	queue = { { recipeID = 2, count = 3, learnAt = 30, candidate = set } },
}
local route = Model.PlanRoute(snapshot)
local fixed
for _, segment in ipairs(route.segments) do
	if segment.fixed then
		fixed = segment
	end
end
equal(fixed and fixed.recipeID, 2, "the queued recipe is on the route")
equal(fixed.fromSkill, 30, "it is crafted where it is first learnable")
equal(fixed.toSkill, 33, "its orange crafts count towards the target")
equal(fixed.crafts, 3, "it is crafted exactly as many times as queued")
equal(route.reachedSkill, 60, "the cheap recipe fills the rest")
equal(route.segments[1].recipeID, 1, "the cheap recipe leads up to it")
equal(route.segments[#route.segments].recipeID, 1, "and carries on after it")
equal(route.queued[1].placed, true, "the queue says where it went")
equal(route.queued[1].atSkill, 30, "at its learn skill")

local plain = Model.PlanRoute({ skill = 1, target = 60, recipes = { cheap, set } })
equal(route.expectedCost > plain.expectedCost, true, "queued crafts add their cost")

snapshot.queue[1].learnAt = 80
snapshot.target = 60
route = Model.PlanRoute(snapshot)
equal(route.queued[1].placed, false, "a recipe learnt past where the route ends is not placed")

local grey = { recipeID = 3, thresholds = { 1, 5, 8, 10 }, netCost = 5, reagentCost = 5 }
snapshot.queue = { { recipeID = 3, count = 2, learnAt = 1, candidate = grey } }
snapshot.skill = 20
route = Model.PlanRoute(snapshot)
equal(route.segments[1].recipeID, 3, "a grey queued recipe is still crafted")
equal(route.segments[1].crafts, 2, "for its queued count")
equal(route.segments[1].toSkill, 20, "gaining nothing")

local service = { recipeID = 4, thresholds = { 30, 50, 60, 70 }, netCost = 900, reagentCost = 900, fee = 100 }
local trained = Model.PlanWithTraining({
	skill = 1,
	target = 60,
	recipes = { cheap },
	queue = { { recipeID = 4, count = 1, learnAt = 30, candidate = service } },
}, { service })
equal(#trained.training, 1, "a queued unlearned recipe is trained")
equal(trained.training[1].recipeID, 4, "it is the queued one")
equal(trained.trainingCost, 100, "its fee is charged")

print("queue_model_spec: " .. checks .. " checks passed")
