-- Small geometry helpers for building the greybox house from code.
local Kit = {}

function Kit.part(props)
	local p = Instance.new(props.Class or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = props.Material or Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		if k ~= "Class" and k ~= "Parent" and k ~= "Material" then
			p[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

-- Axis-aligned box from two corners.
function Kit.box(parent, name, x1, y1, z1, x2, y2, z2, color, material, extra)
	local minX, maxX = math.min(x1, x2), math.max(x1, x2)
	local minY, maxY = math.min(y1, y2), math.max(y1, y2)
	local minZ, maxZ = math.min(z1, z2), math.max(z1, z2)
	local props = {
		Name = name,
		Size = Vector3.new(math.max(maxX - minX, 0.05), math.max(maxY - minY, 0.05), math.max(maxZ - minZ, 0.05)),
		CFrame = CFrame.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2),
		Color = color or Color3.fromRGB(200, 200, 200),
		Material = material,
		Parent = parent,
	}
	if extra then
		for k, v in pairs(extra) do
			props[k] = v
		end
	end
	return Kit.part(props)
end

-- Wall along the X axis at depth z, from x1 to x2, with door gaps {c = centerX, w = width, h = height}.
-- Returns the list of door centres it cut.
function Kit.wallX(parent, name, z, x1, x2, y0, h, doors, color, thickness)
	thickness = thickness or 1
	doors = doors or {}
	table.sort(doors, function(a, b)
		return a.c < b.c
	end)
	local cursor = x1
	local cuts = {}
	for _, d in ipairs(doors) do
		local a, b = d.c - d.w / 2, d.c + d.w / 2
		if a > cursor then
			Kit.box(parent, name, cursor, y0, z - thickness / 2, a, y0 + h, z + thickness / 2, color)
		end
		if (d.h or h) < h then
			Kit.box(parent, name .. "Lintel", a, y0 + d.h, z - thickness / 2, b, y0 + h, z + thickness / 2, color)
		end
		table.insert(cuts, { pos = Vector3.new(d.c, y0, z), axis = "X", width = d.w })
		cursor = b
	end
	if cursor < x2 then
		Kit.box(parent, name, cursor, y0, z - thickness / 2, x2, y0 + h, z + thickness / 2, color)
	end
	return cuts
end

-- Wall along the Z axis at x, from z1 to z2.
function Kit.wallZ(parent, name, x, z1, z2, y0, h, doors, color, thickness)
	thickness = thickness or 1
	doors = doors or {}
	table.sort(doors, function(a, b)
		return a.c < b.c
	end)
	local cursor = z1
	local cuts = {}
	for _, d in ipairs(doors) do
		local a, b = d.c - d.w / 2, d.c + d.w / 2
		if a > cursor then
			Kit.box(parent, name, x - thickness / 2, y0, cursor, x + thickness / 2, y0 + h, a, color)
		end
		if (d.h or h) < h then
			Kit.box(parent, name .. "Lintel", x - thickness / 2, y0 + d.h, a, x + thickness / 2, y0 + h, b, color)
		end
		table.insert(cuts, { pos = Vector3.new(x, y0, d.c), axis = "Z", width = d.w })
		cursor = b
	end
	if cursor < z2 then
		Kit.box(parent, name, x - thickness / 2, y0, cursor, x + thickness / 2, y0 + h, z2, color)
	end
	return cuts
end

function Kit.model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Kit.folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Kit.light(part, brightness, range, color, kind)
	local l = Instance.new(kind or "PointLight")
	l.Brightness = brightness
	l.Range = range
	l.Color = color or Color3.fromRGB(255, 196, 120)
	l.Shadows = true
	l.Parent = part
	return l
end

function Kit.label(part, face, text, textColor, bg)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 0
	g.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = bg and 0 or 1
	t.BackgroundColor3 = bg or Color3.new()
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = textColor or Color3.new(1, 1, 1)
	t.Parent = g
	return g, t
end

-- Thin string between two points (visual only).
function Kit.string(parent, a, b, color, width)
	local d = (b - a).Magnitude
	return Kit.part({
		Name = "String",
		Size = Vector3.new(width or 0.06, width or 0.06, d),
		CFrame = CFrame.lookAt((a + b) / 2, b),
		Color = color or Color3.fromRGB(235, 228, 210),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = parent,
	})
end

function Kit.prompt(parent, actionText, objectText, holdDuration, distance)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = actionText
	p.ObjectText = objectText or ""
	p.HoldDuration = holdDuration or 0
	p.MaxActivationDistance = distance or 9
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.Parent = parent
	return p
end

return Kit
