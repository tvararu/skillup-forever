---@type string, SkillUpNamespace
local _, ns = ...

if ns.broken then
	return
end
local L = ns.L

-- The Patterns page's right side: the selected recipe's item, where it is learnt, its skill-up bands, reagents
-- and their prices, its full item tooltip, and buttons to queue copies.

local PAD = 12
local ICON_SIZE = 40
local REAGENT_HEIGHT = 18
local BAND_NAMES = { "orange", "yellow", "green", "grey" }

---@class SkillUpPatternCardReagent: Button
---@field Icon Texture
---@field Name FontString
---@field Price FontString
---@field itemID integer?

---@class SkillUpPatternCard: Frame
---@field Empty FontString
---@field Body Frame
---@field Icon Texture
---@field Name FontString
---@field Source FontString
---@field Bar SkillUpBar
---@field Ranges FontString
---@field ReagentsLabel FontString
---@field Reagents SkillUpPatternCardReagent[]
---@field Cost FontString
---@field Problem FontString
---@field Stats GameTooltip
---@field Queued FontString
---@field Add Button
---@field Remove Button
---@field profession SkillUpProfession?
---@field entry SkillUpPattern?

---@param parent Frame
---@param template string
---@return FontString
local function Label(parent, template)
	local text = parent:CreateFontString(nil, "OVERLAY", template)
	text:SetJustifyH("LEFT")
	return text
end

---@param itemID integer
---@return string
local function ItemName(itemID)
	local name = C_Item.GetItemNameByID(itemID)
	if not name then
		ns.RequestItemData(itemID)
	end
	return name or string.format(L["item %d"], itemID)
end

-- The bands as the bar draws them, starting where the recipe is learnt when the data only has the placeholder 1.
---@param profession SkillUpProfession
---@param entry SkillUpPattern
---@return number[]?
local function Bands(profession, entry)
	local t = ns.RangeThresholds(profession, entry.recipeID)
	if t and t[1] < entry.skill and entry.skill <= t[2] then
		return { entry.skill, t[2], t[3], t[4] }
	end
	return t
end

---@param t number[]
---@return string
local function RangesText(t)
	local parts = {}
	for i, name in ipairs(BAND_NAMES) do
		parts[i] = ns.COLORS[name]:WrapTextInColorCode(tostring(t[i]))
	end
	return string.format(L["Orange %s, yellow %s, green %s, grey %s"], parts[1], parts[2], parts[3], parts[4])
end

---@param card SkillUpPatternCard
---@param index integer
---@return SkillUpPatternCardReagent
local function ReagentRow(card, index)
	local row = card.Reagents[index]
	if row then
		return row
	end
	row = CreateFrame("Button", nil, card.Body) --[[@as SkillUpPatternCardReagent]]
	row:SetHeight(REAGENT_HEIGHT)
	row.Icon = row:CreateTexture(nil, "ARTWORK")
	row.Icon:SetSize(REAGENT_HEIGHT - 2, REAGENT_HEIGHT - 2)
	row.Icon:SetPoint("LEFT")
	row.Price = Label(row, "GameFontHighlightSmall")
	row.Price:SetJustifyH("RIGHT")
	row.Price:SetPoint("RIGHT")
	row.Name = Label(row, "GameFontHighlightSmall")
	row.Name:SetPoint("LEFT", row.Icon, "RIGHT", 6, 0)
	row.Name:SetPoint("RIGHT", row.Price, "LEFT", -6, 0)
	row.Name:SetWordWrap(false)
	row:SetScript("OnEnter", function(self)
		if self.itemID then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetItemByID(self.itemID)
			GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", GameTooltip_Hide)
	card.Reagents[index] = row
	return row
end

---@param card SkillUpPatternCard
---@param entry SkillUpPattern
---@return Region last
local function RenderReagents(card, entry)
	local reagents = ns.Reagents(entry.recipeID) or {}
	local last = card.ReagentsLabel --[[@as Region]]
	local total, priced = 0, true
	for index, reagent in ipairs(reagents) do
		local row = ReagentRow(card, index)
		row.itemID = reagent.itemID
		-- art-ok: a square item icon in a square slot
		row.Icon:SetTexture(C_Item.GetItemIconByID(reagent.itemID))
		local have = ns.Have(reagent.itemID)
		row.Name:SetText(string.format(L["%d/%d %s"], have, reagent.quantity, ItemName(reagent.itemID)))
		row.Name:SetTextColor((have >= reagent.quantity and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR):GetRGB())
		local price = ns.Price(reagent.itemID)
		if price then
			local copper = price.copper * reagent.quantity
			total = total + copper
			row.Price:SetText(ns.FormatNet(copper, false))
		else
			priced = false
			row.Price:SetText("?")
		end
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4)
		row:SetPoint("RIGHT", card.Body, "RIGHT", -PAD, 0)
		row:Show()
		last = row
	end
	for index = #reagents + 1, #card.Reagents do
		card.Reagents[index]:Hide()
	end
	if #reagents == 0 then
		card.Cost:SetText(L["Reagents not known."])
	elseif priced then
		card.Cost:SetText(string.format(L["Per craft: %s"], ns.FormatNet(total, false)))
	else
		card.Cost:SetText(string.format(L["Per craft: at least %s"], ns.FormatNet(total, false)))
	end
	return last
