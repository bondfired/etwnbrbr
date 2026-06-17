#!/usr/bin/env python3
"""Phase 2: Replace service module source code for SoundScape RNG."""

def replace_cdata(content, unique_str, new_source, label=""):
    pos = content.find(unique_str)
    if pos == -1:
        print(f"WARN: not found [{label}]: {unique_str[:60]}")
        return content
    marker = '<![CDATA['
    cs = content.rfind(marker, 0, pos)
    ce = content.find(']]>', pos)
    if cs == -1 or ce == -1:
        print(f"WARN: CDATA bounds not found [{label}]")
        return content
    result = content[:cs + len(marker)] + new_source + '\n' + content[ce:]
    print(f"OK: {label}")
    return result

def main():
    fp = "/home/user/etwnbrbr/SoundScape_RNG.rbxlx"
    with open(fp, 'r', encoding='utf-8') as f:
        c = f.read()

    # 1. DataService - update store name
    c = replace_cdata(c, 'STORE_NAME = "RNG_Data_v1"', DATASERVICE, "DataService")
    # 2. EconomyService
    c = replace_cdata(c, 'function Svc:SendRolls(plr)', ECONOMYSERVICE, "EconomyService")
    # 3. RNGService - fragment drop logic
    c = replace_cdata(c, 'DependsOn = { "EconomyService", "CardService" }', RNGSERVICE, "RNGService")
    # 4. CardService - collection/fusion
    c = replace_cdata(c, 'MAX_EQUIPPED_TOTAL = 4', CARDSERVICE, "CardService")
    # 5. BackpackService
    c = replace_cdata(c, 'local ticking: {[number]: boolean} = {}', BACKPACKSERVICE, "BackpackService")
    # 6. LeaderboardService
    c = replace_cdata(c, 'function deckPowerTotal(d:any): number', LEADERBOARDSERVICE, "LeaderboardService")
    # 7. UpgradeService
    c = replace_cdata(c, 'Routes = { RequestStatus = true, RequestUpgrade = true, AdminSetPoints = true }', UPGRADESERVICE, "UpgradeService")
    # 8. Server GameStart
    c = replace_cdata(c, 'GameCore.UseMiddleware("RNGService"', SERVERGAMESTART, "ServerGameStart")
    # 9. Loader branding
    c = replace_cdata(c, 'GameCore.Fire("BackpackService","RequestStatus",{})', LOADER, "Loader")

    with open(fp, 'w', encoding='utf-8') as f:
        f.write(c)
    print("Phase 2 complete.")

# =====================================================================

DATASERVICE = r"""local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local GameCore = require(RS.Main.GameCore)
local KVStore  = require(RS.Main.Modules.KVStore)
local Schema   = require(RS.Main.Configs.DataSchema)

local STORE_NAME = "SoundScape_Data_v1"
local LOCK_NAME  = "SoundScape_Locks_v1"
local SAVE_INTERVAL_MIN, SAVE_INTERVAL_MAX = 35, 65
local SHUTDOWN_TIMEOUT = 8

local function now() return os.clock() end
local function keyFor(plr) return ("plr_%d"):format(plr.UserId) end
local function randSaveDelay() return math.random(SAVE_INTERVAL_MIN, SAVE_INTERVAL_MAX) end

local Store = KVStore.new(STORE_NAME, LOCK_NAME)

local Svc = {
	Name = "DataService",
	Routes = {},
	Functions = {},
	Schemas = { Functions = {} },
	_profiles = {},
	_nextSave = {},
	_ev = Instance.new("BindableEvent"),
}

local function deepget(t, path)
	local cur = t
	for seg in string.gmatch(path, "[^%.]+") do
		if type(cur) ~= "table" then return nil end
		cur = cur[seg]
	end
	return cur
end

local function deepset(t, path, v)
	local segs = {}
	for s in string.gmatch(path, "[^%.]+") do table.insert(segs, s) end
	local cur = t
	for i = 1, #segs - 1 do
		local k = segs[i]
		cur[k] = cur[k] or {}
		cur = cur[k]
	end
	cur[segs[#segs]] = v
end

local function loadFor(plr: Player)
	local key = keyFor(plr)
	local session = game.JobId .. ":" .. plr.UserId
	local locked = Store:acquireLock(key, session, 90)
	local raw = Store:get(key)
	local data
	if type(raw) == "table" then
		data = Schema.migrate(raw)
	else
		data = table.clone(Schema.DEFAULT)
	end

	Svc._profiles[plr] = {
		Data = data,
		Loaded = true,
		Dirty = false,
		LockKey = key,
		Session = session,
		Locked = locked,
	}
	Svc._nextSave[plr] = now() + randSaveDelay()
	pcall(function() plr:SetAttribute("DataLoaded", true) end)

	task.spawn(function()
		local ls = plr:FindFirstChild("leaderstats") or Instance.new("Folder")
		ls.Name = "leaderstats"; ls.Parent = plr
		local function setInt(name, v)
			local iv = ls:FindFirstChild(name) or Instance.new("IntValue")
			iv.Name = name; iv.Value = v or 0; iv.Parent = ls
		end
		setInt("Level", data.Level or 1)
		setInt("Scans", data.Rolls or 0)
	end)

	return true
end

local function saveFor(plr: Player, releaseLock: boolean?)
	local p = Svc._profiles[plr]; if not p or not p.Loaded then return end
	if not p.Dirty then
		if releaseLock then
			if p.Locked then Store:releaseLock(p.LockKey) end
			Svc._profiles[plr] = nil
		end
		return
	end
	local ok = Store:set(p.LockKey, p.Data)
	if ok then p.Dirty = false end
	if releaseLock then
		if p.Locked then Store:releaseLock(p.LockKey) end
		Svc._profiles[plr] = nil
	end
end

function Svc:Init()
	for _, plr in ipairs(Players:GetPlayers()) do
		task.spawn(function() self:InitPlayer(plr) end)
	end
	Players.PlayerAdded:Connect(function(plr)
		task.spawn(function() self:InitPlayer(plr) end)
	end)
	Players.PlayerRemoving:Connect(function(plr)
		pcall(function() self:_release(plr, true) end)
	end)
	GameCore.Sched.every("ds-autosave", 1, function()
		local t = now()
		for plr, prof in pairs(self._profiles) do
			if prof.Loaded and t >= (self._nextSave[plr] or (t + 60)) then
				saveFor(plr, false)
				self._nextSave[plr] = t + randSaveDelay()
			end
		end
	end)
	GameCore.OnShutdown(function()
		local deadline = now() + SHUTDOWN_TIMEOUT
		for plr in pairs(self._profiles) do saveFor(plr, true) end
		while now() < deadline do task.wait(0.05) end
	end)
end

function Svc:_release(plr: Player, final: boolean)
	saveFor(plr, true)
end

function Svc:InitPlayer(plr: Player)
	if Svc._profiles[plr] then return end
	pcall(function() plr:SetAttribute("DataLoaded", false) end)
	loadFor(plr)
	Svc._ev:Fire(plr)
end

function Svc:IsLoaded(plr) local p = self._profiles[plr]; return p and p.Loaded or false end

function Svc:EnsureLoaded(plr, timeout)
	if self:IsLoaded(plr) then return true end
	local t0 = now()
	repeat task.wait(0.05) until self:IsLoaded(plr) or (now() - t0) > (timeout or 15)
	return self:IsLoaded(plr)
end

function Svc:WaitLoaded(plr, timeout)
	if self:IsLoaded(plr) then return true end
	local done = false
	local cn = self._ev.Event:Connect(function(p) if p == plr then done = true end end)
	local t0 = now()
	repeat task.wait(0.05) until done or (now() - t0) > (timeout or 15)
	cn:Disconnect()
	return done or self:IsLoaded(plr)
end

function Svc:Get(plr) return self._profiles[plr] end
function Svc:GetData(plr) local p = self._profiles[plr]; return p and p.Data or nil end

function Svc:MarkDirty(plr)
	local p = self._profiles[plr]; if not p then return end
	p.Dirty = true
	self._nextSave[plr] = math.min(self._nextSave[plr] or (now() + 30), now() + 10)
end

function Svc:SaveNow(plr) saveFor(plr, false) end

function Svc:Patch(plr, mutator)
	local p = self._profiles[plr]; if not (p and p.Loaded) then return false end
	local ok, changed = pcall(mutator, p.Data)
	if ok and changed then self:MarkDirty(plr) end
	return ok and changed or false
end

function Svc:SetPath(plr, path, value)
	return self:Patch(plr, function(d)
		local before = deepget(d, path)
		if before == value then return false end
		deepset(d, path, value); return true
	end)
end

function Svc:Inc(plr, path, delta)
	delta = tonumber(delta) or 0
	return self:Patch(plr, function(d)
		local cur = tonumber(deepget(d, path) or 0)
		deepset(d, path, cur + delta)
		return delta ~= 0
	end)
end

Svc.Schemas.Functions.GetPublic = function(payload) return payload == nil or type(payload) == "table" end
function Svc.Functions:GetPublic(player, _payload)
	local d = Svc:GetData(player)
	if not d then return nil end
	return {
		Level = d.Level,
		Xp = d.Xp,
		Rolls = d.Rolls,
		Fragments = d.Fragments,
		CompletedTracks = d.CompletedTracks,
		Equipped = d.Equipped,
	}
end

return Svc
"""

