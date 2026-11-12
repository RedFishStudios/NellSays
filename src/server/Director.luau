-- Episode flow: Forbidden Disc -> Warmup -> Sound Check -> Mum's Call -> HIDE -> Return Signal -> Last Broadcast.
-- "Full" follows the GDD schedule; "Quick" keeps every rule but trims repeated cues and waves.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local Roster = require(script.Parent.Roster)
local Props = require(script.Parent.Props)
local Cues = require(script.Parent.Cues)
local Stations = require(script.Parent.Stations)
local Hiding = require(script.Parent.Hiding)
local Puppeteer = require(script.Parent.Puppeteer)
local Death = require(script.Parent.Death)
local Lights = require(script.Parent.Lights)
local Clock, Fx = State.Clock, State.Fx
local C = Cues.C

local Director = {}
local H
local thread
local quick = false
local ending = nil
local skipVotes = {}
local skipOpen = false
local votes = {}

function Director.bind(house)
	H = house
end

local function q()
	return quick
end

---------------------------------------------------------------- helpers
local function wait(s)
	Clock.wait(s)
end

local function say(text, speaker, source, opts)
	return Cues.say(text, speaker or "Nell", source or "TV", opts)
end

local function cue(spec, extra)
	if #Roster.living() == 0 then
		return { passed = {}, failed = {}, allPassed = false }
	end
	if extra then
		for k, v in pairs(extra) do
			spec[k] = v
		end
	end
	return Cues.run(spec)
end

local function named(slot, propId, verb)
	local owner = Roster.jobOwner(slot)
	if not owner then
		return
	end
	local s = owner:GetAttribute("Slot") or slot
	local spec = C.named(s, propId, ("Nell says, Player %d, %s."):format(s, verb))
	spec.target = s
	return cue(spec, { label = "Named order" })
end

local function objective(text)
	State.set("Objective", text)
end

local function chapter(i)
	State.set("ChapterIndex", i)
	State.set("Chapter", Config.Chapters[i])
	Fx.cine("Chapter", { index = i, name = Config.Chapters[i] })
	Fx.sfx("Clapper")
	Clock.wait(2.5)
end

local function tv(mode)
	State.set("TV", mode)
end

local function flash(part, seconds, sfxName)
	if not part then
		return
	end
	part.Transparency = 0
	if sfxName then
		Fx.sfx(sfxName, part.Position)
	end
	task.delay(seconds, function()
		part.Transparency = 1
	end)
end

local function openDoor(part, baseCF, hingeOffset, angle)
	local hinge = baseCF * CFrame.new(hingeOffset)
	local rel = hinge:Inverse() * baseCF
	TweenService
		:Create(part, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { CFrame = hinge * CFrame.Angles(0, angle, 0) * rel })
		:Play()
	part.CanCollide = false
end

local function resetWorld()
	if not H then
		return
	end
	H.frontDoor.CFrame = H.frontDoorCF
	H.frontDoor.CanCollide = true
	H.utilityDoor.CFrame = H.utilityDoorCF
	H.utilityDoor.CanCollide = true
	H.frontGate.Transparency = 0
	H.frontGate.CanCollide = true
	H.sideGate.Transparency = 0
	H.sideGate.CanCollide = true
	H.deadbolt.CFrame = CFrame.new(H.deadbolt.Position)
	H.denLamp.Enabled = false
	Lights.exitGuides(false)
	Lights.set("normal")
	local cup = H.scares.KitchenCupboard
	if cup then
		cup.CFrame = CFrame.new(26, 8.75, 57.35)
	end
	for _, n in ipairs({ "SidelightHand", "DiningFace", "UtilityFingers" }) do
		if H.scares[n] then
			H.scares[n].Transparency = 1
		end
	end
	tv("off")
	State.set("NellExpr", "idle")
	State.set("NellArms", false)
	State.set("TVWide", false)
	State.set("EditMonitor", "")
	State.set("HidePhase", "none")
	State.set("Objective", "")
	State.set("CueText", "")
	State.set("CueKind", "")
	Props.reset()
end

local function boltTurns()
	TweenService
		:Create(H.deadbolt, TweenInfo.new(0.35), { CFrame = H.deadbolt.CFrame * CFrame.Angles(0, 0, math.rad(90)) })
		:Play()
	Fx.sfx("Deadbolt", H.deadbolt.Position)
end

