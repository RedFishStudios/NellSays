-- House lighting cues. Floor strips and station controls stay lit.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local State = require(script.Parent.State)

local Lights = {}
local H

function Lights.bind(house)
	H = house
	Lighting.ClockTime = 20.6
	Lighting.Brightness = 0.6
	Lighting.Ambient = Color3.fromRGB(40, 36, 44)
	Lighting.OutdoorAmbient = Color3.fromRGB(40, 44, 58)
	Lighting.EnvironmentDiffuseScale = 0.2
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.FogColor = Color3.fromRGB(20, 22, 30)
	Lighting.FogEnd = 400
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	Lights.set("normal")
end

local function each(fn)
	for _, l in ipairs(H.lights) do
		fn(l)
	end
end

-- mode: "normal" | "dim" | "dark"
function Lights.set(mode, fade)
	State.set("Lights", mode)
	each(function(l)
		local base = l.light:GetAttribute("Base") or 1
		local target = mode == "normal" and base or (mode == "dim" and base * 0.35 or 0)
		if fade then
			TweenService:Create(l.light, TweenInfo.new(fade), { Brightness = target }):Play()
		else
			l.light.Brightness = target
		end
		l.bulb.Material = target > 0.05 and Enum.Material.Neon or Enum.Material.SmoothPlastic
		l.bulb.Color = target > 0.05 and Color3.fromRGB(255, 186, 110) or Color3.fromRGB(70, 60, 50)
	end)
	Lighting.Ambient = mode == "normal" and Color3.fromRGB(40, 36, 44) or Color3.fromRGB(14, 12, 18)
end

-- Dip a room (or all) briefly, then return to `level` fraction of base.
function Lights.dip(roomName, seconds, level)
	each(function(l)
		if roomName == nil or l.room == roomName then
			local base = l.light:GetAttribute("Base") or 1
			local back = base * (level or 1)
			l.light.Brightness = base * 0.1
			task.delay(seconds or 0.4, function()
				TweenService:Create(l.light, TweenInfo.new(0.6), { Brightness = back }):Play()
			end)
		end
	end)
end

function Lights.exitGuides(on)
	H.porchLight.Enabled = on
	H.carportLight.Enabled = on
end

return Lights
