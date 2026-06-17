#!/usr/bin/env python3
"""Phase 6 — Fix roll result display.

Issues found:
1. animateMain/animateQuick close overlay immediately after animation with NO delay
   for user to see the result — the card flashes for <0.2 seconds then disappears
2. All card images are "rbxassetid://0" (placeholders) so nothing is visible
3. safeScan timeout of 2 seconds is too short
4. No card name is shown during result display

Fixes:
1. Add 1.8s display delay before closeOverlay in animateMain
2. Add 0.6s display delay before closeOverlay in animateQuick
3. Show card name + artist text on the result display
4. Generate a colored placeholder image from rarity when image is blank
5. Increase safeScan timeout to 6 seconds
6. Add diagnostic prints throughout the roll flow for debugging
"""

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


RNGCONTROLLER = r"""local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local RS = game:GetService("ReplicatedStorage")

local GameCore = require(RS.Main.GameCore)
local Cards    = require(RS.Main.Configs.Cards)
local Admin    = require(RS.Main.Configs.Admin)
local Monetization = require(RS.Main.Configs.Monetization)
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
	AutoScan  = { rolls = 150,   gamepassId = (Monetization.Gamepasses.AutoRoll  and Monetization.Gamepasses.AutoRoll.id  or 0) },
	QuickScan = { rolls = 10000, gamepassId = (Monetization.Gamepasses.QuickRoll and Monetization.Gamepasses.QuickRoll.id or 0) },
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
	local cName = cfg and cfg.name or (result.name or result.collectibleId or result.id or "???")
	local fType = result.fragmentType or "Fragment"
	local fRarity = result.fragmentRarity or result.rarity or "Common"
	return cName, fType, fRarity
end

local function rarityColor(r: string): Color3
	return RARITY_COLORS[r] or Color3.fromRGB(180,180,180)
end

local function isPlaceholderImage(img: string?): boolean
	if not img or img == "" then return true end
	if img == "rbxassetid://0" or img == "rbxassetid://000" then return true end
	return false
end

local _nameLabel: TextLabel? = nil
local function getNameLabel(): TextLabel
	if _nameLabel and _nameLabel.Parent then return _nameLabel end
	local lbl = MainRoll:FindFirstChild("CardNameLabel")
	if lbl then
		_nameLabel = lbl
		return lbl
	end
	lbl = Instance.new("TextLabel")
	lbl.Name = "CardNameLabel"
	lbl.AnchorPoint = Vector2.new(0.5, 0)
	lbl.Position = UDim2.new(0.5, 0, 0.05, 0)
	lbl.Size = UDim2.new(0.9, 0, 0.25, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextColor3 = Color3.new(1,1,1)
	lbl.TextScaled = true
	lbl.TextStrokeTransparency = 0.4
	lbl.TextStrokeColor3 = Color3.new(0,0,0)
	lbl.ZIndex = 10
	lbl.Parent = MainRoll
	_nameLabel = lbl
	return lbl
end

local _artistLabel: TextLabel? = nil
local function getArtistLabel(): TextLabel
	if _artistLabel and _artistLabel.Parent then return _artistLabel end
	local lbl = MainRoll:FindFirstChild("ArtistNameLabel")
	if lbl then
		_artistLabel = lbl
		return lbl
	end
	lbl = Instance.new("TextLabel")
	lbl.Name = "ArtistNameLabel"
	lbl.AnchorPoint = Vector2.new(0.5, 0)
	lbl.Position = UDim2.new(0.5, 0, 0.30, 0)
	lbl.Size = UDim2.new(0.8, 0, 0.15, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.Gotham
	lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
	lbl.TextScaled = true
	lbl.TextStrokeTransparency = 0.6
	lbl.TextStrokeColor3 = Color3.new(0,0,0)
	lbl.ZIndex = 10
	lbl.Parent = MainRoll
	_artistLabel = lbl
	return lbl
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
	task.delay(6.0, function()
		if awaiting then
			awaiting = false
			warn("[RNGController] Roll timed out after 6 seconds")
			closeOverlay(function()
				setBusy(false); animating = false; kickAuto()
			end)
		end
	end)
	print("[RNGController] Firing RequestRoll amount=", amount)
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
	local artist = (cfg and cfg.artist) or result.artist or ""

	print("[RNGController] Showing result:", cName, fType, fRarity)

	local nameLabel = getNameLabel()
	nameLabel.Text = cName
	nameLabel.TextColor3 = color
	nameLabel.Visible = true

	local artistLbl = getArtistLabel()
	artistLbl.Text = artist
	artistLbl.Visible = artist ~= ""

	if isPlaceholderImage(image) then
		MainImage.Image = ""
		MainImage.BackgroundColor3 = color
		MainImage.BackgroundTransparency = 0.15
	else
		MainImage.Image = image
		MainImage.BackgroundTransparency = 1
	end

	MainImage.ImageColor3 = color
	MainImage.ImageTransparency = 1
	MainRarity.Text = fType .. " — " .. fRarity
	MainRarity.TextColor3 = color

	if MainGrad then
		local rcfg = Cards.Rarity[fRarity]
		if rcfg and rcfg.uiGradient then
			MainGrad.Color = rcfg.uiGradient.Color
			MainGrad.Transparency = rcfg.uiGradient.Transparency
		end
	end

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

	local ok, shime = pcall(Shime.new, MainImage, 1, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut)
	if ok and shime then pcall(function() shime:Play() end) end

	tween(s, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Scale = 1.00 }):Play()
	tween(MainImage, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		Size = UDim2.fromOffset(244, 292)
	}):Play()
	task.wait(0.12)

	burstConfetti(MainRoll, fRarity)

	task.wait(1.8)

	nameLabel.Visible = false
	artistLbl.Visible = false
	if isPlaceholderImage(image) then
		MainImage.BackgroundTransparency = 1
	end

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
	QuickRoll.Position    = UDim2.fromScale(0.5, 0.5)

	local cName, fType, fRarity = fragmentLabel(result)
	local cfg = Cards.ById and Cards.ById[result.collectibleId or result.id]
	local image = (cfg and cfg.image) or ""
	local color = rarityColor(fRarity)

	if isPlaceholderImage(image) then
		QuickImage.Image = ""
		QuickImage.BackgroundColor3 = color
		QuickImage.BackgroundTransparency = 0.15
	else
		QuickImage.Image = image
		QuickImage.BackgroundTransparency = 1
	end

	QuickImage.ImageColor3 = color
	QuickImage.ImageTransparency = 1
	QuickRarity.Text = cName .. " · " .. fType .. " — " .. fRarity
	QuickRarity.TextColor3 = color

	if QuickGrad then
		local rcfg = Cards.Rarity[fRarity]
		if rcfg and rcfg.uiGradient then
			QuickGrad.Color = rcfg.uiGradient.Color
			QuickGrad.Transparency = rcfg.uiGradient.Transparency
		end
	end

	local s = QuickRoll:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", QuickRoll)
	s.Scale = 0.9
	tween(s, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.05 }):Play()
	tween(QuickImage, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		ImageTransparency = 0
	}):Play()
	task.wait(0.14)

	tween(s, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Scale = 1.00 }):Play()
	task.wait(0.08)

	burstConfetti(QuickRoll, fRarity)

	task.wait(0.6)

	if isPlaceholderImage(image) then
		QuickImage.BackgroundTransparency = 1
	end

	closeOverlay(function()
		setBusy(false)
		animating = false
		kickAuto()
	end)
end

local function clearMulti()
	for _,c in ipairs(MultiRoll:GetChildren()) do
		if c:IsA("Frame") and c.Name ~= "Template" then c:Destroy() end
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
			local color = rarityColor(res.fragmentRarity or res.rarity or "Common")
			if isPlaceholderImage((cfg and cfg.image) or "") then
				img.Image = ""
				img.BackgroundColor3 = color
				img.BackgroundTransparency = 0.2
			else
				img.Image = (cfg and cfg.image) or ""
				img.BackgroundTransparency = 1
			end
			img.ImageColor3 = color
		end
		local rar = f:FindFirstChild("RarityText")
		if rar and rar:IsA("TextLabel") then
			local cName = res.name or (res.collectibleId or res.id or "???")
			rar.Text = cName .. " · " .. (res.fragmentType or "Fragment") .. " — " .. (res.fragmentRarity or "Common")
		end
		f.Parent = MultiRoll
	end
	task.delay(3.0, function()
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
		print("[RNGController] Received Results from server")
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

		print("[RNGController] Result count:", #list)

		if #list > 1 then
			showMulti(list)
		elseif #list == 1 then
			local last = list[1]
			print("[RNGController] Displaying:", last.id or last.collectibleId, last.fragmentType, last.fragmentRarity)
			if quickOn then animateQuick(last) else animateMain(last) end
		else
			warn("[RNGController] Empty Results payload:", tostring(payload))
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
		print("[RNGController] Fully loaded, scan button active")
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
		kickAuto()
	end)

	print("[RNGController] Started, buttons connected")
end

return C"""


def main():
    fp = "/home/user/etwnbrbr/SoundScape_RNG.rbxlx"
    with open(fp, 'r', encoding='utf-8') as f:
        c = f.read()

    c = replace_cdata(c, 'Name = "RNGController"', RNGCONTROLLER, "RNGController")

    with open(fp, 'w', encoding='utf-8') as f:
        f.write(c)
    print("Phase 6 complete — roll result display fixed.")


if __name__ == "__main__":
    main()
