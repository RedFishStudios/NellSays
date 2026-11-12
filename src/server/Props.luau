-- Interaction props (ProximityPrompts). Everything a cue can ask players to touch goes through here.
local Roster = require(script.Parent.Roster)
local State = require(script.Parent.State)
local Fx = State.Fx

local Props = {}
local H
local listeners = {}
local nextId = 0
Props.unlocked = { FrontDoor = false, UtilityDoor = false }

function Props.listen(fn)
	nextId += 1
	local id = nextId
	listeners[id] = fn
	return function()
		listeners[id] = nil
	end
end

function Props.get(id)
	return H and H.props[id]
end

function Props.setEnabled(id, on)
	local p = Props.get(id)
	if p then
		p.prompt.Enabled = on
	end
end

function Props.setText(id, action, object)
	local p = Props.get(id)
	if p then
		p.prompt.ActionText = action
		if object then
			p.prompt.ObjectText = object
		end
	end
end

function Props.setHold(id, seconds)
	local p = Props.get(id)
	if p then
		p.prompt.HoldDuration = seconds
	end
end

local defaultBehaviour = {
	FrontDoor = function(player)
		if not Props.unlocked.FrontDoor then
			Fx.sfx("HandleRattle", H.frontDoor.Position)
			Fx.toast("The front door is locked. The deadbolt will not move.", { player })
		end
	end,
	UtilityDoor = function(player)
		if not Props.unlocked.UtilityDoor then
			Fx.sfx("HandleRattle", H.utilityDoor.Position)
			Fx.toast("The teal door to the carport is locked.", { player })
		end
	end,
	Lamp = function()
		H.denLamp.Enabled = not H.denLamp.Enabled
		Fx.sfx("Click", H.props.Lamp.part.Position)
	end,
	Curtain = function(player)
		Fx.sfx("WoodClick", H.props.Curtain.part.Position)
	end,
}

function Props.bind(house)
	H = house
	for id, p in pairs(H.props) do
		p.prompt.Triggered:Connect(function(player)
			if not Roster.isLiving(player) then
				return
			end
			if player:GetAttribute("Hidden") then
				return
			end
			local fn = defaultBehaviour[id]
			if fn then
				fn(player)
			end
			for _, l in pairs(listeners) do
				task.spawn(l, player, id)
			end
		end)
	end
	-- Phone is only "answerable" during Mum's Call; Eject/Break/Relay only in the finale
	for _, id in ipairs({ "Relay" }) do
		Props.setEnabled(id, false)
	end
end

function Props.reset()
	Props.unlocked.FrontDoor = false
	Props.unlocked.UtilityDoor = false
	if H then
		Props.setText("Phone", "Touch", "Phone console")
		Props.setText("Deck", "Use", "DVD deck")
		Props.setHold("Deck", 0)
		Props.setEnabled("Relay", false)
	end
end

return Props