ECONOMYSERVICE = r"""local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")

local DataService = require(RS.Main.Services.DataService)

local Svc = {
	Name = "EconomyService",
	Routes = {},
	DependsOn = { "DataService" },
}

local function reqFor(lvl: number)
	local L = require(RS.Main.Configs.Leveling)
	local spec = L.RollsPerLevel or { base = 500, pow = 1.15 }
	return math.floor(spec.base * (lvl ^ spec.pow))
end

function Svc:SendRolls(plr)
	local d = self.Data:GetData(plr); if not d then return end
	self.Net:Send(plr, "RollsUpdate", d.Rolls or 0)
end

function Svc:SendLevel(plr)
	local d = self.Data:GetData(plr); if not d then return end
	local lvl = d.Level or 1
	local prog = d.Progress or 0
	local req = reqFor(lvl)
	self.Net:Send(plr, "LevelUpdate", {
		level    = lvl,
		xp       = prog,
		need     = req,
		progress = prog,
		req      = req,
	})
end

function Svc:AddRolls(plr, amount: number)
	if amount <= 0 then return end
	local d = self.Data:GetData(plr); if not d then return end

	d.Rolls    = (d.Rolls or 0) + amount
	d.Progress = (d.Progress or 0) + amount
	d.Level    = d.Level or 1

	while d.Progress >= reqFor(d.Level) do
		d.Progress -= reqFor(d.Level)
		d.Level += 1
	end

	DataService:MarkDirty(plr)
	self:SendRolls(plr)
	self:SendLevel(plr)
end

function Svc:SafeSendAll(plr)
	task.spawn(function()
		if self.Data:WaitLoaded(plr, 15) then
			self:SendRolls(plr)
			self:SendLevel(plr)
		end
	end)
end

function Svc:Init()
	self.Data = DataService
end

function Svc:Start()
	for _, plr in ipairs(Players:GetPlayers()) do self:SafeSendAll(plr) end
	Players.PlayerAdded:Connect(function(plr) self:SafeSendAll(plr) end)
end

return Svc
"""

