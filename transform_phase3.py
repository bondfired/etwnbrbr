#!/usr/bin/env python3
"""Phase 3 — Controller transformations for SoundScape RNG."""

FILE = "SoundScape_RNG.rbxlx"

def read():
    with open(FILE, "r", encoding="utf-8") as f:
        return f.read()

def write(content):
    with open(FILE, "w", encoding="utf-8") as f:
        f.write(content)

def replace_cdata(content, unique_str, new_source, label):
    idx = content.find(unique_str)
    if idx == -1:
        print(f"SKIP: {label} — unique string not found")
        return content
    cdata_start_tag = "<![CDATA["
    cdata_end_tag = "]]>"
    search_start = max(0, idx - 8000)
    cs = content.rfind(cdata_start_tag, search_start, idx)
    if cs == -1:
        print(f"SKIP: {label} — CDATA start not found")
        return content
    ce = content.find(cdata_end_tag, idx)
    if ce == -1:
        print(f"SKIP: {label} — CDATA end not found")
        return content
    before = content[:cs + len(cdata_start_tag)]
    after = content[ce:]
    content = before + new_source + after
    print(f"OK: {label}")
    return content

# ─────────────────────────────────────────────
# 1. RNGController — scan-based fragment discovery
# ─────────────────────────────────────────────
RNG_CONTROLLER = r'''local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local RS = game:GetService("ReplicatedStorage")

local GameCore = require(RS.Main.GameCore)
local Cards    = require(RS.Main.Configs.Cards)
local Admin    = require(RS.Main.Configs.Admin)
local Monet    = require(RS.Main.Configs.Monet)
local Shime    = require(RS.Main.Modules.Shime)

local L  = Players.LocalPlayer
local PG = L:WaitForChild("PlayerGui")
local GUI = PG:WaitForChild("Main")

local C = { Name = "RNGController", AutoRoutes = {"EconomyService","RNGService","MarketService","UpgradeService"} }

local Buttons      = GUI.Bottom.RollButtonsHolder
local ScanBtn      = Buttons.RollButton:WaitForChild("TextButton") :: TextButton
local ScanMain     = Buttons.RollButton.Main
local QuickBtn     = Buttons.QuickRollButton:WaitForChild("TextButton") :: TextButton
local QuickMain    = Buttons.QuickRollButton.Main
local QuickText    = QuickMain.QuickRollText
local QuickStroke  = QuickMain.UIStroke
local AutoBtn      = Buttons.AutoRollButton:WaitForChild("TextButton") :: TextButton
local AutoMain     = Buttons.AutoRollButton.Main
local AutoText     = AutoMain.AutoRollText
local AutoStroke   = AutoMain.UIStroke

local LevelBar     = GUI.Bottom.LevelBar
local Fill         = LevelBar.Fill
local LevelText    = LevelBar.LevelText
local ScanText     = LevelBar.RollText

local RF           = GUI.RollFrame
local MainRoll     = RF.MainRoll
local MainImage    = MainRoll.TemplateImage :: ImageLabel
local MainRarity   = MainRoll.Rarity :: TextLabel
local MainStroke   = MainRoll:WaitForChild("RarityStroke")
local MainGrad     = MainStroke:FindFirstChild("UIGradient") :: UIGradient?

local QuickRoll    = RF.QuickRoll
local QuickImage   = QuickRoll.TemplateImage :: ImageLabel
local QuickRarity  = QuickRoll.Rarity :: TextLabel
local QuickStroke2 = QuickRoll:WaitForChild("RarityStroke")
local QuickGrad    = QuickStroke2:FindFirstChild("UIGradient") :: UIGradient?

local MultiRoll    = RF:WaitForChild("MultipleRoll")
local MRTemplate   = MultiRoll:WaitForChild("Template") :: Frame
MRTemplate.Visible = false

local GREEN = Color3.fromRGB(0,189,13)
local RED   = Color3.fromRGB(230,60,60)
local SCANS_CAP = 1000

local RARITY_COLORS = {
	Common   = Color3.fromRGB(180,180,180),
	Uncommon = Color3.fromRGB(80,200,80),
	Rare     = Color3.fromRGB(60,120,255),
	Epic     = Color3.fromRGB(180,60,255),
	Mythic   = Color3.fromRGB(255,200,40),
}

local REQUIRE = {
	AutoScan  = { rolls = 150,   gamepassId = (Monet.Gamepasses.AutoRoll  and Monet.Gamepasses.AutoRoll.id  or 0) },
	QuickScan = { rolls = 10000, gamepassId = (Monet.Gamepasses.QuickRoll and Monet.Gamepasses.QuickRoll.id or 0) },
}

local scans, ready, busy = 0, false, false
local autoOn, quickOn = false, false
local fullyLoaded = false
local ownsQuick, ownsAuto = false, false
local autoTickerRunning = false
local animating = false
local awaiting = false

local BASE_MIN_SCAN_GAP   = 0.25
local BASE_AUTO_GAP_MAIN  = 0.75
local BASE_AUTO_GAP_QUICK = 0.40

local effMinGap   = BASE_MIN_SCAN_GAP
local effAutoMain = BASE_AUTO_GAP_MAIN
local effAutoQuick= BASE_AUTO_GAP_QUICK

local function applyScanSpeed(lv:number)
	local mult = 1 + 0.03 * math.max(0, lv or 0)
	effMinGap    = math.max(0.08, BASE_MIN_SCAN_GAP   / mult)
	effAutoMain  = math.max(0.18, BASE_AUTO_GAP_MAIN  / mult)
	effAutoQuick = math.max(0.12, BASE_AUTO_GAP_QUICK / mult)
end
applyScanSpeed(0)

local lastScanT  = 0
local nextAutoAt = 0

local function tween(i:Instance, ti:TweenInfo, props:any) return TweenService:Create(i, ti, props) end
local function setBusy(b:boolean) busy = b; ScanBtn.Active = not b and fullyLoaded end
local function setAuto(on:boolean) autoOn = on; AutoText.Text = on and "Auto Scan: On" or "Auto Scan: Off"; AutoStroke.Color = on and GREEN or RED end
local function setQuick(on:boolean) quickOn = on; QuickText.Text = on and "Quick Scan: On" or "Quick Scan: Off"; QuickStroke.Color = on and GREEN or RED end
local function promptPass(key:string) GameCore.Fire("MarketService","PromptPass",{ key = key }) end

local function asNumberScans(v:any): number
	if type(v) == "number" then return v end
	if type(v) == "table" then return tonumber(v.rolls or v.current or v.value) or 0 end
	return tonumber(v) or 0
end

local function fragmentLabel(result)
	local cfg = Cards.ById and Cards.ById[result.collectibleId or result.id]
	local cName = cfg and cfg.name or (result.collectibleId or result.id or "???")
	local fType = result.fragmentType or "Fragment"
	local fRarity = result.fragmentRarity or result.rarity or "Common"
	return cName, fType, fRarity
end

local function rarityColor(r: string): Color3
	return RARITY_COLORS[r] or Color3.fromRGB(180,180,180)
end

local function burstConfetti(parent: Instance, rarity: string)
	if rarity ~= "Epic" and rarity ~= "Mythic" then return end
	local count = (rarity == "Mythic") and 26 or 14
	for i = 1, count do
		local p = Instance.new("Frame")
		p.Name = "Confetti"
		p.AnchorPoint = Vector2.new(0.5,0.5)
		p.Size = UDim2.fromOffset(6,6)
		p.BackgroundColor3 = Color3.fromHSV((i*0.07)%1, 0.9, 1)
		p.BorderSizePixel = 0
		p.Position = UDim2.fromScale(0.5,0.5)
		p.Parent = parent
		local rot = math.random(-180,180)
		local xoff = math.random(-220,220)
		local yoff = math.random(140,220)
		TweenService:Create(p, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = p.Position + UDim2.fromOffset(xoff, yoff), Rotation = rot, BackgroundTransparency = 0
		}):Play()
		task.delay(0.66, function()
			TweenService:Create(p, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
			game:GetService("Debris"):AddItem(p, 0.22)
		end)
	end
end

local function openOverlay()
	animating = true
	RF.Visible = true
	RF.Active = true
	RF.BackgroundTransparency = 1
	TweenService:Create(RF, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.35
	}):Play()
end

local function closeOverlay(onDone: (() -> ())?)
	if not RF.Visible then
		animating = false
		if onDone then onDone() end
		return
	end
	local tw = TweenService:Create(RF, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1
	})
	tw:Play()
	tw.Completed:Wait()
	RF.Visible = false
	MainRoll.Visible  = false
	QuickRoll.Visible = false
	MultiRoll.Visible = false
	animating = false
	if onDone then onDone() end
end

local function canBypassAuto()  return Admin.CanBypassAuto(L.UserId, L.Name) == true end
local function canBypassQuick() return Admin.CanBypassQuick(L.UserId, L.Name) == true end

local function hasAccessQuick(): boolean
	if Admin and (Admin.CanBypassQuick and Admin.CanBypassQuick(L.UserId, L.Name)) then return true end
	if REQUIRE.QuickScan.gamepassId > 0 and ownsQuick then return true end
	return asNumberScans(scans) >= (REQUIRE.QuickScan.rolls or 0)
end
local function hasAccessAuto(): boolean
	if Admin and (Admin.CanBypassAuto and Admin.CanBypassAuto(L.UserId, L.Name)) then return true end
	if REQUIRE.AutoScan.gamepassId > 0 and ownsAuto then return true end
	return asNumberScans(scans) >= (REQUIRE.AutoScan.rolls or 0)
end

local function kickAuto()
	if autoOn and not autoTickerRunning then
		nextAutoAt = os.clock()
		startAutoTicker()
	end
end

local function safeScan(amount: number)
	if not fullyLoaded then return end
	local t = os.clock()
	if busy or animating or (t - lastScanT) < effMinGap then return end
	lastScanT = t
	setBusy(true)
	animating = true
	awaiting = true
	openOverlay()
	task.delay(2.0, function()
		if awaiting then
			awaiting = false
			closeOverlay(function()
				setBusy(false); animating = false; kickAuto()
			end)
		end
	end)
	GameCore.Fire("RNGService","RequestRoll", { amount = amount, rid = math.floor(t*1000) })
end

function startAutoTicker()
	if autoTickerRunning then return end
	autoTickerRunning = true
	task.spawn(function()
		while autoOn do
			if fullyLoaded and hasAccessAuto() and os.clock() >= nextAutoAt then
				safeScan(1)
				nextAutoAt = os.clock() + (quickOn and effAutoQuick or effAutoMain)
			end
			task.wait(0.05)
		end
		autoTickerRunning = false
	end)
end

local function updateLocks()
	local qHas = hasAccessQuick()
	QuickBtn:SetAttribute("Unlocked", qHas)
	QuickStroke.Color = (qHas and quickOn) and GREEN or RED
	if qHas then
		QuickText.Text = quickOn and "Quick Scan: On" or "Quick Scan: Off"
	else
		QuickText.Text = (REQUIRE.QuickScan.gamepassId > 0 and not canBypassQuick())
			and "Quick Scan: Buy"
			or ("Quick Scan: "..tostring(REQUIRE.QuickScan.rolls).." Scans")
	end
	local aHas = hasAccessAuto()
	AutoBtn:SetAttribute("Unlocked", aHas)
	AutoBtn.AutoButtonColor = aHas
	AutoStroke.Color = (aHas and autoOn) and GREEN or RED
	if aHas then
		AutoText.Text = autoOn and "Auto Scan: On" or "Auto Scan: Off"
	else
		AutoText.Text = (REQUIRE.AutoScan.gamepassId > 0 and not canBypassAuto())
			and "Auto Scan: Buy"
			or ("Auto Scan: "..tostring(REQUIRE.AutoScan.rolls).." Scans")
	end
end

local function animateMain(result)
	openOverlay()
	MultiRoll.Visible = false
	MainRoll.Visible  = true
	QuickRoll.Visible = false
	MainRoll.AnchorPoint = Vector2.new(0.5, 0.5)
	MainRoll.Position    = UDim2.fromScale(0.5, 0.5)

	local cName, fType, fRarity = fragmentLabel(result)
	local cfg = Cards.ById and Cards.ById[result.collectibleId or result.id]
	local image = (cfg and cfg.image) or ""
	local color = rarityColor(fRarity)

	MainImage.ImageColor3 = color
	MainImage.Image = image
	MainImage.ImageTransparency = 1
	MainRarity.Text = fType .. " — " .. fRarity

	local s = MainRoll:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", MainRoll)
	s.Scale = 0.85
	tween(s, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.10 }):Play()

	MainImage.Size = UDim2.fromOffset(10, 12)
	tween(MainImage, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(236, 283), ImageTransparency = 0
	}):Play()
	task.wait(0.24)

	tween(MainImage, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(258, 309)
	}):Play()
	task.wait(0.18)

	local shime = Shime.new(MainImage, 1, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut)
	shime:Play()

	tween(s, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Scale = 1.00 }):Play()
	tween(MainImage, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		Size = UDim2.fromOffset(244, 292)
	}):Play()
	task.wait(0.12)

	burstConfetti(MainRoll, fRarity)

	closeOverlay(function()
		setBusy(false)
		animating = false
		kickAuto()
	end)
end

local function animateQuick(result)
	openOverlay()
	MultiRoll.Visible = false
	MainRoll.Visible  = false
	QuickRoll.Visible = true
	QuickRoll.AnchorPoint = Vector2.new(0.5, 0.5)
	QuickRoll.Position    = UDim2.fromScale(0.505, 0.67)

	local cName, fType, fRarity = fragmentLabel(result)
	local cfg = Cards.ById and Cards.ById[result.collectibleId or result.id]
	local image = (cfg and cfg.image) or ""
	local color = rarityColor(fRarity)

	QuickImage.ImageColor3 = color
	QuickImage.Image = image
	QuickImage.ImageTransparency = 1
	QuickRarity.Text = fType .. " — " .. fRarity

	local s = QuickRoll:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", QuickRoll)
	s.Scale = 0.92
	tween(s, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.03 }):Play()

	QuickImage.Size = UDim2.fromOffset(18, 22)
	tween(QuickImage, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(161, 194), ImageTransparency = 0
	}):Play()
	task.wait(0.12)

	tween(QuickImage, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(170, 204)
	}):Play()
	task.wait(0.08)

	local shime = Shime.new(QuickImage, 1, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut)
	shime:Play()

	tween(QuickImage, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(161, 194)
	}):Play()
	task.wait(0.06)

	burstConfetti(QuickRoll, fRarity)

	closeOverlay(function()
		setBusy(false)
		animating = false
		kickAuto()
	end)
end

RF.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		if animating then return end
		closeOverlay()
	end
end)

local function clearMulti()
	for _, child in ipairs(MultiRoll:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "Template" then
			child:Destroy()
		end
	end
end

local function showMulti(results: {any})
	openOverlay()
	MainRoll.Visible = false
	QuickRoll.Visible = false
	MultiRoll.Visible = true
	clearMulti()
	for _,res in ipairs(results) do
		local f = MRTemplate:Clone()
		f.Visible = true
		local img = f:FindFirstChild("Icon")
		if img and img:IsA("ImageLabel") then
			local cfg = Cards.ById[res.collectibleId or res.id]
			img.Image = (cfg and cfg.image) or ""
			img.ImageColor3 = rarityColor(res.fragmentRarity or res.rarity or "Common")
		end
		local rar = f:FindFirstChild("RarityText")
		if rar and rar:IsA("TextLabel") then
			rar.Text = (res.fragmentType or "Fragment") .. " — " .. (res.fragmentRarity or "Common")
		end
		f.Parent = MultiRoll
	end
	task.delay(2.0, function()
		if MultiRoll.Visible then
			closeOverlay(function()
				setBusy(false)
				animating = false
				kickAuto()
			end)
		end
	end)
end

function C:OnRoute(route, method, payload)
	if route == "EconomyService" then
		if method == "RollsUpdate" then
			ready = true
			scans = payload
			local n = asNumberScans(payload)
			ScanText.Text = ("%d/%d scans"):format(math.min(n, SCANS_CAP), SCANS_CAP)
			updateLocks()
			setBusy(busy)
			kickAuto()
		elseif (method == "LevelUpdate" or method == "Level" or method == "Status") then
			local lv   = tonumber(payload.level or payload.lv or (payload.data and payload.data.level)) or 1
			local xp   = tonumber(payload.xp    or (payload.data and payload.data.xp   ) or payload.progress) or 0
			local need = tonumber(payload.need  or payload.xpToNext or (payload.data and payload.data.need) or payload.req) or 1
			LevelText.Text = ("Level %d"):format(lv)
			Fill.Size = UDim2.fromScale(math.clamp(xp / math.max(1, need), 0, 1), 1)
		end

	elseif route == "RNGService" and method == "Results" then
		awaiting = false
		local list
		if typeof(payload) == "table" and payload[1] then
			list = payload
		elseif typeof(payload) == "table" and payload.results and payload.results[1] then
			list = payload.results
		elseif typeof(payload) == "table" and (payload.collectibleId or payload.id) then
			list = { payload }
		else
			list = {}
		end

		if #list > 1 then
			showMulti(list)
		elseif #list == 1 then
			local last = list[1]
			if quickOn then animateQuick(last) else animateMain(last) end
		else
			warn("[RNGController] Empty Results payload:", payload)
			closeOverlay(function()
				setBusy(false); animating = false; kickAuto()
			end)
		end
		updateLocks()
		setBusy(false)
		kickAuto()

	elseif route == "MarketService" and method == "PassOwnResult" then
		if payload.key == "AutoRoll"  then ownsAuto  = payload.owns end
		if payload.key == "QuickRoll" then ownsQuick = payload.owns end
		updateLocks()
		kickAuto()

	elseif route == "UpgradeService" then
		if method == "UpgradesSnapshot" then
			local levels = payload.levels or payload.Levels or {}
			applyScanSpeed(tonumber(levels.ScanSpeed or levels.RollSpeed or 0) or 0)
		elseif method == "Upgraded" and (tostring(payload.id) == "ScanSpeed" or tostring(payload.id) == "RollSpeed") then
			applyScanSpeed(tonumber(payload.level or payload.Level or 0) or 0)
		end
	end
end

local function nudge(gui: GuiObject)
	local t = tween(gui, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = gui.Position + UDim2.fromOffset(4,0) })
	t:Play(); t.Completed:Wait()
	tween(gui, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = gui.Position - UDim2.fromOffset(4,0) }):Play()
end

function C:Init()
	task.defer(function()
		if REQUIRE.QuickScan.gamepassId > 0 then GameCore.Fire("MarketService","CheckPass",{ key="QuickRoll", rid=os.clock() }) end
		if REQUIRE.AutoScan.gamepassId > 0  then GameCore.Fire("MarketService","CheckPass",{ key="AutoRoll",  rid=os.clock() }) end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if player ~= L then return end
		if passId == REQUIRE.QuickScan.gamepassId and purchased then
			GameCore.Fire("MarketService","CheckPass",{ key="QuickRoll", rid=os.clock() })
		elseif passId == REQUIRE.AutoScan.gamepassId and purchased then
			GameCore.Fire("MarketService","CheckPass",{ key="AutoRoll", rid=os.clock() })
		end
	end)

	task.spawn(function()
		while not GameCore.Ready() do task.wait(0.1) end
		task.wait(0.4)
		fullyLoaded = true
		updateLocks()
		setBusy(false)
		kickAuto()
	end)
end

function C:Start()
	setAuto(false); setQuick(false)
	updateLocks()

	ScanBtn.MouseButton1Click:Connect(function()
		if not fullyLoaded then return end
		safeScan(1)
	end)

	QuickBtn.MouseButton1Click:Connect(function()
		if animating then return end
		if not hasAccessQuick() then
			if REQUIRE.QuickScan.gamepassId > 0 and not canBypassQuick() then
				promptPass("QuickRoll")
			else
				nudge(QuickMain)
			end
			return
		end
		setQuick(not quickOn)
		updateLocks()
	end)

	AutoBtn.MouseButton1Click:Connect(function()
		if animating then return end
		if not hasAccessAuto() then
			if REQUIRE.AutoScan.gamepassId > 0 and not canBypassAuto() then
				promptPass("AutoRoll")
			else
				nudge(AutoMain)
			end
			return
		end
		setAuto(not autoOn)
		updateLocks()
		if autoOn then kickAuto() end
	end)
end

return C
'''

