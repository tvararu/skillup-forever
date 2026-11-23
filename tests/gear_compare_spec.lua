-- Run from the repository root: luajit tests/gear_compare_spec.lua
-- A pattern card's comparison of what a recipe makes with what the player wears in that slot.
local Client = dofile("tests/client.lua")
local equal = Client.equal

local BELT, WORN_BELT, RING, KIT = 1001, 1002, 1003, 1004

local c = Client.load({ auctionator = false })
local G = c.G
local info = {
	[BELT] = { "item:1001", "INVTYPE_WAIST" },
	[RING] = { "item:1003", "INVTYPE_FINGER" },
	[KIT] = { "item:1004", "" },
}
G.C_Item.GetItemInfo = function(id)
	local item = info[id]
	if item then
		return "Item", item[1], 2, 20, 20, "Armor", "Leather", 1, item[2]
	end
end
local stats = {
	["item:1001"] = { ITEM_MOD_AGILITY_SHORT = 8, ITEM_MOD_STAMINA_SHORT = 3, RESISTANCE0_NAME = 60 },
	["item:1002"] = { ITEM_MOD_STAMINA_SHORT = 5, ITEM_MOD_STRENGTH_SHORT = 2, RESISTANCE0_NAME = 60 },
}
G.C_Item.GetItemStats = function(link)
	return stats[link]
end
local worn = { [6] = "item:1002" }
G.GetInventoryItemLink = function(unit, slot)
	return unit == "player" and worn[slot] or nil
end
local ns = c.ns

equal(ns.GearComparison(KIT), nil, "something not worn has nothing to compare")
equal(ns.GearComparison(9999), nil, "nor does an item the client has not loaded")

local belt = ns.GearComparison(BELT)
equal(belt.link, "item:1001", "a belt is compared by its link")
equal(#belt.against, 1, "with the one waist slot")
equal(belt.against[1].link, "item:1002", "against the belt worn there")
local deltas = {}
for _, delta in ipairs(belt.against[1].deltas) do
	deltas[delta.stat] = delta.delta
end
equal(deltas.ITEM_MOD_AGILITY_SHORT, 8, "a stat only it has is a gain")
equal(deltas.ITEM_MOD_STAMINA_SHORT, -2, "a stat both have is the difference")
equal(deltas.ITEM_MOD_STRENGTH_SHORT, -2, "a stat only the worn one has is a loss")
equal(deltas.RESISTANCE0_NAME, nil, "an equal stat is left out")
equal(belt.pawn, nil, "without Pawn there is no Pawn verdict")

local ring = ns.GearComparison(RING)
equal(#ring.against, 2, "a ring is compared with both ring slots")
equal(ring.against[1].link, nil, "an empty slot has nothing worn")
equal(#ring.against[1].deltas, 0, "and no stats to lose")

G.PawnGetItemData = function(link)
	return { Link = link }
end
G.PawnIsItemAnUpgrade = function(item)
	if item.Link == "item:1001" then
		return { { "Prot", "Protection", 0.12, "item:1002" } }
	end
end
local verdict = ns.GearComparison(BELT).pawn
equal(verdict.upgrades[1].scale, "Protection", "Pawn's upgrade names its scale")
equal(verdict.upgrades[1].percent, 0.12, "and by how much")
equal(verdict.upgrades[1].existing, "item:1002", "and what it replaces")
equal(#ns.GearComparison(RING).pawn.upgrades, 0, "Pawn saying nothing is no upgrade")
G.PawnIsItemAnUpgrade = function()
	error("scales not loaded")
end
equal(ns.GearComparison(BELT).pawn, nil, "a Pawn error leaves the verdict out")

Client.report("gear_compare_spec")