RNGSERVICE = r"""local Players   = game:GetService("Players")
local RS        = game:GetService("ReplicatedStorage")

local GameCore       = require(RS.Main.GameCore)
local CardsCfg       = require(RS.Main.Configs.Cards)
local DataService    = require(RS.Main.Services.DataService)
local CardService    = require(RS.Main.Services.CardService)
local QuestService   = require(RS.Main.Services.QuestService)
local EconomyService = require(RS.Main.Services.EconomyService)
local UpgCfg         = require(RS.Main.Configs.Upgrades)

local Svc = {
	Name = "RNGService",
	Routes = {},
	DependsOn = { "EconomyService", "CardService" },
}

local function sanitizeRarity(s: any): string?
	if typeof(s) ~= "string" then return nil end
	local n = s:lower():gsub("^%s*(.-)%s*$", "%1")
	for key, _ in pairs(CardsCfg.Rarity) do
		if key:lower() == n then return key end
	end
	return nil
end

local function getLuckMult(plr: Player): number
	local exp  = tonumber(plr:GetAttribute("LuckExpire")) or 0
	local mult = tonumber(plr:GetAttribute("LuckMult")) or 1
	if exp <= os.time() then mult = 1 end

	local prof = DataService:Get(plr)
	if prof and prof.Data and prof.Data.Upgrades and prof.Data.Upgrades.Levels then
		local luckLv = tonumber(prof.Data.Upgrades.Levels.Luck or 0) or 0
		if luckLv > 0 then
			local cfg = UpgCfg.Upgrades.Luck
			if cfg then mult *= 1 + (luckLv * (cfg.perLevel / 100)) end
		end
	end

	return mult
end

local function buildWeightedDrawer(pool)
	local cum, total = {}, 0
	for i, e in ipairs(pool) do
		local w = tonumber(e.weight) or 0
		if w > 0 then
			total += w
			cum[#cum + 1] = { t = total, id = e.id }
		end
	end
	local rng = Random.new()
	return function()
		if total <= 0 then return nil end
		local r = rng:NextNumber(0, total)
		local lo, hi = 1, #cum
		while lo < hi do
			local mid = (lo + hi) // 2
			if r <= cum[mid].t then hi = mid else lo = mid + 1 end
		end
		return cum[lo] and cum[lo].id or nil
	end
end

local function drawerWithLuck(mult: number, zoneFilter: string?)
	local pool = {}
	for _, e in ipairs(CardsCfg.RollPool) do
		local def = CardsCfg.ById[e.id]
		if def and (not zoneFilter or def.zone == zoneFilter) then
			table.insert(pool, { id = e.id, weight = (e.weight or 0) * (mult or 1) })
		end
	end
	if #pool == 0 then
		for _, e in ipairs(CardsCfg.RollPool) do
			table.insert(pool, { id = e.id, weight = (e.weight or 0) * (mult or 1) })
		end
	end
	return buildWeightedDrawer(pool)
end

local function drawerByRarityWithLuck(r: string, mult: number)
	local pool = {}
	for _, e in ipairs(CardsCfg.RollPool) do
		local def = CardsCfg.ById[e.id]
		if def and def.rarity == r then
			table.insert(pool, { id = e.id, weight = (e.weight or 0) * (mult or 1) })
		end
	end
	if #pool == 0 then return function() return nil end end
	return buildWeightedDrawer(pool)
end

Svc.Routes.RequestRoll = function(plr: Player, payload)
	if type(payload) ~= "table" then return false, "bad payload" end
	local amount = tonumber(payload.amount)
	if not amount then return false, "bad amount" end
	amount = math.clamp(math.floor(amount), 1, 50)

	local zone = tostring(payload.zone or "City")

	local forceCard = plr:GetAttribute("ForceNextCard")
	if type(forceCard) ~= "string" or not CardsCfg.ById[forceCard] then forceCard = nil end
	local forceRarity = sanitizeRarity(plr:GetAttribute("ForceNextRarity"))
	if forceCard then forceRarity = nil end
	if forceCard or forceRarity then
		plr:SetAttribute("ForceNextCard", nil)
		plr:SetAttribute("ForceNextRarity", nil)
	end

	local luck     = getLuckMult(plr)
	local drawAll  = drawerWithLuck(luck, zone)
	local drawRare = forceRarity and drawerByRarityWithLuck(forceRarity, luck) or nil

	local results = {}

	for _ = 1, amount do
		local collectibleId
		if forceCard then
			collectibleId = forceCard; forceCard = nil
		elseif forceRarity then
			collectibleId = drawRare(); forceRarity = nil
			if not collectibleId then collectibleId = drawAll() end
		else
			collectibleId = drawAll()
		end

		local def = collectibleId and CardsCfg.ById[collectibleId]
		if not def then
			collectibleId = drawAll()
			def = collectibleId and CardsCfg.ById[collectibleId]
		end

		if def then
			local fragType = CardsCfg.PickRandomFragment(collectibleId)
			local fragRarity = CardsCfg.RollFragmentRarity(luck)

			CardService:GiveFragment(plr, collectibleId, fragType, fragRarity)

			table.insert(results, {
				id            = def.id,
				name          = def.name,
				artist        = def.artist,
				fragmentType  = fragType,
				fragmentRarity = fragRarity,
				collectibleType = def.collectibleType or def.unitType,
				image         = tostring(def.image or "rbxassetid://0"),
				color         = def.color or Color3.fromRGB(255, 255, 255),
				rarity        = def.rarity,
				weight        = tonumber(CardsCfg.RollWeights[def.id]) or 1,
			})

			local rarIdx = 1
			for i, r in ipairs(CardsCfg.FragmentRarity) do
				if r.id == fragRarity then rarIdx = i; break end
			end
			if rarIdx >= 3 then
				pcall(function() QuestService:Increment(plr, "RareFinds", 1) end)
			end
		end
	end

	EconomyService:AddRolls(plr, amount)

	pcall(function() Svc.Net:Send(plr, "Ack", { ok = true, amount = amount }) end)
	pcall(function() GameCore.Fire("UpgradeService", "RequestStatus", {}, plr) end)

	Svc.Net:Send(plr, "Results", results)

	pcall(function() QuestService:Increment(plr, "Rolls", amount) end)

	return true
end

return Svc
"""

