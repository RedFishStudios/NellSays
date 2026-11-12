-- Builds the playable house from the GDD floor plans (origin = front-left interior corner,
-- +X east, +Z towards the back, ground floor top at y = 0, upstairs at y = 14).
local Kit = require(script.Parent.Kit)
local Figures = require(script.Parent.Figures)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local House = {}

local CREAM = Color3.fromRGB(232, 222, 196)
local OAK = Color3.fromRGB(78, 52, 34)
local OAK_LIGHT = Color3.fromRGB(120, 84, 52)
local BLUE_CLAP = Color3.fromRGB(70, 104, 150)
local DOOR_RED = Color3.fromRGB(150, 32, 30)
local TEAL = Color3.fromRGB(30, 120, 120)
local OLIVE = Color3.fromRGB(96, 104, 54)
local MUSTARD = Color3.fromRGB(196, 150, 50)
local SILVER = Color3.fromRGB(170, 172, 176)
local BLACK = Color3.fromRGB(12, 12, 12)
local AMBER = Color3.fromRGB(255, 186, 110)
local WHITE = Color3.fromRGB(240, 240, 235)

local CEIL = 13
local UP = 14
local DOOR = { w = 8, h = 10.5 }

local function d(c)
	return { c = c, w = DOOR.w, h = DOOR.h }
end

local Rooms = {
	{ name = "Den", floor = 0, x1 = 0, z1 = 0, x2 = 30, z2 = 26 },
	{ name = "Entry", floor = 0, x1 = 30, z1 = 0, x2 = 45, z2 = 26 },
	{ name = "Dining", floor = 0, x1 = 45, z1 = 0, x2 = 76, z2 = 26 },
	{ name = "Kitchen", floor = 0, x1 = 0, z1 = 26, x2 = 30, z2 = 58 },
	{ name = "Rear hall", floor = 0, x1 = 30, z1 = 26, x2 = 45, z2 = 58 },
	{ name = "Utility", floor = 0, x1 = 45, z1 = 26, x2 = 76, z2 = 58 },
	{ name = "Carport", floor = 0, x1 = 76, z1 = -14, x2 = 98, z2 = 58 },
	{ name = "Kid's bedroom", floor = 1, x1 = 0, z1 = 0, x2 = 30, z2 = 30 },
	{ name = "Edit room", floor = 1, x1 = 0, z1 = 30, x2 = 30, z2 = 58 },
	{ name = "Landing", floor = 1, x1 = 30, z1 = 0, x2 = 46, z2 = 58 },
	{ name = "Main bedroom", floor = 1, x1 = 46, z1 = 0, x2 = 76, z2 = 30 },
	{ name = "Bathroom", floor = 1, x1 = 46, z1 = 30, x2 = 76, z2 = 58 },
	{ name = "Studio", floor = 0, x1 = 140, z1 = -10, x2 = 200, z2 = 40 },
}

function House.roomAt(pos)
	local floor = pos.Y > CEIL - 1 and 1 or 0
	for _, r in ipairs(Rooms) do
		if
			(r.floor == floor or r.name == "Carport" or r.name == "Studio")
			and pos.X >= r.x1
			and pos.X <= r.x2
			and pos.Z >= r.z1
			and pos.Z <= r.z2
		then
			return r.name
		end
	end
	if pos.Z < 0 then
		return "Front yard"
	end
	return "Outside"
end

