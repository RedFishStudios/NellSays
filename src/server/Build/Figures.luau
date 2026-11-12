-- Primitive-built stand-ins for Nell (marionette) and the Puppeteer.
local Kit = require(script.Parent.Kit)

local Figures = {}

local WOOD = Color3.fromRGB(226, 205, 168)
local WOOD_DARK = Color3.fromRGB(120, 84, 52)
local VELVET = Color3.fromRGB(110, 26, 32)
local IVORY = Color3.fromRGB(236, 228, 206)
local HAIR = Color3.fromRGB(22, 18, 20)
local BRASS = Color3.fromRGB(181, 140, 62)
local BLACK = Color3.fromRGB(10, 10, 10)
local STRING = Color3.fromRGB(235, 228, 210)

local function rel(model, pivot, name, size, offset, color, material, extra)
	local p = Kit.part({
		Name = name,
		Size = size,
		CFrame = pivot * offset,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})
	if extra then
		for k, v in pairs(extra) do
			p[k] = v
		end
	end
	return p
end

-- pivot: CFrame at the floor under Nell, facing the camera (LookVector = towards the viewer).
function Figures.nell(parent, pivot)
	local m = Kit.model(parent, "Nell")
	local P = function(...)
		return rel(m, pivot, ...)
	end
	local C = CFrame.new
	-- Feet hang just above the floor
	local root = P("Root", Vector3.new(1, 0.2, 1), C(0, 0.4, 0), WOOD, nil, { Transparency = 1 })
	m.PrimaryPart = root
	P("ShoeL", Vector3.new(0.45, 0.3, 0.7), C(-0.3, 0.55, -0.1), BLACK)
	P("ShoeR", Vector3.new(0.45, 0.3, 0.7), C(0.3, 0.55, -0.1), BLACK)
	P("LegL", Vector3.new(0.38, 1.3, 0.38), C(-0.3, 1.35, 0), WOOD, Enum.Material.Wood)
	P("LegR", Vector3.new(0.38, 1.3, 0.38), C(0.3, 1.35, 0), WOOD, Enum.Material.Wood)
	P("KneeL", Vector3.new(0.42, 0.14, 0.42), C(-0.3, 1.3, 0), BRASS, Enum.Material.Metal)
	P("KneeR", Vector3.new(0.42, 0.14, 0.42), C(0.3, 1.3, 0), BRASS, Enum.Material.Metal)
	P("Dress", Vector3.new(1.5, 1.6, 1), C(0, 2.55, 0), VELVET, Enum.Material.Fabric)
	P("Skirt", Vector3.new(1.8, 0.5, 1.2), C(0, 1.95, 0), VELVET, Enum.Material.Fabric)
	P("Collar", Vector3.new(1.1, 0.18, 0.85), C(0, 3.38, 0), IVORY, Enum.Material.Fabric)
	P("ArmL", Vector3.new(0.34, 1.4, 0.34), C(-0.95, 2.55, 0), WOOD, Enum.Material.Wood)
	P("ArmR", Vector3.new(0.34, 1.4, 0.34), C(0.95, 2.55, 0), WOOD, Enum.Material.Wood)
	P("SleeveL", Vector3.new(0.5, 0.45, 0.5), C(-0.95, 3.1, 0), VELVET, Enum.Material.Fabric)
	P("SleeveR", Vector3.new(0.5, 0.45, 0.5), C(0.95, 3.1, 0), VELVET, Enum.Material.Fabric)
	P("WristL", Vector3.new(0.4, 0.14, 0.4), C(-0.95, 2.1, 0), BRASS, Enum.Material.Metal)
	P("WristR", Vector3.new(0.4, 0.14, 0.4), C(0.95, 2.1, 0), BRASS, Enum.Material.Metal)
	-- Head (face is on the -Z side of the pivot frame, i.e. towards the viewer)
	local head = P("Head", Vector3.new(1.3, 1.45, 1.1), C(0, 4.15, 0), WOOD, Enum.Material.Wood)
	P("HairTop", Vector3.new(1.6, 0.5, 1.35), C(0, 4.95, 0.05), HAIR)
	P("HairBack", Vector3.new(1.6, 1.5, 0.3), C(0, 4.3, 0.6), HAIR)
	P("HairL", Vector3.new(0.18, 1.45, 1.3), C(-0.78, 4.35, 0.05), HAIR)
	P("HairR", Vector3.new(0.18, 1.45, 1.3), C(0.78, 4.35, 0.05), HAIR)
	P("Fringe", Vector3.new(1.4, 0.35, 0.12), C(0, 4.62, -0.57), HAIR)
	P("EyeL", Vector3.new(0.12, 0.12, 0.05), C(-0.27, 4.25, -0.56), BLACK)
	P("EyeR", Vector3.new(0.12, 0.12, 0.05), C(0.27, 4.25, -0.56), BLACK)
	P(
		"CheekL",
		Vector3.new(0.05, 0.22, 0.22),
		C(-0.36, 3.98, -0.565) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(205, 110, 95)
	)
	P(
		"CheekR",
		Vector3.new(0.05, 0.22, 0.22),
		C(0.36, 3.98, -0.565) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(205, 110, 95)
	)
	-- Idle mouth: one straight line with brass jaw hinges
	local idle = { P("MouthIdle", Vector3.new(0.62, 0.07, 0.05), C(0, 3.72, -0.56), BLACK) }
	P("HingeL", Vector3.new(0.14, 0.22, 0.05), C(-0.4, 3.72, -0.565), BRASS, Enum.Material.Metal)
	P("HingeR", Vector3.new(0.14, 0.22, 0.05), C(0.4, 3.72, -0.565), BRASS, Enum.Material.Metal)
	for _, p in ipairs(idle) do
		p:SetAttribute("Expr", "idle")
	end
	-- Smile: wide mouth pulled up at the corners by two hidden strings
	local smile = {
		P("SmileMid", Vector3.new(0.7, 0.16, 0.05), C(0, 3.66, -0.565), Color3.fromRGB(40, 0, 0)),
		P("SmileL", Vector3.new(0.4, 0.1, 0.05), C(-0.48, 3.8, -0.565) * CFrame.Angles(0, 0, math.rad(-35)), BLACK),
		P("SmileR", Vector3.new(0.4, 0.1, 0.05), C(0.48, 3.8, -0.565) * CFrame.Angles(0, 0, math.rad(35)), BLACK),
		P("TeethL", Vector3.new(0.12, 0.08, 0.05), C(-0.15, 3.7, -0.57), IVORY),
		P("TeethR", Vector3.new(0.12, 0.08, 0.05), C(0.15, 3.7, -0.57), IVORY),
	}
	local cornerL = pivot * Vector3.new(-0.62, 3.92, -0.58)
	local cornerR = pivot * Vector3.new(0.62, 3.92, -0.58)
	local s1 = Kit.string(m, cornerL, pivot * Vector3.new(-1.6, 8.5, -0.6), Color3.fromRGB(150, 20, 20), 0.05)
	local s2 = Kit.string(m, cornerR, pivot * Vector3.new(1.6, 8.5, -0.6), Color3.fromRGB(150, 20, 20), 0.05)
	s1.Name, s2.Name = "SmileStringL", "SmileStringR"
	table.insert(smile, s1)
	table.insert(smile, s2)
	for _, p in ipairs(smile) do
		p:SetAttribute("Expr", "smile")
		p.Transparency = 1
	end
	-- Blood streams (grown by the client during the reveal)
	for _, side in ipairs({ -1, 1 }) do
		local b = P(
			side < 0 and "BloodL" or "BloodR",
			Vector3.new(0.07, 0.05, 0.04),
			C(side * 0.27, 4.17, -0.57),
			Color3.fromRGB(150, 0, 0),
			Enum.Material.Glass
		)
		b:SetAttribute("Expr", "blood")
		b:SetAttribute("Side", side)
		b.Transparency = 1
	end
	-- Crossbar and the five everyday strings (crown, wrists, knees)
	local barY = 8.5
	P("Crossbar", Vector3.new(3.2, 0.25, 0.3), C(0, barY, 0), WOOD_DARK, Enum.Material.Wood)
	P("Crossbar2", Vector3.new(0.3, 0.25, 2.2), C(0, barY, 0), WOOD_DARK, Enum.Material.Wood)
	local anchors = {
		{ Vector3.new(0, 5.2, 0), Vector3.new(0, barY, 0) },
		{ Vector3.new(-0.95, 2.0, 0), Vector3.new(-1.5, barY, 0) },
		{ Vector3.new(0.95, 2.0, 0), Vector3.new(1.5, barY, 0) },
		{ Vector3.new(-0.3, 1.3, 0), Vector3.new(-0.3, barY, -1) },
		{ Vector3.new(0.3, 1.3, 0), Vector3.new(0.3, barY, 1) },
	}
	for _, a in ipairs(anchors) do
		Kit.string(m, pivot * a[1], pivot * a[2], STRING, 0.04)
	end
	m:SetAttribute("BasePivot", nil)
	head:SetAttribute("IsHead", true)
	return m
