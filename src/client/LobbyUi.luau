-- Pre-game lobby: Player 1-4 slots, challenge per role, Full Episode / Quick Test, Ready.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local T = Ui.Theme

local LobbyUi = {}
local player = Players.LocalPlayer
local gs = ReplicatedStorage:WaitForChild("GameState")

function LobbyUi.init(root)
	local panel = Ui.new("TextButton", {
		Name = "Lobby",
		Text = "",
		AutoButtonColor = false,
		Modal = true,
		Size = UDim2.new(0, 900, 0, 560),
		Position = UDim2.new(0.5, -450, 0.5, -280),
		BackgroundColor3 = T.Bg,
		BackgroundTransparency = 0.04,
		Parent = root,
	}, { Ui.corner(16), Ui.stroke(T.Accent, 2) })
	Ui.label({
		Text = "HUSH HOUR",
		Font = T.Bold,
		TextSize = 42,
		TextColor3 = T.Nell,
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.fromOffset(0, 12),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = panel,
	})
	Ui.label({
		Text = 'Pick a player number and a challenge. Only obey orders that begin with "Nell says".',
		TextSize = 15,
		TextColor3 = T.Dim,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 62),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = panel,
	})

	local cards = {}
	for i = 1, 4 do
		local info = Config.Slots[i]
		local card = Ui.new("Frame", {
			Size = UDim2.new(0, 205, 0, 250),
			Position = UDim2.fromOffset(18 + (i - 1) * 218, 94),
			BackgroundColor3 = T.Panel,
			Parent = panel,
		}, { Ui.corner(10), Ui.stroke(info.color, 2) })
		Ui.label({
			Text = ("PLAYER %d"):format(i),
			Font = T.Bold,
			TextSize = 22,
			TextColor3 = info.color,
			Size = UDim2.new(1, -16, 0, 26),
			Position = UDim2.fromOffset(8, 8),
			Parent = card,
		})
		Ui.label({
			Text = ("%s — %s"):format(info.role, info.room),
			TextSize = 13,
			TextColor3 = T.Dim,
			Size = UDim2.new(1, -16, 0, 34),
			Position = UDim2.fromOffset(8, 34),
			Parent = card,
		})
		local owner = Ui.label({
			Text = "Open",
			Font = T.Bold,
			TextSize = 16,
			Size = UDim2.new(1, -16, 0, 22),
			Position = UDim2.fromOffset(8, 70),
			Parent = card,
		})
		local claim = Ui.button({
			Text = "Claim",
			Size = UDim2.new(1, -16, 0, 36),
			Position = UDim2.fromOffset(8, 96),
			Parent = card,
		})
		claim.Activated:Connect(function()
			local f = gs.Slots:FindFirstChild("Slot" .. i)
			if f and f:GetAttribute("Owner") == player.UserId then
				Net.send("ReleaseSlot")
			else
				Net.send("ClaimSlot", i)
			end
		end)
		Ui.label({
			Text = "Challenge:",
			TextSize = 13,
			TextColor3 = T.Dim,
			Size = UDim2.new(1, -16, 0, 16),
			Position = UDim2.fromOffset(8, 140),
			Parent = card,
		})
		local chBtns = {}
		for c = 1, 2 do
			local name = info.challenges[c]
			local b = Ui.button({
				Text = Config.ChallengeInfo[name].label,
				TextSize = 14,
				Size = UDim2.new(1, -16, 0, 32),
				Position = UDim2.fromOffset(8, 158 + (c - 1) * 38),
				Parent = card,
			})
			b.Activated:Connect(function()
				Net.send("SetChallenge", i, c)
			end)
			chBtns[c] = b
		end
		cards[i] = { owner = owner, claim = claim, ch = chBtns }
	end

	-- mode selection (test lobby options)
	Ui.label({
		Text = "EPISODE",
		Font = T.Bold,
		TextSize = 14,
		TextColor3 = T.Dim,
		Size = UDim2.new(0, 200, 0, 18),
		Position = UDim2.fromOffset(18, 356),
		Parent = panel,
	})
	local fullBtn = Ui.button({
		Text = "1. FULL EPISODE  (~25 min)",
		Size = UDim2.new(0, 300, 0, 46),
		Position = UDim2.fromOffset(18, 378),
		Parent = panel,
	}, function()
		Net.send("SetMode", "Full")
	end)
	local quickBtn = Ui.button({
		Text = "2. QUICK TEST  (~6-8 min)",
		Size = UDim2.new(0, 300, 0, 46),
		Position = UDim2.fromOffset(330, 378),
		Parent = panel,
	}, function()
		Net.send("SetMode", "Quick")
	end)
	local modeDesc = Ui.label({
		Text = "",
		TextSize = 13,
		TextColor3 = T.Dim,
		Size = UDim2.new(0, 612, 0, 36),
		Position = UDim2.fromOffset(18, 428),
		Parent = panel,
	})

	local readyBtn = Ui.button({
		Text = "READY",
		Size = UDim2.new(0, 230, 0, 96),
		Position = UDim2.fromOffset(650, 356),
		BackgroundColor3 = T.Accent,
		TextColor3 = Color3.new(0, 0, 0),
		TextSize = 28,
		Parent = panel,
	})
	readyBtn.Activated:Connect(function()
		Net.send("Ready", not player:GetAttribute("Ready"))
	end)
	local readyInfo = Ui.label({
		Text = "",
		TextSize = 14,
		Size = UDim2.new(0, 230, 0, 20),
		Position = UDim2.fromOffset(650, 456),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = panel,
	})
	Ui.label({
		Text = "Controls: WASD move · Shift sprint (5s) · C crouch · E interact / station input / hide · Q ping · mouse look.\nController: left stick, L3 sprint, B crouch, X interact, D-pad up ping. Mobile: on-screen buttons.",
		TextSize = 13,
		TextColor3 = T.Dim,
		Size = UDim2.new(1, -36, 0, 40),
		Position = UDim2.new(0, 18, 1, -54),
		Parent = panel,
	})

	RunService.RenderStepped:Connect(function()
		local phase = gs:GetAttribute("Phase") or "Lobby"
		panel.Visible = phase == "Lobby"
		if not panel.Visible then
			return
		end
		local mySlot = player:GetAttribute("Slot") or 0
		for i = 1, 4 do
			local f = gs.Slots:FindFirstChild("Slot" .. i)
			local ownerId = f and f:GetAttribute("Owner") or 0
			local c = cards[i]
			local mine = ownerId == player.UserId
			if ownerId == 0 then
				c.owner.Text = "Open"
				c.owner.TextColor3 = T.Good
				c.claim.Text = "Claim"
				c.claim.AutoButtonColor = true
			else
				local p = Players:GetPlayerByUserId(ownerId)
				local ready = p and p:GetAttribute("Ready")
				c.owner.Text = (mine and "You" or ("Taken: " .. (f:GetAttribute("OwnerName") or "?")))
					.. (ready and "  ✓ READY" or "")
				c.owner.TextColor3 = mine and T.Accent or T.Dim
				c.claim.Text = mine and "Release" or "Taken"
			end
			local choice = f and f:GetAttribute("Challenge") or 1
			for k = 1, 2 do
				c.ch[k].BackgroundColor3 = choice == k and Config.Slots[i].color or T.Panel2
				c.ch[k].TextColor3 = choice == k and Color3.new(0, 0, 0) or T.Text
				c.ch[k].Text = (choice == k and "● " or "○ ")
					.. Config.ChallengeInfo[Config.Slots[i].challenges[k]].label
			end
		end
		local mode = gs:GetAttribute("Mode") or "Full"
		fullBtn.BackgroundColor3 = mode == "Full" and T.Accent or T.Panel2
		fullBtn.TextColor3 = mode == "Full" and Color3.new(0, 0, 0) or T.Text
		quickBtn.BackgroundColor3 = mode == "Quick" and T.Accent or T.Panel2
		quickBtn.TextColor3 = mode == "Quick" and Color3.new(0, 0, 0) or T.Text
		modeDesc.Text = mode == "Full"
				and "The GDD's normal chapter flow and timing: 3 station waves, 2 HIDE patrols, full cue decks."
			or "Shorter: fewer repeated cues, 1 station wave, 1 HIDE patrol. Real inputs, scoring, hiding, death and multiplayer rules stay on."
		local ready = player:GetAttribute("Ready")
		readyBtn.Text = mySlot == 0 and "PICK A SLOT" or (ready and "✓ READY" or "READY")
		local cd = gs:GetAttribute("Countdown") or 0
		readyInfo.Text = cd > 0 and ("Starting in %d..."):format(cd)
			or ("%d / %d ready"):format(gs:GetAttribute("ReadyCount") or 0, gs:GetAttribute("PlayerCount") or 0)
	end)
end

return LobbyUi