CARDSERVICE = r"""local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local GameCore    = require(RS.Main.GameCore)
local CardsCfg    = require(RS.Main.Configs.Cards)
local DataService = require(RS.Main.Services.DataService)

local MAX_EQUIPPED_TOTAL = 4

local Svc = {
	Name = "CardService",
	Routes = {},
	DependsOn = {"DataService"},
}

function Svc:GiveFragment(plr: Player, collectibleId: string, fragmentType: string, rarity: string)
	local prof = DataService:Get(plr); if not prof then return end
	local d = prof.Data
	d.Fragments = d.Fragments or {}
	d.Fragments[collectibleId] = d.Fragments[collectibleId] or {}
	local frag = d.Fragments[collectibleId][fragmentType]
	if not frag then
		frag = { count = 0, bestRarity = "Common" }
		d.Fragments[collectibleId][fragmentType] = frag
	end
	frag.count = (frag.count or 0) + 1

	local newIdx, oldIdx = 1, 1
	for i, r in ipairs(CardsCfg.FragmentRarity) do
		if r.id == rarity then newIdx = i end
		if r.id == (frag.bestRarity or "Common") then oldIdx = i end
	end
	if newIdx > oldIdx then frag.bestRarity = rarity end

	d.Cards = d.Cards or {}
	d.Cards[collectibleId] = (d.Cards[collectibleId] or 0) + 1

	DataService:MarkDirty(plr)
	self:Send(plr)
end

function Svc:Send(plr: Player)
	local prof = DataService:Get(plr); if not prof then return end
	local d = prof.Data

	local fragmentList = {}
	for collId, frags in pairs(d.Fragments or {}) do
		local def = CardsCfg.ById[collId]
		if def then
			for fragType, fragData in pairs(frags) do
				table.insert(fragmentList, {
					collectibleId = collId,
					name = def.name,
					artist = def.artist,
					fragmentType = fragType,
					count = fragData.count or 0,
					bestRarity = fragData.bestRarity or "Common",
					collectibleType = def.collectibleType or def.unitType,
					rarity = def.rarity,
					image = def.image,
					color = def.color,
				})
			end
		end
	end

	local completedList = {}
	for collId, track in pairs(d.CompletedTracks or {}) do
		local def = CardsCfg.ById[collId]
		if def then
			table.insert(completedList, {
				id = collId,
				name = def.name,
				artist = def.artist,
				rarity = track.rarity or "Common",
				fusionLevel = track.fusionLevel or 0,
				collectibleType = def.collectibleType or def.unitType,
				image = def.image,
				color = def.color,
				power = def.power or 0,
				equipped = false,
			})
		end
	end

	for _, ct in ipairs(completedList) do
		for _, eqId in pairs(d.Equipped or {}) do
			if eqId == ct.id then ct.equipped = true; break end
		end
	end

	self.Net:Send(plr, "CardsUpdate", {
		fragments = fragmentList,
		completed = completedList,
		equipped = d.Equipped or {},
	})
end

Svc.Routes.RequestFuse = function(plr: Player, payload)
	if type(payload) ~= "table" then return false, "bad payload" end
	local collectibleId = tostring(payload.id or "")
	local def = CardsCfg.ById[collectibleId]
	if not def then return false, "bad collectible" end

	local prof = DataService:Get(plr); if not prof then return false, "no profile" end
	local d = prof.Data
	d.Fragments = d.Fragments or {}
	d.CompletedTracks = d.CompletedTracks or {}

	if not CardsCfg.IsTrackComplete(d.Fragments, collectibleId) then
		return false, "missing fragments"
	end

	local trackRarity = CardsCfg.GetLowestFragmentRarity(d.Fragments, collectibleId)

	local existing = d.CompletedTracks[collectibleId]
	if existing then
		local existIdx, newIdx = 1, 1
		for i, r in ipairs(CardsCfg.FragmentRarity) do
			if r.id == existing.rarity then existIdx = i end
			if r.id == trackRarity then newIdx = i end
		end
		if newIdx > existIdx then
			existing.rarity = trackRarity
		end
		existing.fusionLevel = (existing.fusionLevel or 0) + 1
	else
		d.CompletedTracks[collectibleId] = {
			rarity = trackRarity,
			fusionLevel = 0,
		}
	end

	for _, fragType in ipairs(def.fragments or {}) do
		local frag = d.Fragments[collectibleId] and d.Fragments[collectibleId][fragType]
		if frag then
			frag.count = math.max(0, (frag.count or 1) - 1)
		end
	end

	DataService:MarkDirty(plr)
	Svc:Send(plr)

	Svc.Net:Send(plr, "FuseResult", {
		ok = true,
		id = collectibleId,
		name = def.name,
		rarity = trackRarity,
		fusionLevel = d.CompletedTracks[collectibleId].fusionLevel,
	})

	pcall(function()
		local QuestService = require(RS.Main.Services.QuestService)
		QuestService:Increment(plr, "TracksFused", 1)
	end)

	return true
end

Svc.Routes.RequestEquip = function(plr: Player, payload)
	local id = payload and payload.id
	if type(id) ~= "string" then return false, "bad id" end

	local prof = DataService:Get(plr); if not prof then return false, "no profile" end
	local d = prof.Data
	d.CompletedTracks = d.CompletedTracks or {}
	d.Equipped = d.Equipped or {}

	if not d.CompletedTracks[id] then return false, "track not completed" end

	local count = 0
	for _ in pairs(d.Equipped) do count += 1 end
	if count >= MAX_EQUIPPED_TOTAL then return false, "slots full" end

	for _, eqId in pairs(d.Equipped) do
		if eqId == id then return false, "already equipped" end
	end

	local slot = "Slot" .. tostring(count + 1)
	d.Equipped[slot] = id

	DataService:MarkDirty(plr)
	Svc:Send(plr)
	return true
end

Svc.Routes.RequestUnequip = function(plr: Player, payload)
	local id = payload and payload.id
	if type(id) ~= "string" then return false, "bad id" end

	local prof = DataService:Get(plr); if not prof then return false, "no profile" end
	local d = prof.Data
	d.Equipped = d.Equipped or {}

	local found = false
	local newEquip = {}
	local idx = 1
	for _, eqId in pairs(d.Equipped) do
		if eqId == id and not found then
			found = true
		else
			newEquip["Slot" .. idx] = eqId
			idx += 1
		end
	end

	if not found then return false, "not equipped" end
	d.Equipped = newEquip

	DataService:MarkDirty(plr)
	Svc:Send(plr)
	return true
end

Svc.Routes.GiveCard = function(plr: Player, payload)
	if not (plr and require(RS.Main.Configs.Admin).IsAdmin(plr.UserId)) then
		return false, "not admin"
	end
	local targetName = payload.target
	local cardId = payload.id
	local amount = tonumber(payload.amount) or 1
	if type(targetName) ~= "string" or type(cardId) ~= "string" then return false, "bad args" end
	local target = Players:FindFirstChild(targetName)
	if not target then return false, "player not found" end
	local prof = DataService:Get(target); if not prof then return false, "no profile" end
	local d = prof.Data
	d.Cards = d.Cards or {}
	d.Cards[cardId] = (d.Cards[cardId] or 0) + amount
	DataService:MarkDirty(target)
	Svc:Send(target)
	return true
end

Svc.Routes.AdminGiveFragment = function(plr: Player, payload)
	if not (plr and require(RS.Main.Configs.Admin).IsAdmin(plr.UserId)) then
		return false, "not admin"
	end
	local targetName = tostring(payload.target or "")
	local target = Players:FindFirstChild(targetName)
	if not target then return false, "player not found" end

	Svc:GiveFragment(
		target,
		tostring(payload.collectibleId or ""),
		tostring(payload.fragmentType or "Beat"),
		tostring(payload.rarity or "Common")
	)
	return true
end

Svc.Routes.AdminCompleteTrack = function(plr: Player, payload)
	if not (plr and require(RS.Main.Configs.Admin).IsAdmin(plr.UserId)) then
		return false, "not admin"
	end
	local targetName = tostring(payload.target or "")
	local target = Players:FindFirstChild(targetName)
	if not target then return false, "player not found" end

	local prof = DataService:Get(target); if not prof then return false, "no profile" end
	local d = prof.Data
	d.CompletedTracks = d.CompletedTracks or {}
	d.CompletedTracks[tostring(payload.id or "")] = {
		rarity = tostring(payload.rarity or "Common"),
		fusionLevel = 0,
	}
	DataService:MarkDirty(target)
	Svc:Send(target)
	return true
end

Svc.Routes.WipeInventory = function(plr: Player, payload)
	if not (plr and require(RS.Main.Configs.Admin).IsAdmin(plr.UserId)) then
		return false, "not admin"
	end
	local targetName = tostring(payload.target or "")
	local target = Players:FindFirstChild(targetName)
	if not target then return false, "player not found" end
	local prof = DataService:Get(target); if not prof then return false, "no profile" end
	local d = prof.Data
	d.Fragments = {}
	d.CompletedTracks = {}
	d.Equipped = {}
	d.Cards = {}
	DataService:MarkDirty(target)
	Svc:Send(target)
	return true
end

function Svc:Start()
	Players.PlayerAdded:Connect(function(plr)
		task.spawn(function()
			if DataService:EnsureLoaded(plr, 15) then self:Send(plr) end
		end)
	end)
	for _, plr in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			if DataService:EnsureLoaded(plr, 15) then self:Send(plr) end
		end)
	end
end

return Svc
"""