---------------------------------------------------------------- HIDE reveal + patrol
local function hideSequence(route, loopFrom, duration)
	State.set("HidePhase", "reveal")
	tv("nell")
	Fx.cine("Insert", { seconds = 9 })
	Fx.say("Nell", "Nell says...", "TV", { style = "whisper", duration = 1.6 })
	wait(1.8)
	Fx.sfx("StringTwang")
	State.set("NellExpr", "smile")
	wait(4.5)
	Fx.say("Nell", "HIDE!", "TV", { style = "scream", duration = 1.2 })
	Fx.sfx("Scream")
	Fx.sfx("LightsOff")
	Lights.set("dark", 0.5)
	Fx.loop("Ambience", true)
	Fx.loop("Heartbeat", true)
	State.set("HidePhase", "warning")
	objective("HIDE! Get into a hiding spot (press E at a closet, desk, couch, bench or tub)")
	Clock.setTimer("Hide", Config.HideGrace)
	wait(Config.HideGrace)
	Clock.clearTimer()
	State.set("HidePhase", "patrol")
	objective("Stay hidden. Watch through the gap. If it sees you, RUN.")
	Clock.setTimer("Patrol", duration)
	local start = route == "A" and H.patrolA or H.patrolB
	Puppeteer.run(start, route == "A" and H.patrolALoop or H.patrolBLoop, duration)
	Clock.clearTimer()
	Puppeteer.park()
	State.set("HidePhase", "none")
	Fx.loop("Heartbeat", false)
	Fx.loop("Ambience", false)
	for _, p in ipairs(Roster.living()) do
		if not Puppeteer.spotted[p] then
			Fx.result("ding", "Hide", "The Puppeteer never saw you", { p })
		end
	end
	Lights.set("dim", 1)
	say("Nell says, come out now.")
	Hiding.releaseAll(true)
	Lights.set("normal", 1.5)
end

---------------------------------------------------------------- chapters
local CH = {}

-- 1. Forbidden Disc (opening cutscene, unanimous skip after 8s)
CH[1] = function()
	chapter(1)
	objective("Watch the opening (all players can vote to skip after 8s)")
	local living = Roster.living()
	local host = living[1]
	for _, p in ipairs(living) do
		if p:GetAttribute("Slot") == 1 then
			host = p
		end
	end
	local solo = #living == 1
	State.set("Host", host and host.UserId or 0)
	table.clear(skipVotes)
	skipOpen = false
	State.set("SkipVotes", 0)
	Fx.loop("Rain", true)
	Fx.loop("Clock", true)
	Fx.loop("HouseHum", true)
	Fx.cine("Intro", {
		host = host and host.UserId or 0,
		hostSlot = host and host:GetAttribute("Slot") or 1,
		solo = solo,
		quick = quick,
	})
	local skipped = false
	local t0 = os.clock()
	local function at(t)
		while os.clock() - t0 < t do
			if os.clock() - t0 > 8 then
				skipOpen = true
			end
			local need = #Roster.living()
			local have = 0
			for p in pairs(skipVotes) do
				if p.Parent then
					have += 1
				end
			end
			State.set("SkipVotes", have)
			if skipOpen and need > 0 and have >= need then
				skipped = true
				return false
			end
			task.wait(0.1)
		end
		return true
	end
	local hostLine = solo and "My parents won't be home for a while. They told me not to play this. Just one round."
		or "Hey, my parents won't be home for a while. You guys wanna play this game? I'm forbidden to play it."
	-- Roblox TTS filters lines about parents being away, so the voice says a close variant; captions keep the GDD line.
	local hostVoice = solo and "Nobody's home for a while. They told me not to play this. Just one round."
		or "Hey, nobody's home for a while. You guys wanna play this game? I'm forbidden to play it."
	local beats = quick
			and {
				{
					1,
					function()
						Fx.say("Host", hostLine, "ROOM", { duration = 5, voiceText = hostVoice })
					end,
				},
				{
					6.5,
					function()
						Fx.sfx("Click")
						Fx.sfx("DoorSlam", H.frontDoor.Position)
						Lights.dip("Entry", 0.5, 0.55)
					end,
				},
				{ 7.6, boltTurns },
				{
					9,
					function()
						Fx.sfx("HandleRattle", H.frontDoor.Position)
					end,
				},
				{
					10.5,
					function()
						Fx.sfx("GateClang", H.sideGate.Position)
					end,
				},
				{
					12,
					function()
						Fx.sfx("TvOn", H.tvPos)
						tv("static")
					end,
				},
				{
					13.5,
					function()
						tv("nell")
						Fx.sfx("WoodClick", H.tvPos)
					end,
				},
				{
					15,
					function()
						Fx.say("Nell", "Oh. You came.", "TV")
					end,
				},
				{
					18,
					function()
						Fx.say("Nell", "Nell says, stand on your mark.", "TV")
					end,
				},
				{
					21.5,
					function()
						Fx.sfx("Clapper")
					end,
				},
				{ 22.5, nil },
			}
		or {
			{
				11,
				function()
					Fx.say("Host", hostLine, "ROOM", { duration = 6, voiceText = hostVoice })
				end,
			},
			{
				18,
				function()
					if not solo then
						Fx.say("Friend", "Just one round.", "ROOM")
					end
				end,
			},
			{
				24,
				function()
					Fx.sfx("Click")
				end,
			},
			{
				24.6,
				function()
					Fx.sfx("DoorSlam", H.frontDoor.Position)
					Lights.dip("Entry", 0.6, 0.55)
				end,
			},
			{ 26, boltTurns },
			{
				34,
				function()
					Fx.sfx("HandleRattle", H.frontDoor.Position)
				end,
			},
			{
				37,
				function()
					Fx.sfx("GateClang", H.sideGate.Position)
				end,
			},
			{
				41,
				function()
					Fx.sfx("TvOn", H.tvPos)
					tv("static")
				end,
			},
			{
				44,
				function()
					tv("nell")
					Fx.sfx("WoodClick", H.tvPos)
				end,
			},
			{
				49,
				function()
					Fx.say("Nell", "Oh. You came.", "TV")
				end,
			},
			{
				55,
				function()
					tv("frozen")
				end,
			},
			{
				58,
				function()
					Fx.sfx("StringTwang")
					tv("nell")
				end,
			},
			{
				64,
				function()
					Fx.say("Nell", "Nell says, stand on your mark.", "TV")
				end,
			},
			{
				68.5,
				function()
					Fx.sfx("Clapper")
				end,
			},
			{ 70, nil },
		}
	for _, b in ipairs(beats) do
		if not at(b[1]) then
			break
		end
		if b[2] then
			b[2]()
		end
	end
	skipOpen = false
	Fx.cine("IntroEnd", { skipped = skipped })
	tv("nell")
	Lights.set("normal")
	if skipped then
		Fx.sfx("DoorSlam", H.frontDoor.Position)
		H.deadbolt.CFrame = CFrame.new(H.deadbolt.Position) * CFrame.Angles(0, 0, math.rad(90))
		Fx.toast(
			'Recap: the front door slammed and locked itself. Nell is on the TV. Only obey orders that begin with "Nell says".'
		)
	end
	for i, p in ipairs(Roster.living()) do
		Roster.teleport(p, H.spawns[((p:GetAttribute("Slot") or i) - 1) % 4 + 1])
	end
	Fx.loop("Clock", false)
