#!/usr/bin/env python3
"""Phase 7 — Fix server GameCore silent startup failure.

Root cause: ServerGameStart uses warn() for FATAL error messages, but
the user has warnings filtered in Studio Output — so require failures
are invisible. Additionally, GameCore.Configure() and MathX.setGameCore()
are not wrapped in pcall, so they can crash the script silently.

Fixes:
1. Replace all warn() with print() in error paths
2. Add print() after each successful pcall(require, ...) for diagnostics
3. Wrap GameCore.Configure(), MathX.setGameCore(), and AC calls in pcall
"""

import sys

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


SERVER_GAME_START = r"""local RS          = game:GetService("ReplicatedStorage")
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
if not ok1 then print("[Server] FATAL: GameCore failed to load:", tostring(GameCore)); return end
print("[Server] GameCore loaded OK")

local ok2, Promise = pcall(require, RS.Main.GameCore.Promise)
if not ok2 then print("[Server] FATAL: Promise failed to load:", tostring(Promise)); return end
print("[Server] Promise loaded OK")

local ok3, Async = pcall(require, RS.Main.GameCore.AsyncTasks)
if not ok3 then print("[Server] FATAL: AsyncTasks failed to load:", tostring(Async)); return end
print("[Server] AsyncTasks loaded OK")

local ok4, MathX = pcall(require, RS.Main.GameCore.MathX)
if not ok4 then print("[Server] FATAL: MathX failed to load:", tostring(MathX)); return end
print("[Server] MathX loaded OK")

local okPT, PingTimes = pcall(require, RS.Main.Modules.PingTimes)
if okPT then
	GameCore.PingTimes = PingTimes
	print("[Server] PingTimes loaded OK")
else
	print("[Server] PingTimes skipped:", tostring(PingTimes))
end

local okC, errC = pcall(function()
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
end)
if not okC then print("[Server] FATAL: GameCore.Configure failed:", tostring(errC)); return end
print("[Server] GameCore configured")

local okM, errM = pcall(function()
	MathX.setGameCore(GameCore)
end)
if not okM then print("[Server] FATAL: MathX.setGameCore failed:", tostring(errM)); return end

local okAC, errAC = pcall(function()
	GameCore.AC.Start()
	GameCore.AC.AttachNetGuards()
end)
if not okAC then print("[Server] FATAL: AC start failed:", tostring(errAC)); return end

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
	print("[Server] FATAL: GameCore.Auto() FAILED:", tostring(autoErr))
	print("[Server] Game will run with limited functionality")
end
"""


def main():
    path = "SoundScape_RNG.rbxlx"
    print(f"Reading {path}...")
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    print(f"  {len(content)} chars")

    content = replace_cdata(
        content,
        '[Server] RemoteEvents pre-created for',
        SERVER_GAME_START,
        "ServerGameStart — diagnostic prints + pcall wrapping"
    )

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Wrote {len(content)} chars to {path}")
    print("Done — Phase 7 applied.")


if __name__ == "__main__":
    main()