# ─────────────────────────────────────────────
# 2. LevelController — "scans" text
# ─────────────────────────────────────────────
LEVEL_CONTROLLER = r'''local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local GameCore = require(RS.Main.GameCore)

local L = Players.LocalPlayer
local GUI = L:WaitForChild("PlayerGui"):WaitForChild("Main")

local Bar       = GUI.Bottom.LevelBar
local Fill      = Bar:WaitForChild("Fill") :: Frame
local LevelText = Bar:WaitForChild("LevelText") :: TextLabel
local ScanText  = Bar:WaitForChild("RollText") :: TextLabel

local C = { Name = "LevelController", AutoRoutes = { "EconomyService" } }

local lastLevel = 1

local TickList = Bar:FindFirstChild("LevelTickList")
local TICKS = {}
if TickList then
	for i = 1, 5 do
		TICKS[i] = TickList:FindFirstChild("LevelTick"..i)
	end
end

local scale = Bar:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", Bar)

local function tweenFill(pct: number)
	local goal = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0)
	TweenService:Create(
		Fill,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = goal }
	):Play()
end

local function pulseLevelText()
	local tw1 = TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.12 })
	local tw2 = TweenService:Create(scale, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 })
	tw1:Play()
	tw1.Completed:Wait()
	tw2:Play()
end

function C:OnRoute(route, method, payload)
	if route ~= "EconomyService" or method ~= "LevelUpdate" then return end

	local lvl = (payload.level :: number) or 1
	local prog = (payload.progress :: number) or 0
	local req = math.max(1, (payload.req :: number) or 1)

	LevelText.Text = ("Lv. %d"):format(lvl)
	ScanText.Text  = ("%d/%d scans"):format(math.clamp(prog, 0, req), req)

	tweenFill(prog / req)

	if lvl > lastLevel then
		task.spawn(pulseLevelText)
	end
	lastLevel = lvl

	for i = 1, #TICKS do
		local t = TICKS[i]
		if t and t:IsA("Frame") then
			t.Visible = true
		end
	end
end

return C
'''