end

-- 2. Warmup
CH[2] = function()
	chapter(2)
	objective('Practice: obey only orders that begin with "Nell says"')
	say("Let's practise. Practice orders cost nothing.")
	cue(C.touch({ "Star" }, "Nell says, touch the star."), { practice = true, label = "Practice" })
	cue(C.touch({ "Circle" }, "Touch the circle.", false), { practice = true, label = "Practice (fake)" })
	if quick then
		objective("Follow Nell's orders. Mistakes now cost strikes.")
		say("Now it counts.")
		cue(C.crouch(true), { label = "Crouch" })
		cue(C.crouch(false), { label = "Hold the crouch" })
		cue(C.lookAway(), { label = "Look away" })
		return
	end
	cue(C.touch({ "Lamp" }, "Nell says, turn on the lamp."), { practice = true, label = "Practice" })
	objective("Follow Nell's orders. Mistakes now cost strikes.")
	say("Good. Now it counts.")
	cue(C.mark("Blue", true), { label = "Floor mark" })
	cue(C.mark("Red", false), { label = "Hold your mark" })
	cue(C.crouch(true), { label = "Crouch" })
	cue(C.crouch(false), { label = "Hold the crouch" })
	cue(C.lookAway(), { label = "Look away" })
	cue(C.mark("Yellow", true), { label = "Floor mark" })
	objective("Tape Marks")
	local r = cue(C.mark("Green", true), { label = "Tape Marks 1" })
	if r.allPassed then
		Fx.sfx("WoodClick")
	end
	r = cue(C.mark("Blue", false, "Now blue."), { label = "Tape Marks 2" })
	if r.allPassed then
		Fx.sfx("WoodClick")
	end
	cue(
		C.seq(
			{ { type = "touch", id = "Lamp" }, { type = "mark", color = "Red" } },
			"Nell says, touch the lamp, then stand on a red mark.",
			14
		),
		{ label = "Tape Marks 3" }
	)
	objective("Test the locked exits together")
	local unl = Props.listen(function(_, id)
		if id == "UtilityDoor" then
			flash(H.scares.UtilityFingers, 1.2, "WoodClick")
		end
	end)
	cue(
		C.touch(
			{ "FrontDoor", "UtilityDoor" },
			"Nell says, try the front door, then the teal door in the utility room.",
			true,
			40
		),
		{ label = "Locked exits" }
	)
	unl()
	cue(C.zone("Den", "Nell says, come back to the rug.", "the den", 25), { label = "Regroup" })
end

-- 3. Sound Check
CH[3] = function()
	chapter(3)
	objective("Den orders, then the stations")
	if not quick then
		cue(C.mark("Blue", true), { label = "Den cue" })
		named(3, "Triangle", "tap the triangle")
		cue(C.still(true), { label = "Freeze" })
		cue(C.still(false), { label = "Freeze (bait)" })
	else
		named(3, "Triangle", "tap the triangle")
	end
	say("Nell says, go to your stations.")
	objective("Go to your station (see the roster). Hold E at the station inside its zone.")
	State.set("EditMonitor", "cupboard")
	Fx.cine("Route", {})
	wait(quick and 8 or 20)
	local waves = quick and 1 or 3
	for w = 1, waves do
		say(("Nell says, wave %d. Ready... three, two, one."):format(w), "Nell", "TV", { duration = 3 })
		Stations.runWave(w)
		if not quick and #Roster.living() > 0 then
			cue(C.crouch(true), { label = "Station order" })
			cue(C.crouch(false), { label = "Station order (bait)" })
		end
	end
	Stations.clear()
	objective("Regroup in the entry")
	cue(
		C.zone("Hall", "Nell says, everyone back to the entry hall.", "the entry hall", quick and 25 or 30),
		{ label = "Regroup" }
	)
	if not quick then
		cue(C.touch({ "Curtain" }, "Open the curtain.", false), { label = "Curtain (bait)" })
		cue(C.mark("Green", true), { label = "Floor mark" })
		cue(C.mark("Blue", true), { label = "Floor mark" })
		cue(C.mark("Red", false, "Now red."), { label = "Floor change (bait)" })
		cue(C.still(true), { label = "Freeze" })
	end
	-- the TV shows the upstairs cupboard opening; the real one stays shut, then knocks
	tv("cupboard")
	Fx.cine("Insert", { seconds = 4 })
	Lights.dip("Landing sconce", 2, 0.45)
	wait(3)
	tv("nell")
	for _ = 1, 3 do
		Fx.sfx("Knock", H.scares.LinenCupboard)
		wait(0.6)
	end
	State.set("EditMonitor", "")
	wait(1)
