---@type string, SkillUpNamespace
local _, ns = ...

if ns.broken then
	return
end
local L = ns.L

-- The Patterns page's data: every recipe a profession has, whether this character knows it, can learn it now or
-- is still missing it, and where it is learnt. Data/PatternSources.lua adds what the rest of the bundle lacks:
-- Merchant's Favor prices, reputation and specialisation requirements, and whether a product binds on pickup.

---@alias SkillUpPatternSource "basic"|"trainer"|"favor"|"rep"|"vendor"|"drop"|"unknown"
---@alias SkillUpPatternState "known"|"learnable"|"missing"

---@class SkillUpPattern
---@field recipeID integer
---@field name string
---@field itemID integer?
---@field skill number Base skill it is learnt at.
---@field state SkillUpPatternState
---@field source SkillUpPatternSource
---@field favor integer? Merchant's Favor price.
---@field rep {[1]: integer, [2]: integer}? Faction ID and the standing it asks.
---@field repMet boolean
---@field spec string?
---@field bop boolean?
---@field gone boolean? Forever no longer teaches it.
---@field scroll integer? The pattern item.
---@field queued integer

-- Where a recipe can come from, in the order a list shows them.
ns.PATTERN_SOURCES = { "basic", "trainer", "favor", "rep", "vendor", "drop", "unknown" }
ns.PATTERN_SOURCE_TEXT = {
	basic = L["Basic"],
	trainer = L["Trainer"],
	favor = L["Merchant's Favor"],
	rep = L["Reputation"],
	vendor = L["Vendor"],
	drop = L["Drop"],
	unknown = L["Unknown"],
}

-- The standing this character has with a faction, nil when the client does not say.
---@param factionID integer
---@return integer?
local function Standing(factionID)
	local lookup = _G.GetFactionInfoByID
	if type(lookup) ~= "function" then
		return nil
	end
	local ok, _, _, standing = pcall(lookup, factionID)
	return ok and type(standing) == "number" and standing or nil
end

-- [recipeID] = the bundle's English name, built once: the set names and the search read it.
---@type table<integer, string>?
local bundledNames

-- A recipe's name: the bundle's, which set names are read from, else the client's.
---@param recipeID integer
---@return string
local function Name(recipeID)
	if not bundledNames then
		bundledNames = {}
		for _, names in pairs(ns.RecipeNames or {}) do
			for name, id in pairs(names) do
				bundledNames[id] = name
			end
		end
	end
	return bundledNames[recipeID] or C_Spell.GetSpellName(recipeID) or string.format(L["recipe %d"], recipeID)
end

-- Where a recipe nothing places is learnt: its orange start when the data has a real one, else as far below
-- yellow as grey is above it, a guess that matches trainer recipes.
---@param recipeID integer
---@return number
local function BandedLearnSkill(recipeID)
	local t = ns.Model.Get(recipeID)
	if not t then
		return 1
	elseif t[1] > 1 then
		return t[1]
	end
	return math.max(1, 2 * t[2] - t[4])
end

