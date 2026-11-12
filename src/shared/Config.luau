-- Hush Hour: tuning values from the GDD. Server and client both read this.
local Config = {}

Config.MaxPlayers = 4

-- Movement (GDD: Controls and Production Handoff)
Config.WalkSpeed = 14
Config.SprintSpeed = 18
Config.SprintSeconds = 5
Config.CrouchSpeed = 7

-- Roles. Slot number follows the player all episode.
Config.Stations = { "Recorder", "Breaker", "TV", "Radio" }
Config.Slots = {
	[1] = {
		role = "Recorder",
		station = "Recorder",
		room = "Upstairs edit room",
		challenges = { "ReelTiming", "SpliceOrder" },
		color = Color3.fromRGB(232, 92, 92),
	},
	[2] = {
		role = "Power",
		station = "Breaker",
		room = "Utility room",
		challenges = { "BreakerPattern", "ResetTiming" },
		color = Color3.fromRGB(88, 150, 240),
	},
	[3] = {
		role = "Picture",
		station = "TV",
		room = "Den CRT",
		challenges = { "TVTuning", "ButtonMatch" },
		color = Color3.fromRGB(96, 200, 120),
	},
	[4] = {
		role = "Sound",
		station = "Radio",
		room = "Kitchen radio",
		challenges = { "RadioPatch", "ChannelHunt" },
		color = Color3.fromRGB(240, 200, 80),
	},
}

Config.StationInfo = {
	Recorder = { label = "Edit room recorder", room = "Edit room", slot = 1, minDuration = 16 },
	Breaker = { label = "Utility breaker", room = "Utility", slot = 2, minDuration = 14 },
	TV = { label = "Den TV", room = "Den", slot = 3, minDuration = 10 },
	Radio = { label = "Kitchen radio", room = "Kitchen", slot = 4, minDuration = 10 },
	Console = { label = "Service console", room = "Den", slot = 0, minDuration = 8 },
}

-- Order a lone player walks: Edit room -> Utility -> Kitchen -> Den
Config.SoloOrder = { "Recorder", "Breaker", "Radio", "TV" }
-- Starting assignment groups by living count (GDD page 6)
Config.AssignmentGroups = {
	[1] = { { "Recorder", "Breaker", "Radio", "TV" } },
	[2] = { { "Recorder", "TV" }, { "Breaker", "Radio" } },
	[3] = { { "Recorder" }, { "Breaker" }, { "TV", "Radio" } },
	[4] = { { "Recorder" }, { "Breaker" }, { "TV" }, { "Radio" } },
}
Config.WaveWindow = { 96, 43, 24, 19 }

Config.ChallengeInfo = {
	ReelTiming = { label = "Reel Timing", kind = "Timing" },
	ResetTiming = { label = "Reset Timing", kind = "Timing" },
	SpliceOrder = { label = "Splice Order", kind = "Sequence" },
	BreakerPattern = { label = "Breaker Pattern", kind = "Sequence" },
	TVTuning = { label = "TV Tuning", kind = "Tuning" },
	ButtonMatch = { label = "Button Match", kind = "Match" },
	RadioPatch = { label = "Radio Patch", kind = "Patch" },
	ChannelHunt = { label = "Channel Hunt", kind = "Channel" },
}

Config.ChallengeHelp = {
	Timing = "Press E / X / PRESS when the marker crosses the green band. Hit 3 sweeps.",
	Sequence = "Watch the four symbols flash, then press them in the same order.",
	Tuning = "Turn the dial (A/D or the arrows) onto the target symbol and hold it there to lock. Lock 2 signals.",
	Match = "Press the button that matches the symbol on the screen. Match 3 screens.",
	Patch = "Tap a cable end, then tap the end with the same shape. Lock all 4 pairs.",
	Channel = "Turn through the channels. Confirm the 2 channels whose symbols match the target codes.",
}

-- Symbols carry a glyph and a name so colour is never required.
Config.Symbols = {
	Star = { glyph = "★", color = Color3.fromRGB(255, 220, 90) },
	Circle = { glyph = "●", color = Color3.fromRGB(120, 200, 255) },
	Triangle = { glyph = "▲", color = Color3.fromRGB(120, 230, 140) },
	Square = { glyph = "■", color = Color3.fromRGB(255, 130, 130) },
	Diamond = { glyph = "◆", color = Color3.fromRGB(220, 150, 255) },
	Cross = { glyph = "✚", color = Color3.fromRGB(255, 170, 90) },
	Club = { glyph = "♣", color = Color3.fromRGB(200, 200, 240) },
	Heart = { glyph = "♥", color = Color3.fromRGB(255, 110, 160) },
	Gear = { glyph = "⚙", color = Color3.fromRGB(190, 190, 190) },
}
Config.SymbolOrder = { "Star", "Circle", "Triangle", "Square", "Diamond", "Cross", "Club", "Heart" }

Config.MarkColors = {
	Blue = { color = Color3.fromRGB(60, 110, 230), pattern = "Stripes" },
	Red = { color = Color3.fromRGB(210, 50, 50), pattern = "Dots" },
	Yellow = { color = Color3.fromRGB(240, 200, 40), pattern = "Checks" },
	Green = { color = Color3.fromRGB(60, 180, 80), pattern = "Waves" },
}

-- Puppeteer (GDD: Search and Lethal Sight)
Config.Monster = {
	WalkSpeed = 10,
	SprintSpeed = 21,
	SightConfirm = 0.6,
	SightRange = 80,
	SightHalfAngle = math.rad(62),
	KillRange = 2.5,
	ChaseGiveUp = 30,
}

Config.HideGrace = 5
Config.DeathCutsceneLength = 7.5
Config.MaxStrikes = 3
Config.VoteSeconds = 20
Config.ExitSeconds = 58
Config.FrontGateAt = 40
Config.SideGateAt = 44

Config.Chapters = {
	"Forbidden Disc",
	"Warmup",
	"Sound Check",
	"Mum's Call",
	"HIDE",
	"Return Signal",
	"Last Broadcast",
}

-- Default response windows for command kinds (seconds)
Config.Windows = {
	mark = 8,
	crouch = 6,
	still = 3.4,
	lookaway = 6,
	touch = 8,
	touch2 = 12,
	named = 6,
	symbol = 8,
	zone = 12,
	fake = 4,
}

return Config
