-- Server-authoritative round state machine for a single Babble Blox server.
--
-- Single-place architecture: this server IS the lobby. There's no separate
-- lobby place and no TeleportService hop into a "game place" -- that would
-- introduce a loading screen exactly where Roblox players expect to hop in
-- and out freely. Players simply join this server and the game finds room
-- for them, whether it's mid-lobby or mid-round.
--
-- Phases: WaitingForPlayers -> RoundIntro -> Describing (90s) -> Reveal -> Scoring -> (next round or back to waiting)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local WordBank = require(ReplicatedStorage:WaitForChild("WordBank"))
local PlayerDataManager = require(ServerScriptService:WaitForChild("PlayerDataManager"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameStateUpdate = Remotes:WaitForChild("GameStateUpdate")
local DescriberPrompt = Remotes:WaitForChild("DescriberPrompt")
local RoundResult = Remotes:WaitForChild("RoundResult")
local DescriberTapWord = Remotes:WaitForChild("DescriberTapWord")
local SubmitGuess = Remotes:WaitForChild("SubmitGuess")

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local phase = "WaitingForPlayers"
local phaseDeadline = math.huge

local roundQueue = {} -- describer rotation order
local activePlayers = {} -- Player -> { score, hasGuessedCorrectly }
local waitingToJoin = {} -- players who joined mid-round; folded in at the next round boundary

local describer = nil
local currentPrompt = nil
local currentGuessOptions = nil
local clueWords = {}

local usedPromptIndices = {}
local usedPromptCount = 0

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function countActive()
	local n = 0
	for _ in pairs(activePlayers) do
		n += 1
	end
	return n
end

local function shuffled(list)
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = math.random(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

local function publicPlayerList()
	local list = {}
	for player, data in pairs(activePlayers) do
		table.insert(list, { userId = player.UserId, name = player.Name, score = data.score })
	end
	return list
end

local function currentStatePayload()
	local timeLeft = 0
	if phase ~= "WaitingForPlayers" then
		timeLeft = math.max(0, phaseDeadline - os.clock())
	end

	return {
		phase = phase,
		timeLeft = timeLeft,
		describerName = describer and describer.Name or nil,
		clueWords = clueWords,
		players = publicPlayerList(),
		promptCategory = currentPrompt and currentPrompt.category or nil,
		guessOptions = currentGuessOptions,
	}
end

local function broadcastState()
	GameStateUpdate:FireAllClients(currentStatePayload())
end

local function enterPhase(newPhase, duration)
	phase = newPhase
	phaseDeadline = duration == math.huge and math.huge or (os.clock() + duration)
	broadcastState()
end

local function pickNextDescriber()
	local attempts = #roundQueue
	for _ = 1, attempts do
		local candidate = table.remove(roundQueue, 1)
		if candidate == nil then
			break
		end
		table.insert(roundQueue, candidate) -- rotate to the back regardless
		if candidate.Parent and activePlayers[candidate] then
			return candidate
		end
	end
	return nil
end

local function admitWaitingPlayers()
	for _, player in ipairs(waitingToJoin) do
		if player.Parent and not activePlayers[player] then
			activePlayers[player] = { score = 0, hasGuessedCorrectly = false }
			table.insert(roundQueue, player)
		end
	end
	waitingToJoin = {}
end

local function pickPrompt()
	local pool = WordBank.Prompts
	if usedPromptCount >= #pool then
		usedPromptIndices = {}
		usedPromptCount = 0
	end

	local index
	repeat
		index = math.random(1, #pool)
	until not usedPromptIndices[index]

	usedPromptIndices[index] = true
	usedPromptCount += 1
	return pool[index]
end

-- ---------------------------------------------------------------------------
-- Round flow (forward-declared: these mutually reference each other)
-- ---------------------------------------------------------------------------

local startRound, advancePhase, endGameCheckAndContinue, revealAnswer, tick

startRound = function()
	admitWaitingPlayers()

	if countActive() < GameConfig.MIN_PLAYERS then
		describer = nil
		currentPrompt = nil
		currentGuessOptions = nil
		clueWords = {}
		enterPhase("WaitingForPlayers", math.huge)
		return
	end

	describer = pickNextDescriber()
	if not describer then
		enterPhase("WaitingForPlayers", math.huge)
		return
	end

	currentPrompt = pickPrompt()
	currentGuessOptions = shuffled(currentPrompt.guessOptions)
	clueWords = {}
	for _, data in pairs(activePlayers) do
		data.hasGuessedCorrectly = false
	end

	enterPhase("RoundIntro", GameConfig.INTRO_DURATION)

	-- The secret prompt only ever goes to the describer's client.
	DescriberPrompt:FireClient(describer, {
		answer = currentPrompt.answer,
		category = currentPrompt.category,
		clueWordPool = WordBank.ClueWordPool,
	})
end

revealAnswer = function()
	local correctGuessers = {}
	for player, data in pairs(activePlayers) do
		if data.hasGuessedCorrectly then
			table.insert(correctGuessers, player.Name)
		end
	end

	if describer and activePlayers[describer] then
		activePlayers[describer].score += #correctGuessers * GameConfig.DESCRIBER_POINTS_PER_CORRECT_GUESSER
		PlayerDataManager.AwardXp(describer, #correctGuessers * 10)
	end

	for player, data in pairs(activePlayers) do
		if data.hasGuessedCorrectly then
			PlayerDataManager.AwardXp(player, 15)
		end
	end

	RoundResult:FireAllClients({
		answer = currentPrompt and currentPrompt.answer or "",
		correctGuessers = correctGuessers,
		players = publicPlayerList(),
	})

	enterPhase("Reveal", GameConfig.REVEAL_DURATION)
end

endGameCheckAndContinue = function()
	if countActive() < GameConfig.MIN_PLAYERS then
		describer = nil
		currentPrompt = nil
		currentGuessOptions = nil
		clueWords = {}
		enterPhase("WaitingForPlayers", math.huge)
	else
		startRound()
	end
end

advancePhase = function()
	if phase == "RoundIntro" then
		enterPhase("Describing", GameConfig.DESCRIBING_DURATION)
	elseif phase == "Describing" then
		revealAnswer()
	elseif phase == "Reveal" then
		enterPhase("Scoring", GameConfig.SCORING_DURATION)
	elseif phase == "Scoring" then
		endGameCheckAndContinue()
	end
end

tick = function()
	if phase == "WaitingForPlayers" then
		admitWaitingPlayers()
		if countActive() >= GameConfig.MIN_PLAYERS then
			startRound()
		else
			broadcastState()
		end
		return
	end

	if os.clock() >= phaseDeadline then
		advancePhase()
	else
		broadcastState()
	end
end

-- ---------------------------------------------------------------------------
-- Client input
-- ---------------------------------------------------------------------------

DescriberTapWord.OnServerEvent:Connect(function(player, word)
	if phase ~= "Describing" or player ~= describer then
		return
	end
	if typeof(word) ~= "string" then
		return
	end
	if #clueWords >= GameConfig.MAX_CLUE_WORDS then
		return
	end

	local allowed = false
	for _, w in ipairs(WordBank.ClueWordPool) do
		if w == word then
			allowed = true
			break
		end
	end
	if not allowed then
		return
	end

	table.insert(clueWords, word)
	broadcastState()
end)

SubmitGuess.OnServerEvent:Connect(function(player, guessText)
	if phase ~= "Describing" or player == describer then
		return
	end
	if typeof(guessText) ~= "string" then
		return
	end

	local data = activePlayers[player]
	if not data or data.hasGuessedCorrectly then
		return
	end

	-- Guesses are always one of the pre-approved multiple-choice options sent
	-- to every client for this round, so no free-text filtering is needed here.
	if currentPrompt and guessText == currentPrompt.answer then
		data.hasGuessedCorrectly = true
		local timeLeft = math.max(0, phaseDeadline - os.clock())
		local bonus = math.floor((timeLeft / GameConfig.DESCRIBING_DURATION) * GameConfig.GUESS_POINTS_BASE)
		data.score += GameConfig.GUESS_POINTS_BASE + bonus
		broadcastState()
	end
end)

-- ---------------------------------------------------------------------------
-- Join / leave -- always accepted, never rejected mid-round
-- ---------------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player)
	PlayerDataManager.LoadProfile(player)

	if phase == "WaitingForPlayers" then
		activePlayers[player] = { score = 0, hasGuessedCorrectly = false }
		table.insert(roundQueue, player)
	else
		table.insert(waitingToJoin, player)
	end

	-- Sync the new/returning client with whatever's already happening.
	task.defer(function()
		if player.Parent then
			GameStateUpdate:FireClient(player, currentStatePayload())
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	activePlayers[player] = nil
	PlayerDataManager.SaveProfile(player)

	for i, p in ipairs(roundQueue) do
		if p == player then
			table.remove(roundQueue, i)
			break
		end
	end
	for i, p in ipairs(waitingToJoin) do
		if p == player then
			table.remove(waitingToJoin, i)
			break
		end
	end

	if player == describer and phase == "Describing" then
		-- Describer disconnecting mid-round ends it early rather than stalling everyone else.
		describer = nil
		revealAnswer()
	end
end)

-- ---------------------------------------------------------------------------
-- Main loop
-- ---------------------------------------------------------------------------

task.spawn(function()
	while true do
		task.wait(1)
		tick()
	end
end)