end

---@param card SkillUpPatternCard
local function Render(card)
	local profession, entry = card.profession, card.entry
	card.Body:SetShown(entry ~= nil)
	card.Empty:SetShown(entry == nil)
	card.Stats:Hide()
	if not (profession and entry) then
		return
	end
	local itemID = entry.itemID
	-- art-ok: a square item icon in a square slot
	card.Icon:SetTexture(itemID and C_Item.GetItemIconByID(itemID) or C_Spell.GetSpellTexture(entry.recipeID))
	local quality = itemID and C_Item.GetItemQualityByID(itemID)
	local color = quality and ITEM_QUALITY_COLORS[quality] and ITEM_QUALITY_COLORS[quality].color or NORMAL_FONT_COLOR
	card.Name:SetText(entry.name)
	card.Name:SetTextColor(color:GetRGB())
	card.Source:SetText(ns.PatternDetail(entry))

	local t = Bands(profession, entry)
	local bar = card.Bar
	if t then
		ns.LayoutSkillBar(bar, t, profession.skill or profession.base)
		bar:SetScale(math.min(1, card.Body:GetWidth() * 0.45 / bar:GetWidth()))
		bar:ClearAllPoints()
		bar:SetPoint("TOPRIGHT", card.Body, "TOPRIGHT", -PAD / bar:GetScale(), -PAD / bar:GetScale())
		bar:Show()
		card.Ranges:SetText(RangesText(t))
		card.Ranges:Show()
	else
		bar:Hide()
		card.Ranges:Hide()
	end
	local right = t and bar or card.Body
	local edge = t and "LEFT" or "RIGHT"
	card.Name:SetPoint("RIGHT", right, edge, -PAD, 0)
	card.Source:SetPoint("RIGHT", right, edge, -PAD, 0)
	-- The reagents start under the icon, or under the bands when those reach lower.
	local below = 0
	if t then
		below = math.max(0, bar:GetHeight() * bar:GetScale() + 2 + card.Ranges:GetStringHeight() - ICON_SIZE)
	end
	card.ReagentsLabel:ClearAllPoints()
	card.ReagentsLabel:SetPoint("TOPLEFT", card.Icon, "BOTTOMLEFT", 0, -12 - below)

	local last = RenderReagents(card, entry)
	card.Cost:ClearAllPoints()
	card.Cost:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -6)

	local queued = ns.QueuedCount(entry.recipeID)
	card.Queued:SetText(string.format(L["Queued: %d"], queued))
	card.Remove:SetEnabled(queued > 0)

	if itemID then
		card.Problem:SetText("")
		local shown, problem = pcall(function()
			local stats = card.Stats
			stats:SetOwner(card, "ANCHOR_NONE")
			stats:ClearAllPoints()
			stats:SetPoint("TOPLEFT", card.Cost, "BOTTOMLEFT", -4, -8)
			stats:SetItemByID(itemID)
			stats:SetFrameStrata(card:GetFrameStrata())
			stats:SetFrameLevel(card:GetFrameLevel() + 20)
			stats:Show()
		end)
		if not shown then
			card.Problem:SetText(RED_FONT_COLOR:WrapTextInColorCode(tostring(problem)))
			card.Problem:SetPoint("TOPLEFT", card.Cost, "BOTTOMLEFT", 0, -8)
		end
	end