end

-- 4. Mum's Call
CH[4] = function()
	chapter(4)
	objective("The phone is ringing. Answer it in the entry hall.")
	Props.setText("Phone", "Answer", "Telephone")
	local answeredBy
	local unl = Props.listen(function(p, id)
		if id == "Phone" and not answeredBy then
			answeredBy = p
		end
	end)
	for _ = 1, 2 do
		if answeredBy then
			break
		end
		Fx.sfx("PhoneRing", H.props.Phone.part.Position)
		local t = Clock.now()
		while Clock.now() - t < 4.6 and not answeredBy do
			task.wait(0.1)
		end
	end
	unl()
	Props.setText("Phone", "Touch", "Phone console")
	if answeredBy then
		Fx.result("ding", "Answer the phone", ("Player %d picked up"):format(answeredBy:GetAttribute("Slot") or 0))
	else
		Fx.toast("Nobody answered. The phone clicks onto speaker.")
	end
	local phonePos = H.props.Phone.part.Position
	wait(0.6)
	Fx.say("Mum", "Hey, I'm on my way back. Why is the front door open?", "PHONE", { pos = phonePos, duration = 4.2 })
	wait(5.9)
	-- the fake door request: no prefix. Trying the door costs a strike.
	State.set("CueText", "Open the door for me.")
	State.set("CueSource", "PHONE")
	Fx.say("Mum", "Open the door for me.", "PHONE", { pos = phonePos, duration = 1.6 })
	local baited = {}
	local unl2 = Props.listen(function(p, id)
		if id == "FrontDoor" and not baited[p] then
			baited[p] = true
		end
	end)
	wait(4)
	unl2()
	State.set("CueText", "")
	local any = false
	for p in pairs(baited) do
		any = true
		Fx.result("wrong", "That wasn't Nell", "You tried the door for the voice on the phone", { p })
		Roster.addStrike(p, "tried the door for the fake Mum", "Entry")
	end
	if not any then
		Fx.result("ding", "Restraint", "Nobody opened the door")
	end
	flash(H.scares.SidelightHand, 0.8, "GlassHit")
	wait(2.4)
	Fx.say("Copy", "...on my way back.", "UPSTAIRS", { pos = H.scares.LinenCupboard, duration = 1.8 })
	wait(2.5)
	if not quick then
		objective("Hall orders")
		cue(C.away(phonePos, 8, "Nell says, step away from the phone."), { label = "Step away" })
		cue(
			C.lookAt(Vector3.new(41.5, 7, 16), "Nell says, face the stairs.", "Look at the stairs"),
			{ label = "Face the stairs" }
		)
		cue(C.lookBack(), { label = "Look behind (bait)" })
		cue(C.still(true), { label = "Freeze" })
		named(4, "Phone", "tap the console")
		cue(
			C.zone("RunnerStop", "Nell says, follow the yellow runner.", "the stop marker", 15),
			{ label = "Yellow runner" }
		)
	end
	objective("Relay: press the matching shape in each room")
	local relay = quick and { { "Entry", "Triangle" } }
		or { { "Entry", "Triangle" }, { "Dining", "Star" }, { "Kitchen", "Circle" }, { "Utility", "Square" } }
	for _, r in ipairs(relay) do
		local room, sym = r[1], r[2]
		local res = cue(
			C.any(
				"Pad_" .. room .. "_" .. sym,
				("Nell says, press the %s in the %s."):format(sym:lower(), room:lower())
			),
			{ label = "Relay: " .. room, window = quick and 20 or 20 }
		)
		Lights.dip(room == "Utility" and "Utility" or room, 0.5, 1)
		if room == "Dining" then
			flash(H.scares.DiningFace, 0.8, nil)
		elseif room == "Kitchen" and res then
			local cup = H.scares.KitchenCupboard
			TweenService:Create(cup, TweenInfo.new(0.2), {
				CFrame = cup.CFrame
					* CFrame.new(0, -1.75, 0)
					* CFrame.Angles(math.rad(-80), 0, 0)
					* CFrame.new(0, 1.75, 0),
			}):Play()
			Fx.sfx("CupboardSlam", cup.Position)
		end
		wait(1)
	end
	objective("Back to the den")
	if not quick then
		cue(C.still(true), { label = "Freeze" })
		cue(C.still(false), { label = "Freeze (bait)" })
		cue(C.climb("Come up the stairs."), { source = "UPSTAIRS", speaker = "Copy", label = "Upstairs voice (bait)" })
	end
	cue(C.zone("Den", "Nell says, back to the den.", "the den", 25), { label = "Regroup" })
	if not quick then
		cue(C.mark("Blue", true), { label = "Regroup mark" })
	end
	Fx.sfx("PhoneRing", H.scares.LinenCupboard)
	tv("eyes")
	Fx.cine("Insert", { seconds = 3 })
	wait(3)
	tv("nell")
