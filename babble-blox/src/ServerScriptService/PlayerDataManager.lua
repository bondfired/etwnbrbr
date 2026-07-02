-- Per-player progression profile (xp, level, streak, cosmetics) as sketched
-- in the roadmap. This is a minimal DataStore wrapper for the first pass;
-- swap in a session-locking library (e.g. ProfileService/ProfileStore) before
-- shipping, since Roblox players joining/leaving constantly makes double-
-- session data corruption a real risk that this simple version doesn't guard against.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local profileStore = DataStoreService:GetDataStore("BabbleBlox_PlayerProfiles_v1")

local DEFAULT_PROFILE = {
	xp = 0,
	level = 1,
	streak = 0,
	lastPlayedDate = "",
	unlockedCosmetics = {},
	equippedCosmetics = {},
	gamesPlayed = 0,
}

local cache = {}

local PlayerDataManager = {}

function PlayerDataManager.LoadProfile(player)
	local success, data = pcall(function()
		return profileStore:GetAsync("Player_" .. player.UserId)
	end)

	if success and data then
		cache[player.UserId] = data
	else
		cache[player.UserId] = table.clone(DEFAULT_PROFILE)
	end

	return cache[player.UserId]
end

function PlayerDataManager.GetProfile(player)
	return cache[player.UserId]
end

function PlayerDataManager.SaveProfile(player)
	local data = cache[player.UserId]
	if not data then
		return
	end

	local success, err = pcall(function()
		profileStore:SetAsync("Player_" .. player.UserId, data)
	end)

	if not success then
		warn("BabbleBlox: failed to save profile for " .. player.Name .. ": " .. tostring(err))
	end

	cache[player.UserId] = nil
end

function PlayerDataManager.AwardXp(player, amount)
	local data = cache[player.UserId]
	if not data then
		return
	end

	data.xp += amount
	data.gamesPlayed += 1
	data.level = math.floor(data.xp / 100) + 1
end

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerDataManager.SaveProfile(player)
	end
end)

return PlayerDataManager