end

---@param text string
---@param parent Frame
---@param onClick fun()
---@return Button
local function ActionButton(text, parent, onClick)
	local button = CreateFrame("Button", nil, parent, "SharedButtonSmallTemplate") --[[@as Button]]
	button:SetText(text)
	button:SetWidth(button:GetTextWidth() + 32)
	button:SetScript("OnClick", onClick)
	return button
end

---@param parent Frame
---@return SkillUpPatternCard
function ns.CreatePatternCard(parent)
	local card = CreateFrame("Frame", nil, parent, "InsetFrameTemplate") --[[@as SkillUpPatternCard]]
	card.Reagents = {}

	card.Empty = card:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	card.Empty:SetPoint("CENTER")
	card.Empty:SetText(L["Choose a pattern to see its card."])

	local body = CreateFrame("Frame", nil, card)
	body:SetPoint("TOPLEFT")
	body:SetPoint("BOTTOMRIGHT")
	card.Body = body

	card.Icon = body:CreateTexture(nil, "ARTWORK")
	card.Icon:SetSize(ICON_SIZE, ICON_SIZE)
	card.Icon:SetPoint("TOPLEFT", PAD, -PAD)
	card.Name = Label(body, "GameFontNormalLarge")
	card.Name:SetPoint("TOPLEFT", card.Icon, "TOPRIGHT", 8, -2)
	local header = CreateFrame("Button", nil, body)
	header:SetPoint("TOPLEFT", card.Icon, "TOPLEFT")
	header:SetPoint("BOTTOMRIGHT", card.Name, "BOTTOMRIGHT", 0, -16)
	header:SetScript("OnEnter", function(self)
		local itemID = card.entry and card.entry.itemID
		if itemID then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetItemByID(itemID)
			GameTooltip:Show()
		end
	end)
	header:SetScript("OnLeave", GameTooltip_Hide)
	card.Source = Label(body, "GameFontHighlightSmall")
	card.Source:SetPoint("TOPLEFT", card.Name, "BOTTOMLEFT", 0, -4)

	card.Bar = ns.CreateSkillBar()
	card.Bar:SetParent(body)
	card.Ranges = Label(body, "GameFontHighlightSmall")
	card.Ranges:SetJustifyH("RIGHT")
	card.Ranges:SetPoint("TOPRIGHT", card.Bar, "BOTTOMRIGHT", 0, -2)

	card.ReagentsLabel = Label(body, "GameFontNormal")
	card.ReagentsLabel:SetText(L["Reagents"])
	card.Cost = Label(body, "GameFontHighlight")
	card.Problem = Label(body, "GameFontHighlightSmall")

	card.Stats = CreateFrame("GameTooltip", "SkillUpForeverPatternCardTooltip", body, "GameTooltipTemplate") --[[@as GameTooltip]]

	local function Change(delta)
		local entry = card.entry
		if entry then
			ns.QueueCraft(entry.recipeID, math.max(0, ns.QueuedCount(entry.recipeID) + delta))
		end
	end
	card.Add = ActionButton(L["Queue a copy"], body, function()
		Change(1)
	end)
	card.Add:SetPoint("BOTTOMLEFT", PAD, PAD)
	card.Remove = ActionButton(L["Remove a copy"], body, function()
		Change(-1)
	end)
	card.Remove:SetPoint("LEFT", card.Add, "RIGHT", 6, 0)
	for _, button in ipairs({ card.Add, card.Remove }) do
		button:SetFrameLevel(card:GetFrameLevel() + 40)
	end
	card.Queued = Label(body, "GameFontHighlight")
	card.Queued:SetPoint("BOTTOMLEFT", card.Add, "TOPLEFT", 2, 6)

	local events = CreateFrame("Frame", nil, card)
	events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	local pending = false
	events:SetScript("OnEvent", function()
		if pending or not (card:IsVisible() and card.entry) then
			return
		end
		pending = true
		C_Timer.After(0.1, function()
			pending = false
			if card:IsVisible() then
				Render(card)
			end
		end)
	end)

	---@param profession SkillUpProfession?
	---@param entry SkillUpPattern?
	function card:SetPattern(profession, entry)
		self.profession, self.entry = profession, entry
		Render(self)
	end
	card:SetScript("OnShow", Render)
	return card
end