end

-- 5. HIDE
CH[5] = function()
	chapter(5)
	objective("Stay close to the marked rooms")
	cue(C.crouch(true), { label = "Crouch" })
	if not quick then
		cue(C.mark("Green", true), { label = "Floor mark" })
	end
	hideSequence("A", nil, quick and 45 or 60)
	if quick then
		return
	end
	objective("Regroup on the ground floor")
	cue(C.crouch(true), { label = "Crouch" })
	cue(C.crouch(false), { label = "Hold the crouch (bait)" })
	cue(
		C.seq(
			{ { type = "touch", id = "HallLamp" }, { type = "mark", color = "Blue" } },
			"Nell says, touch the hall lamp, then stand on a blue mark.",
			16
		),
		{ label = "Two-step" }
	)
	cue(C.still(true), { label = "Freeze" })
	cue(C.zone("Den", "Nell says, stay near the den.", "the den", 12), { label = "Regroup" })
	hideSequence("B", nil, 60)
	objective("Back to the den and the service console")
	cue(C.mark("Blue", true), { label = "Floor mark" })
	cue(C.symbol(), { label = "Match the symbol" })
	cue(C.still(true), { label = "Freeze" })
	cue(C.still(false), { label = "Freeze (bait)" })
	cue(C.lookAway(), { label = "Look away" })
	cue(C.still(true, nil), { text = "Nell says, let the picture run.", label = "Let it run" })
	tv("eject")
	wait(2)
	tv("nell")
end

-- 6. Return Signal
CH[6] = function()
	chapter(6)
	objective("Group repair at the service console")
	State.set("TVWide", true)
	cue(
		C.zone("Console", "Nell says, everyone to the service console.", "the service console", 20),
		{ label = "Regroup" }
	)
	if not quick then
		cue(C.touch({ "Star" }, "Nell says, touch the star."), { label = "Maintenance clue" })
		cue(C.mark("Yellow", true), { label = "Floor mark" })
	end
	local function ownerOf(slot)
		return Roster.jobOwner(slot)
	end
	-- round 1: chosen green-bar or pattern challenge
	local o1 = ownerOf(1) or Roster.living()[1]
	if o1 then
		say(("Nell says, Player %d, run the console."):format(o1:GetAttribute("Slot") or 1))
		Stations.runConsole(1, Stations.challengeFor("Recorder"), o1, quick and 45 or 40)
	end
	if not quick then
		cue(C.zone("Console", "Nell says, everyone ready at the console.", "the console", 12), { label = "Team ready" })
		-- round 2: radio cables + a true/fake confirmation
		local o2 = ownerOf(4) or Roster.living()[1]
		if o2 then
			say(("Nell says, Player %d, patch the signal."):format(o2:GetAttribute("Slot") or 4))
			Stations.runConsole(2, Stations.challengeFor("Radio"), o2, 40)
		end
		cue(C.touch({ "Deck" }, "Confirm on the deck.", false), { label = "Confirmation (bait)" })
		-- round 3: lock the TV signal while teammates match floor symbols
		local o3 = ownerOf(3) or Roster.living()[1]
		if o3 then
			say(
				("Nell says, Player %d, lock the picture. Everyone else, find a mark."):format(
					o3:GetAttribute("Slot") or 3
				)
			)
			local spec = C.symbol()
			spec.exclude = o3
			spec.label = "Floor symbols"
			spec.window = 20
			task.spawn(function()
				Clock.wait(3)
				if #Roster.living() > 1 then
					Cues.run(spec)
				end
			end)
			Stations.runConsole(3, Stations.challengeFor("TV"), o3, 40)
		end
		Fx.sfx("Latch", H.tvPos)
		objective("Arm the Eject relay")
		cue(C.mark("Green", true), { label = "Floor mark" })
		cue(C.mark("Blue", true), { label = "Floor mark" })
	end
	tv("puppets")
	State.set("TVWide", true)
	Fx.cine("Insert", { seconds = 4 })
	wait(2)
	tv("nell")
	cue(C.touch({ "Deck" }, "Press Play again.", false), { label = "Press Play (bait)" })
	if not quick then
		Props.setEnabled("Relay", true)
		cue(C.any("Relay", "Nell says, touch the relay."), { label = "Arm the relay" })
		cue(C.mark("Yellow", true), { label = "Floor mark" })
		Fx.loop("Rain", false)
		wait(2)
		Fx.loop("Rain", true)
	end
end