end

-- The Puppeteer: 13-stud stagehand in black canvas, four arms, split wooden mask, crossbar.
-- Returns a model with two sub-models: Lower (legs) and Upper (torso, arms, head, crossbar).
-- The Upper pivot is at hip height (y=5) so it can be lowered/tilted to fold through doors.
function Figures.puppeteer(parent, name)
	local m = Kit.model(parent, name or "Puppeteer")
	local lower = Kit.model(m, "Lower")
	local upper = Kit.model(m, "Upper")
	local base = CFrame.new()
	local CANVAS = Color3.fromRGB(18, 18, 20)
	local MASK = Color3.fromRGB(200, 180, 140)
	local function L(...)
		return rel(lower, base, ...)
	end
	local function U(...)
		return rel(upper, base, ...)
	end
	local C = CFrame.new
	local root = L("Root", Vector3.new(2, 2, 2), C(0, 1, 0), CANVAS, nil, { Transparency = 1 })
	lower.PrimaryPart = root
	L("LegL", Vector3.new(0.9, 5, 0.9), C(-0.8, 2.5, 0), CANVAS, Enum.Material.Fabric)
	L("LegR", Vector3.new(0.9, 5, 0.9), C(0.8, 2.5, 0), CANVAS, Enum.Material.Fabric)
	L("Hips", Vector3.new(2.4, 1, 1.2), C(0, 5, 0), CANVAS, Enum.Material.Fabric)
	local hip = U("Hip", Vector3.new(0.5, 0.5, 0.5), C(0, 5, 0), CANVAS, nil, { Transparency = 1 })
	upper.PrimaryPart = hip
	U("Torso", Vector3.new(2.6, 4.5, 1.4), C(0, 7.6, 0), CANVAS, Enum.Material.Fabric)
	U("Shoulders", Vector3.new(3.6, 0.8, 1.4), C(0, 9.8, 0), CANVAS, Enum.Material.Fabric)
	U("Neck", Vector3.new(0.6, 0.8, 0.6), C(0, 10.5, 0), CANVAS)
	U("Head", Vector3.new(1.6, 2, 1.5), C(0, 11.7, 0), CANVAS, Enum.Material.Fabric)
	-- Split wooden mask (front is -Z)
	U("MaskL", Vector3.new(0.72, 1.9, 0.2), C(-0.42, 11.7, -0.82), MASK, Enum.Material.Wood)
	U(
		"MaskR",
		Vector3.new(0.72, 1.9, 0.2),
		C(0.42, 11.7, -0.82) * CFrame.Angles(0, 0, math.rad(4)),
		MASK,
		Enum.Material.Wood
	)
	U("SlotL", Vector3.new(0.4, 0.12, 0.05), C(-0.42, 12.0, -0.94), BLACK)
	U("SlotR", Vector3.new(0.4, 0.12, 0.05), C(0.42, 12.0, -0.94), BLACK)
	-- Upper arms raised holding the crossbar
	U(
		"UpperArmL",
		Vector3.new(0.5, 3.4, 0.5),
		C(-1.9, 11.2, -0.6) * CFrame.Angles(math.rad(-20), 0, math.rad(-15)),
		CANVAS
	)
	U(
		"UpperArmR",
		Vector3.new(0.5, 3.4, 0.5),
		C(1.9, 11.2, -0.6) * CFrame.Angles(math.rad(-20), 0, math.rad(15)),
		CANVAS
	)
	U("CrossbarA", Vector3.new(5, 0.3, 0.3), C(0, 13, -1.2), WOOD_DARK, Enum.Material.Wood)
	U("CrossbarB", Vector3.new(0.3, 0.3, 2.5), C(0, 13, -1.2), WOOD_DARK, Enum.Material.Wood)
	for i = -2, 2 do
		local s = Kit.string(
			upper,
			Vector3.new(i * 1.1, 13, -1.2),
			Vector3.new(i * 1.1, 9 + math.abs(i) * 0.6, -1.4),
			STRING,
			0.04
		)
		s.Name = "BarString"
	end
	-- Lower arms hang nearly to the floor, hinged and long
	U("LowerArmL", Vector3.new(0.45, 7.5, 0.45), C(-2.1, 6.2, 0) * CFrame.Angles(0, 0, math.rad(-6)), CANVAS)
	U("LowerArmR", Vector3.new(0.45, 7.5, 0.45), C(2.1, 6.2, 0) * CFrame.Angles(0, 0, math.rad(6)), CANVAS)
	for _, side in ipairs({ -1, 1 }) do
		U(
			side < 0 and "HandL" or "HandR",
			Vector3.new(0.7, 1.1, 0.35),
			C(side * 2.5, 2.2, -0.1),
			MASK,
			Enum.Material.Wood
		)
		for f = 0, 2 do
			U(
				"Finger",
				Vector3.new(0.12, 0.9, 0.12),
				C(side * 2.5 + (f - 1) * 0.2, 1.3, -0.15),
				MASK,
				Enum.Material.Wood
			)
		end
	end
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	return m
end

return Figures