BACKPACKSERVICE = r"""local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")

local GameCore    = require(RS.Main.GameCore)
local DataService = require(RS.Main.Services.DataService)
local ItemsCfg    = require(RS.Main.Configs.Items)
local AdminCfg    = require(RS.Main.Configs.Admin)
local CodesCfg    = require(RS.Main.Configs.Codes)

local Svc = {
	Name = "BackpackService",
	Routes = {},
	DependsOn = { "DataService" },
}

local function isAdmin(plr: Player): boolean
	if AdminCfg.IsAdmin then return AdminCfg.IsAdmin(plr.UserId, plr.Name) end
	return false
end

local function now() return os.time() end

local function send(plr: Player)
	local prof = DataService:Get(plr); if not prof then return end
	local d = prof.Data
	d.Items = d.Items or {}
	Svc.Net:Send(plr, "BackpackUpdate", d.Items)
end

local function addItem(plr: Player, itemId: string, amount: number)
	local prof = DataService:Get(plr); if not prof then return false, "no profile" end
	local d = prof.Data
	d.Items = d.Items or {}
	d.Items[itemId] = (tonumber(d.Items[itemId]) or 0) + amount
	if d.Items[itemId] <= 0 then d.Items[itemId] = nil end
	DataService:MarkDirty(plr)
	send(plr)
	return true
end

local function getLuck(plr: Player)
	local prof = DataService:Get(plr); if not prof then return 1, 0 end
	local d = prof.Data; d.State = d.State or {}
	local exp  = tonumber(d.State.luckExpire or 0) or 0
	local mult = tonumber(d.State.luckMult or 1) or 1
	return mult, exp
end

local function setLuck(plr: Player, mult: number, expireAt: number)
	local prof = DataService:Get(plr); if not prof then return end
	local d = prof.Data; d.State = d.State or {}
	d.State.luckMult   = mult
	d.State.luckExpire = expireAt
	DataService:MarkDirty(plr)
	plr:SetAttribute("LuckMult", mult)
	plr:SetAttribute("LuckExpire", expireAt)
end

local ticking: {[number]: boolean} = {}

local function pushPotionStatus(plr: Player)
	local mult, expAt = getLuck(plr)
	if expAt <= now() or mult <= 1 then
		Svc.Net:Send(plr, "PotionStatus", { active = false })
	else
		Svc.Net:Send(plr, "PotionStatus", {
			active   = true,
			id       = "RarityBooster",
			icon     = ItemsCfg.RarityBooster and ItemsCfg.RarityBooster.icon or "",
			mult     = mult,
			expireAt = expAt,
		})
	end
end

local function startTicker(plr: Player)
	if ticking[plr.UserId] then return end
	ticking[plr.UserId] = true
	task.spawn(function()
		while ticking[plr.UserId] do
			local _, expAt = getLuck(plr)
			if expAt <= now() then
				setLuck(plr, 1, 0)
				pushPotionStatus(plr)
				ticking[plr.UserId] = nil
				break
			end
			pushPotionStatus(plr)
			task.wait(0.5)
		end
	end)
end

function Svc:GiveItem(plr: Player, itemId: string, amount: number)
	return addItem(plr, itemId, math.max(1, amount or 1))
end

Svc.Routes.AdminGiveItem = function(plr: Player, payload)
	if not isAdmin(plr) then return false, "no permission" end
	if type(payload) ~= "table" then return false, "bad payload" end

	local targetName = tostring(payload.target or "")
	local itemId     = tostring(payload.itemId or "")
	local amount     = math.clamp(tonumber(payload.amount or 1) or 1, 1, 100000)

	local def = ItemsCfg[itemId]
	if not def then
		for _, it in pairs(ItemsCfg) do
			if string.lower(it.name or "") == string.lower(itemId) then
				def = it; itemId = it.id; break
			end
		end
	end
	if not def then return false, "invalid item" end

	local target: Player? = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if string.lower(p.Name) == string.lower(targetName) then target = p; break end
	end
	if not target then return false, "player not found" end

	local ok, err = addItem(target, itemId, amount)
	if not ok then return false, err end
	return true
end

Svc.Routes.RedeemCode = function(plr: Player, payload)
	if type(payload) ~= "table" then return false, "bad payload" end
	local code = tostring(payload.code or ""):upper():gsub("%s+", "")
	if code == "" then return false, "empty" end
	local codeEntry = CodesCfg[code]
	if not codeEntry then return false, "invalid" end

	local prof = DataService:Get(plr); if not prof then return false, "no profile" end
	local d = prof.Data; d.Codes = d.Codes or {}
	if d.Codes[code] == true then return false, "used" end

	local rewards = codeEntry.reward or codeEntry
	for itemId, amt in pairs(rewards) do
		if type(amt) == "number" and amt > 0 then
			addItem(plr, itemId, amt)
		end
	end
	d.Codes[code] = true
	DataService:MarkDirty(plr)

	Svc.Net:Send(plr, "CodeResult", { ok = true, code = code })
	return true
end

Svc.Routes.RequestUse = function(plr: Player, payload)
	if type(payload) ~= "table" then return false, "bad payload" end
	local id = tostring(payload.id or "")
	local want = math.max(1, tonumber(payload.amount or 1) or 1)

	local def = ItemsCfg[id]
	if not def then return false, "bad item" end

	local prof = DataService:Get(plr); if not prof then return false, "no profile" end
	local d = prof.Data; d.Items = d.Items or {}

	local have = tonumber(d.Items[id] or 0) or 0
	if have <= 0 then return false, "none" end

	local useN = math.min(want, have)
	d.Items[id] = have - useN
	if d.Items[id] <= 0 then d.Items[id] = nil end
	DataService:MarkDirty(plr)
	send(plr)

	if id == "FragmentScanner" then
		Svc.Net:Send(plr, "Used", { id = id, amount = useN })
		Svc.Net:Send(plr, "TriggerRoll", { amount = 5 * useN })
		return true
	end

	if id == "RarityBooster" then
		local baseMult = tonumber(def.use and def.use.payload and def.use.payload.mult) or 1.5
		local baseDur  = tonumber(def.use and def.use.payload and def.use.payload.duration) or 60

		local u = d.Upgrades and d.Upgrades.Levels or {}
		local potLv = tonumber(u.PotionDuration or 0) or 0
		local durBonus = 1 + (0.01 * potLv)

		local curMult, curExpAt = getLuck(plr)
		local start = math.max(now(), curExpAt)
		local effDur = baseDur * durBonus
		local newExp = start + (effDur * useN)
		local newMult = math.max(curMult, baseMult)

		setLuck(plr, newMult, newExp)
		pushPotionStatus(plr)
		startTicker(plr)

		pcall(function()
			local QS = require(RS.Main.Services.QuestService)
			QS:Increment(plr, "PotionsUsed", useN)
		end)

		Svc.Net:Send(plr, "Used", { id = id, amount = useN })
		return true
	end

	Svc.Net:Send(plr, "Used", { id = id, amount = useN })
	return true
end

Svc.Routes.RequestStatus = function(plr: Player)
	pushPotionStatus(plr)
	return true
end

Svc.Routes.ForceSend = function(plr: Player)
	send(plr)
	return true
end

function Svc:Start()
	Players.PlayerAdded:Connect(function(plr)
		task.spawn(function()
			if DataService:EnsureLoaded(plr, 15) then
				send(plr)
				local m, e = getLuck(plr)
				setLuck(plr, m, e)
				pushPotionStatus(plr)
				if e > now() and m > 1 then startTicker(plr) end
			end
		end)
	end)
	for _, plr in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			if DataService:EnsureLoaded(plr, 15) then
				send(plr)
				local m, e = getLuck(plr)
				setLuck(plr, m, e)
				pushPotionStatus(plr)
				if e > now() and m > 1 then startTicker(plr) end
			end
		end)
	end
end

return Svc
"""

