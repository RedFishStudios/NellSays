--@localscript
-- Hush Hour client entry point.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
ReplicatedStorage:WaitForChild("GameState")
ReplicatedStorage:WaitForChild("Remotes")

local Client = script.Parent
local Ui = require(Client.Ui)
local Controls = require(Client.Controls)
local Tv = require(Client.Tv)
local Cinema = require(Client.Cinema)
local Hud = require(Client.Hud)
local Minigames = require(Client.Minigames)
local LobbyUi = require(Client.LobbyUi)
local TestPanel = require(Client.TestPanel)

local player = Players.LocalPlayer
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

local gui = Ui.new("ScreenGui", {
	Name = "HushHour",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
local hudRoot =
	Ui.new("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })

Controls.init()
Tv.init(hudRoot)
Cinema.init(hudRoot)
Hud.init(hudRoot)
Minigames.init(hudRoot)
LobbyUi.init(hudRoot)
TestPanel.init(hudRoot)
print("[HushHour] client ready")
