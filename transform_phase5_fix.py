#!/usr/bin/env python3
"""Phase 5 — Fix server/client initialization race condition and add robust error handling.

The root cause of the OnClientEvent crash:
- Client's GameCore.Auto() processes controllers and calls GameCore.On(route, ...)
- GameCore.On() calls ensureRemote(route) which uses WaitForChild(name, 10)
- If server hasn't created the RemoteEvents yet, WaitForChild returns nil
- Then r.OnClientEvent:Connect(...) errors with "attempt to index nil with 'OnClientEvent'"

Fix approach:
1. Pre-create ALL RemoteEvents/RemoteFunctions in ServerGameStart BEFORE GameCore.Auto()
2. Add pcall wrapping and diagnostic prints to identify any remaining issues
3. Fix the client GameStart to be more resilient
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

local SERVICE_NAMES = {
	"DataService", "EconomyService", "RNGService", "CardService",
	"BackpackService", "LeaderboardService", "UpgradeService",
	"QuestService", "MarketService", "AudioService", "CardPetService",
	"CodesService",
}

for _, name in ipairs(SERVICE_NAMES) do
	if not GC_REMOTES:FindFirstChild(name) then
		local re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = GC_REMOTES
	end
	if not GC_REMOTES:FindFirstChild(name .. "_fn") then
		local rf = Instance.new("RemoteFunction")
		rf.Name = name .. "_fn"
		rf.Parent = GC_REMOTES
	end
end

print("[Server] RemoteEvents pre-created for", #SERVICE_NAMES, "services")

local ok1, GameCore = pcall(require, RS.Main.GameCore)
if not ok1 then warn("[Server] FATAL: GameCore failed to load:", GameCore); return end

local ok2, Promise = pcall(require, RS.Main.GameCore.Promise)
if not ok2 then warn("[Server] FATAL: Promise failed to load:", Promise); return end

local ok3, Async = pcall(require, RS.Main.GameCore.AsyncTasks)
if not ok3 then warn("[Server] FATAL: AsyncTasks failed to load:", Async); return end

local ok4, MathX = pcall(require, RS.Main.GameCore.MathX)
if not ok4 then warn("[Server] FATAL: MathX failed to load:", MathX); return end

local okPT, PingTimes = pcall(require, RS.Main.Modules.PingTimes)
if okPT then GameCore.PingTimes = PingTimes end

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

print("[Server] GameCore configured")

MathX.setGameCore(GameCore)
GameCore.AC.Start()
GameCore.AC.AttachNetGuards()

print("[Server] AC started, calling GameCore.Auto()...")

local lastReq = {}
GameCore.UseMiddleware("RNGService", function(ctx, next)
	local uid = ctx.player.UserId
	local t   = os.clock()
	if (t - (lastReq[uid] or 0)) < 0.20 then return end
	lastReq[uid] = t
	next(ctx)
end)

local autoOk, autoErr = pcall(function()
	GameCore.Auto()
end)

if autoOk then
	print("[Server] SoundScape RNG - GameCore Started successfully")
else
	warn("[Server] GameCore.Auto() FAILED:", tostring(autoErr))
	warn("[Server] Game will run with limited functionality")
end
"""


CLIENT_GAMESTART = r"""local RS = game:GetService("ReplicatedStorage")
local GameCore = require(RS.Main.GameCore)
local Promise  = require(RS.Main.GameCore.Promise)
local Async    = require(RS.Main.GameCore.AsyncTasks)
local MathX    = require(RS.Main.GameCore.MathX)

GameCore.Configure({
	Roots = {
		Services = RS.Main.Services,
		Controllers = RS.Main.Controllers,
	},
	Promise = Promise,
	Async   = Async,
})

task.spawn(function()
	local okPT, PingTimes = pcall(require, RS.Main.Modules.PingTimes)
	if okPT then GameCore.PingTimes = PingTimes end

	local ok, err = pcall(function()
		GameCore.Auto()
	end)

	if ok then
		print("[Client] GameCore Started")
	else
		warn("[Client] GameCore.Auto() error:", tostring(err))
		warn("[Client] Retrying in 2 seconds...")
		task.wait(2)
		local ok2, err2 = pcall(function()
			GameCore.Auto()
		end)
		if ok2 then
			print("[Client] GameCore Started (retry)")
		else
			warn("[Client] GameCore.Auto() retry failed:", tostring(err2))
		end
	end
end)"""


def main():
    fp = "/home/user/etwnbrbr/SoundScape_RNG.rbxlx"
    with open(fp, 'r', encoding='utf-8') as f:
        c = f.read()

    # Fix 1: Replace ServerGameStart with robust version that pre-creates RemoteEvents
    c = replace_cdata(c, '[Server] SoundScape RNG - GameCore Started', SERVERGAMESTART, "ServerGameStart")

    # Fix 2: Replace Client GameStart with retry logic
    c = replace_cdata(c, '[Client] Gamecore Started', CLIENT_GAMESTART, "ClientGameStart")

    with open(fp, 'w', encoding='utf-8') as f:
        f.write(c)
    print("Phase 5 complete.")


if __name__ == "__main__":
    main()