LEADERBOARDSERVICE = r"""local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local GameCore    = require(RS.Main.GameCore)
local DataService = require(RS.Main.Services.DataService)
local CardsCfg    = require(RS.Main.Configs.Cards)

local Svc = {
	Name = "LeaderboardService",
	Routes = {},
	DependsOn = {"DataService"},
}

local function collectionPower(d: any): number
	local sum = 0
	for collId, track in pairs(d.CompletedTracks or {}) do
		local def = CardsCfg.ById[collId]
		if def then
			local basePow = def.power or 0
			local rarBonus = 1
			for i, r in ipairs(CardsCfg.FragmentRarity or {}) do
				if r.id == (track.rarity or "Common") then rarBonus = i; break end
			end
			sum += basePow * rarBonus * (1 + (track.fusionLevel or 0) * 0.1)
		end
	end
	return math.floor(sum)
end

local function snapshotTop(limit: number)
	local rows = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local prof = DataService:Get(plr)
		if prof and prof.Data then
			local d = prof.Data
			local completed = 0
			for _ in pairs(d.CompletedTracks or {}) do completed += 1 end
			table.insert(rows, {
				userId    = plr.UserId,
				username  = plr.Name,
				deckPow   = collectionPower(d),
				rolled    = tonumber(d.Rolls or 0),
				completed = completed,
			})
		end
	end
	table.sort(rows, function(a, b)
		if a.deckPow ~= b.deckPow then return a.deckPow > b.deckPow end
		return a.completed > b.completed
	end)
	if #rows > limit then
		local t = table.create(limit)
		for i = 1, limit do t[i] = rows[i] end
		return t
	end
	return rows
end

function Svc:Broadcast()
	local snap = snapshotTop(50)
	self.Net:Broadcast("Snapshot", snap)
end

function Svc:Start()
	task.spawn(function()
		while true do
			self:Broadcast()
			task.wait(10)
		end
	end)
	Players.PlayerAdded:Connect(function() task.delay(1, function() self:Broadcast() end) end)
	Players.PlayerRemoving:Connect(function() task.delay(0.1, function() self:Broadcast() end) end)
end

return Svc
"""