# ─────────────────────────────────────────────
# 3. LeaderboardController — "Collection Power"
# ─────────────────────────────────────────────
LEADERBOARD_CONTROLLER = r'''local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local GameCore = require(RS.Main.GameCore)

local C = { Name = "LeaderboardController", AutoRoutes = {"LeaderboardService"} }

local L  = Players.LocalPlayer
local PG = L:WaitForChild("PlayerGui")
local GUI = PG:WaitForChild("Main")

local Root = GUI:WaitForChild("LeaderboardFrame")
local Main = Root.Main.CanvasGroup.ScrollingFrame
local Template = Main:WaitForChild("Template") :: Frame
Template.Visible = false
local CloseBtn: TextButton = Root:WaitForChild("CloseLeader")

local OPEN_POS   = UDim2.new(0.971, 0, 0.03, 0)
local CLOSED_POS = UDim2.new(1.25,  0, 0.03, 0)

local TWEEN_INFO = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function disableCorePlayerList()
	for i = 1, 8 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
		if ok then return end
		task.wait(0.1)
	end
end

Root.Position = OPEN_POS
Root:SetAttribute("IsOpen", true)
local tweening = false

local function setOpen(isOpen: boolean)
	if tweening then return end
	local cur = Root:GetAttribute("IsOpen")
	if cur == isOpen then return end
	Root:SetAttribute("IsOpen", isOpen)
	tweening = true
	local goal = isOpen and OPEN_POS or CLOSED_POS
	TweenService:Create(Root, TWEEN_INFO, { Position = goal }):Play()
	task.delay(TWEEN_INFO.Time + 0.02, function() tweening = false end)
end

local function toggle()
	setOpen(not Root:GetAttribute("IsOpen"))
end

local function fmtComma(n:number): string
	local s = tostring(math.floor(n))
	return s:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
end

local function setPlayerIcon(img: ImageLabel, userId:number)
	pcall(function()
		img.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(userId)
	end)
end

local function clearChildren()
	for _,c in ipairs(Main:GetChildren()) do
		if c:IsA("Frame") and c.Name ~= "Template" then c:Destroy() end
	end
end

local function buildRow(rank:number, row:any)
	local f = Template:Clone()
	f.Name = ("Row_%d"):format(rank)
	f.Visible = true
	f.Parent = Main

	local icon = f:FindFirstChild("PlayerIcon")
	if icon and icon:IsA("ImageLabel") then setPlayerIcon(icon, row.userId or 0) end

	local nameLabel = f:FindFirstChild("UsernameText")
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = ("#%d  %s"):format(rank, tostring(row.username or "???"))
	end

	local rollLabel = f:FindFirstChild("RollingText")
	if rollLabel and rollLabel:IsA("TextLabel") then
		rollLabel.Text = ("Power: %s"):format(fmtComma(tonumber(row.power or row.rolled or 0)))
	end
end

function C:OnRoute(route, method, payload)
	if route == "LeaderboardService" and method == "Snapshot" then
		clearChildren()
		for i,row in ipairs(payload) do
			buildRow(i, row)
		end
	end
end

function C:Init()
	disableCorePlayerList()
end

CloseBtn.Activated:Connect(toggle)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.Tab then
		toggle()
	end
end)

Root:GetPropertyChangedSignal("Visible"):Connect(function()
	if Root.Visible and Root:GetAttribute("IsOpen") == nil then
		Root:SetAttribute("IsOpen", true)
		Root.Position = OPEN_POS
	end
end)

Template.Visible = false

return C
'''

