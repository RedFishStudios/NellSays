-- First-person movement: walk 14, sprint 18 for up to 5s, crouch 7. E interact (prompts), Q ping.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config)

local Controls = {}
local player = Players.LocalPlayer
local crouching = false
local sprinting = false
local stamina = Config.SprintSeconds
Controls.locked = false -- cutscenes / hiding
Controls.onPing = nil

local function humanoid()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

function Controls.setCrouch(on)
	if crouching == on then
		return
	end
	crouching = on
	Net.send("Crouch", on)
end

function Controls.isCrouching()
	return crouching
end
function Controls.stamina()
	return stamina / Config.SprintSeconds
end

local function onSprint(_, state)
	if state == Enum.UserInputState.Begin then
		sprinting = true
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		sprinting = false
	end
	return Enum.ContextActionResult.Pass
end

local function onCrouch(_, state)
	if state == Enum.UserInputState.Begin then
		Controls.setCrouch(not crouching)
	end
	return Enum.ContextActionResult.Sink
end

local function onPing(_, state)
	if state == Enum.UserInputState.Begin then
		Controls.ping("Here")
	end
	return Enum.ContextActionResult.Sink
end

function Controls.ping(label)
	local cam = workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local hit = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 80, params)
	local pos = hit and hit.Position or (cam.CFrame.Position + cam.CFrame.LookVector * 20)
	Net.send("Ping", pos, label)
end

function Controls.init()
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMaxZoomDistance = 0.5
	ContextActionService:BindAction("HushSprint", onSprint, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("HushSprint", "Sprint")
	ContextActionService:SetPosition("HushSprint", UDim2.new(1, -170, 1, -150))
	ContextActionService:BindAction("HushCrouch", onCrouch, true, Enum.KeyCode.C, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("HushCrouch", "Crouch")
	ContextActionService:SetPosition("HushCrouch", UDim2.new(1, -240, 1, -100))
	ContextActionService:BindAction("HushPing", onPing, true, Enum.KeyCode.Q, Enum.KeyCode.DPadUp)
	ContextActionService:SetTitle("HushPing", "Ping")
	ContextActionService:SetPosition("HushPing", UDim2.new(1, -100, 1, -220))

	player.CharacterAdded:Connect(function()
		crouching = false
		stamina = Config.SprintSeconds
		Net.send("Crouch", false)
	end)

	local lookAcc = 0
	RunService.RenderStepped:Connect(function(dt)
		local hum = humanoid()
		if hum then
			local moving = hum.MoveDirection.Magnitude > 0.1
			local speed = Config.WalkSpeed
			if crouching then
				speed = Config.CrouchSpeed
			elseif sprinting and moving and stamina > 0 then
				speed = Config.SprintSpeed
				stamina = math.max(0, stamina - dt)
			else
				stamina = math.min(Config.SprintSeconds, stamina + dt * 0.6)
			end
			if Controls.locked then
				speed = 0
			end
			hum.WalkSpeed = speed
			local target = crouching and Vector3.new(0, -1.7, 0) or Vector3.zero
			hum.CameraOffset = hum.CameraOffset:Lerp(target, math.min(1, dt * 10))
		end
		lookAcc += dt
		if lookAcc >= 0.1 then
			lookAcc = 0
			local cam = workspace.CurrentCamera
			if cam then
				Net.sendUnreliable("Look", cam.CFrame.LookVector)
			end
		end
	end)
end

return Controls
