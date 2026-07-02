-- Per-device UI. Every player -- describer and guessers alike -- renders
-- their own role-specific view here; there's no shared-screen assumption
-- anywhere in this script, by design (see roadmap: "no shared TV screen").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameStateUpdate = Remotes:WaitForChild("GameStateUpdate")
local DescriberPrompt = Remotes:WaitForChild("DescriberPrompt")
local RoundResult = Remotes:WaitForChild("RoundResult")
local DescriberTapWord = Remotes:WaitForChild("DescriberTapWord")
local SubmitGuess = Remotes:WaitForChild("SubmitGuess")

-- ---------------------------------------------------------------------------
-- Build the UI
-- ---------------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BabbleBloxUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

-- Status bar: phase, timer, live clue sentence
local statusBar = Instance.new("Frame")
statusBar.Size = UDim2.new(1, 0, 0, 70)
statusBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
statusBar.BorderSizePixel = 0
statusBar.Parent = screenGui

local phaseLabel = Instance.new("TextLabel")
phaseLabel.Size = UDim2.new(0.4, 0, 1, 0)
phaseLabel.BackgroundTransparency = 1
phaseLabel.TextColor3 = Color3.new(1, 1, 1)
phaseLabel.TextScaled = true
phaseLabel.Font = Enum.Font.GothamBold
phaseLabel.Text = "Waiting for players..."
phaseLabel.Parent = statusBar

local timerLabel = Instance.new("TextLabel")
timerLabel.Position = UDim2.new(0.4, 0, 0, 0)
timerLabel.Size = UDim2.new(0.2, 0, 1, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
timerLabel.TextScaled = true
timerLabel.Font = Enum.Font.GothamBold
timerLabel.Text = ""
timerLabel.Parent = statusBar

local clueLabel = Instance.new("TextLabel")
clueLabel.Position = UDim2.new(0.6, 0, 0, 0)
clueLabel.Size = UDim2.new(0.4, 0, 1, 0)
clueLabel.BackgroundTransparency = 1
clueLabel.TextColor3 = Color3.new(1, 1, 1)
clueLabel.TextScaled = true
clueLabel.Font = Enum.Font.Gotham
clueLabel.Text = ""
clueLabel.Parent = statusBar

-- Describer panel: secret answer + tappable word-bank grid
local describerPanel = Instance.new("Frame")
describerPanel.Name = "DescriberPanel"
describerPanel.Size = UDim2.new(1, 0, 1, -70)
describerPanel.Position = UDim2.new(0, 0, 0, 70)
describerPanel.BackgroundTransparency = 1
describerPanel.Visible = false
describerPanel.Parent = screenGui

local answerLabel = Instance.new("TextLabel")
answerLabel.Size = UDim2.new(1, 0, 0, 60)
answerLabel.BackgroundColor3 = Color3.fromRGB(50, 120, 60)
answerLabel.TextColor3 = Color3.new(1, 1, 1)
answerLabel.TextScaled = true
answerLabel.Font = Enum.Font.GothamBold
answerLabel.Text = ""
answerLabel.Parent = describerPanel

local wordGridFrame = Instance.new("ScrollingFrame")
wordGridFrame.Position = UDim2.new(0, 0, 0, 70)
wordGridFrame.Size = UDim2.new(1, 0, 1, -70)
wordGridFrame.BackgroundTransparency = 1
wordGridFrame.CanvasSize = UDim2.new(0, 0, 2, 0)
wordGridFrame.Parent = describerPanel

local wordGrid = Instance.new("UIGridLayout")
wordGrid.CellSize = UDim2.new(0, 150, 0, 60)
wordGrid.CellPadding = UDim2.new(0, 10, 0, 10)
wordGrid.Parent = wordGridFrame

-- Guesser panel: multiple-choice buttons (tap-friendly, no free typing needed)
local guesserPanel = Instance.new("Frame")
guesserPanel.Name = "GuesserPanel"
guesserPanel.Size = UDim2.new(1, 0, 1, -70)
guesserPanel.Position = UDim2.new(0, 0, 0, 70)
guesserPanel.BackgroundTransparency = 1
guesserPanel.Visible = false
guesserPanel.Parent = screenGui

local guessLayout = Instance.new("UIListLayout")
guessLayout.Padding = UDim.new(0, 12)
guessLayout.Parent = guesserPanel

-- ---------------------------------------------------------------------------
-- State + helpers
-- ---------------------------------------------------------------------------

local hasGuessedThisRound = false
local lastPhase = nil

local function clearGuessButtons()
	for _, child in ipairs(guesserPanel:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function buildDescriberWordBank(words)
	for _, child in ipairs(wordGridFrame:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	for _, word in ipairs(words) do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(0, 150, 0, 60)
		button.BackgroundColor3 = Color3.fromRGB(70, 90, 200)
		button.TextColor3 = Color3.new(1, 1, 1)
		button.TextScaled = true
		button.Font = Enum.Font.GothamBold
		button.Text = word
		button.Parent = wordGridFrame

		button.Activated:Connect(function()
			DescriberTapWord:FireServer(word)
		end)
	end
end

local function buildGuessOptions(options)
	clearGuessButtons()
	hasGuessedThisRound = false

	for _, option in ipairs(options) do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, -40, 0, 70)
		button.Position = UDim2.new(0, 20, 0, 0)
		button.BackgroundColor3 = Color3.fromRGB(200, 90, 70)
		button.TextColor3 = Color3.new(1, 1, 1)
		button.TextScaled = true
		button.Font = Enum.Font.GothamBold
		button.Text = option
		button.Parent = guesserPanel

		button.Activated:Connect(function()
			if hasGuessedThisRound then
				return
			end
			hasGuessedThisRound = true
			SubmitGuess:FireServer(option)
			button.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
		end)
	end
end

-- ---------------------------------------------------------------------------
-- Server events
-- ---------------------------------------------------------------------------

GameStateUpdate.OnClientEvent:Connect(function(state)
	phaseLabel.Text = state.phase
	timerLabel.Text = state.phase == "WaitingForPlayers" and "" or string.format("%d s", math.ceil(state.timeLeft or 0))
	clueLabel.Text = table.concat(state.clueWords or {}, " ")

	local isDescriber = state.describerName == localPlayer.Name
	describerPanel.Visible = (state.phase == "RoundIntro" or state.phase == "Describing") and isDescriber
	guesserPanel.Visible = state.phase == "Describing" and not isDescriber and state.describerName ~= nil

	-- Rebuild the guess options exactly once per round, at the RoundIntro -> * transition.
	if state.phase == "RoundIntro" and lastPhase ~= "RoundIntro" and state.guessOptions then
		buildGuessOptions(state.guessOptions)
	end

	lastPhase = state.phase
end)

DescriberPrompt.OnClientEvent:Connect(function(data)
	answerLabel.Text = "Describe: " .. data.answer
	buildDescriberWordBank(data.clueWordPool)
end)

RoundResult.OnClientEvent:Connect(function(result)
	clueLabel.Text = "Answer: " .. result.answer
end)