# ─────────────────────────────────────────────
# 4. InventoryController — fragments + completed tracks + fusion
# ─────────────────────────────────────────────
INVENTORY_CONTROLLER = r'''local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameCore = require(RS.Main.GameCore)
local Cards    = require(RS.Main.Configs.Cards)
local Shime    = require(RS.Main.Modules.Shime)

local C = { Name = "InventoryController", AutoRoutes = {"CardService"} }

local L  = Players.LocalPlayer
local PG = L:WaitForChild("PlayerGui")
local GUI = PG:WaitForChild("Main")
local InventoryFrame = GUI.Menus.InventoryFrame

local MainContainer    = InventoryFrame.Main.CanvasGroup.ScrollingFrame
local AttackContainer  = InventoryFrame.AttackFrame.Container
local SupportContainer = InventoryFrame.SupportFrame.Container

local TemplateMain = MainContainer:WaitForChild("Template") :: ImageButton
TemplateMain.Visible = false
TemplateMain.AutoButtonColor = false

for _,c in ipairs({AttackContainer, SupportContainer}) do
	local t = c:FindFirstChild("Template")
	if t and t:IsA("GuiObject") then t.Visible = false end
end

local Filters     = InventoryFrame.Main.FiltersContainer
local BtnAllKinds = (Filters:FindFirstChild("AllButton") or Filters:FindFirstChild("Allbutton")) :: GuiButton?
local BtnAttack   = Filters:FindFirstChild("AttackButton")  :: GuiButton?
local BtnSupport  = Filters:FindFirstChild("SupportButton") :: GuiButton?
local BtnBasic    = Filters:FindFirstChild("BasicButton")   :: GuiButton?
local BtnGold     = Filters:FindFirstChild("GoldButton")    :: GuiButton?
local BtnAllBlue  = Filters:FindFirstChild("AllBlueButton"):: GuiButton?
local BtnSecret   = Filters:FindFirstChild("SecretButton")  :: GuiButton?

local SearchBox = InventoryFrame.Main.SearchBox
local EmptyState: TextLabel = InventoryFrame.Main.CanvasGroup:FindFirstChild("EmptyState") :: TextLabel

local RARITY_COLORS = {
	Common   = Color3.fromRGB(180,180,180),
	Uncommon = Color3.fromRGB(80,200,80),
	Rare     = Color3.fromRGB(60,120,255),
	Epic     = Color3.fromRGB(180,60,255),
	Mythic   = Color3.fromRGB(255,200,40),
}

local FRAG_TYPES = {"Beat","Melody","Bass","Vocal"}
local MAX_EQUIPPED = 4

type CollectibleView = {
	id: string, name: string?, image: string?,
	collectibleType: string, fragments: {[string]: {count: number, bestRarity: string}},
	complete: boolean, fusionLevel: number, equipped: boolean,
	trackRarity: string?,
}

local _items: {[string]: CollectibleView} = {}
local _ui   : {[string]: ImageButton} = {}
local _fragments = {}
local _completed = {}
local _equipped  = {}

local currentTab  : "Fragments"|"Completed" = "Fragments"
local currentRarity: string = "All"
local searchQuery = ""

local function addHoverTweensTile(tile: ImageButton)
	tile.AutoButtonColor = false
	local scale = tile:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Scale = 1; scale.Parent = tile
	tile.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1.05}):Play()
	end)
	tile.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1.00}):Play()
	end)
	tile.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.95}):Play()
	end)
	tile.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.05}):Play()
	end)
end

local function equippedCount(): number
	local n = 0
	for _, _ in pairs(_equipped) do n += 1 end
	return n
end

local function shakeMain()
	local f = InventoryFrame.Main
	TweenService:Create(f, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = f.Position + UDim2.fromOffset(4,0)}):Play()
	task.wait(0.05)
	TweenService:Create(f, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = f.Position + UDim2.fromOffset(-8,0)}):Play()
	task.wait(0.05)
	TweenService:Create(f, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = f.Position + UDim2.fromOffset(4,0)}):Play()
end

local function pingNew(tile: Instance)
	local badge = tile:FindFirstChild("NewText")
	if not (badge and badge:IsA("TextLabel")) then return end
	badge.Visible = true
	badge.TextTransparency = 1
	badge.BackgroundTransparency = 1
	TweenService:Create(badge, TweenInfo.new(0.12), {TextTransparency = 0}):Play()
	task.delay(2, function()
		if not badge or not badge.Parent then return end
		TweenService:Create(badge, TweenInfo.new(0.18), {TextTransparency = 1}):Play()
		task.delay(0.19, function()
			if badge and badge.Parent then badge.Visible = false end
		end)
	end)
end

local function matchesText(id, name)
	local q = (searchQuery or ""):lower()
	if q == "" then return true end
	return (string.find((id or ""):lower(), q, 1, true) ~= nil)
		or (string.find((name or ""):lower(), q, 1, true) ~= nil)
end

local function clearAll()
	for id, btn in pairs(_ui) do
		btn:Destroy()
	end
	_ui = {}
end

local function fragProgress(collectibleId: string): (number, number, string)
	local cfg = Cards.ById and Cards.ById[collectibleId]
	if not cfg then return 0, 4, "Common" end
	local needed = cfg.fragments or FRAG_TYPES
	local have = 0
	local worst = "Mythic"
	local rarityOrder = {Common=1, Uncommon=2, Rare=3, Epic=4, Mythic=5}
	local fragData = _fragments[collectibleId] or {}
	for _, ft in ipairs(needed) do
		local fd = fragData[ft]
		if fd and fd.count and fd.count > 0 then
			have += 1
			local r = fd.bestRarity or "Common"
			if (rarityOrder[r] or 1) < (rarityOrder[worst] or 5) then
				worst = r
			end
		end
	end
	return have, #needed, worst
end

local function rebuildUI()
	clearAll()

	if currentTab == "Fragments" then
		for collectibleId, fragData in pairs(_fragments) do
			local cfg = Cards.ById and Cards.ById[collectibleId]
			if not cfg then continue end
			local name = cfg.name or collectibleId
			if not matchesText(collectibleId, name) then continue end

			local have, total, worst = fragProgress(collectibleId)
			if have == 0 then continue end

			local tile = TemplateMain:Clone()
			tile.Name = collectibleId
			tile.Visible = true
			_ui[collectibleId] = tile
			addHoverTweensTile(tile)

			tile.Image = cfg.image or ""
			tile.ImageColor3 = RARITY_COLORS[worst] or Color3.fromRGB(180,180,180)

			local dup = tile:FindFirstChild("DuplicationText")
			if dup and dup:IsA("TextLabel") then
				dup.Text = ("%d/%d"):format(have, total)
			end
			local rt = tile:FindFirstChild("RarityText")
			if rt and rt:IsA("TextLabel") then
				rt.Text = have >= total and "READY" or worst
			end

			tile.MouseButton1Click:Connect(function()
				if have >= total then
					GameCore.Fire("CardService","RequestFuse",{collectibleId = collectibleId})
				end
			end)

			tile.Parent = MainContainer
		end

	elseif currentTab == "Completed" then
		for collectibleId, trackData in pairs(_completed) do
			local cfg = Cards.ById and Cards.ById[collectibleId]
			if not cfg then continue end
			local name = cfg.name or collectibleId
			if not matchesText(collectibleId, name) then continue end

			local rarity = trackData.rarity or "Common"

			local tile = TemplateMain:Clone()
			tile.Name = collectibleId
			tile.Visible = true
			_ui[collectibleId] = tile
			addHoverTweensTile(tile)

			tile.Image = cfg.image or ""
			tile.ImageColor3 = RARITY_COLORS[rarity] or Color3.fromRGB(180,180,180)

			local dup = tile:FindFirstChild("DuplicationText")
			if dup and dup:IsA("TextLabel") then
				local fl = trackData.fusionLevel or 0
				dup.Text = fl > 0 and ("Lv."..tostring(fl)) or rarity
			end
			local rt = tile:FindFirstChild("RarityText")
			if rt and rt:IsA("TextLabel") then
				rt.Text = tostring(cfg.power or 0)
			end

			local isEquipped = false
			for _, eqId in pairs(_equipped) do
				if eqId == collectibleId then isEquipped = true; break end
			end

			tile.MouseButton1Click:Connect(function()
				if isEquipped then
					GameCore.Fire("CardService","RequestUnequip",{id=collectibleId})
				else
					if equippedCount() >= MAX_EQUIPPED then
						shakeMain(); return
					end
					GameCore.Fire("CardService","RequestEquip",{id=collectibleId})
				end
			end)

			if isEquipped then
				tile.Parent = AttackContainer
			else
				tile.Parent = MainContainer
			end
		end
	end

	local any = false
	for _ in pairs(_ui) do any = true; break end
	if EmptyState then EmptyState.Visible = not any end
end

if SearchBox then
	SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		searchQuery = (SearchBox.Text or ""):lower()
		rebuildUI()
	end)
end

local function wireFilter(btn: GuiButton?, setState: ()->())
	if not btn then return end
	btn.MouseButton1Click:Connect(function()
		setState()
		rebuildUI()
	end)
end

wireFilter(BtnAllKinds, function() currentTab = "Fragments"; currentRarity = "All" end)
wireFilter(BtnAttack,   function() currentTab = "Fragments" end)
wireFilter(BtnSupport,  function() currentTab = "Completed" end)
wireFilter(BtnBasic,    function() currentRarity = "Common" end)
wireFilter(BtnGold,     function() currentRarity = "Rare" end)
wireFilter(BtnAllBlue,  function() currentRarity = "Epic" end)
wireFilter(BtnSecret,   function() currentRarity = "Mythic" end)

function C:OnRoute(route, method, payload)
	if route == "CardService" and method == "CardsUpdate" then
		if payload.fragments then _fragments = payload.fragments end
		if payload.completed then _completed = payload.completed end
		if payload.equipped  then _equipped  = payload.equipped  end
		rebuildUI()
	end
end

return C
'''