UPGRADESERVICE = r"""local RS      = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameCore    = require(RS.Main.GameCore)
local DataService = require(RS.Main.Services.DataService)
local UpgCfg      = require(RS.Main.Configs.Upgrades)
local AdminCfg    = require(RS.Main.Configs.Admin)

local Svc = { Name = "UpgradeService", Routes = { RequestStatus = true, RequestUpgrade = true, AdminSetPoints = true } }

local PER_POINT = tonumber(UpgCfg.PointsPerRolls) or 500
local function rollsToNextPoint(totalRolls: number)
	if PER_POINT <= 0 then return 0 end
	local rem = totalRolls % PER_POINT
	return (rem == 0) and PER_POINT or (PER_POINT - rem)
end

local function isAdmin(plr: Player): boolean
	if AdminCfg.IsAdmin then return AdminCfg.IsAdmin(plr.UserId, plr.Name) end
	return false
end

local function ensure(plr)
	local d = DataService:GetData(plr)
	if not d then
		return { Levels = {}, Points = 0, RollsDone = 0, PointsSpent = 0, BonusPoints = 0 }, nil
	end
	d.Upgrades = d.Upgrades or { Levels = {}, Points = 0, RollsDone = 0, PointsSpent = 0, BonusPoints = 0 }
	d.Upgrades.Levels      = d.Upgrades.Levels or {}
	d.Upgrades.Points      = d.Upgrades.Points or 0
	d.Upgrades.RollsDone   = d.Upgrades.RollsDone or 0
	d.Upgrades.PointsSpent = d.Upgrades.PointsSpent or 0
	d.Upgrades.BonusPoints = d.Upgrades.BonusPoints or 0
	return d.Upgrades, d
end

local function snapshotPayload(plr)
	local u, d = ensure(plr)
	local rolls   = tonumber(d and d.Rolls or 0) or 0
	local gained  = (PER_POINT > 0) and math.floor(rolls / PER_POINT) or 0
	local spent   = tonumber(u.PointsSpent or 0) or 0
	local bonus   = tonumber(u.BonusPoints or 0) or 0
	u.Points      = math.max(0, (gained + bonus) - spent)
	return {
		points      = u.Points,
		rollsToNext = rollsToNextPoint(rolls),
		levels      = u.Levels,
	}
end

local function sendSnapshot(plr)
	if not DataService:WaitLoaded(plr, 10) then return end
	Svc.Net:Send(plr, "UpgradesSnapshot", snapshotPayload(plr))
end

local function findPlayerByName(name: string): Player?
	name = tostring(name or "")
	if name == "" then return nil end
	for _, p in ipairs(Players:GetPlayers()) do
		if string.lower(p.Name) == string.lower(name) then return p end
	end
	return nil
end

Svc.Routes.RequestStatus = function(plr)
	sendSnapshot(plr)
	return true
end

Svc.Routes.RequestUpgrade = function(plr, payload)
	if not DataService:WaitLoaded(plr, 5) then return false, "data not loaded" end
	local u, d = ensure(plr); if not d then return false, "no profile" end
	local id  = tostring(payload.id or "")
	local amt = math.max(1, tonumber(payload.times or payload.amount or 1) or 1)
	local cfg = UpgCfg.Upgrades[id]; if not cfg then return false, "bad upgrade" end

	u.Levels[id] = u.Levels[id] or 0
	local cur = u.Levels[id]
	if cur >= (cfg.maxLevel or 0) then return false, "maxed" end

	local rolls  = tonumber(d.Rolls or 0) or 0
	local gained = (PER_POINT > 0) and math.floor(rolls / PER_POINT) or 0
	local spent  = tonumber(u.PointsSpent or 0) or 0
	local bonus  = tonumber(u.BonusPoints or 0) or 0
	u.Points     = math.max(0, (gained + bonus) - spent)

	local can = math.min(amt, u.Points, (cfg.maxLevel or 0) - cur)
	if can <= 0 then return false, "no points" end

	u.Points      = u.Points - can
	u.Levels[id]  = cur + can
	u.PointsSpent = spent + can

	DataService:MarkDirty(plr)
	Svc.Net:Send(plr, "Upgraded", {
		id          = id,
		level       = u.Levels[id],
		points      = snapshotPayload(plr).points,
		rollsToNext = snapshotPayload(plr).rollsToNext,
	})
	sendSnapshot(plr)
	return true
end

Svc.Routes.AdminSetPoints = function(_plr, payload)
	if not isAdmin(_plr) then return false, "no permission" end
	if type(payload) ~= "table" then return false, "bad payload" end
	local targetName = tostring(payload.target or "")
	local desired    = tonumber(payload.points)
	if targetName == "" or not desired or desired < 0 then return false, "bad args" end

	local target = findPlayerByName(targetName)
	if not target then return false, "player not found" end
	if not DataService:EnsureLoaded(target, 10) then return false, "no profile" end

	local u, d = ensure(target); if not d then return false, "no profile" end
	local rolls  = tonumber(d.Rolls or 0) or 0
	local gained = (PER_POINT > 0) and math.floor(rolls / PER_POINT) or 0
	local spent  = tonumber(u.PointsSpent or 0) or 0

	local newBonus = math.max(0, math.floor(desired + spent - gained))
	u.BonusPoints = newBonus
	u.Points      = math.max(0, (gained + newBonus) - spent)

	DataService:MarkDirty(target)
	sendSnapshot(target)
	return true
end

return Svc
"""

SERVERGAMESTART = r"""local RS          = game:GetService("ReplicatedStorage")
local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local GC_REMOTES = RS:FindFirstChild("GameCore_Remotes")
if not GC_REMOTES then
	GC_REMOTES = Instance.new("Folder")
	GC_REMOTES.Name = "GameCore_Remotes"
	GC_REMOTES.Parent = RS
else
	for _, child in ipairs(RS:GetChildren()) do
		if child:IsA("Folder") and child.Name == "GameCore_Remotes" and child ~= GC_REMOTES then
			for _, it in ipairs(child:GetChildren()) do it.Parent = GC_REMOTES end
			child:Destroy()
		end
	end
end

local GameCore = require(RS.Main.GameCore)
local Promise  = require(RS.Main.GameCore.Promise)
local Async    = require(RS.Main.GameCore.AsyncTasks)
local MathX    = require(RS.Main.GameCore.MathX)

GameCore.PingTimes = require(RS.Main.Modules.PingTimes)

GameCore.Configure({
	RemotesFolder = GC_REMOTES,
	Roots = {
		Services    = RS.Main.Services,
		Controllers = RS.Main.Controllers,
	},
	Promise = Promise,
	Async   = Async,
	AC = { Whitelist = { [797399348] = true } },
	AntiCheat = {
		Enabled  = true,
		Mode     = "enforce",
		LogLevel = "warn",
		Network  = {
			MaxPayloadBytes = 8 * 1024,
			ReplayWindow    = 8,
			Rate = {
				Default  = { calls = 20, window = 1.0 },
				PerRoute = {
					RNGService    = { calls = 8, window = 0.5 },
					RNGService_fn = { calls = 8, window = 0.5 },
				},
			},
		},
		Movement = {
			BaseWalkSpeed  = 16,
			MaxSprintSpeed = 50,
			SpeedTolerance = 15,
			MaxTP          = 100,
			TPWindow       = 0.25,
			CheckNoclip    = false,
		},
		Integrity = {
			LockHumanoidProps      = true,
			BlockDescendantScripts = true,
			DisallowSetHiddenProps = true,
		},
	},
})

MathX.setGameCore(GameCore)
GameCore.AC.Start()
GameCore.AC.AttachNetGuards()

local lastReq = {}
GameCore.UseMiddleware("RNGService", function(ctx, next)
	local uid = ctx.player.UserId
	local t   = os.clock()
	if (t - (lastReq[uid] or 0)) < 0.20 then return end
	lastReq[uid] = t
	next(ctx)
end)

GameCore.Auto()
print("[Server] SoundScape RNG - GameCore Started")
"""

