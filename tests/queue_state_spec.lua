local Client = dofile("tests/client.lua")
local equal = Client.equal
local c = Client.load()
local ns = c.ns

equal(#ns.QueuedCrafts(), 0, "nothing is queued at first")
ns.SetSkipped(3275, true)
ns.QueueCraft(3275, 2)
equal(ns.IsSkipped(3275), false, "queueing restores a skipped recipe")
equal(ns.QueuedCount(3275), 2, "the count is kept")
ns.QueueCraft(3276, 1)
ns.QueueCraft(3275, 3)
local queued = ns.QueuedCrafts()
equal(#queued, 2, "queueing again changes the count, not the list")
equal(queued[1].recipeID, 3275, "the first queued stays first")
equal(queued[1].count, 3, "with its new count")
equal(#ns.QueuedCrafts(129), 2, "the profession lists its queue")
equal(#ns.QueuedCrafts(164), 0, "another profession has none")

ns.SetSkipped(3276, true)
equal(ns.QueuedCount(3276), 0, "skipping removes it from the queue")
ns.CraftedQueued(3275)
equal(ns.QueuedCount(3275), 2, "a craft takes one off")
ns.CraftedQueued(3275)
ns.CraftedQueued(3275)
equal(ns.QueuedCount(3275), 0, "the last craft removes it")
ns.CraftedQueued(3275)
equal(#ns.QueuedCrafts(), 0, "crafting an unqueued recipe changes nothing")

ns.QueueCraft(3275, 1)
ns.QueueCraft(3276, 1)
ns.ClearQueue(129)
equal(#ns.QueuedCrafts(), 0, "clearing empties the profession's queue")
ns.QueueCraft(3275, 0)
equal(#ns.QueuedCrafts(), 0, "a zero count queues nothing")

ns.QueueCraft(3275, 2)
c.Fire("UNIT_SPELLCAST_SUCCEEDED", "target", "cast", 3275)
equal(ns.QueuedCount(3275), 2, "another unit's cast is not a craft")
c.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 3275)
equal(ns.QueuedCount(3275), 1, "the player's craft of a queued recipe takes one off")
ns.ClearQueue()

local reloaded = Client.load({
	saved = {
		craftQueue = {
			["Tester Surname-6941"] = {
				{ recipeID = 3275, count = 2 },
				{ recipeID = "bad", count = 1 },
				{ recipeID = 3276, count = -1 },
				{ recipeID = 2, count = math.huge },
				"junk",
			},
			Other = 3,
		},
	},
})
equal(reloaded.ns.QueuedCount(3275), 2, "a saved queue survives reload")
equal(#reloaded.ns.QueuedCrafts(), 1, "invalid entries are removed")
equal(reloaded.ns.db.craftQueue.Other, nil, "malformed character queues are removed")

Client.report("queue_state_spec")