# ─────────────────────────────────────────────
# 5. BackpackController — RarityBooster + FragmentScanner
# ─────────────────────────────────────────────
BACKPACK_CONTROLLER = r'''local Players 	   = game:GetService("Players")
local RS      	   = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS 		   = game:GetService("UserInputService")

local GameCore = require(RS.Main.GameCore)
local ItemsCfg = require(RS.Main.Configs.Items)

local C = { Name="BackpackController", AutoRoutes={"BackpackService"} }

local L  = Players.LocalPlayer
local PG = L:WaitForChild("PlayerGui")
local GUI = PG:WaitForChild("Main")
local Frame = GUI.Menus.BackpackFrame

local MainRoot = Frame.Main
local Filters  = MainRoot.FiltersContainer
local BtnAll   = Filters:WaitForChild("AllButton")     :: GuiButton
local BtnPot   = Filters:WaitForChild("PotionsButton") :: GuiButton
local BtnCards = Filters:WaitForChild("CardsButton")   :: GuiButton

local Panel    = MainRoot.InformationPanel
local Use1     = Panel:WaitForChild("UseButton")       :: GuiButton
local Use10    = Panel:WaitForChild("Use10Button")     :: GuiButton
local Use50    = Panel:WaitForChild("Use50Button")     :: GuiButton
local Desc     = Panel:WaitForChild("DescriptionText") :: TextLabel
local NameText = Panel:WaitForChild("ItemNameText")    :: TextLabel

local List     = MainRoot.CanvasGroup.ScrollingFrame
local Template = List:WaitForChild("Template")         :: Frame
Template.Visible = false

local UIGradient = Template.RarityStroke.UIGradient

local BoosterHUD = GUI.Bottom:WaitForChild("PotionsContainer")
local BoosterIcon = BoosterHUD:WaitForChild("PotionIcon") :: ImageLabel
local TimeLeft   = BoosterIcon:WaitForChild("TimeLeftText") :: TextLabel
BoosterHUD.Visible = false

local counts: {[string]: number} = {}
local tiles : {[string]: Frame} = {}
local selectedId: string? = nil
type Filter = "All"|"Potions"|"Cards"
local curFilter: Filter = "All"

local expireAtEpoch: number = 0

local PanelScale = Panel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", Panel)
Panel.Visible = false
PanelScale.Scale = 0.98

local function setGradient(grad: UIGradient, colorseq: ColorSequence)
	if grad then grad.Color = colorseq end
end

local function spinGradient(grad: UIGradient, seconds: number)
	if not grad then return end
	task.spawn(function()
		while grad.Parent do
			grad.Rotation = 0
			local tw = TweenService:Create(grad, TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {Rotation = 360})
			tw:Play(); tw.Completed:Wait()
		end
	end)
end

local function pulseStroke(stroke: UIStroke, base: number)
	if not stroke then return end
	task.spawn(function()
		while stroke.Parent do
			TweenService:Create(stroke, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Thickness = base + 1.5}):Play()
			task.wait(0.6)
			TweenService:Create(stroke, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.In),  {Thickness = base}):Play()
			task.wait(0.6)
		end
	end)
end

local function categoryOf(id: string): Filter
	if id == "FragmentScanner" then
		return "Cards"
	end
	if id and (id:lower():find("booster", 1, true) or id:lower():find("potion", 1, true)) then
		return "Potions"
	end
	return "Potions"
end

local function pointInside(gui: GuiObject, x: number, y: number): boolean
	if not gui or not gui.Visible then return false end
	local p, s = gui.AbsolutePosition, gui.AbsoluteSize
	return x >= p.X and x <= p.X + s.X and y >= p.Y and y <= p.Y + s.Y
end

local function setQty(tile: Frame, n: number)
	local dup = tile:FindFirstChild("DuplicationText")
	if dup and dup:IsA("TextLabel") then dup.Text = "x"..tostring(math.max(0, n or 0)) end
	local btn = tile:FindFirstChild("TextButton")
	if btn and btn:IsA("GuiButton") then
		btn.AutoButtonColor = (n or 0) > 0
		btn.Active = (n or 0) > 0
	end
	local icon = tile:FindFirstChild("Icon")
	if icon and icon:IsA("ImageLabel") then
		icon.ImageTransparency = (n or 0) > 0 and 0 or 0.4
	end
end

local function select(id: string?)
	selectedId = id
	local show = id ~= nil
	if show and not Panel.Visible then
		Panel.Visible = true
		PanelScale.Scale = 0.96
		TweenService:Create(PanelScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.00 }):Play()
	elseif not show and Panel.Visible then
		Panel.Visible = false
	end
	local def = id and ItemsCfg[id]
	if def then
		NameText.Text = def.name or id
		Desc.Text     = def.Description or ""
	else
		NameText.Text = ""; Desc.Text = ""
	end
	local n = (id and counts[id]) or 0
	Use1.Visible  = show and n >= 1
	Use10.Visible = show and n >= 10
	Use50.Visible = show and n >= 50
end

local function popInTile(tile: Frame)
	local s = tile:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", tile)
	s.Scale = 0.82
	TweenService:Create(s, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	if tile.BackgroundTransparency then
		local bt0 = tile.BackgroundTransparency
		tile.BackgroundTransparency = 1
		TweenService:Create(tile, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = bt0}):Play()
	end
end

local function wireTileButton(tile: Frame, btn: GuiButton)
	btn.AutoButtonColor = false
	btn.Active = true
	local s = tile:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", tile)
	if s.Scale == 0 then s.Scale = 1 end
	local hoverT, leaveT, downT, upT
	local function kill(t) if t and t.PlaybackState == Enum.PlaybackState.Playing then t:Cancel() end end
	local strokeHolder  = tile:FindFirstChild("RarityStroke")
	local tileStroke    = strokeHolder and strokeHolder:FindFirstChildOfClass("UIStroke")
	local baseThickness = tileStroke and tileStroke.Thickness or 2
	btn.MouseEnter:Connect(function()
		kill(leaveT); kill(hoverT)
		hoverT = TweenService:Create(s, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1.04})
		hoverT:Play()
		if tileStroke then TweenService:Create(tileStroke, TweenInfo.new(0.10), {Thickness = baseThickness + 1}):Play() end
	end)
	local function leave()
		kill(hoverT); kill(leaveT)
		leaveT = TweenService:Create(s, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1})
		leaveT:Play()
		if tileStroke then TweenService:Create(tileStroke, TweenInfo.new(0.10), {Thickness = baseThickness}):Play() end
	end
	btn.MouseLeave:Connect(leave)
	btn.MouseButton1Down:Connect(function()
		kill(downT)
		downT = TweenService:Create(s, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.96})
		downT:Play()
	end)
	btn.MouseButton1Up:Connect(function()
		kill(upT)
		upT = TweenService:Create(s, TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.05})
		upT:Play()
		task.delay(0.10, function()
			if btn:IsDescendantOf(tile) then
				local mouse = UIS:GetMouseLocation()
				local p, sz = tile.AbsolutePosition, tile.AbsoluteSize
				local hovering = mouse.X >= p.X and mouse.X <= p.X+sz.X and mouse.Y >= p.Y and mouse.Y <= p.Y+sz.Y
				TweenService:Create(s, TweenInfo.new(0.08), {Scale = hovering and 1.04 or 1}):Play()
			end
		end)
	end)
end

local function applyTileFX(tile: Frame, id: string)
	local stroke = tile:FindFirstChild("RarityStroke")
	if not stroke then return end
	local grad = stroke:FindFirstChildOfClass("UIGradient")
	if id == "RarityBooster" then
		setGradient(grad, ColorSequence.new{
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB( 34, 220, 120)),
			ColorSequenceKeypoint.new(0.50, Color3.fromRGB(  2, 180,  90)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB( 34, 220, 120)),
		})
	elseif id == "FragmentScanner" then
		setGradient(grad, ColorSequence.new{
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(120,  60, 255)),
			ColorSequenceKeypoint.new(0.50, Color3.fromRGB( 55, 140, 255)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(120,  60, 255)),
		})
	else
		return
	end
	spinGradient(grad, 2.4)
	local uiStroke = stroke:FindFirstChildOfClass("UIStroke") or stroke:FindFirstChildWhichIsA("UIStroke")
	if uiStroke then pulseStroke(uiStroke, uiStroke.Thickness) end
end

local function makeTile(id: string)
	local def = ItemsCfg[id]; if not def then return end
	local t = Template:Clone()
	t.Name = id
	t.Visible = true
	t.Parent = List
	popInTile(t)
	local icon = t:FindFirstChild("Icon")
	if icon and icon:IsA("ImageLabel") then icon.Image = def.icon or "" end
	applyTileFX(t, id)
	local btn = t:FindFirstChild("TextButton") :: GuiButton
	if btn then
		wireTileButton(t, btn)
		btn.MouseButton1Click:Connect(function()
			select(id)
		end)
	end
	tiles[id] = t
	setQty(t, counts[id] or 0)
end

local function ensureTile(id: string)
	if not tiles[id] then makeTile(id) end
	return tiles[id]
end

local function passesFilter(id: string): boolean
	if curFilter == "All" then return true end
	return categoryOf(id) == curFilter
end

local function refreshFilter()
	for id, t in pairs(tiles) do
		t.Visible = passesFilter(id)
	end
	if selectedId and not passesFilter(selectedId) then select(nil) end
end

BtnAll.MouseButton1Click:Connect(function() curFilter="All";     refreshFilter() end)
BtnPot.MouseButton1Click:Connect(function() curFilter="Potions"; refreshFilter() end)
BtnCards.MouseButton1Click:Connect(function() curFilter="Cards"; refreshFilter() end)

local useDebounce = false
local function fireUse(times: number)
	if useDebounce then return end
	useDebounce = true
	task.delay(0.15, function() useDebounce = false end)
	if not selectedId then return end
	local id   = selectedId
	local have = counts[id] or 0
	if have <= 0 then return end
	local toSend = math.min(times, have)
	GameCore.Fire("BackpackService","RequestUse",{ id = id, amount = toSend })
end

Use1.MouseButton1Click:Connect(function() fireUse(1)  end)
Use10.MouseButton1Click:Connect(function() fireUse(10) end)
Use50.MouseButton1Click:Connect(function() fireUse(50) end)

UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	if not Panel.Visible then return end
	local loc = input.Position
	if not pointInside(Panel, loc.X, loc.Y) then
		select(nil)
	end
end)

local function formatTime(sec: number): string
	sec = math.max(0, math.floor(sec))
	local m = sec // 60
	local s = sec % 60
	return (m > 0) and string.format("%d:%02d", m, s) or (tostring(s).."s")
end

local function setBoosterHUDActive(icon: string?, expAt: number)
	expireAtEpoch = expAt
	if icon then BoosterIcon.Image = icon end
	BoosterHUD.Visible = true
end

local function setBoosterHUDInactive()
	BoosterHUD.Visible = false
	expireAtEpoch = 0
	TimeLeft.Text = ""
end

task.spawn(function()
	while true do
		if BoosterHUD.Visible and expireAtEpoch and expireAtEpoch > 0 then
			local remain = math.max(0, expireAtEpoch - os.time())
			TimeLeft.Text = formatTime(remain)
			if remain <= 0 then
				setBoosterHUDInactive()
			end
		end
		task.wait(0.2)
	end
end)

function C:OnRoute(route, method, payload)
	if route ~= "BackpackService" then return end

	if method == "BackpackUpdate" then
		for id, n in pairs(payload) do
			counts[id] = n
			local tile = ensureTile(id)
			if tile then setQty(tile, n) end
		end
		for id, tile in pairs(tiles) do
			if payload[id] == nil then
				counts[id] = nil
				tile.Visible = false
			end
		end
		select(selectedId)
		refreshFilter()

	elseif method == "Used" then
		if payload and payload.id == "RarityBooster" then
			GameCore.Fire("QuestService","Increment",{ statKey = "BoostersUsed", amount = 1 })
		end

	elseif method == "TriggerScan" or method == "TriggerRoll" then
		select(nil)
		if _G.UIManager then
			_G.UIManager.Close("Backpack")
		else
			Frame.Visible = false
		end
		local amt = tonumber(payload.amount or 5) or 5
		GameCore.Fire("RNGService","RequestRoll",{ amount = amt, rid = os.clock() })

	elseif method == "BoosterStatus" or method == "PotionStatus" then
		if payload.active then
			setBoosterHUDActive(payload.icon, tonumber(payload.expireAt) or 0)
		else
			setBoosterHUDInactive()
		end
	end
end

function C:Start()
	select(nil)
	refreshFilter()
	local expireAttr = tonumber(L:GetAttribute("BoosterExpire") or L:GetAttribute("LuckExpire") or 0) or 0
	if expireAttr > os.time() then
		local icon = (ItemsCfg.RarityBooster and ItemsCfg.RarityBooster.icon) or nil
		setBoosterHUDActive(icon, expireAttr)
	else
		setBoosterHUDInactive()
	end
	GameCore.Fire("BackpackService","RequestStatus",{})
end

return C
'''