LOADER = r"""local ReplicatedFirst   = game:GetService("ReplicatedFirst")
local Players           = game:GetService("Players")
local RS                = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local ContentProvider   = game:GetService("ContentProvider")
local RunService        = game:GetService("RunService")

pcall(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)

local L  = Players.LocalPlayer
local PG = L:WaitForChild("PlayerGui")

local GUI           = PG:WaitForChild("Main")
local LoadingScreen = GUI:WaitForChild("LoadingScreen")
local Center        = LoadingScreen:WaitForChild("CenterContainer")
local LoadText      = Center:WaitForChild("LoadText")
local ProgressBar   = Center:WaitForChild("ProgressBar")
local Fill          = ProgressBar:WaitForChild("Fill")
local PercentLabel  = ProgressBar:WaitForChild("Percent")
local Whoosh: Sound? = LoadingScreen:FindFirstChild("Whoosh")

local okGC, GameCore  = pcall(function() return require(RS.Main.GameCore) end)
local okSh, Shime     = pcall(function() return require(RS.Main.Modules.Shime) end)
local okItems, ItemsCfg = pcall(function() return require(RS.Main.Configs.Items) end)

local function ensureVisible()
	GUI.Enabled = true
	LoadingScreen.Visible = true
	local function bumpZ(root: Instance, z: number)
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("GuiObject") then d.ZIndex = z end
		end
		if root:IsA("GuiObject") then root.ZIndex = z end
	end
	bumpZ(LoadingScreen, 10)
	local sg = GUI :: ScreenGui
	if sg then sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; sg.DisplayOrder = 9999 end
end

ensureVisible()

local function tween(i, ti, props) return TweenService:Create(i, ti, props) end
local function setPercent(p)
	p = math.clamp(p or 0, 0, 1)
	Fill.Size = UDim2.fromScale(p, 1)
	PercentLabel.Text = (math.floor(p * 100 + 0.5)) .. "%"
end

local shimmer
if okSh and Shime then
	local ok, inst = pcall(function()
		return Shime.new(Fill, 0.8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false, 0)
	end)
	if ok then shimmer = inst; pcall(function() shimmer:Play() end) end
end

local targetP, currentP = 0, 0
local function requestProgress(to) targetP = math.clamp(to or 0, 0, 1) end
task.spawn(function()
	while LoadingScreen.Parent do
		currentP += (targetP - currentP) * 0.18
		if math.abs(targetP - currentP) < 0.002 then currentP = targetP end
		setPercent(currentP)
		RunService.RenderStepped:Wait()
	end
end)

local function logoIntro()
	local s = Center:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", Center)
	s.Scale = 0.86
	if Whoosh then pcall(function() Whoosh:Play() end) end
	tween(s, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.02 }):Play()
	task.wait(0.28)
	tween(s, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Scale = 1.00 }):Play()
end

local function collectImages(root: Instance)
	local list = {}
	for _, d in ipairs(root:GetDescendants()) do
		if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= "" then
			table.insert(list, d)
		elseif d:IsA("Texture") and d.Texture ~= "" then
			table.insert(list, d)
		end
	end
	return list
end

local function preloadUI()
	local assets = {}
	for _, inst in ipairs(collectImages(LoadingScreen)) do table.insert(assets, inst) end
	for _, inst in ipairs(collectImages(GUI)) do table.insert(assets, inst) end
	if #assets > 0 then pcall(function() ContentProvider:PreloadAsync(assets) end) end
end

local function isClientSafe(mod: ModuleScript): boolean
	if mod:GetAttribute("ServerOnly") == true then return false end
	if mod:GetAttribute("ClientOnly") == false then return false end
	local name = string.lower(mod.Name)
	local parentName = mod.Parent and string.lower(mod.Parent.Name) or ""
	if parentName == "services" or name:find("service") then return false end
	return true
end

local function requireClientModules(container: Instance, w0, wspan)
	local list = {}
	for _, obj in ipairs(container:GetDescendants()) do
		if obj:IsA("ModuleScript") and isClientSafe(obj) then
			table.insert(list, obj)
		end
	end
	local n = #list
	for i, m in ipairs(list) do
		pcall(function() require(m) end)
		local f = (n > 0) and (i / n) or 1
		requestProgress(w0 + f * wspan)
		RunService.Heartbeat:Wait()
	end
end

local function warmRoutes()
	if not okGC then return end
	pcall(function() GameCore.Fire("BackpackService","RequestStatus",{}) end)
	pcall(function() GameCore.Fire("QuestService","RequestQuests",{}) end)
	pcall(function() GameCore.Fire("MarketService","CheckPass",{ key="AutoRoll",  rid=os.clock() }) end)
	pcall(function() GameCore.Fire("MarketService","CheckPass",{ key="QuickRoll", rid=os.clock() }) end)
end

local function waitForCore(timeout)
	if not okGC then return end
	local t0 = os.clock()
	while not GameCore.Ready() do
		if timeout and os.clock() - t0 > timeout then break end
		task.wait(0.05)
	end
end

local function waitForDataLoaded(timeout)
	local t0 = os.clock()
	if L:GetAttribute("DataLoaded") == true then return true end
	local done = false
	local conn = L.AttributeChanged:Connect(function(attr)
		if attr == "DataLoaded" and L:GetAttribute("DataLoaded") == true then done = true end
	end)
	while not done do
		if timeout and os.clock() - t0 > timeout then break end
		if L:GetAttribute("DataLoaded") == true then break end
		task.wait(0.05)
	end
	conn:Disconnect()
	return L:GetAttribute("DataLoaded") == true
end

local function finishAndHide()
	requestProgress(1)
	if shimmer then pcall(function() shimmer:Cancel() end) end
	task.wait(0.15)
	local s = Center:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", Center)
	s.Scale = 1
	tween(s, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.96 }):Play()
	task.delay(0.11, function()
		tween(s, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.02 }):Play()
	end)
	task.wait(0.22)
	local fade = tween(LoadingScreen, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
	fade:Play(); fade.Completed:Wait()
	LoadingScreen.Visible = false
	LoadingScreen:Destroy()
end

task.spawn(function()
	setPercent(0)
	LoadText.Text = "Loading SoundScape..."
	logoIntro()

	requestProgress(0.06); preloadUI()
	requestProgress(0.12)

	local main = RS:FindFirstChild("Main")
	if main then
		if main:FindFirstChild("Configs")     then requireClientModules(main.Configs,     0.12, 0.06) end
		if main:FindFirstChild("Modules")     then requireClientModules(main.Modules,     0.18, 0.07) end
		if main:FindFirstChild("Controllers") then requireClientModules(main.Controllers, 0.25, 0.08) end
	end
	requestProgress(0.36)

	LoadText.Text = "Connecting..."; waitForCore(8); requestProgress(0.46)
	LoadText.Text = "Syncing data..."; warmRoutes(); requestProgress(0.62)
	waitForDataLoaded(12); requestProgress(0.80)

	LoadText.Text = "Tuning frequencies..."; task.wait(0.25); requestProgress(0.92)
	LoadText.Text = "Ready to drop..."; task.wait(0.25); requestProgress(0.98)

	finishAndHide()
end)
"""

if __name__ == "__main__":
    main()