-- 7. Last Broadcast (final commands, vote, ending)
local function runVote()
	State.set("Phase", "Vote")
	objective("Vote: Stay for Sign-Off or Pull the Disc")
	table.clear(votes)
	State.set("VotePull", 0)
	State.set("VoteStay", 0)
	Clock.setTimer("Vote", Config.VoteSeconds)
	Fx.say("Nell", "Will you stay for the sign-off?", "TV")
	while Clock.timerRemaining() > 0 do
		local living = Roster.living()
		local pull, stay = 0, 0
		for _, p in ipairs(living) do
			if votes[p] == "Pull" then
				pull += 1
			elseif votes[p] == "Stay" then
				stay += 1
			end
		end
		State.set("VotePull", pull)
		State.set("VoteStay", stay)
		if pull + stay >= #living and #living > 0 then
			break
		end
		task.wait(0.2)
	end
	Clock.clearTimer()
	local living = Roster.living()
	local pull = 0
	for _, p in ipairs(living) do
		if votes[p] == "Pull" then
			pull += 1
		end
	end
	State.set("Phase", "Playing")
	-- strict majority pulls the disc; tie or expiry stays for the sign-off
	return pull * 2 > #living and "OffAir" or "Audience"
end

local function finish(name)
	ending = name
	Puppeteer.park()
	Stations.clear()
	Clock.clearTimer()
	State.set("Phase", "Results")
	State.set("Ending", name)
	State.set("CueText", "")
	objective("")
	local results = {}
	for _, p in ipairs(Roster.all()) do
		if p:GetAttribute("Slot") and p:GetAttribute("Slot") > 0 then
			local outcome = p:GetAttribute("Outcome")
			if outcome == "" or outcome == nil then
				outcome = p:GetAttribute("Alive") and "Survived" or "Puppet"
			end
			table.insert(results, {
				slot = p:GetAttribute("Slot"),
				name = p.DisplayName,
				outcome = outcome,
				cause = p:GetAttribute("Cause") or "",
				strikes = p:GetAttribute("Strikes") or 0,
			})
		end
	end
	Net.fireAll("Results", name, results)
end
Director.finish = finish

local function offAir()
	State.set("Ending", "")
	objective("Off Air: gather at the deck")
	cue(C.zone("Deck", "Nell says, gather at the deck.", "the DVD deck", 15), { label = "Gather" })
	cue(
		C.pick("Gear", { "Star", "Gear", "Club", "Heart" }, "Nell says, match the service symbol."),
		{ label = "Service symbol", hint = "Pick the service symbol shown on the console" }
	)
	Props.setEnabled("Relay", true)
	cue(C.any("Relay", "Nell says, set the relay to Service."), { label = "Relay to Service" })
	-- Eject (hold 2s), then Break Disc (hold 2s); any survivor
	objective("Hold Eject on the deck, then hold Break Disc")
	Props.setText("Deck", "Eject", "DVD deck")
	Props.setHold("Deck", 2)
	local stage = 0
	local unl = Props.listen(function(p, id)
		if id == "Deck" then
			if stage == 0 then
				stage = 1
				Fx.sfx("Click", H.tvPos)
				Props.setText("Deck", "Break Disc", "The disc")
			elseif stage == 1 then
				stage = 2
			end
		end
	end)
	Fx.say("Nell", "Nell says, eject the disc and break it.", "TV")
	Clock.setTimer("Break the disc", 30)
	while stage < 2 and #Roster.living() > 0 do
		if Clock.timerRemaining() <= 0 then
			Clock.setTimer("Break the disc", 30)
		end
		task.wait(0.1)
	end
	unl()
	Clock.clearTimer()
	Props.setText("Deck", "Use", "DVD deck")
	Props.setHold("Deck", 0)
	if #Roster.living() == 0 then
		return
	end
	Fx.sfx("DiscSnap", H.tvPos)
	Fx.result("ding", "Break the disc", "The strings go slack")
	State.set("NellExpr", "slack")
	Fx.say("Nell", "Nell says, follow the porch light.", "TV")
	wait(2.5)
	Lights.set("dark")
	Fx.sfx("LightsOff")
	tv("off")
	wait(1.4)
	Lights.exitGuides(true)
	Lights.set("dim")
	Fx.loop("Ambience", true)
	-- 58s exit pursuit with a 5s search warning; retry if anyone is left inside
	local attempt = 0
	while true do
		attempt += 1
		local inside = Roster.living()
		if #inside == 0 then
			break
		end
		State.set("HidePhase", "escape")
		objective("ESCAPE! Front gate opens at 40s, side gate at 44s. Cross the street line.")
		Clock.setTimer("Exit", Config.ExitSeconds)
		local exitStart = Clock.now()
		local monsterStarted = false
		local frontOpen, sideOpen = Props.unlocked.FrontDoor, Props.unlocked.UtilityDoor
		while Clock.timerRemaining() > 0 do
			local t = Clock.now() - exitStart
			if not monsterStarted and t >= Config.HideGrace then
				monsterStarted = true
				task.spawn(Puppeteer.run, H.patrolB, H.patrolBLoop, nil, 2)
			end
			if not frontOpen and t >= Config.FrontGateAt then
				frontOpen = true
				Props.unlocked.FrontDoor = true
				openDoor(H.frontDoor, H.frontDoorCF, Vector3.new(4, 0, 0), math.rad(-100))
				H.frontGate.Transparency = 0.8
				H.frontGate.CanCollide = false
				Fx.sfx("Deadbolt", H.frontDoor.Position)
				Fx.sfx("Latch", H.frontGate.Position)
				Fx.toast("The front door and front gate are OPEN!")
			end
			if not sideOpen and t >= Config.SideGateAt then
				sideOpen = true
				Props.unlocked.UtilityDoor = true
				openDoor(H.utilityDoor, H.utilityDoorCF, Vector3.new(0, 0, -4), math.rad(100))
				H.sideGate.Transparency = 0.8
				H.sideGate.CanCollide = false
				Fx.sfx("Latch", H.sideGate.Position)
				Fx.toast("The teal door and side gate are OPEN!")
			end
			for _, p in ipairs(Roster.living()) do
				local r = Roster.root(p)
				if r and r.Position.Z < H.exitZ then
					p:SetAttribute("Exited", true)
					p:SetAttribute("Outcome", "Escaped")
					p:SetAttribute("Cause", "Crossed the street line")
					Hiding.forget(p)
					Fx.result("ding", "Escaped", "You crossed the street line", { p })
					Fx.toast(("Player %d escaped!"):format(p:GetAttribute("Slot") or 0))
				end
			end
			if #Roster.living() == 0 then
				break
			end
			task.wait(0.1)
		end
		Clock.clearTimer()
		local left = Roster.living()
		if #left == 0 then
			break
		end
		Puppeteer.park()
		for _, p in ipairs(left) do
			Fx.result("wrong", "Missed the exit", "Time ran out inside the house", { p })
			Roster.addStrike(p, "missed the timed exit", "the house")
		end
		while Death.busy() do
			task.wait(0.2)
		end
		if #Roster.living() > 0 then
			Fx.toast("Retry: another 58 seconds to get out.")
		end
	end
	Puppeteer.park()
	Fx.loop("Ambience", false)
	State.set("HidePhase", "none")