# ─────────────────────────────────────────────
# 6. UpgradeController — "scans" text
# ─────────────────────────────────────────────
UPGRADE_CONTROLLER = r'''local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")

local GameCore = require(RS.Main.GameCore)
local UpgCfg   = require(RS.Main.Configs.Upgrades)

local C = { Name="UpgradeController", AutoRoutes={"UpgradeService","RNGService", "EconomyService"} }

local L  = Players.LocalPlayer
local PG = L:WaitForChild("PlayerGui")
local GUI = PG:WaitForChild("Main"):WaitForChild("Menus")
local Frame = GUI.UpgradesFrame

local Main       = Frame:WaitForChild("Main")
local Scroll     = Main.CanvasGroup.ScrollingFrame
local Template   = Scroll:FindFirstChild("Template"); if not Template then warn("Upgrades Template missing"); return end
Template.Visible = false

local Bar        = Main.UpgradeBar
local Fill       = Bar:WaitForChild("Fill")
local TickCon    = Bar:WaitForChild("UpgradeTickCon")

local PointsText     = Main:WaitForChild("PointsText")
local NotePointsText = Main:WaitForChild("NotePointsText")

local GREEN = Color3.fromRGB(60,200,80)

local PER_POINT = tonumber(UpgCfg.PointsPerRolls) or 1000

local function applyStrokeFX(stroke: UIStroke?)
	if not stroke then return end
	TweenService:Create(stroke, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Thickness = stroke.Thickness + 1 }):Play()
	stroke.Color = GREEN
end

local function _safeName(def, lvl, per)
	local n = def.name
	if type(n) == "function" then local ok, v = pcall(n, lvl, per); n = ok and v or def.name end
	return tostring(n or "Upgrade")
end
local function _safeDesc(def, lvl, per)
	local d = def.desc
	if type(d) == "function" then local ok, v = pcall(d, lvl, per); d = ok and v or "" end
	return tostring(d or "")
end

local function _updateRowText(id, lvl)
	local def = UpgCfg.Upgrades[id]; if not def then return end
	local per = tonumber(def.perLevel) or 0
	local max = tonumber(def.maxLevel) or 0
	local row = Scroll:FindFirstChild(id); if not (row and row:IsA("Frame")) then return end
	row.UpgradeNameText.Text = ("%s %d/%d"):format(_safeName(def, lvl, per), lvl, max)
	local desc = _safeDesc(def, lvl, per)
	row.DescText.Text = (desc ~= "" and desc) or ("(+%.2f per level)"):format(per)
end

local function makeUpgradeRow(upgId: string, lvl: number, pts: number)
	local def = UpgCfg.Upgrades[upgId]; if not def then return end
	local perLevel = tonumber(def.perLevel) or 0
	local maxLevel = tonumber(def.maxLevel) or 0
	local name = _safeName(def, lvl, perLevel)
	local desc = _safeDesc(def, lvl, perLevel)

	local row = Template:Clone()
	row.Name, row.Visible, row.Parent = upgId, true, Scroll
	row.UpgradeNameText.Text = ("%s %d/%d"):format(name, lvl, maxLevel)
	row.DescText.Text        = (desc ~= "" and desc) or ("(+%.2f per level)"):format(perLevel)

	local strokeHolder = row:FindFirstChild("RarityStroke")
	applyStrokeFX(strokeHolder and strokeHolder:FindFirstChildOfClass("UIStroke"))

	local function try(times)
		if (maxLevel > 0 and lvl >= maxLevel) or (pts or 0) <= 0 then return end
		GameCore.Fire("UpgradeService","RequestUpgrade",{ id = upgId, times = times })
	end
	local uc = row:FindFirstChild("UpgradesContainer")
	if uc then
		local b1, b5, b10 = uc:FindFirstChild("Use1Button"), uc:FindFirstChild("Use5Button"), uc:FindFirstChild("Use10Button")
		if b1  then b1.MouseButton1Click:Connect(function()  try(1)  end) end
		if b5  then b5.MouseButton1Click:Connect(function()  try(5)  end) end
		if b10 then b10.MouseButton1Click:Connect(function() try(10) end) end
	end
end

local function iterTicks()
	local list = {}
	for _,c in ipairs(TickCon:GetChildren()) do
		if c:IsA("Frame") then table.insert(list, c) end
	end
	table.sort(list, function(a,b) return a.Name < b.Name end)
	return list
end

local function setBar(progress: number)
	progress = math.clamp(progress, 0, 1)
	TweenService:Create(Fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.new(progress,0,1,0) }):Play()
	local ticks = iterTicks()
	local filled = math.floor(progress * #ticks + 1e-6)
	for i, tick in ipairs(ticks) do
		local on = i <= filled
		TweenService:Create(tick, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundColor3 = on and GREEN or Color3.fromRGB(60,60,60), BackgroundTransparency = on and 0 or 0.25 }
		):Play()
	end
end

local function _renderMeta(points, scansToNextVal)
	PointsText.Text     = ("You have %d Upgrade Points remaining!"):format(points or 0)
	NotePointsText.Text = ("%d scans until you earn more Upgrade Points!"):format(scansToNextVal or 0)
	local progress = 1 - ((scansToNextVal or 0) / PER_POINT)
	setBar(progress)
end

local lastPing = 0
local function pingStatus()
	local t = os.clock()
	if t - lastPing < 0.08 then return end
	lastPing = t
	GameCore.Fire("UpgradeService","RequestStatus",{})
end

function C:OnRoute(route, method, payload)
	if route == "EconomyService" and method == "RollsUpdate" then
		pingStatus()
		return
	end

	if route == "RNGService" and method == "Results" then
		pingStatus()
		return
	end

	if route ~= "UpgradeService" then return end

	if method == "UpgradesSnapshot" then
		local points      = tonumber(payload.points or 0)
		local scansToNext = tonumber(payload.rollsToNext or payload.scansToNext or 0)
		local levels      = payload.levels or {}

		_renderMeta(points, scansToNext)

		for _,c in ipairs(Scroll:GetChildren()) do
			if c:IsA("Frame") and c.Name ~= "Template" then c:Destroy() end
		end
		for id,_ in pairs(UpgCfg.Upgrades) do
			local lvl = tonumber(levels[id] or 0) or 0
			makeUpgradeRow(id, lvl, points)
		end

	elseif method == "Upgraded" then
		local id          = payload.id
		local newLevel    = tonumber(payload.level or 0)
		local points      = tonumber(payload.points or 0)
		local scansToNext = tonumber(payload.rollsToNext or payload.scansToNext or 0)

		_updateRowText(id, newLevel)
		_renderMeta(points, scansToNext)
	end
end

function C:Start()
	GameCore.Fire("UpgradeService","RequestStatus",{})
end

return C
'''

# ═══════════════════════════════════════════
content = read()

replacements = [
    ('Name = "RNGController", AutoRoutes = {"EconomyService","RNGService","MarketService","UpgradeService"}',
     RNG_CONTROLLER, "RNGController"),
    ('Name = "LevelController", AutoRoutes = { "EconomyService" }',
     LEVEL_CONTROLLER, "LevelController"),
    ('Name = "LeaderboardController", AutoRoutes = {"LeaderboardService"}',
     LEADERBOARD_CONTROLLER, "LeaderboardController"),
    ('Name = "InventoryController", AutoRoutes = {"CardService"}',
     INVENTORY_CONTROLLER, "InventoryController"),
    ('Name="BackpackController", AutoRoutes={"BackpackService"}',
     BACKPACK_CONTROLLER, "BackpackController"),
    ('Name="UpgradeController", AutoRoutes={"UpgradeService","RNGService", "EconomyService"}',
     UPGRADE_CONTROLLER, "UpgradeController"),
]

for unique_str, new_source, label in replacements:
    content = replace_cdata(content, unique_str, new_source, label)

write(content)
print("Phase 3 complete.")
