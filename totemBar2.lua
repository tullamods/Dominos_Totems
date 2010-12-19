--[[
	totemBar2.lua
		A totem bar for Dominos that mimics the standard totem bar
--]]

--hurray for constants
local MAX_TOTEMS = MAX_TOTEMS
local NUM_PAGES = NUM_MULTI_CAST_PAGES
local NUM_BUTTONS_PER_PAGE = NUM_MULTI_CAST_BUTTONS_PER_PAGE
local RECALL_SPELLS = TOTEM_MULTI_CAST_RECALL_SPELLS
local SUMMON_SPELLS = TOTEM_MULTI_CAST_SUMMON_SPELLS
local TOTEM_PRIORITIES = SHAMAN_TOTEM_PRIORITIES
local START_ACTION_ID = 132 --actionID start of the totembar


local TotemBar = Dominos:CreateClass('Frame', Dominos.Frame)

function TotemBar:New()
	local f = self.super.New(self, 'totem')
	f:LoadButtons()
	f:Layout()

	return f
end

function TotemBar:GetDefaults()
	return {
		point = 'CENTER',
		spacing = 2,
		showRecall = true,
		showTotems = true
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

function TotemBar:GetBaseID()
	return START_ACTION_ID
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
			local totem = self:GetTotemButton(totemId)
			self:LoadFlyoutButtons(totem, GetMultiCastTotemSpells(totemId))
			table.insert(buttons, totem)
		end
	end

	--add recall button
	if self:ShowingRecall() and self:IsRecallKnown() then
		table.insert(buttons, self:GetRecallButton())
	end

	self.header:Execute([[ control:ChildUpdate('action', nil) ]])
end

function TotemBar:IsCallKnown()
	return IsSpellKnown(TOTEM_MULTI_CAST_SUMMON_SPELLS[1], false)
end

function TotemBar:GetCallButton()
	return self:CreateSpellButton(TOTEM_MULTI_CAST_SUMMON_SPELLS[1])
end


function TotemBar:IsRecallKnown()
	return IsSpellKnown(TOTEM_MULTI_CAST_RECALL_SPELLS[1], false)
end

function TotemBar:GetRecallButton()
	return self:CreateSpellButton(TOTEM_MULTI_CAST_RECALL_SPELLS[1])
end


function TotemBar:GetTotemButton(id)
	local totem = self:CreateActionButton(self:GetBaseID() + id)
	totem:SetAttribute('totemId', id)
	totem:SetAttribute('type2', 'attribute')
	totem:SetAttribute('ctrl-type1', 'attribute')
	totem:SetAttribute('alt-type1', 'attribute')
	totem:SetAttribute('shift-type1', 'attribute')

	totem.flyout = self:CreateTotemFlyout(totem)
	totem:SetAttribute('attribute-frame', totem.flyout)
	totem:SetAttribute('attribute-name', 'toggleshown')
	totem:SetAttribute('attribute-value', true)

	return totem
end

function TotemBar:CreateSpellButton(spellID)
	local b = Dominos.SpellButton:New(spellID)
	b:SetParent(self.header)
	return b
end

function TotemBar:CreateActionButton(actionID)
	local b = Dominos.ActionButton:New(actionID)
	b:SetParent(self.header)
	b:LoadAction()
	return b
end

function TotemBar:CreateTotemFlyout(totem)
	local totemId = totem:GetAttribute('totemId')

	local frame = CreateFrame('Frame', nil, totem, 'SecureHandlerAttributeTemplate')
	frame:SetPoint('BOTTOM', totem, 'TOP', 0, 2)
	frame:SetSize(totem:GetWidth(), (totem:GetHeight() + 4) * 4)
	frame:SetScript('OnShow', function() RegisterAutoHide(frame, 0.2) end)

	frame:SetAttribute('_onattributechanged', [[
		if name == 'toggleshown' then
			if self:IsShown() then
				self:Hide()
			else
				self:Show()
			end
		end
	]])
	
	frame.buttons = {}
	frame:SetScale(0.8)
	frame:Hide()

	return frame
end

function TotemBar:LoadFlyoutButtons(totem, ...)
	local flyout = totem.flyout

	--create buttons
	for i = 1, select('#', ...) do
		local spellId = select(i, ...)
		local b = flyout.buttons[i]
		if b then
			b:SetSpell(spellId)
		else
			b = Dominos.SpellButton:New(spellId)
			b:SetParent(flyout)
			b:SetAttribute('type', 'multispell')
			b:SetAttribute('action', totem:GetAttribute('action'))
			flyout:WrapScript(b, 'PostClick', [[ self:GetParent():Hide() ]])
			
			table.insert(flyout.buttons, b)
		end
	end

	--layout buttons
	for i, b in pairs(flyout.buttons) do
		if i == 1 then
			b:SetPoint('BOTTOM', flyout, 'BOTTOM', 0, 0)
		else
			b:SetPoint('BOTTOM', flyout.buttons[i - 1], 'TOP', 0, 4)
		end
	end
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