---@param profession SkillUpContext
---@param recipeID integer
---@param data table
---@param scroll integer?
---@return SkillUpPatternSource
local function SourceOf(profession, recipeID, data, scroll)
	if data.gone then
		return "unknown"
	elseif data.basic then
		return "basic"
	elseif data.favor then
		return "favor"
	elseif data.rep then
		return "rep"
	elseif ns.TrainingFor(profession, recipeID) or data.trainer then
		return "trainer"
	elseif scroll then
		local catalogue = ns.Catalogue and type(ns.Catalogue.Recipe) == "function" and ns.Catalogue.Recipe(recipeID)
		if data.scrollPrice or ns.db.vendor[scroll] or (catalogue and #catalogue.vendors > 0) then
			return "vendor"
		elseif (ns.ScrollDrops and ns.ScrollDrops[scroll]) or (ns.WorldDrops and ns.WorldDrops[scroll]) then
			return "drop"
		end
	end
	return "unknown"
end

-- Every recipe of the profession, in the order they are learnt, then by name.
---@param profession SkillUpContext
---@return SkillUpPattern[]
function ns.Patterns(profession)
	local entries = {}
	local sources = ns.PatternSources or {}
	for recipeID, recipe in pairs(ns.RecipeData) do
		local data = sources[recipeID] or {}
		if recipe.skillLine == profession.skillLine and not data.gone then
			local scrollData = ns.RecipeScrolls and ns.RecipeScrolls[recipeID]
			local scroll = scrollData and scrollData[1] or nil
			local learnAt = ns.LearnSkill(profession, recipeID) - profession.modifier
			if learnAt <= 0 then
				learnAt = data.train or BandedLearnSkill(recipeID)
			end
			local rep = data.rep
			local repMet = true
			if rep then
				local standing = Standing(rep[1])
				repMet = standing ~= nil and standing >= rep[2]
			end
			local source = SourceOf(profession, recipeID, data, scroll)
			local state = "missing"
			if ns.IsLearned(recipeID) then
				state = "known"
			elseif
				not data.gone
				and source ~= "drop"
				and source ~= "unknown"
				and profession.base >= learnAt
				and repMet
				and not data.spec
			then
				state = "learnable"
			end
			entries[#entries + 1] = {
				recipeID = recipeID,
				name = Name(recipeID),
				itemID = recipe.output and recipe.output.itemID or nil,
				skill = learnAt,
				state = state,
				source = source,
				favor = data.favor,
				rep = rep,
				repMet = repMet,
				spec = data.spec,
				bop = data.bop,
				gone = data.gone,
				scroll = scroll,
				queued = ns.QueuedCount(recipeID),
			}
		end
	end
	table.sort(entries, function(a, b)
		if a.skill ~= b.skill then
			return a.skill < b.skill
		end
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.recipeID < b.recipeID
	end)
	return entries
end

---@class SkillUpPatternFilter
---@field show? "all"|"known"|"learnable"|"missing"
---@field source? SkillUpPatternSource
---@field search? string

-- Whether a recipe's name or one of its reagents' names holds the search text, ignoring case.
---@param entry SkillUpPattern
---@param needle string
---@return boolean
local function Matches(entry, needle)
	if entry.name:lower():find(needle, 1, true) then
		return true
	end
	local recipe = ns.RecipeData[entry.recipeID]
	for _, reagent in ipairs(recipe and recipe.reagents or {}) do
		local name = C_Item.GetItemNameByID(reagent.itemID)
		if name and name:lower():find(needle, 1, true) then
			return true
		end
	end
	return false
end

---@param entries SkillUpPattern[]
---@param filter SkillUpPatternFilter
---@return SkillUpPattern[]
function ns.FilterPatterns(entries, filter)
	local show = filter.show or "all"
	local needle = filter.search and filter.search:lower():match("^%s*(.-)%s*$") or ""
	local kept = {}
	for _, entry in ipairs(entries) do
		local shown = show == "all"
			or entry.state == show
			or (show == "missing" and entry.state ~= "known")
		if shown and (not filter.source or entry.source == filter.source) and (needle == "" or Matches(entry, needle)) then
			kept[#kept + 1] = entry
		end
	end
	return kept
end

-- A set's name: the first word of a recipe named like "Stormrider's Leather Belt".
---@param name string
---@return string?
local function SetName(name)
	return name:match("^(%S+'s) ")
end

-- The recipes of the profession sharing this one's set name, in learn order; nil for a recipe with none.
---@param profession SkillUpContext
---@param recipeID integer
---@return SkillUpPattern[]?
function ns.PatternSet(profession, recipeID)
	local setName = SetName(Name(recipeID))
	if not setName then
		return nil
	end
	local set = {}
	for _, entry in ipairs(ns.Patterns(profession)) do
		if SetName(entry.name) == setName then
			set[#set + 1] = entry
		end
	end
	return set
end

-- Queues one of every recipe in this one's set that is not queued already.
---@param profession SkillUpContext
---@param recipeID integer
function ns.QueueSet(profession, recipeID)
	for _, entry in ipairs(ns.PatternSet(profession, recipeID) or {}) do
		if ns.QueuedCount(entry.recipeID) == 0 then
			ns.QueueCraft(entry.recipeID, 1)
		end
	end
end
