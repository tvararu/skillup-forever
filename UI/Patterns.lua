---@type string, SkillUpNamespace
local _, ns = ...

if ns.broken then
	return
end
local L = ns.L
local Parts = ns.PageParts

-- The Patterns page: every recipe of a profession, known or not, with where it is learnt. A click queues one
-- craft of it for the route, shift-click its whole set; the route then makes them on the way to its target.

local SHOW_OPTIONS = {
	{ "all", L["All recipes"] },
	{ "known", L["Learned"] },
	{ "learnable", L["Learnable now"] },
	{ "missing", L["Not learned"] },
}
local QUEUE_ICON = "Interface\\RaidFrame\\ReadyCheck-Ready"

---@class SkillUpPatternsPage: Frame
---@field Profession DropdownButton
---@field Skill FontString
---@field Filter DropdownButton
---@field Search EditBox
---@field List SkillUpList
---@field Summary FontString
---@field ToRoute Button
---@field Clear Button
---@field Card SkillUpPatternCard
local page
---@type integer?
local selected
---@type SkillUpPatternFilter
local filter = { show = "all" }
---@type integer?
local chosen
local Render

---@return SkillUpProfession?
local function Profession()
	local professions = ns.RouteProfessions()
	if not (selected and professions[selected]) then
		local open = ns.OpenSkillLine()
		selected = open and professions[open] and open or nil
		if not selected then
			for skillLine in pairs(professions) do
				if not selected or skillLine < selected then
					selected = skillLine
				end
			end
		end
	end
	return selected and professions[selected] or nil
end

---@param entry SkillUpPattern
---@return string
local function SourceText(entry)
	local text = ns.PATTERN_SOURCE_TEXT[entry.source]
	if entry.favor then
		text = string.format(L["%s %d"], text, entry.favor)
	end
	if entry.rep and not entry.repMet then
		text = string.format(L["%s, standing too low"], text)
	end
	if entry.spec then
		text = string.format(L["%s, needs %s"], text, entry.spec)
	end
	if entry.gone then
		text = L["Not taught in Forever"]
	end
	return text
end

---@param entry SkillUpPattern
---@return string
function ns.PatternDetail(entry)
	local detail = string.format(L["Skill %d, %s"], entry.skill, SourceText(entry))
	if entry.bop then
		detail = string.format(L["%s, binds on pickup"], detail)
	end
	return detail
end

---@param entry SkillUpPattern
---@return ColorMixin
local function Color(entry)
	if entry.queued > 0 then
		return GREEN_FONT_COLOR
	elseif entry.state == "known" then
		return GRAY_FONT_COLOR
	elseif entry.state == "learnable" then
		return HIGHLIGHT_FONT_COLOR
	end
	return NORMAL_FONT_COLOR
end

---@param entry SkillUpPattern
---@return string
local function Text(entry)
	if entry.queued > 0 then
		return string.format(L["%s (queued %d)"], entry.name, entry.queued)
	end
	return entry.name
end

---@param profession SkillUpProfession
---@param entry SkillUpPattern
---@return fun()
local function Click(profession, entry)
	return function()
		chosen = entry.recipeID
		Render()
	end
end

---@param profession SkillUpProfession
---@param entry SkillUpPattern
---@return fun(owner: Region, root: ForeverMenuDescription)
local function Menu(profession, entry)
	return function(_, root)
		root:CreateTitle(entry.name)
		local queued = ns.QueuedCount(entry.recipeID)
		root:CreateButton(queued > 0 and L["Queue one more"] or L["Queue to craft"], function()
			ns.QueueCraft(entry.recipeID, queued + 1)
		end)
		if queued > 0 then
			root:CreateButton(L["Remove from queue"], function()
				ns.QueueCraft(entry.recipeID, 0)
			end)
		end
	end
end