end

local function audience()
	objective("Stay for the sign-off")
	cue(C.mark("Yellow", true), { label = "Yellow mark" })
	cue(C.lookAt(nil, "Nell says, face the television."), { label = "Face the CRT" })
	local a = Config.SymbolOrder[math.random(1, 4)]
	State.set("TVSymbol", a)
	cue(
		C.pick(a, { "Star", "Circle", "Triangle", "Square" }, "Nell says, match the symbol on the screen."),
		{ label = "Match symbol 1", hint = "The TV shows " .. a }
	)
	local b = Config.SymbolOrder[math.random(5, 8)]
	State.set("TVSymbol", b)
	cue(
		C.pick(b, { "Diamond", "Cross", "Club", "Heart" }, "Nell says, and this one."),
		{ label = "Match symbol 2", hint = "The TV shows " .. b }
	)
	State.set("TVSymbol", "")
	cue(C.mark("Blue", true, "Nell says, take your places."), { label = "Take your places" })
	-- the room becomes the set
	Fx.cine("ToSet", {})
	wait(1)
	local survivors = Roster.living()
	for i, p in ipairs(survivors) do
		Roster.teleport(p, H.studio.audienceMarks[(i - 1) % 4 + 1] * CFrame.Angles(0, math.rad(180), 0))
	end
	Fx.sfx("Clapper")
	objective("Stand on your mark")
	wait(2)
	cue(C.still(true), { label = "Stage mark 1" })
	cue(C.crouch(true), { label = "Stage mark 2" })
	cue(C.still(true), { text = "Nell says, smile for the camera. Hold still.", label = "Stage mark 3" })
	Fx.say("Nell", "Just... one... round.", "STAGE", { style = "slow", duration = 4 })
	wait(4)
	-- transformation: strings lower and lift each survivor upright
	Fx.cine("Transform", {})
	Fx.sfx("StringTwang")
	for _, p in ipairs(Roster.living()) do
		local char = p.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = true
			TweenService
				:Create(hrp, TweenInfo.new(6, Enum.EasingStyle.Sine), { CFrame = hrp.CFrame + Vector3.new(0, 1.2, 0) })
				:Play()
			local top = hrp.Position.Y + 12
			for _, n in ipairs({ "Head", "LeftHand", "RightHand", "Left Arm", "Right Arm" }) do
				local part = char:FindFirstChild(n)
				if part then
					local s = require(script.Parent.Build.Kit).string(
						char,
						part.Position + Vector3.new(0, 1.2 + part.Size.Y / 2, 0),
						Vector3.new(part.Position.X, top, part.Position.Z),
						Color3.fromRGB(235, 228, 210),
						0.05
					)
					s.Anchored = true
				end
			end
		end
		p:SetAttribute("Outcome", "Cast")
		p:SetAttribute("Cause", "Stayed for the sign-off")
	end
	wait(quick and 8 or 20)
	Fx.sfx("Clapper")
	wait(2)
end