function House.build()
	local old = workspace:FindFirstChild("House")
	if old then
		old:Destroy()
	end
	local oldStudio = workspace:FindFirstChild("StudioSet")
	if oldStudio then
		oldStudio:Destroy()
	end
	for _, n in ipairs({ "Baseplate", "SpawnLocation" }) do
		local x = workspace:FindFirstChild(n)
		if x then
			x:Destroy()
		end
	end

	local root = Kit.folder(workspace, "House")
	local shell = Kit.folder(root, "Shell")
	local furn = Kit.folder(root, "Furniture")
	local marksF = Kit.folder(root, "Marks")
	local propsF = Kit.folder(root, "Props")
	local lightsF = Kit.folder(root, "Lights")
	local zonesF = Kit.folder(root, "Zones")
	local hidesF = Kit.folder(root, "HideSpots")
	local scareF = Kit.folder(root, "Scares")

	local H = {
		root = root,
		marks = {},
		props = {},
		hideSpots = {},
		zones = {},
		doors = {},
		lights = {},
		scares = {},
		roomAt = House.roomAt,
		rooms = Rooms,
	}

	local function addDoors(list, label)
		for _, c in ipairs(list) do
			c.label = label
			table.insert(H.doors, c)
		end
	end

	---------------------------------------------------------------- outside
	Kit.box(shell, "Grass", -60, -1.4, -40, 210, -1, 110, Color3.fromRGB(52, 72, 44), Enum.Material.Grass)
	Kit.box(shell, "Street", -60, -1.05, -36, 210, -0.95, -20, Color3.fromRGB(34, 34, 38), Enum.Material.Asphalt)
	Kit.box(shell, "Sidewalk", -60, -1, -20, 120, -0.7, -16, Color3.fromRGB(120, 120, 118), Enum.Material.Concrete)
	local streetLine = Kit.box(
		shell,
		"StreetLine",
		-60,
		-0.69,
		-16.6,
		120,
		-0.66,
		-16.2,
		Color3.fromRGB(240, 220, 90),
		Enum.Material.Neon
	)
	streetLine.CanCollide = false
	H.exitZ = -16.4
	-- Fence with a front gate (x38) and a side-drive gate (x85)
	local FENCE = Color3.fromRGB(225, 225, 215)
	Kit.wallX(shell, "Fence", -14, -12, 100, -1, 8, { { c = 38, w = 6, h = 8 }, { c = 85, w = 8, h = 8 } }, FENCE, 0.6)
	Kit.wallZ(shell, "Fence", -12, -14, 66, -1, 8, {}, FENCE, 0.6)
	Kit.wallZ(shell, "Fence", 100, -14, 66, -1, 8, {}, FENCE, 0.6)
	Kit.wallX(shell, "Fence", 66, -12, 100, -1, 8, {}, FENCE, 0.6)
	local frontGate = Kit.box(
		propsF,
		"FrontGate",
		35,
		-1,
		-14.3,
		41,
		7,
		-13.7,
		Color3.fromRGB(245, 245, 240),
		Enum.Material.WoodPlanks
	)
	local sideGate = Kit.box(
		propsF,
		"SideGate",
		81,
		-1,
		-14.3,
		89,
		7,
		-13.7,
		Color3.fromRGB(140, 140, 145),
		Enum.Material.DiamondPlate
	)
	H.frontGate, H.sideGate = frontGate, sideGate
	-- Porch, path and carport
	Kit.box(shell, "Porch", 32, -1, -7, 44, 0, 0, OAK_LIGHT, Enum.Material.WoodPlanks)
	Kit.box(shell, "PorchRoof", 31, 11, -8, 45, 11.5, 0, Color3.fromRGB(60, 60, 64))
	Kit.box(shell, "PorchPostL", 32, 0, -7.6, 32.6, 11, -7, WHITE)
	Kit.box(shell, "PorchPostR", 43.4, 0, -7.6, 44, 11, -7, WHITE)
	local porchBulb = Kit.box(lightsF, "PorchBulb", 37.6, 9.6, -1.2, 38.4, 10.4, -0.4, AMBER, Enum.Material.Neon)
	H.porchLight = Kit.light(porchBulb, 1.6, 22, AMBER)
	Kit.box(shell, "Path", 36, -1, -14, 40, -0.6, -7, Color3.fromRGB(130, 128, 120), Enum.Material.Concrete)
	Kit.box(furn, "CoirMat", 35.5, 0, -2.5, 40.5, 0.06, -0.5, Color3.fromRGB(150, 110, 60), Enum.Material.Fabric)
	Kit.box(furn, "Boots", 42, 0, -2, 43, 1.4, -1, Color3.fromRGB(240, 200, 40), Enum.Material.Rubber)
	Kit.box(furn, "Letterbox", 32.5, -1, -13.4, 33.5, 3.5, -12.6, Color3.fromRGB(120, 30, 30), Enum.Material.Metal)
	Kit.box(furn, "Hedge", -10, -1, -12.5, 30, 2.5, -10, Color3.fromRGB(40, 80, 40), Enum.Material.Grass)
	Kit.box(shell, "CarportFloor", 76.5, -1, -14, 98, -0.5, 58, Color3.fromRGB(110, 110, 110), Enum.Material.Concrete)
	Kit.box(
		shell,
		"CarportRoof",
		76.5,
		11,
		26,
		98,
		11.4,
		58,
		Color3.fromRGB(150, 155, 160),
		Enum.Material.CorrodedMetal
	)
	for _, z in ipairs({ 27, 42, 57 }) do
		Kit.box(
			shell,
			"CarportPost",
			97,
			-0.5,
			z - 0.4,
			97.8,
			11,
			z + 0.4,
			Color3.fromRGB(90, 90, 90),
			Enum.Material.Metal
		)
	end
	local carportBulb = Kit.box(lightsF, "CarportBulb", 85, 10.2, 40, 86, 10.9, 41, AMBER, Enum.Material.Neon)
	H.carportLight = Kit.light(carportBulb, 1.4, 26, AMBER)
	H.porchLight.Enabled = false
	H.carportLight.Enabled = false

	---------------------------------------------------------------- ground floor
	local floors = {
		{ "Den", 0, 0, 30, 26, Color3.fromRGB(110, 86, 62), Enum.Material.Carpet },
		{ "Entry", 30, 0, 45, 26, OAK, Enum.Material.WoodPlanks },
		{ "Dining", 45, 0, 76, 26, OAK, Enum.Material.WoodPlanks },
		{ "Kitchen", 0, 26, 30, 58, Color3.fromRGB(205, 205, 200), Enum.Material.Marble },
		{ "RearHall", 30, 26, 45, 58, OAK, Enum.Material.WoodPlanks },
		{ "Utility", 45, 26, 76, 58, Color3.fromRGB(140, 140, 135), Enum.Material.Concrete },
	}
	for _, f in ipairs(floors) do
		Kit.box(shell, "Floor" .. f[1], f[2], -1, f[3], f[4], 0, f[5], f[6], f[7])
	end
	-- exterior walls (blue clapboard outside, cream inside)
	addDoors(Kit.wallX(shell, "WallS", 0, -0.5, 76.5, 0, UP, { d(38) }, CREAM), "Front door")
	Kit.wallX(shell, "WallN", 58, -0.5, 76.5, 0, UP, {}, CREAM)
	Kit.wallZ(shell, "WallW", 0, 0, 58, 0, UP, {}, CREAM)
	addDoors(Kit.wallZ(shell, "WallE", 76, 0, 58, 0, UP, { d(41) }, CREAM), "Utility door")
	Kit.wallX(shell, "SkinS", -0.7, -0.9, 76.9, -1, 28, { { c = 38, w = 8, h = 11.5 } }, BLUE_CLAP, 0.4)
	Kit.wallX(shell, "SkinN", 58.7, -0.9, 76.9, -1, 28, {}, BLUE_CLAP, 0.4)
	Kit.wallZ(shell, "SkinW", -0.7, -0.5, 58.5, -1, 28, {}, BLUE_CLAP, 0.4)
	Kit.wallZ(shell, "SkinE", 76.7, -0.5, 58.5, -1, 28, { { c = 41, w = 8, h = 11.5 } }, BLUE_CLAP, 0.4)
	-- interior walls
	addDoors(Kit.wallZ(shell, "WallDenEntry", 30, 0.5, 57.5, 0, CEIL, { d(9), d(43) }, CREAM), "Interior")
	addDoors(Kit.wallZ(shell, "WallEntryDining", 45, 0.5, 57.5, 0, CEIL, { d(4.6), d(46) }, CREAM), "Interior")
	addDoors(Kit.wallX(shell, "WallMid", 26, 0.5, 75.5, 0, CEIL, { d(16), d(34.5), d(60) }, CREAM), "Interior")
	-- upstairs floor slab with stairwell hole x38.5-44.5, z8-24.8
	local SLAB = Color3.fromRGB(60, 78, 128)
	Kit.box(shell, "UpFloor", 0, CEIL, 0, 38.5, UP, 58, SLAB, Enum.Material.Carpet)
	Kit.box(shell, "UpFloor", 44.5, CEIL, 0, 76, UP, 58, SLAB, Enum.Material.Carpet)
	Kit.box(shell, "UpFloor", 38.5, CEIL, 0, 44.5, UP, 8, SLAB, Enum.Material.Carpet)
	Kit.box(shell, "UpFloor", 38.5, CEIL, 24.8, 44.5, UP, 58, SLAB, Enum.Material.Carpet)
	Kit.box(shell, "Roof", -1, 27, -1, 77, 28, 59, Color3.fromRGB(70, 60, 60))
	-- Stairs: 14 steps rising north from z=8 to the landing
	for i = 1, 14 do
		Kit.box(
			shell,
			"Step",
			38.5,
			0,
			8 + (i - 1) * 1.2,
			44.5,
			i,
			8 + i * 1.2,
			i % 2 == 0 and OAK or OAK_LIGHT,
			Enum.Material.WoodPlanks
		)
	end
	Kit.box(furn, "StairRail", 38.3, 3, 8, 38.5, 3.2, 24.8, WHITE, nil, { CanCollide = false })
	for z = 8.5, 24, 1.5 do
		Kit.box(
			furn,
			"Spindle",
			38.35,
			(z - 8) / 1.2,
			z,
			38.45,
			(z - 8) / 1.2 + 3,
			z + 0.1,
			WHITE,
			nil,
			{ CanCollide = false }
		)
	end
	-- landing banister around the stairwell
	Kit.box(shell, "Banister", 38.2, UP, 8, 38.5, UP + 3, 24.8, WHITE)
	Kit.box(shell, "Banister", 38.2, UP, 7.7, 44.5, UP + 3, 8, WHITE)

	---------------------------------------------------------------- upstairs walls
	Kit.wallX(shell, "UpWallS", 0, -0.5, 76.5, UP, CEIL, {}, CREAM)
	Kit.wallX(shell, "UpWallN", 58, -0.5, 76.5, UP, CEIL, {}, CREAM)
	Kit.wallZ(shell, "UpWallWest", 0, 0, 58, UP, CEIL, {}, CREAM)
	Kit.wallZ(shell, "UpWallEast", 76, 0, 58, UP, CEIL, {}, CREAM)
	addDoors(Kit.wallZ(shell, "UpWallW", 30, 0.5, 57.5, UP, CEIL, { d(16), d(43) }, CREAM), "Upstairs")
	addDoors(Kit.wallZ(shell, "UpWallE", 46, 0.5, 57.5, UP, CEIL, { d(4.6), d(43) }, CREAM), "Upstairs")
	Kit.wallX(shell, "UpWallKidEdit", 30, 0.5, 29.5, UP, CEIL, {}, Color3.fromRGB(170, 175, 220))
	Kit.wallX(shell, "UpWallMainBath", 30, 46.5, 75.5, UP, CEIL, {}, Color3.fromRGB(220, 200, 200))

	-- doorway floor strips stay lit in blackouts
	for _, c in ipairs(H.doors) do
		local size = c.axis == "X" and Vector3.new(c.width, 0.06, 1.3) or Vector3.new(1.3, 0.06, c.width)
		local strip = Kit.part({
			Name = "DoorStrip",
			Size = size,
			CFrame = CFrame.new(c.pos + Vector3.new(0, 0.03, 0)),
			Color = Color3.fromRGB(255, 170, 80),
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = false,
			CanQuery = false,
			Parent = lightsF,
		})
		strip:SetAttribute("Strip", true)
	end

	---------------------------------------------------------------- lights
	local function roomLight(room, x, y, z, brightness, range)
		local bulb =
			Kit.box(lightsF, "Bulb" .. room, x - 0.5, y - 0.6, z - 0.5, x + 0.5, y, z + 0.5, AMBER, Enum.Material.Neon)
		bulb.CanCollide = false
		local l = Kit.light(bulb, brightness or 1.2, range or 26)
		l:SetAttribute("Room", room)
		l:SetAttribute("Base", l.Brightness)
		table.insert(H.lights, { light = l, bulb = bulb, room = room })
		return l, bulb
	end
	roomLight("Den", 15, CEIL, 13)
	roomLight("Entry", 37, CEIL, 14, 1.1)
	roomLight("Dining", 60, CEIL - 1.5, 13, 1.3)
	roomLight("Kitchen", 15, CEIL, 42)
	roomLight("Rear hall", 37, CEIL, 42, 0.8)
	roomLight("Utility", 60, CEIL, 42, 0.9)
	roomLight("Landing", 38, UP + CEIL, 40, 0.9, 30)
	roomLight("Edit room", 15, UP + CEIL, 44)
	roomLight("Kid's bedroom", 15, UP + CEIL, 15)
	roomLight("Main bedroom", 61, UP + CEIL, 15)
	roomLight("Bathroom", 61, UP + CEIL, 44)
	local _, sconce = roomLight("Landing sconce", 31, UP + 8, 30, 0.6, 18)
	H.sconce = sconce

	---------------------------------------------------------------- props helper
	local function prop(id, part, action, objectText, hold, dist)
		local pr = Kit.prompt(part, action, objectText, hold, dist)
		pr.Name = "Prompt"
		part:SetAttribute("PropId", id)
		H.props[id] = { part = part, prompt = pr, id = id }
		return part
	end

	---------------------------------------------------------------- den
	Kit.box(furn, "Rug", 6, 0, 9, 26, 0.04, 20.5, MUSTARD, Enum.Material.Fabric)
	for i = 0, 5 do
		Kit.box(
			furn,
			"RugStripe",
			6,
			0.041,
			9.5 + i * 1.9,
			26,
			0.045,
			10.1 + i * 1.9,
			Color3.fromRGB(150, 100, 30),
			Enum.Material.Fabric,
			{ CanCollide = false }
		)
	end
	-- couch (olive) with two hiding positions behind it
	Kit.box(furn, "CouchSeat", 9, 0, 20.5, 23, 1.7, 23.5, OLIVE, Enum.Material.Fabric)
	Kit.box(furn, "CouchBack", 9, 1.7, 22.6, 23, 3.4, 23.5, OLIVE, Enum.Material.Fabric)
	Kit.box(furn, "CouchArm", 8, 0, 20.5, 9, 2.6, 23.5, OLIVE, Enum.Material.Fabric)
	Kit.box(furn, "CouchArm", 23, 0, 20.5, 24, 2.6, 23.5, OLIVE, Enum.Material.Fabric)
	-- TV console, CRT, DVD deck
	Kit.box(furn, "TVConsole", 11, 0, 0.5, 21, 2.4, 3.2, OAK_LIGHT, Enum.Material.Wood)
	local crt = Kit.box(furn, "CRT", 13.5, 2.4, 0.7, 18.5, 6.8, 4.4, SILVER, Enum.Material.Metal)
	local screen = Kit.box(propsF, "CRTScreen", 14, 3, 4.4, 18, 6, 4.5, Color3.fromRGB(8, 10, 12), Enum.Material.Glass)
	screen.CanCollide = false
	H.tvScreen = screen
	H.tvPos = Vector3.new(16, 4.5, 4.4)
	local deck =
		Kit.box(propsF, "DVDDeck", 18.7, 2.4, 1.2, 20.9, 2.9, 3.2, Color3.fromRGB(190, 192, 196), Enum.Material.Metal)
	prop("Deck", deck, "Use", "DVD deck", 0, 6)
	local tvKnob = Kit.box(propsF, "TVKnobs", 18.6, 3, 3.6, 18.9, 6, 4.3, Color3.fromRGB(60, 60, 60))
	prop("Station_TV", tvKnob, "Tune", "Den TV station", 0, 8)
	-- service console + relay (Return Signal / Off Air)
	local console =
		Kit.box(propsF, "ServiceConsole", 24, 0, 0.8, 28.5, 3.5, 3.4, Color3.fromRGB(80, 90, 96), Enum.Material.Metal)
	Kit.label(console, Enum.NormalId.Top, "SERVICE", Color3.fromRGB(255, 220, 140))
	prop("Station_Console", console, "Operate", "Service console", 0, 8)
	local relay = Kit.box(propsF, "Relay", 28.7, 2, 4.2, 29.5, 5, 6.2, Color3.fromRGB(150, 40, 40), Enum.Material.Metal)
	Kit.label(relay, Enum.NormalId.Left, "RELAY", WHITE)
	prop("Relay", relay, "Set to Service", "Relay", 0, 6)
	-- small tables with the star / circle / triangle buttons (spaced so the nearest prompt is unambiguous)
	local function buttonTable(id, symbol, x, z)
		Kit.box(furn, "SideTable", x - 1.2, 0, z - 1.2, x + 1.2, 2.4, z + 1.2, OAK_LIGHT, Enum.Material.Wood)
		local b = Kit.box(
			propsF,
			id .. "Button",
			x - 0.6,
			2.4,
			z - 0.6,
			x + 0.6,
			2.8,
			z + 0.6,
			Config.Symbols[symbol].color,
			Enum.Material.Neon
		)
		Kit.label(b, Enum.NormalId.Top, Config.Symbols[symbol].glyph, BLACK)
		prop(id, b, "Tap", symbol, 0, 5)
	end
	buttonTable("Star", "Star", 24, 7.5)
	buttonTable("Circle", "Circle", 4, 12)
	buttonTable("Triangle", "Triangle", 27.5, 17)
	-- upright lamp
	Kit.box(furn, "LampPole", 2.8, 0, 3.8, 3.2, 6, 4.2, Color3.fromRGB(60, 50, 40))
	local shade = Kit.box(propsF, "LampShade", 2, 6, 3, 4, 7.5, 5, Color3.fromRGB(240, 220, 170), Enum.Material.Fabric)
	local lampLight = Kit.light(shade, 1.0, 16)
	lampLight.Enabled = false
	H.denLamp = lampLight
	prop("Lamp", shade, "Switch", "Lamp", 0, 7)
	-- bay window with curtain bait
	Kit.box(
		furn,
		"BayWindow",
		2,
		3,
		0.5,
		10,
		9,
		0.7,
		Color3.fromRGB(80, 100, 130),
		Enum.Material.Glass,
		{ Transparency = 0.3 }
	)
	local curtain =
		Kit.box(propsF, "Curtain", 0.6, 2, 0.8, 2, 10, 2.4, Color3.fromRGB(150, 60, 50), Enum.Material.Fabric)
	prop("Curtain", curtain, "Open", "Curtain", 0, 6)

	---------------------------------------------------------------- entry
	local phoneTable =
		Kit.box(furn, "HallConsole", 30.5, 0, 15, 32.4, 3, 19.5, Color3.fromRGB(70, 45, 30), Enum.Material.Wood)
	local phone =
		Kit.box(propsF, "Phone", 30.9, 3, 16.6, 32, 3.6, 18, Color3.fromRGB(220, 200, 160), Enum.Material.SmoothPlastic)
	prop("Phone", phone, "Touch", "Phone console", 0, 7)
	H.phoneTable = phoneTable
	Kit.box(furn, "HallLampPole", 31.3, 0, 23, 31.7, 6, 23.4, Color3.fromRGB(60, 50, 40))
	local hallShade =
		Kit.box(propsF, "HallLamp", 30.7, 6, 22.4, 32.3, 7.3, 24, Color3.fromRGB(240, 220, 170), Enum.Material.Fabric)
	prop("HallLamp", hallShade, "Touch", "Hall lamp", 0, 6)
	Kit.box(furn, "CoatHooks", 30.6, 6.5, 1, 30.8, 6.8, 5, Color3.fromRGB(60, 100, 170))
	Kit.box(furn, "Raincoat", 30.7, 3.5, 2, 31.4, 6.5, 3.5, Color3.fromRGB(240, 200, 40), Enum.Material.Fabric)
	Kit.box(furn, "UmbrellaStand", 43, 0, 25, 44, 2.5, 25.8, Color3.fromRGB(60, 60, 60))
	Kit.box(
		furn,
		"Sidelight",
		42.5,
		2,
		-0.6,
		44.5,
		9,
		-0.45,
		Color3.fromRGB(180, 200, 220),
		Enum.Material.Glass,
		{ Transparency = 0.4, CanCollide = false }
	)
	-- front door with chain and a visible deadbolt
	local frontDoor = Kit.box(propsF, "FrontDoor", 34, 0, -0.3, 42, 10.5, 0.3, DOOR_RED, Enum.Material.Wood)
	prop("FrontDoor", frontDoor, "Open", "Front door", 0, 7)
	H.frontDoor = frontDoor
	H.frontDoorCF = frontDoor.CFrame
	local bolt =
		Kit.box(propsF, "Deadbolt", 40.4, 4.8, 0.3, 41.2, 5.6, 0.6, Color3.fromRGB(200, 160, 60), Enum.Material.Metal)
	bolt.CanCollide = false
	H.deadbolt = bolt
	Kit.box(
		furn,
		"DoorChain",
		39,
		6,
		0.3,
		41,
		6.1,
		0.4,
		Color3.fromRGB(200, 160, 60),
		Enum.Material.Metal,
		{ CanCollide = false }
	)
	-- yellow runner from the entry to a stop marker in the rear hall
	Kit.box(
		furn,
		"YellowRunner",
		33,
		0,
		4,
		35.5,
		0.05,
		44,
		Color3.fromRGB(230, 200, 40),
		Enum.Material.Fabric,
		{ CanCollide = false }
	)
	local stop = Kit.box(
		furn,
		"RunnerStop",
		32.5,
		0.05,
		44,
		36,
		0.07,
		47,
		Color3.fromRGB(230, 60, 40),
		Enum.Material.Neon,
		{ CanCollide = false }
	)
	Kit.label(stop, Enum.NormalId.Top, "STOP", WHITE)
	H.zones.RunnerStop = { center = Vector3.new(34.2, 0, 45.5), radius = 3.2, y = 0 }

	---------------------------------------------------------------- kitchen
	Kit.box(furn, "Cabinets", 6, 0, 55, 29, 3.4, 57.5, Color3.fromRGB(235, 225, 195), Enum.Material.Wood)
	Kit.box(furn, "Counter", 6, 3.4, 54.8, 29, 3.7, 57.5, Color3.fromRGB(110, 140, 70), Enum.Material.Slate)
	Kit.box(furn, "Fridge", 0.5, 0, 52, 4.5, 8, 57.5, Color3.fromRGB(230, 230, 225), Enum.Material.Metal)
	Kit.box(furn, "Kettle", 20, 3.7, 55.5, 21.2, 4.8, 56.7, Color3.fromRGB(200, 30, 30), Enum.Material.Metal)
	Kit.box(furn, "HeightChart", 0.5, 1, 30, 0.6, 7, 31, WHITE, nil, { CanCollide = false })
	local radioTable = Kit.box(furn, "RadioTable", 15.5, 0, 34, 20.5, 3, 36, OAK_LIGHT, Enum.Material.Wood)
	local radio =
		Kit.box(propsF, "Radio", 16.2, 3, 34.3, 19.8, 5, 35.7, Color3.fromRGB(140, 90, 50), Enum.Material.Wood)
	Kit.label(radio, Enum.NormalId.Front, "RADIO", Color3.fromRGB(255, 220, 160))
	prop("Station_Radio", radio, "Patch", "Kitchen radio station", 0, 8)
	local cupboardDoor = Kit.box(
		scareF,
		"KitchenCupboard",
		24,
		7,
		57.2,
		28,
		10.5,
		57.5,
		Color3.fromRGB(235, 225, 195),
		Enum.Material.Wood
	)
	H.scares.KitchenCupboard = cupboardDoor
	Kit.box(furn, "WallCupboards", 6, 7, 56.5, 24, 10.5, 57.5, Color3.fromRGB(235, 225, 195), Enum.Material.Wood)

	---------------------------------------------------------------- rear hall
	Kit.box(furn, "ShoeRack", 43, 0, 50, 44.5, 2, 56, Color3.fromRGB(150, 150, 150), Enum.Material.Metal)
	Kit.box(
		lightsF,
		"FloorStrip",
		30.6,
		0,
		27,
		31,
		0.15,
		57,
		Color3.fromRGB(255, 160, 80),
		Enum.Material.Neon,
		{ CanCollide = false }
	)

	---------------------------------------------------------------- dining
	Kit.box(furn, "DiningTable", 53, 0, 9, 67, 3.2, 17, OAK_LIGHT, Enum.Material.Wood)
	for _, x in ipairs({ 55, 60, 65 }) do
		Kit.box(furn, "Chair", x - 1, 0, 6.5, x + 1, 2, 8.5, OAK, Enum.Material.Wood)
		Kit.box(furn, "Chair", x - 1, 0, 17.5, x + 1, 2, 19, OAK, Enum.Material.Wood)
	end
	Kit.box(furn, "Bench", 54, 0, 20.5, 64, 0.4, 23, OAK, Enum.Material.Wood)
	Kit.box(furn, "BenchTop", 54, 1.9, 20.5, 64, 2.3, 23, OAK, Enum.Material.Wood)
	Kit.box(furn, "BenchBack", 54, 0, 22.6, 64, 1.9, 23, OAK, Enum.Material.Wood)
	Kit.box(furn, "BenchEnd", 53.6, 0, 20.5, 54, 2.3, 23, OAK, Enum.Material.Wood)
	Kit.box(furn, "BenchEnd", 64, 0, 20.5, 64.4, 2.3, 23, OAK, Enum.Material.Wood)
	Kit.box(
		furn,
		"GlazedDoor",
		62,
		1,
		0.5,
		68,
		10,
		0.7,
		Color3.fromRGB(150, 180, 210),
		Enum.Material.Glass,
		{ Transparency = 0.3 }
	)
	Kit.box(furn, "FloralCurtain", 60.5, 1, 0.6, 62, 10.5, 1.4, Color3.fromRGB(200, 150, 160), Enum.Material.Fabric)
	local fakeHandle =
		Kit.box(propsF, "WindowHandle", 70, 4, 0.5, 71.5, 4.6, 1.1, Color3.fromRGB(200, 160, 60), Enum.Material.Metal)
	Kit.box(
		furn,
		"DiningWindow",
		68,
		3,
		0.5,
		74,
		9,
		0.7,
		Color3.fromRGB(80, 100, 130),
		Enum.Material.Glass,
		{ Transparency = 0.3 }
	)
	prop("Window", fakeHandle, "Pull", "Window handle", 0, 6)

	---------------------------------------------------------------- utility
	Kit.box(furn, "Washer", 47, 0, 52, 51, 4, 57.5, WHITE, Enum.Material.Metal)
	Kit.box(furn, "Dryer", 51.5, 0, 52, 55.5, 4, 57.5, WHITE, Enum.Material.Metal)
	Kit.box(furn, "CleaningShelf", 70, 0, 27, 75.5, 7, 29.5, OAK_LIGHT, Enum.Material.Wood)
	Kit.box(furn, "WallFlashlight", 75.4, 5, 32, 75.5, 6, 33, Color3.fromRGB(240, 200, 40))
	local breaker = Kit.box(
		propsF,
		"Breaker",
		57.5,
		3,
		57,
		62.5,
		8,
		57.5,
		Color3.fromRGB(120, 125, 130),
		Enum.Material.DiamondPlate
	)
	Kit.label(breaker, Enum.NormalId.Front, "BREAKER", Color3.fromRGB(255, 220, 140))
	prop("Station_Breaker", breaker, "Reset", "Utility breaker station", 0, 10)
	local utilDoor = Kit.box(propsF, "UtilityDoor", 75.7, 0, 37, 76.3, 10.5, 45, TEAL, Enum.Material.Wood)
	prop("UtilityDoor", utilDoor, "Open", "Teal door", 0, 7)
	H.utilityDoor = utilDoor
	H.utilityDoorCF = utilDoor.CFrame
	Kit.box(
		furn,
		"UtilityWindow",
		64,
		4,
		57.3,
		70,
		9,
		57.5,
		Color3.fromRGB(80, 100, 130),
		Enum.Material.Glass,
		{ Transparency = 0.3 }
	)

	---------------------------------------------------------------- relay shape pads (Mum's Call)
	local padRooms = {
		Entry = { { 31.6, 20.5 }, { 36.4, 20.5 }, { 31.6, 24.6 }, { 36.4, 24.6 } },
		Dining = { { 47.5, 19 }, { 51.2, 19 }, { 47.5, 23.5 }, { 51.2, 23.5 } },
		Kitchen = { { 6, 36 }, { 10, 36 }, { 6, 40.5 }, { 10, 40.5 } },
		Utility = { { 50, 32 }, { 54, 32 }, { 50, 36.5 }, { 54, 36.5 } },
	}
	local padSymbols = { "Star", "Circle", "Triangle", "Square" }
	for room, spots in pairs(padRooms) do
		for i, s in ipairs(spots) do
			local sym = padSymbols[(i + #room) % 4 + 1]
			local x, z = s[1], s[2]
			local pad = Kit.box(
				propsF,
				"Pad",
				x - 0.8,
				0,
				z - 0.8,
				x + 0.8,
				2.6,
				z + 0.8,
				Config.Symbols[sym].color,
				Enum.Material.SmoothPlastic
			)
			Kit.label(pad, Enum.NormalId.Top, Config.Symbols[sym].glyph, BLACK)
			Kit.label(pad, Enum.NormalId.Front, Config.Symbols[sym].glyph, BLACK)
			prop("Pad_" .. room .. "_" .. sym, pad, "Press", sym .. " (" .. room .. ")", 0, 3)
		end
	end

	---------------------------------------------------------------- floor marks
	local colorNames = { "Blue", "Red", "Yellow", "Green" }
	local function mark(room, x, z, colorName, symbol)
		local info = Config.MarkColors[colorName]
		local m = Kit.box(
			marksF,
			"Mark",
			x - 1.1,
			0.05,
			z - 1.1,
			x + 1.1,
			0.09,
			z + 1.1,
			info.color,
			Enum.Material.Neon,
			{ CanCollide = false, Transparency = 0.15 }
		)
		Kit.label(m, Enum.NormalId.Top, Config.Symbols[symbol].glyph, Color3.new(1, 1, 1))
		m:SetAttribute("MarkColor", colorName)
		m:SetAttribute("Symbol", symbol)
		table.insert(H.marks, { part = m, color = colorName, symbol = symbol, room = room, pos = Vector3.new(x, 0, z) })
	end
	local denX = { 9, 13.5, 18, 22.5 }
	local denZ = { 10.8, 13.4, 16, 18.6 }
	for r = 1, 4 do
		for c = 1, 4 do
			mark("Den", denX[c], denZ[r], colorNames[(r + c) % 4 + 1], padSymbols[(r + 2 * c) % 4 + 1])
		end
	end
	mark("Entry", 31.8, 2.6, "Blue", "Star")
	mark("Entry", 36.6, 6.8, "Red", "Circle")
	mark("Entry", 31.8, 6.8, "Yellow", "Triangle")
	mark("Entry", 36.6, 11.5, "Green", "Square")
	mark("Kitchen", 8, 47, "Blue", "Circle")
	mark("Kitchen", 12, 47, "Red", "Star")
	mark("Kitchen", 16, 47, "Yellow", "Square")
	mark("Kitchen", 20, 47, "Green", "Triangle")
	mark("Dining", 49, 3, "Blue", "Square")
	mark("Dining", 49, 12, "Red", "Triangle")

	---------------------------------------------------------------- station zones
	H.zones.TV = { center = Vector3.new(16, 0, 6.5), radius = 7, y = 0 }
	H.zones.Radio = { center = Vector3.new(18, 0, 31.5), radius = 7, y = 0 }
	H.zones.Breaker = { center = Vector3.new(60, 0, 51), radius = 8, y = 0 }
	H.zones.Recorder = { center = Vector3.new(16, UP, 42), radius = 7.5, y = UP }
	H.zones.Console = { center = Vector3.new(24, 0, 6), radius = 9, y = 0 }
	H.zones.Den = { center = Vector3.new(15, 0, 14), radius = 15, y = 0 }
	H.zones.Hall = { center = Vector3.new(36, 0, 14), radius = 12, y = 0 }
	H.zones.Deck = { center = Vector3.new(18, 0, 6), radius = 8, y = 0 }
	for name, z in pairs(H.zones) do
		local disc = Kit.part({
			Name = "Zone_" .. name,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.06, z.radius * 2, z.radius * 2),
			CFrame = CFrame.new(z.center + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(120, 200, 255),
			Material = Enum.Material.Neon,
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			Parent = zonesF,
		})
		z.part = disc
	end

	---------------------------------------------------------------- upstairs rooms
	-- edit room (recorder station)
	Kit.box(furn, "EditDesk", 12, UP, 45.5, 20, UP + 3, 48.5, Color3.fromRGB(215, 200, 170), Enum.Material.Wood)
	local recorder = Kit.box(
		propsF,
		"Recorder",
		13,
		UP + 3,
		45.8,
		17.5,
		UP + 4.2,
		48,
		Color3.fromRGB(70, 70, 75),
		Enum.Material.Metal
	)
	Kit.label(recorder, Enum.NormalId.Front, "REC", Color3.fromRGB(255, 80, 80))
	prop("Station_Recorder", recorder, "Record", "Edit room recorder", 0, 8)
	local recLight = Kit.box(
		lightsF,
		"RecLight",
		17.6,
		UP + 3,
		46,
		18.2,
		UP + 3.6,
		46.6,
		Color3.fromRGB(255, 40, 40),
		Enum.Material.Neon
	)
	Kit.light(recLight, 0.6, 8, Color3.fromRGB(255, 60, 60))
	local monitor = Kit.box(
		propsF,
		"EditMonitor",
		18.3,
		UP + 3,
		46.2,
		19.8,
		UP + 4.6,
		48,
		Color3.fromRGB(150, 150, 150),
		Enum.Material.Metal
	)
	H.editMonitor = monitor
	for i = 0, 3 do
		Kit.box(
			furn,
			"AcousticPanel",
			0.5,
			UP + 4,
			33 + i * 6,
			0.9,
			UP + 9,
			37 + i * 6,
			Color3.fromRGB(60, 60, 70),
			Enum.Material.Fabric
		)
	end
	-- kid's bedroom: broad desk with two hide slots
	Kit.box(furn, "KidDeskTop", 0.5, UP + 3.2, 8, 5.5, UP + 3.6, 22, Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
	Kit.box(furn, "KidDeskSide", 0.5, UP, 7.6, 5.5, UP + 3.2, 8, Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
	Kit.box(furn, "KidDeskSide", 0.5, UP, 22, 5.5, UP + 3.2, 22.4, Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
	Kit.box(furn, "KidDeskMid", 0.5, UP, 14.8, 5.5, UP + 3.2, 15.2, Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
	Kit.box(furn, "KidDeskPanel", 5.1, UP + 1.6, 8, 5.5, UP + 3.2, 22, Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
	Kit.box(furn, "KidDeskPanelLow", 5.1, UP, 8, 5.5, UP + 1.0, 22, Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
	local deskLamp =
		Kit.box(lightsF, "GreenLamp", 2, UP + 3.6, 20, 3, UP + 4.6, 21, Color3.fromRGB(60, 160, 60), Enum.Material.Neon)
	Kit.light(deskLamp, 0.4, 8, Color3.fromRGB(120, 255, 120))
	Kit.box(furn, "KidBed", 10, UP, 23.5, 20, UP + 2, 29.5, Color3.fromRGB(70, 80, 140), Enum.Material.Fabric)
	Kit.box(furn, "ToyBlocks", 20, UP, 6, 22, UP + 1, 8, Color3.fromRGB(220, 80, 60))
	Kit.box(furn, "Clock", 21, UP + 2, 28, 22, UP + 3, 29, Color3.fromRGB(240, 210, 40))
	-- main bedroom: wide curtain closet with two slots
	Kit.box(furn, "ClosetBack", 75, UP, 6, 75.5, UP + 9, 22, Color3.fromRGB(90, 60, 50), Enum.Material.Wood)
	Kit.box(furn, "ClosetEnd", 70.6, UP, 5.6, 75.5, UP + 9, 6, Color3.fromRGB(90, 60, 50), Enum.Material.Wood)
	Kit.box(furn, "ClosetEnd", 70.6, UP, 22, 75.5, UP + 9, 22.4, Color3.fromRGB(90, 60, 50), Enum.Material.Wood)
	Kit.box(furn, "ClosetMid", 70.6, UP, 13.8, 75.5, UP + 9, 14.2, Color3.fromRGB(90, 60, 50), Enum.Material.Wood)
	Kit.box(furn, "ClosetTop", 70.6, UP + 9, 5.6, 75.5, UP + 9.4, 22.4, Color3.fromRGB(90, 60, 50), Enum.Material.Wood)
	Kit.box(furn, "ClosetCurtain", 70.6, UP, 6, 71, UP + 9, 9.6, Color3.fromRGB(110, 40, 60), Enum.Material.Fabric)
	Kit.box(furn, "ClosetCurtain", 70.6, UP, 10.4, 71, UP + 9, 17.6, Color3.fromRGB(110, 40, 60), Enum.Material.Fabric)
	Kit.box(furn, "ClosetCurtain", 70.6, UP, 18.4, 71, UP + 9, 22, Color3.fromRGB(110, 40, 60), Enum.Material.Fabric)
	Kit.box(furn, "MainBed", 52, UP, 20, 62, UP + 2.2, 29.5, Color3.fromRGB(120, 30, 40), Enum.Material.Fabric)
	Kit.box(furn, "DressingTable", 47, UP, 24, 49, UP + 3, 29, OAK_LIGHT, Enum.Material.Wood)
	Kit.box(
		furn,
		"Mirror",
		46.6,
		UP + 3,
		25,
		46.8,
		UP + 7,
		28,
		Color3.fromRGB(200, 210, 220),
		Enum.Material.Glass,
		{ Reflectance = 0.4 }
	)
	-- bathroom: tub with one slot
	Kit.box(furn, "TubSide", 66, UP, 50, 75.5, UP + 2.6, 50.4, Color3.fromRGB(240, 235, 220))
	Kit.box(furn, "TubSide", 66, UP, 57.1, 75.5, UP + 2.6, 57.5, Color3.fromRGB(240, 235, 220))
	Kit.box(furn, "TubEnd", 66, UP, 50, 66.4, UP + 2.6, 57.5, Color3.fromRGB(240, 235, 220))
	Kit.box(
		furn,
		"TubCurtain",
		66,
		UP + 2.6,
		50,
		66.2,
		UP + 9,
		55.5,
		Color3.fromRGB(200, 220, 210),
		Enum.Material.Fabric
	)
	Kit.box(furn, "Sink", 47, UP, 52, 49, UP + 3.4, 55, WHITE)
	Kit.box(furn, "Hamper", 47, UP, 33, 49, UP + 2.5, 35, Color3.fromRGB(180, 160, 120), Enum.Material.Fabric)
	Kit.box(
		furn,
		"MintTile",
		75.4,
		UP,
		30.5,
		75.5,
		UP + 6,
		57.5,
		Color3.fromRGB(170, 220, 190),
		nil,
		{ CanCollide = false }
	)
	-- landing: linen cupboard, hatch, portraits
	Kit.box(
		scareF,
		"LinenCupboard",
		30.5,
		UP,
		51,
		33.5,
		UP + 9,
		57.5,
		Color3.fromRGB(235, 230, 215),
		Enum.Material.Wood
	)
	H.scares.LinenCupboard = Vector3.new(33.6, UP + 4, 54)
	Kit.box(
		furn,
		"Hatch",
		36,
		UP + CEIL - 0.1,
		44,
		40,
		UP + CEIL,
		48,
		Color3.fromRGB(140, 120, 90),
		Enum.Material.Wood,
		{ CanCollide = false }
	)
	H.scares.Hatch = Vector3.new(38, UP + CEIL - 0.5, 46)

	---------------------------------------------------------------- scare props (hidden until used)
	local function scareProp(name, x1, y1, z1, x2, y2, z2, color)
		local p = Kit.box(
			scareF,
			name,
			x1,
			y1,
			z1,
			x2,
			y2,
			z2,
			color,
			Enum.Material.SmoothPlastic,
			{ CanCollide = false, Transparency = 1 }
		)
		H.scares[name] = p
		return p
	end
	scareProp("SidelightHand", 42.8, 4.5, -1.3, 44.2, 6.6, -0.8, Color3.fromRGB(225, 220, 210))
	scareProp("DiningFace", 69.8, 5, -1.6, 72.2, 7.6, -0.9, Color3.fromRGB(215, 210, 200))
	scareProp("UtilityFingers", 65, 6, 58.8, 69, 6.8, 59.4, Color3.fromRGB(200, 180, 140))

	---------------------------------------------------------------- hide spots (8 total)
	local function hide(id, room, inside, peekFrom, peekAt, exit, promptPos)
		local pp = Kit.part({
			Name = "Hide_" .. id,
			Size = Vector3.new(1.5, 1.5, 1.5),
			CFrame = CFrame.new(promptPos or inside),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			Parent = hidesF,
		})
		local pr = Kit.prompt(pp, "Hide", room, 0, 6)
		pr.Name = "HidePrompt"
		pr.Exclusivity = Enum.ProximityPromptExclusivity.OneGlobally
		table.insert(H.hideSpots, {
			id = id,
			room = room,
			inside = CFrame.new(inside),
			peek = CFrame.lookAt(peekFrom, peekAt),
			exit = CFrame.new(exit),
			part = pp,
			prompt = pr,
		})
	end
	hide(
		"CouchL",
		"Den",
		Vector3.new(12, 1.4, 24.5),
		Vector3.new(12, 3.9, 24.3),
		Vector3.new(14, 3, 4),
		Vector3.new(7, 3, 24.5),
		Vector3.new(8.6, 2, 24.6)
	)
	hide(
		"CouchR",
		"Den",
		Vector3.new(20, 1.4, 24.5),
		Vector3.new(20, 3.9, 24.3),
		Vector3.new(18, 3, 4),
		Vector3.new(25.5, 3, 24.5),
		Vector3.new(23.4, 2, 24.6)
	)
	hide(
		"Bench",
		"Dining",
		Vector3.new(59, 1.1, 21.6),
		Vector3.new(59, 1.3, 20.3),
		Vector3.new(46, 4, 5),
		Vector3.new(59, 3, 24.5),
		Vector3.new(59, 1.5, 20.2)
	)
	hide(
		"DeskA",
		"Kid's bedroom",
		Vector3.new(2.8, UP + 1.2, 11.5),
		Vector3.new(5.7, UP + 1.3, 11.5),
		Vector3.new(30, UP + 4, 16),
		Vector3.new(7.5, UP + 3, 11.5),
		Vector3.new(5.8, UP + 1.5, 11.5)
	)
	hide(
		"DeskB",
		"Kid's bedroom",
		Vector3.new(2.8, UP + 1.2, 18.5),
		Vector3.new(5.7, UP + 1.3, 18.5),
		Vector3.new(30, UP + 4, 16),
		Vector3.new(7.5, UP + 3, 18.5),
		Vector3.new(5.8, UP + 1.5, 18.5)
	)
	hide(
		"ClosetA",
		"Main bedroom",
		Vector3.new(73, UP + 3, 10),
		Vector3.new(70.7, UP + 5, 10),
		Vector3.new(46, UP + 4, 4.6),
		Vector3.new(68, UP + 3, 10),
		Vector3.new(70.2, UP + 3, 10)
	)
	hide(
		"ClosetB",
		"Main bedroom",
		Vector3.new(73, UP + 3, 18),
		Vector3.new(70.7, UP + 5, 18),
		Vector3.new(50, UP + 4, 4.6),
		Vector3.new(68, UP + 3, 18),
		Vector3.new(70.2, UP + 3, 18)
	)
	hide(
		"Tub",
		"Bathroom",
		Vector3.new(71, UP + 1.2, 53.7),
		Vector3.new(66.6, UP + 3.4, 56),
		Vector3.new(46, UP + 4, 43),
		Vector3.new(63, UP + 3, 53.7),
		Vector3.new(65.3, UP + 2.5, 53.7)
	)

	---------------------------------------------------------------- spawns and patrol nodes
	H.spawns = {
		CFrame.new(12, 3, 12) * CFrame.Angles(0, math.rad(180), 0),
		CFrame.new(20, 3, 12) * CFrame.Angles(0, math.rad(180), 0),
		CFrame.new(12, 3, 17) * CFrame.Angles(0, math.rad(180), 0),
		CFrame.new(20, 3, 17) * CFrame.Angles(0, math.rad(180), 0),
	}
	local function node(x, y, z, lx, lz, wait)
		return { pos = Vector3.new(x, y, z), look = lx and Vector3.new(lx, y, lz) or nil, wait = wait or 0 }
	end
	H.patrolA = {
		node(38, UP, 55),
		node(34, UP, 43, 15, 48, 2),
		node(24, UP, 43, 10, 50, 1.5),
		node(42, UP, 43, 60, 50, 2),
		node(56, UP, 46, 72, 53.7, 1.5),
		node(34, UP, 16, 10, 15, 2),
		node(22, UP, 15, 3, 15, 1.5),
		node(41, UP, 4.5, 60, 4.5, 1.5),
		node(58, UP, 9, 73, 14, 1.5),
		node(41.5, 0, 5),
		node(33, 0, 9, 15, 15, 2),
		node(16, 0, 14, 16, 24, 2),
		node(16, 0, 33, 6, 45, 1.5),
		node(36, 0, 42, 36, 55, 1.5),
		node(58, 0, 44, 60, 52, 1.5),
		node(60, 0, 24.5, 59, 21.5, 2),
		node(37, 0, 17, 37, 3, 1),
	}
	H.patrolALoop = 11
	H.patrolB = {
		node(72, 0, 41),
		node(58, 0, 44, 60, 52, 1.5),
		node(36, 0, 42, 36, 55, 1.5),
		node(16, 0, 33, 6, 45, 1.5),
		node(16, 0, 14, 16, 24, 2),
		node(33, 0, 9, 15, 15, 2),
		node(60, 0, 24.5, 59, 21.5, 2),
		node(37, 0, 17),
		node(41, UP, 4.5, 60, 4.5, 1.5),
		node(58, UP, 9, 73, 14, 1.5),
		node(22, UP, 15, 3, 15, 1.5),
		node(24, UP, 43, 10, 50, 1.5),
		node(56, UP, 46, 72, 53.7, 1.5),
		node(38, UP, 50, 38, 30, 1),
	}
	H.patrolBLoop = 2

	---------------------------------------------------------------- studio set (Nell's stage, death room, audience ending)
	H.studio = House.buildStudio(H)
	return H
end

function House.buildStudio(H)
	local set = Kit.folder(workspace, "StudioSet")
	local stage = Kit.folder(set, "Stage")
	local puppets = Kit.folder(stage, "Puppets")
	local sx, sz = 150, 0
	local function S(x, z)
		return sx + x, sz + z
	end
	local function sbox(parent, name, x1, y1, z1, x2, y2, z2, color, mat, extra)
		local ax, az = S(x1, z1)
		local bx, bz = S(x2, z2)
		return Kit.box(parent, name, ax, y1, az, bx, y2, bz, color, mat, extra)
	end
	-- shell
	sbox(set, "SetFloor", -2, -1, -6, 44, 0, 40, Color3.fromRGB(70, 50, 36), Enum.Material.WoodPlanks)
	sbox(set, "SetWall", -2, 0, -6, -1, 30, 40, BLACK)
	sbox(set, "SetWall", 43, 0, -6, 44, 30, 40, BLACK)
	sbox(set, "SetWall", -2, 0, -7, 44, 30, -6, BLACK)
	sbox(set, "SetWall", -2, 0, 39, 44, 30, 40, BLACK)
	sbox(set, "SetCeiling", -2, 30, -6, 44, 31, 40, BLACK)
	-- stage dressing (mirrored into the CRT feed)
	sbox(stage, "Backdrop", 6, 0, 28, 36, 16, 28.6, Color3.fromRGB(56, 40, 30), Enum.Material.Wood)
	sbox(stage, "CurtainL", 6, 0, 27, 10, 16, 28, Color3.fromRGB(110, 20, 24), Enum.Material.Fabric)
	sbox(stage, "CurtainR", 32, 0, 27, 36, 16, 28, Color3.fromRGB(110, 20, 24), Enum.Material.Fabric)
	sbox(stage, "Valance", 6, 14, 26.5, 36, 16, 28, Color3.fromRGB(130, 30, 30), Enum.Material.Fabric)
	sbox(stage, "PaintedRain", 12, 4, 27.9, 20, 10, 28, Color3.fromRGB(70, 90, 120), Enum.Material.SmoothPlastic)
	for i = 0, 6 do
		sbox(
			stage,
			"RainStreak",
			12.5 + i * 1.1,
			4.3,
			27.85,
			12.6 + i * 1.1,
			9.7,
			27.9,
			Color3.fromRGB(180, 200, 230),
			nil,
			{ CanCollide = false }
		)
	end
	sbox(stage, "PaintedHouse", 24, 0, 27.7, 30, 7, 27.9, Color3.fromRGB(220, 200, 160))
	sbox(stage, "PaintedRoof", 23.5, 7, 27.7, 30.5, 9, 27.9, Color3.fromRGB(160, 60, 50))
	sbox(stage, "PaintedTree", 32, 0, 27.6, 34, 10, 27.8, Color3.fromRGB(80, 110, 70))
	sbox(
		stage,
		"StageFloor",
		4,
		0,
		10,
		38,
		0.06,
		27,
		Color3.fromRGB(110, 76, 48),
		Enum.Material.WoodPlanks,
		{ CanCollide = false }
	)
	-- copies of the den couch, rug, CRT, lamps (audience ending)
	sbox(set, "SetRug", 12, 0.06, 9, 30, 0.1, 20.5, MUSTARD, Enum.Material.Fabric, { CanCollide = false })
	sbox(set, "SetCouch", 13, 0, 22.5, 29, 1.7, 25, OLIVE, Enum.Material.Fabric)
	sbox(set, "SetCouchBack", 13, 1.7, 24.2, 29, 3.4, 25, OLIVE, Enum.Material.Fabric)
	sbox(set, "SetCRT", 18.5, 0, 1, 23.5, 4.2, 4.5, SILVER, Enum.Material.Metal)
	sbox(set, "CableRamp", 8, 0, 6, 34, 0.3, 7, Color3.fromRGB(30, 30, 30))
	sbox(set, "WhiteTape", 6, 0.06, 7.5, 36, 0.09, 7.8, WHITE, Enum.Material.Neon, { CanCollide = false })
	for _, x in ipairs({ 8, 34 }) do
		local lamp =
			sbox(set, "TungstenLamp", x - 1, 6, 3, x + 1, 8, 5, Color3.fromRGB(255, 230, 180), Enum.Material.Neon)
		local spot = Kit.light(lamp, 2.2, 40, Color3.fromRGB(255, 214, 160), "SpotLight")
		spot.Face = Enum.NormalId.Back
		spot.Angle = 70
		sbox(set, "LampStand", x - 0.2, 0, 3.8, x + 0.2, 6, 4.2, BLACK)
	end
	local key = sbox(stage, "KeyLight", 20.5, 14, 12, 21.5, 14.4, 13, AMBER, Enum.Material.Neon)
	local keyL = Kit.light(key, 1.6, 26, Color3.fromRGB(255, 210, 160), "PointLight")
	keyL.Shadows = false
	-- Nell
	local nx, nz = S(21, 18)
	local nellPivot = CFrame.new(nx, 0, nz)
	local nell = Figures.nell(stage, nellPivot)
	-- puppet marks: left, right, behind-left, behind-right
	local marks = {}
	for _, off in ipairs({ { -4, 0 }, { 4, 0 }, { -2, 3.6 }, { 2, 3.6 } }) do
		local mx, mz = S(21 + off[1], 18 + off[2])
		table.insert(marks, CFrame.new(mx, 0, mz))
		sbox(
			stage,
			"PuppetMark",
			21 + off[1] - 0.7,
			0.07,
			18 + off[2] - 0.7,
			21 + off[1] + 0.7,
			0.1,
			18 + off[2] + 0.7,
			WHITE,
			Enum.Material.Neon,
			{ CanCollide = false, Transparency = 0.5 }
		)
		local rig = Kit.box(
			stage,
			"Rig",
			mx - 1.5,
			13,
			mz - 0.1,
			mx + 1.5,
			13.2,
			mz + 0.1,
			Color3.fromRGB(100, 70, 45),
			Enum.Material.Wood
		)
		rig.CanCollide = false
	end
	-- audience marks for surviving players (Audience ending)
	local audience = {}
	for _, off in ipairs({ { -7, -2 }, { -3, -4 }, { 3, -4 }, { 7, -2 } }) do
		local ax, az = S(21 + off[1], 18 + off[2])
		table.insert(audience, CFrame.new(ax, 3, az))
		sbox(
			set,
			"AudienceMark",
			21 + off[1] - 1,
			0.1,
			18 + off[2] - 1,
			21 + off[1] + 1,
			0.13,
			18 + off[2] + 1,
			Color3.fromRGB(240, 200, 40),
			Enum.Material.Neon,
			{ CanCollide = false }
		)
	end
	-- the dark room beyond a reusable doorway (death cutscene)
	Kit.wallX(
		set,
		"DarkWall",
		sz + 30,
		sx - 1,
		sx + 43,
		0,
		16,
		{ { c = sx + 6, w = 6, h = 10 } },
		Color3.fromRGB(40, 36, 34)
	)
	sbox(set, "DarkRoomFloor", -1, 0, 30, 14, 0.02, 39, BLACK)
	local doorX, doorZ = S(6, 30)
	local hinge = CFrame.new(doorX - 3, 5, doorZ + 0.2)
	local darkDoor = Kit.part({
		Name = "DarkDoor",
		Size = Vector3.new(6, 10, 0.4),
		CFrame = hinge * CFrame.Angles(0, math.rad(100), 0) * CFrame.new(3, 0, 0),
		Color = Color3.fromRGB(60, 40, 30),
		Material = Enum.Material.Wood,
		CanCollide = false,
		Parent = set,
	})
	local rim = sbox(set, "RimLight", 4, 11, 27, 8, 11.2, 28, Color3.fromRGB(255, 230, 190), Enum.Material.Neon)
	local rimL = Kit.light(rim, 2, 14, Color3.fromRGB(255, 220, 180), "SpotLight")
	rimL.Face = Enum.NormalId.Bottom
	rimL.Angle = 60
	local stagePup = Figures.puppeteer(set, "StagePuppeteer")
	local px, pz = S(6, 34)
	stagePup.Lower:PivotTo(CFrame.new(px, 0, pz))
	stagePup.Upper:PivotTo(CFrame.new(px, 5, pz))
	local tx, tz = S(21, 4)
	local camTarget = Vector3.new(nx, 4.2, nz + 1)
	set:SetAttribute("TvCam", CFrame.lookAt(Vector3.new(tx, 5, tz), camTarget))
	set:SetAttribute("WideCam", CFrame.lookAt(Vector3.new(tx, 7.5, tz - 4), camTarget + Vector3.new(0, 1, 0)))
	set:SetAttribute("EyesCam", CFrame.lookAt(Vector3.new(nx, 4.25, nz - 3.2), Vector3.new(nx, 4.2, nz)))
	set:SetAttribute("NellPivot", nellPivot)
	return {
		folder = set,
		stage = stage,
		puppets = puppets,
		nell = nell,
		nellPivot = nellPivot,
		puppetMarks = marks,
		audienceMarks = audience,
		tvCam = CFrame.lookAt(Vector3.new(tx, 5, tz), camTarget),
		wideCam = CFrame.lookAt(Vector3.new(tx, 7.5, tz - 4), camTarget + Vector3.new(0, 1, 0)),
		darkDoor = darkDoor,
		darkHinge = hinge,
		darkDoorPos = Vector3.new(doorX, 0, doorZ),
		darkCam = CFrame.lookAt(Vector3.new(doorX + 6, 3.5, doorZ - 9), Vector3.new(doorX, 3, doorZ + 1)),
		stagePuppeteer = stagePup,
	}
end

return House
