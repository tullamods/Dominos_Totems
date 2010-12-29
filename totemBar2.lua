--[[
	totemBar2.lua
		A totem bar for Dominos that mimics the standard totem bar
--]]

--hurray for constants
local MAX_TOTEMS = MAX_TOTEMS
local NUM_PAGES = NUM_MULTI_CAST_PAGES
local NUM_BUTTONS_PER_PAGE = NUM_MULTI_CAST_BUTTONS_PER_PAGE
local TOTEM_MULTI_CAST_RECALL_SPELLS = TOTEM_MULTI_CAST_RECALL_SPELLS
local TOTEM_MULTI_CAST_SUMMON_SPELLS = TOTEM_MULTI_CAST_SUMMON_SPELLS
local TOTEM_PRIORITIES = SHAMAN_TOTEM_PRIORITIES
local START_ACTION_ID = 132 --actionID start of the totembar
local MAX_FLYOUT_BUTTONS = 6


local TotemBar = Dominos:CreateClass('Frame', Dominos.Frame)

function TotemBar:New()
	local f = self.super.New(self, 'totem')
	f:LoadButtons()
	f:Layout()

	return f
end

function TotemBar:Create(id)
	local f = self.super.Create(self, id)

	f.header:SetFrameRef('UIParent', UIParent)

	f.header:SetAttribute('_onstate-showTotemFlyout', [[
		local totemId = tonumber(newstate)
		local totem = myTotems[totemId]
		local totemFlyout = self:GetFrameRef('totemFlyout')

		local prevTotem = totemFlyout:GetParent()
		if prevTotem == totem then
			if totemFlyout:IsShown() then
				totemFlyout:Hide()
				return
			end
		end

		totemFlyout:Hide()
		totemFlyout:SetParent(totem)
		totemFlyout:SetAttribute('totemId', totemId)

		totemFlyout:RunAttribute('loadButtons', GetMultiCastTotemSpells(totemId))

		--place the totem bar intelligently based on cursor position + bar orientation
		local UIParent = self:GetFrameRef('UIParent')
		local isVertical = floor(self:GetParent():GetWidth()) < floor(self:GetParent():GetHeight())
		if isVertical then
			local x, y = UIParent:GetMousePosition()
			if x < 0.5 then
				totemFlyout:RunAttribute('layout-right')
			else
				totemFlyout:RunAttribute('layout-left')
			end
		else
			local x, y = UIParent:GetMousePosition()
			if y < 0.5 then
				totemFlyout:RunAttribute('layout-top')
			else
				totemFlyout:RunAttribute('layout-bottom')
			end
		end

		totemFlyout:Show()
	]])

	f.header:SetAttribute('_onstate-showCallFlyout', [[
		local flyout = self:GetFrameRef('callFlyout')
		if flyout:IsShown() then
			flyout:Hide()
			return
		end

		--show/hide buttons
		flyout:SetParent(self:GetFrameRef('totemCall'))
		flyout:RunAttribute('loadButtons')

		--place the totem bar intelligently based on cursor position + bar orientation
		local UIParent = self:GetFrameRef('UIParent')
		local isVertical = floor(self:GetParent():GetWidth()) < floor(self:GetParent():GetHeight())
		if isVertical then
			local x, y = UIParent:GetMousePosition()
			if x < 0.5 then
				flyout:RunAttribute('layout-right')
			else
				flyout:RunAttribute('layout-left')
			end
		else
			local x, y = UIParent:GetMousePosition()
			if y < 0.5 then
				flyout:RunAttribute('layout-top')
			else
				flyout:RunAttribute('layout-bottom')
			end
		end

		flyout:Show()
	]])

	--paging stuff
	f.header:SetAttribute('baseId', START_ACTION_ID)
	f.header:SetAttribute('maxTotems', MAX_TOTEMS)
	f.header:SetAttribute('numPages', #TOTEM_MULTI_CAST_SUMMON_SPELLS)

	f.header:SetAttribute('_onstate-page', [[
		local page = newstate or 1
		local startId = self:GetAttribute('baseId') + (page - 1) * self:GetAttribute('maxTotems')

		if myTotems then
			for _, totem in pairs(myTotems) do
				totem:SetAttribute('action', totem:GetAttribute('totemId') + startId)
			end
		end

		local totemCall = self:GetFrameRef('totemCall')
		if totemCall then
			totemCall:SetAttribute('spell', totemCall:GetAttribute('spell-page' .. page))
		end

		self:CallMethod('SetPage', page)
	]])

	--remember page setting
	f.header.SetPage = function(self, page) f.sets.page = page end

	return f
end

function TotemBar:GetDefaults()
	return {
		point = 'CENTER',
		spacing = 2,
		showRecall = true,
		showTotems = true,
		page = 1,
	}
end

function TotemBar:NumButtons()
	local numButtons = 0

	if self:IsCallKnown() then
		numButtons = numButtons + 1
	end

	if self:ShowingTotems() then
		numButtons = numButtons + MAX_TOTEMS
	end

	if self:ShowingRecall() and self:IsRecallKnown() then
		numButtons = numButtons + 1
	end

	return numButtons
end

--handle displaying the totemic recall button
function TotemBar:SetShowRecall(show)
	self.sets.showRecall = show and true or false
	self:LoadButtons()
	self:Layout()
end

function TotemBar:ShowingRecall()
	return self.sets.showRecall
end

--handle displaying all of the totem buttons
function TotemBar:SetShowTotems(show)
	self.sets.showTotems = show and true or false
	self:LoadButtons()
	self:Layout()
end

function TotemBar:ShowingTotems()
	return self.sets.showTotems
end


--[[ button stuff]]--

function TotemBar:LoadButtons()
	local buttons = self.buttons

	--create totem flyout, if necessary
	if not self.totemFlyout then
		local totemFlyout = self:CreateTotemFlyout()
		self.totemFlyout = totemFlyout
		self.header:SetFrameRef('totemFlyout', totemFlyout)
	end

	--create call flyout, if necessary
	if not self.callFlyout then
		local callFlyout = self:CreateCallFlyout()
		self.callFlyout = callFlyout
		self.header:SetFrameRef('callFlyout', callFlyout)
	end

	--remove old buttons
	for i, b in pairs(buttons) do
		b:Free()
		buttons[i] = nil
	end

	--add call of X button
	if self:IsCallKnown() then
		table.insert(buttons, self:GetCallButton())
	end

	--add totem actions
	if self:ShowingTotems() then
		for _, totemId in ipairs(SHAMAN_TOTEM_PRIORITIES) do
			table.insert(buttons,  self:GetTotemButton(totemId))
		end
	end

	--add recall button
	if self:ShowingRecall() and self:IsRecallKnown() then
		table.insert(buttons, self:GetRecallButton())
	end

	self.header:Execute([[ control:ChildUpdate('action', nil) ]])
	self.header:SetAttribute('state-page', self.sets.page or 1)
end


--[[
	Totem Button
--]]

function TotemBar:GetTotemButton(id)
	local totem = self:CreateActionButton(START_ACTION_ID + id)
	totem:SetAttribute('totemId', id)
	totem:SetAttribute('type2', 'attribute')
	totem:SetAttribute('ctrl-type1', 'attribute')
	totem:SetAttribute('alt-type1', 'attribute')
	totem:SetAttribute('shift-type1', 'attribute')
	totem:SetAttribute('attribute-frame', totem:GetParent())
	totem:SetAttribute('attribute-name', 'state-showTotemFlyout')
	totem:SetAttribute('attribute-value', id)
	totem:SetScript('OnDragStart', nil)
	totem:SetScript('OnReceiveDrag', nil)

	self.header:SetFrameRef('addTotem', totem)
	self.header:Execute([[
		local b = self:GetFrameRef('addTotem')
		local totemId = tonumber(b:GetAttribute('totemId'))

		myTotems = myTotems or table.new()
		myTotems[totemId] = b
	]])

	return totem
end


--[[
	Totem Flyout
--]]

function TotemBar:CreateTotemFlyout()
	local flyout = CreateFrame('Frame', nil, nil, 'SecureHandlerAttributeTemplate')
	flyout:SetScript('OnShow', function(self) RegisterAutoHide(self, 0.2) end)

	--load totem buttons
	flyout:SetAttribute('loadButtons', [[
		local totem = self:GetParent()
		local actionId = totem:GetAttribute('action')
		local currentTotem = select(2, GetActionInfo(actionId))
		local count = 0

		for i = 1, select('#', ...) do
			local spell = select(i, ...)
			if spell ~= currentTotem then
				count = count + 1

				local b = myButtons[count]
				b:SetAttribute('spell', spell)
				b:SetAttribute('action', actionId)
				b:Show()
			end
		end
		self:SetAttribute('numTotems', count)

		for i = count + 1, #myButtons do
			local b = myButtons[i]
			b:SetAttribute('spell', nil)
			b:Hide()
		end

		return count
	]])

	flyout:SetAttribute('layout-left', [[
		local numTotems = self:GetAttribute('numTotems')

		self:ClearAllPoints()
		self:SetPoint('RIGHT', self:GetParent(), 'LEFT', -2, 0)

		for i = 1, numTotems do
			local b = myButtons[i]
			b:ClearAllPoints()
			if i == 1 then
				b:SetPoint('RIGHT', self, 'RIGHT', 0, 0)
			else
				b:SetPoint('RIGHT', myButtons[i - 1], 'LEFT', -2, 0)
			end
		end

		if numTotems > 0 then
			self:SetWidth(myButtons[1]:GetWidth()*numTotems + 2*(numTotems - 1))
			self:SetHeight(myButtons[1]:GetHeight())
		else
			self:SetWidth(0)
			self:SetHeight(0)
		end
	]])

	flyout:SetAttribute('layout-right', [[
		local numTotems = self:GetAttribute('numTotems')

		self:ClearAllPoints()
		self:SetPoint('LEFT', self:GetParent(), 'RIGHT', 2, 0)

		for i = 1, numTotems do
			local b = myButtons[i]
			b:ClearAllPoints()
			if i == 1 then
				b:SetPoint('LEFT', self, 'LEFT', 0, 0)
			else
				b:SetPoint('LEFT', myButtons[i - 1], 'RIGHT', 2, 0)
			end
		end

		if numTotems > 0 then
			self:SetWidth(myButtons[1]:GetWidth()*numTotems + 2*(numTotems - 1))
			self:SetHeight(myButtons[1]:GetHeight())
		else
			self:SetWidth(0)
			self:SetHeight(0)
		end
	]])

	flyout:SetAttribute('layout-top', [[
		local numTotems = self:GetAttribute('numTotems')

		self:ClearAllPoints()
		self:SetPoint('BOTTOM', self:GetParent(), 'TOP', 0, 2)

		for i = 1, numTotems do
			local b = myButtons[i]
			b:ClearAllPoints()
			if i == 1 then
				b:SetPoint('BOTTOM', self, 'BOTTOM', 0, 0)
			else
				b:SetPoint('BOTTOM', myButtons[i - 1], 'TOP', 0, 2)
			end
		end

		if numTotems > 0 then
			self:SetWidth(myButtons[1]:GetWidth())
			self:SetHeight(myButtons[1]:GetHeight()*numTotems + 2*(numTotems - 1))
		else
			self:SetWidth(0)
			self:SetHeight(0)
		end
	]])

	flyout:SetAttribute('layout-bottom', [[
		local numTotems = self:GetAttribute('numTotems')

		self:ClearAllPoints()
		self:SetPoint('TOP', self:GetParent(), 'BOTTOM', 0, -2)

		for i = 1, numTotems do
			local b = myButtons[i]
			b:ClearAllPoints()
			if i == 1 then
				b:SetPoint('TOP', self, 'TOP', 0, 0)
			else
				b:SetPoint('TOP', myButtons[i - 1], 'BOTTOM', 0, -2)
			end
		end

		if numTotems > 0 then
			self:SetWidth(myButtons[1]:GetWidth())
			self:SetHeight(myButtons[1]:GetHeight()*numTotems + 2*(numTotems - 1))
		else
			self:SetWidth(0)
			self:SetHeight(0)
		end
	]])

	for i = 1, MAX_FLYOUT_BUTTONS do
		local b = Dominos.SpellButton:New()
		b:SetParent(flyout)
		b:SetAttribute('type', 'multispell')

		flyout:SetFrameRef('addButton',  b)

		flyout:WrapScript(b, 'PostClick', [[
			self:GetParent():Hide()
		]])

		flyout:Execute([[
			local b = self:GetFrameRef('addButton')
			myButtons = myButtons or table.new()
			table.insert(myButtons, b)
			b:Hide()
		]])
	end

	flyout:SetScale(0.8)
	flyout:Hide()

	return flyout
end


--[[
	Call Button
--]]

function TotemBar:GetCallButton()
	local totemCall = self:CreateSpellButton(TOTEM_MULTI_CAST_SUMMON_SPELLS[self.header:GetAttribute('state-page')])
	totemCall:SetParent(self.header)
	totemCall:SetAttribute('type2', 'attribute')
	totemCall:SetAttribute('ctrl-type1', 'attribute')
	totemCall:SetAttribute('alt-type1', 'attribute')
	totemCall:SetAttribute('shift-type1', 'attribute')

	totemCall:SetAttribute('attribute-frame', totemCall:GetParent())
	totemCall:SetAttribute('attribute-name', 'state-showCallFlyout')
	totemCall:SetAttribute('attribute-value', true)

	totemCall:SetAttribute('_onmousewheel', [[
		local delta = delta
		local page = self:GetParent():GetAttribute('state-page') or 1

		if delta > 0 then
			page = page + 1
			if page > self:GetParent():GetAttribute('numPages') then
				page = 1
			end
		else
			page = page - 1
			if page <= 0 then
				page = self:GetParent():GetAttribute('numPages')
			end
		end

		self:GetParent():SetAttribute('state-page', page)
	]])

	for id, spellId in ipairs(TOTEM_MULTI_CAST_SUMMON_SPELLS) do
		totemCall:SetAttribute('spell-page' .. id, spellId)
	end

	self.header:SetFrameRef('totemCall', totemCall)
	return totemCall
end

function TotemBar:IsCallKnown()
	return IsSpellKnown(TOTEM_MULTI_CAST_SUMMON_SPELLS[1])
end


--[[
	Call Flyout
--]]

function TotemBar:CreateCallFlyout()
	local flyout = CreateFrame('Frame', nil, nil, 'SecureHandlerAttributeTemplate')
	flyout:SetScript('OnShow', function(self) RegisterAutoHide(self, 0.2) end)

	flyout:SetAttribute('loadButtons', [[
		local totemCall = self:GetParent()
		local numPages = totemCall:GetParent():GetAttribute('numPages') or 0
		local currentPage = totemCall:GetParent():GetAttribute('state-page')
		local count = 0

		for page = 1, numPages do
			if page ~= currentPage then
				count = count + 1

				local b = myButtons[count]
				b:SetAttribute('attribute-value', page)
				b:SetAttribute('spell', totemCall:GetAttribute('spell-page' .. page))
				b:Show()
			end
		end

		for i = count + 1, numPages do
			local b = myButtons[i]
			b:SetAttribute('attribute-value', nil)
			b:SetAttribute('spell', nil)
			b:Hide()
		end

		self:SetAttribute('countPages', count)
	]])

	flyout:SetAttribute('layout-left', [[
		local numPages = self:GetAttribute('countPages') or 0

		self:ClearAllPoints()
		self:SetPoint('RIGHT', self:GetParent(), 'LEFT', -2, 0)

		for i = 1, numPages do
			local b = myButtons[i]
			b:ClearAllPoints()
			if i == 1 then
				b:SetPoint('RIGHT', self, 'RIGHT', 0, 0)
			else
				b:SetPoint('RIGHT', myButtons[i - 1], 'LEFT', -2, 0)
			end
		end

		self:SetWidth(myButtons[1]:GetWidth()*numPages + 2*(numPages - 1))
		self:SetHeight(myButtons[1]:GetHeight())
	]])

	flyout:SetAttribute('layout-right', [[
		local numPages = self:GetAttribute('countPages') or 0

		self:ClearAllPoints()
		self:SetPoint('LEFT', self:GetParent(), 'RIGHT', 2, 0)

		for i = 1, #myButtons do
			local b = myButtons[i]
			b:ClearAllPoints()
			if i == 1 then
				b:SetPoint('LEFT', self, 'LEFT', 0, 0)
			else
				b:SetPoint('LEFT', myButtons[i - 1], 'RIGHT', 2, 0)
			end
		end

		self:SetWidth(myButtons[1]:GetWidth()*numPages + 2*(numPages - 1))
		self:SetHeight(myButtons[1]:GetHeight())
	]])

	flyout:SetAttribute('layout-top', [[
		local numPages = self:GetAttribute('countPages') or 0

		self:ClearAllPoints()
		self:SetPoint('BOTTOM', self:GetParent(), 'TOP', 0, 2)

		for i = 1, numPages do
			local b = myButtons[i]
			b:ClearAllPoints()
			if i == 1 then
				b:SetPoint('BOTTOM', self, 'BOTTOM', 0, 0)
			else
				b:SetPoint('BOTTOM', myButtons[i - 1], 'TOP', 0, 2)
			end
		end

		self:SetWidth(myButtons[1]:GetWidth())
		self:SetHeight(myButtons[1]:GetHeight()*numPages + 2*(numPages - 1))
	]])

	flyout:SetAttribute('layout-bottom', [[
		local numPages = self:GetAttribute('countPages') or 0

		self:ClearAllPoints()
		self:SetPoint('TOP', self:GetParent(), 'BOTTOM', 0, -2)

		for i = 1, numPages do
			local b = myButtons[i]
			b:ClearAllPoints()
			if i == 1 then
				b:SetPoint('TOP', self, 'TOP', 0, 0)
			else
				b:SetPoint('TOP', myButtons[i - 1], 'BOTTOM', 0, -2)
			end
		end

		self:SetWidth(myButtons[1]:GetWidth())
		self:SetHeight(myButtons[1]:GetHeight()*numPages + 2*(numPages - 1))
	]])

	flyout:SetScale(0.8)
	flyout:Hide()

	for i = 1, #TOTEM_MULTI_CAST_SUMMON_SPELLS do
		local b = Dominos.SpellButton:New()
		b:SetParent(flyout)
		b:SetAttribute('type', 'attribute')
		b:SetAttribute('attribute-name', 'state-page')
		b:SetAttribute('attribute-frame', self.header)

		flyout:WrapScript(b, 'PostClick', [[
			self:GetParent():Hide()
		]])

		flyout:SetFrameRef('addButton',  b)

		flyout:Execute([[
			local b = self:GetFrameRef('addButton')
			myButtons = myButtons or table.new()
			table.insert(myButtons, b)
			b:Hide()
		]])
	end

	return flyout
end


--[[
	Recall Button
--]]

function TotemBar:GetRecallButton()
	return self:CreateSpellButton(TOTEM_MULTI_CAST_RECALL_SPELLS[1])
end

function TotemBar:IsRecallKnown()
	return IsSpellKnown(TOTEM_MULTI_CAST_RECALL_SPELLS[1], false)
end


--[[
	base button templates
--]]

--spell
function TotemBar:CreateSpellButton(spellId)
	local b = Dominos.SpellButton:New(spellId)
	b:SetParent(self.header)
	return b
end

--action
function TotemBar:CreateActionButton(actionId)
	local b = Dominos.ActionButton:New(actionId)
	b:SetParent(self.header)
	b:LoadAction()
	return b
end


--[[ right click menu ]]--

function TotemBar:AddLayoutPanel(menu)
	local L = LibStub('AceLocale-3.0'):GetLocale('Dominos-Config', 'enUS')
	local panel = menu:AddLayoutPanel()

	--add show totemic recall toggle
	local showRecall = panel:NewCheckButton(L.ShowTotemRecall)

	showRecall:SetScript('OnClick', function(b)
		self:SetShowRecall(b:GetChecked());
		panel.colsSlider:OnShow() --force update the columns slider
	end)

	showRecall:SetScript('OnShow', function(b)
		b:SetChecked(self:ShowingRecall())
	end)

	--add show totems toggle
	local showTotems = panel:NewCheckButton(L.ShowTotems)

	showTotems:SetScript('OnClick', function(b)
		self:SetShowTotems(b:GetChecked());
		panel.colsSlider:OnShow()
	end)

	showTotems:SetScript('OnShow', function(b)
		b:SetChecked(self:ShowingTotems())
	end)
end

function TotemBar:CreateMenu()
	self.menu = Dominos:NewMenu(self.id)
	self:AddLayoutPanel(self.menu)
	self.menu:AddAdvancedPanel()
end


--[[ Totem Bar Loader ]]--

local DTB = Dominos:NewModule('Totems')

function DTB:Load()
	self.frame = TotemBar:New()
end

function DTB:Unload()
	self.frame:Free()
end