CH[7] = function()
	chapter(7)
	objective("Final commands")
	State.set("NellArms", true)
	if quick then
		cue(C.mark("Blue", true), { label = "Final command" })
		cue(C.mark("Red", false), { label = "Final bait" })
	else
		cue(C.mark("Blue", true), { label = "Final 1" })
		cue(C.still(true), { label = "Final 2" })
		cue(C.still(false), { label = "Final 3 (bait)" })
		cue(C.touch({ "Lamp" }, "Nell says, touch the lamp."), { label = "Final 4" })
		cue(C.mark("Red", true), { label = "Final 5" })
		cue(C.mark("Green", false, "Change to green."), { label = "Final 6 (bait)" })
		cue(C.crouch(true), { label = "Final 7" })
		cue(C.crouch(false), { label = "Final 8 (bait)" })
		cue(C.lookAway(), { label = "Final 9" })
		cue(C.mark("Yellow", true), { label = "Final 10" })
	end
	if #Roster.living() == 0 then
		return
	end
	local choice = runVote()
	Fx.toast(choice == "OffAir" and "The party chose: PULL THE DISC" or "The party chose: STAY FOR SIGN-OFF")
	if choice == "OffAir" then
		offAir()
		local anyEscaped = false
		for _, p in ipairs(Roster.all()) do
			if p:GetAttribute("Outcome") == "Escaped" then
				anyEscaped = true
			end
		end
		if anyEscaped then
			Fx.cine("OffAirEnd", {})
			wait(3)
			finish("Off Air")
		else
			Fx.cine("FullCast", {})
			Fx.say("Nell", "Everyone made it.", "TV")
			wait(4)
			finish("Full Cast")
		end
	else
		audience()
		finish("The Audience")
	end
end

---------------------------------------------------------------- lifecycle
local function cleanup()
	Cues.abort()
	Stations.clear()
	Puppeteer.park()
	Hiding.releaseAll(true)
	Clock.clearTimer()
	State.set("HidePhase", "none")
	Fx.loop("Heartbeat", false)
	Fx.loop("Ambience", false)
end

local function cancelThread()
	if thread then
		if coroutine.status(thread) ~= "dead" then
			pcall(task.cancel, thread)
		end
		thread = nil
	end
	cleanup()
end

function Director.runFrom(index, opts)
	cancelThread()
	ending = nil
	State.set("Phase", "Playing")
	thread = task.spawn(function()
		if opts and opts.patrolOnly then
			State.set("ChapterIndex", 5)
			State.set("Chapter", "HIDE (test patrol)")
			hideSequence("A", nil, quick and 45 or 60)
			index = 6
		end
		for i = index, #CH do
			if #Roster.living() == 0 or ending then
				break
			end
			State.set("ChapterIndex", i)
			CH[i]()
		end
	end)
end

function Director.start(mode)
	quick = mode == "Quick"
	State.set("Mode", quick and "Quick" or "Full")
	resetWorld()
	Death.reset()
	Clock.releaseAll()
	Roster.inSession = true
	for i, p in ipairs(Roster.all()) do
		Roster.resetAttributes(p)
		local slot = p:GetAttribute("Slot")
		if not slot or slot == 0 then
			p:SetAttribute("Alive", false)
			p:SetAttribute("Outcome", "Spectating")
		else
			task.spawn(Roster.spawn, p, H.spawns[(slot - 1) % 4 + 1])
		end
	end
	task.wait(1)
	Director.runFrom(1)
end

function Director.jump(index)
	if State.get("Phase") ~= "Playing" and State.get("Phase") ~= "Vote" then
		return
	end
	resetWorld()
	if index > 1 then
		tv("nell")
		H.deadbolt.CFrame = CFrame.new(H.deadbolt.Position) * CFrame.Angles(0, 0, math.rad(90))
		Fx.loop("Rain", true)
		Fx.loop("HouseHum", true)
	end
	Director.runFrom(index)
end

function Director.testPatrol()
	if State.get("Phase") ~= "Playing" and State.get("Phase") ~= "Vote" then
		return
	end
	Director.runFrom(6, { patrolOnly = true })
end

function Director.stopAll()
	cancelThread()
	ending = nil
	Roster.inSession = false
end

function Director.isQuick()
	return quick
end

-- Called after deaths resolve: end the run when nobody is left inside.
function Director.checkEnd()
	local phase = State.get("Phase")
	if phase ~= "Playing" and phase ~= "Vote" then
		return
	end
	if #Roster.living() > 0 then
		return
	end
	local anyEscaped = false
	for _, p in ipairs(Roster.all()) do
		if p:GetAttribute("Outcome") == "Escaped" then
			anyEscaped = true
		end
	end
	cancelThread()
	if anyEscaped then
		Fx.cine("OffAirEnd", {})
		task.wait(3)
		finish("Off Air")
	else
		Fx.cine("FullCast", {})
		Fx.say("Nell", "Everyone made it.", "TV")
		task.wait(4)
		finish("Full Cast")
	end
end

Net.on("SkipVote", function(p)
	-- votes cast before the 8s mark are kept; they count once skipping opens
	if State.get("ChapterIndex") == 1 and State.get("Phase") == "Playing" then
		skipVotes[p] = true
	end
end)
Net.on("Vote", function(p, choice)
	if State.get("Phase") == "Vote" and Roster.isLiving(p) and (choice == "Pull" or choice == "Stay") then
		votes[p] = choice
	end
end)

Director.resetWorld = resetWorld
return Director
