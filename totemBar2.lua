--[[
	totemBar2.lua
		A totem bar for Dominos that mimics the standard totem bar
--]]

if not select(2, UnitClass('player')) == 'SHAMAN' then
	return
end

--hurray for constants
local MAX_TOTEMS = MAX_TOTEMS
local TOTEM_MULTI_CAST_RECALL_SPELLS = TOTEM_MULTI_CAST_RECALL_SPELLS
local TOTEM_MULTI_CAST_SUMMON_SPELLS = TOTEM_MULTI_CAST_SUMMON_SPELLS
local TOTEM_PRIORITIES = SHAMAN_TOTEM_PRIORITIES
local START_ACTION_ID = 132 --actionID start of the totembar
local MAX_FLYOUT_BUTTONS = 6

--flyout layout code
local flyout_doLayout = [[
	local numButtons, direction = ...
	local point, relPoint, xOff, yOff

	if direction == 'left' then
		point = 'RIGHT'
		relPoint = 'LEFT'
		xOff = -4
		yOff = 0
	elseif direction == 'right' then
		point = 'LEFT'
		relPoint = 'RIGHT'
		xOff = 4
		yOff = 0
	elseif direction == 'top' then
		point = 'BOTTOM'
		relPoint = 'TOP'
		xOff = 0
		yOff = 4
	elseif direction == 'bottom' then
		point = 'TOP'
		relPoint = 'BOTTOM'
		xOff = 0
		yOff = -4
	end

	self:ClearAllPoints()
	self:SetPoint(point, self:GetParent(), relPoint, xOff, yOff)

	for i = 1, numButtons do
		local b = myButtons[i]
		b:ClearAllPoints()
		if i == 1 then
			b:SetPoint(point, self, point, 0, 0)
		else
			b:SetPoint(point, myButtons[i - 1], relPoint, xOff, yOff)
		end
	end

	if numButtons > 0 then
		if direction == 'left' or direction == 'right' then
			self:SetWidth(myButtons[1]:GetWidth()*numButtons + math.abs(xOff)*(numButtons - 1))
			self:SetHeight(myButtons[1]:GetHeight())
		else
			self:SetWidth(myButtons[1]:GetWidth())
			self:SetHeight(myButtons[1]:GetHeight()*numButtons + math.abs(yOff)*(numButtons - 1))
		end
	else
		self:SetWidth(0)
		self:SetHeight(0)
	end
]]


local TotemBar = Dominos:CreateClass('Frame', Dominos.Frame)

function TotemBar:New(pageId)
	local f = self.super.New(self, 'totem' .. pageId)
	f.totemId = pageId
	f:LoadButtons()
	f:Layout()

	return f
end

function TotemBar:Create(id)
	local f = self.super.Create(self, id)

	f.header:SetFrameRef('UIParent', UIParent)

	f.header:SetAttribute('getFlyoutDirection', [[
		local isVertical = ...
		local UIParent = self:GetFrameRef('UIParent')

		if isVertical then
			local x, y = UIParent:GetMousePosition()
			if x < 0.5 then
				return 'right'
			end
			return 'left'
		end

		local x, y = UIParent:GetMousePosition()
		if y < 0.5 then
			return 'top'
		end
		return 'bottom'
	]])

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
		local isVertical = floor(self:GetParent():GetWidth()) < floor(self:GetParent():GetHeight())
		local direction = self:RunAttribute('getFlyoutDirection', isVertical)
		totemFlyout:RunAttribute('layout', totemFlyout:GetAttribute('numTotems'), direction)
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
		local isVertical = floor(self:GetParent():GetWidth()) < floor(self:GetParent():GetHeight())
		local direction = self:RunAttribute('getFlyoutDirection', isVertical)
		flyout:RunAttribute('layout', self:GetAttribute('numPages'), direction)
		flyout:Show()
	]])

	--paging stuff
	f.header:SetAttribute('baseId', START_ACTION_ID)
	f.header:SetAttribute('maxTotems', MAX_TOTEMS)
	f.header:SetAttribute('numPages', #TOTEM_MULTI_CAST_SUMMON_SPELLS)

	f.header:SetAttribute('_onstate-page', [[
		self:CallMethod('SetPage', page)
		self:ChildUpdate('page', newstate or 1)
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
		page = self.totemId or 1,
		hidden = self.totemId > 1
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

	if self:ShowingRecall() then
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
	return self.sets.showRecall and self:IsRecallKnown()
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
	for i, button in pairs(buttons) do
		self:RemoveButton(i)
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
	if self:ShowingRecall() then
		table.insert(buttons, self:GetRecallButton())
	end

	self.header:Execute([[ control:ChildUpdate('page', self:GetAttribute('state-page')) ]])
end


--[[
	Totem Button
--]]

function TotemBar:GetTotemButton(id)
	local totem = self:CreateActionButton(id + START_ACTION_ID + (self.totemId - 1) * MAX_TOTEMS)
	totem:SetAttribute('totemId', id)
	totem:SetAttribute('type2', 'attribute')
	totem:SetAttribute('alt-type1', 'attribute')
	totem:SetAttribute('shift-type1', 'attribute')
	totem:SetAttribute('ctrl-type1', 'attribute')
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

	flyout:SetAttribute('layout', flyout_doLayout)

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

	--add recall spells
	totemCall:SetAttribute('alt-type1', 'spell')
	totemCall:SetAttribute('alt-spell1', TOTEM_MULTI_CAST_RECALL_SPELLS[1])

	totemCall:SetAttribute('type3', 'spell')
	totemCall:SetAttribute('spell3', TOTEM_MULTI_CAST_RECALL_SPELLS[1])

	totemCall:SetAttribute('type2', 'attribute')
	totemCall:SetAttribute('ctrl-type1', 'attribute')
--	totemCall:SetAttribute('alt-type1', 'attribute')
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

	totemCall:SetAttribute('_childupdate-page', [[
		local page = message or 1

		self:SetAttribute('spell', self:GetAttribute('spell-page' .. page))
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
	flyout:SetScale(0.8)
	flyout:Hide()

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

	flyout:SetAttribute('layout', flyout_doLayout)

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

	b:SetAttribute('showgrid', 1)
	b:SetAttribute('_childupdate-page', [[
		local page = message or 1
		local startId = self:GetParent():GetAttribute('baseId') + (page - 1) * self:GetParent():GetAttribute('maxTotems')

		self:SetAttribute('action', startId + self:GetAttribute('totemId'))
	]])

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

function TotemBar:UPDATE_BINDINGS()
	for _,b in pairs(self.buttons) do
		b:UpdateHotkey(b.buttonType)
	end
end


--[[ Totem Bar Loader ]]--

local DTB = Dominos:NewModule('Totems')

function DTB:Load()
	for i = 1, #TOTEM_MULTI_CAST_SUMMON_SPELLS do
		TotemBar:New(i)
	end
end

function DTB:Unload()
	for i = 1, #TOTEM_MULTI_CAST_SUMMON_SPELLS do
		local f = Dominos.Frame:Get('totem' .. i)
		if f then
			f:Free()
		end
	end
end