function Render()
	local profession = Profession()
	page.List:Begin()
	if not profession then
		page.Profession:SetText(L["No profession"])
		page.Skill:SetText("")
		page.Summary:SetText("")
		page.Clear:Disable()
		page.List:Message(L["Learn a crafting profession to see its patterns."])
		page.List:Finish()
		page.Card:SetPattern(nil, nil)
		return
	end
	page.Profession:SetText(profession.name)
	page.Skill:SetText(string.format(L["%d / %d"], profession.base, profession.max))
	local entries = ns.Patterns(profession)
	local known, queued = 0, 0
	local chosenEntry
	for _, entry in ipairs(entries) do
		if entry.recipeID == chosen then
			chosenEntry = entry
		end
		if entry.state == "known" then
			known = known + 1
		end
		if entry.queued > 0 then
			queued = queued + 1
		end
	end
	page.Summary:SetText(string.format(L["%d of %d learned, %d queued"], known, #entries, queued))
	page.Clear:SetEnabled(queued > 0)
	local shown = ns.FilterPatterns(entries, filter)
	for _, entry in ipairs(shown) do
		page.List:Add({
			icon = entry.itemID and C_Item.GetItemIconByID(entry.itemID) or QUEUE_ICON,
			text = Text(entry),
			detail = ns.PatternDetail(entry),
			color = Color(entry),
			current = entry.recipeID == chosen,
			click = Click(profession, entry),
			menu = Menu(profession, entry),
		})
	end
	if #shown == 0 then
		page.List:Message(L["No recipe matches."])
	end
	page.List:Finish()
	page.Card:SetPattern(profession, chosenEntry)
end

local function Refresh()
	if page and page:IsShown() then
		Render()
	end
end

---@param root RootMenuDescriptionProxy
local function BuildFilterMenu(root)
	for _, option in ipairs(SHOW_OPTIONS) do
		local value = option[1]
		root:CreateRadio(option[2], function()
			return filter.show == value
		end, function()
			filter.show = value
			Render()
		end)
	end
	root:CreateDivider()
	root:CreateRadio(L["Any source"], function()
		return filter.source == nil
	end, function()
		filter.source = nil
		Render()
	end)
	for _, source in ipairs(ns.PATTERN_SOURCES) do
		root:CreateRadio(ns.PATTERN_SOURCE_TEXT[source], function()
			return filter.source == source
		end, function()
			filter.source = source
			Render()
		end)
	end
end

local function CreatePage()
	page = CreateFrame("Frame", nil, ProfessionsFrame) --[[@as SkillUpPatternsPage]]
	page:SetAllPoints(ProfessionsFrame)
	page:SetFrameLevel(ProfessionsFrame.CraftingPage:GetFrameLevel())
	page:SetFrameStrata("HIGH")
	page:Hide()
	page.Profession, page.Skill = Parts.CreateHeader(page, function(root)
		local professions = {}
		for _, profession in pairs(ns.RouteProfessions()) do
			professions[#professions + 1] = profession
		end
		table.sort(professions, function(a, b)
			return a.name < b.name
		end)
		for _, profession in ipairs(professions) do
			local skillLine = profession.skillLine
			root:CreateRadio(profession.name, function()
				return skillLine == selected
			end, function()
				selected = skillLine
				chosen = nil
				page.List.scrollBox:ScrollToBegin()
				Render()
			end)
		end
	end)

	local search = CreateFrame("EditBox", nil, page, "SearchBoxTemplate") --[[@as EditBox]]
	search:SetSize(160, 20)
	search:SetPoint("TOPRIGHT", -24, -34)
	search:SetScript("OnTextChanged", function(editBox, userInput)
		SearchBoxTemplate_OnTextChanged(editBox)
		if userInput then
			filter.search = editBox:GetText()
			Render()
		end
	end)
	page.Search = search

	local filterButton = CreateFrame("DropdownButton", nil, page, "WowStyle1FilterDropdownTemplate") --[[@as DropdownButton]]
	filterButton:SetPoint("RIGHT", search, "LEFT", -10, 0)
	filterButton:SetText(L["Filter"])
	filterButton:SetupMenu(function(_, root)
		BuildFilterMenu(root)
	end)
	ns.StepDropdownUnderGamepad(filterButton)
	page.Filter = filterButton

	local inset = CreateFrame("Frame", nil, page, "InsetFrameTemplate") --[[@as Frame]]
	local title = inset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("BOTTOMLEFT", inset, "TOPLEFT", 4, 4)
	title:SetText(L["Patterns"])
	inset:SetPoint("TOPLEFT", 16, -88)
	inset:SetPoint("BOTTOMRIGHT", page, "BOTTOM", -60, 44)
	page.List = ns.CreateList(inset)

	local card = ns.CreatePatternCard(page)
	card:SetPoint("TOPLEFT", inset, "TOPRIGHT", 8, 0)
	card:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -16, 44)
	page.Card = card

	local summary = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	summary:SetPoint("LEFT", inset, "BOTTOMLEFT", 4, -21)
	page.Summary = summary

	local toRoute = CreateFrame("Button", nil, page, "SharedButtonSmallTemplate") --[[@as Button]]
	toRoute:SetText(L["Show route"])
	toRoute:SetWidth(120)
	toRoute:SetPoint("RIGHT", card, "BOTTOMRIGHT", 0, -21)
	toRoute:SetScript("OnClick", function()
		ns.Pages.Select("route")
	end)
	page.ToRoute = toRoute

	local clear = CreateFrame("Button", nil, page, "SharedButtonSmallTemplate") --[[@as Button]]
	clear:SetText(L["Clear queue"])
	clear:SetWidth(120)
	clear:SetPoint("RIGHT", toRoute, "LEFT", -6, 0)
	clear:SetScript("OnClick", function()
		ns.ClearQueue(selected)
	end)
	page.Clear = clear

	page:SetScript("OnShow", Render)
end

function ns.AttachPatterns()
	CreatePage()
	ns.Pages.Register({
		id = "patterns",
		title = L["Patterns"],
		setting = function()
			return ns.db.showProfessionTabs
		end,
		page = page,
	})
	ns.WhenStale("patterns", Refresh)
end
