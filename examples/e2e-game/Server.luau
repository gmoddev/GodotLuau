-- Authoritative game rules. No client supplies damage, position, health or rewards.
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local Http = game:GetService("HttpService")
local Store = game:GetService("DataStoreService"):GetDataStore("RelaySiegeV1")
local Remotes = game.ReplicatedStorage
local Request = Remotes.Request
local State = Remotes.State
local Terminals = {Vector3.new(-14, 0, -10), Vector3.new(14, 0, -10), Vector3.new(0, 0, -20)}
local Records = {}
local Bots = {}
local Round = 0
local Phase = "Loading"
local TimeLeft = 150
local Reactor = 300
local Kills = 0
local Relays = {false, false, false}
local Progress = {Rounds = 0, Wins = 0, Credits = 0, Receipts = {}}
local SaveState = "Loading progress"
local SaveBusy = false
local Result = nil
local SpawnClock = 0
local NextBot = 0
local TickClock = 0
local SnapshotClock = 0
local Started = false

local function Finite(N)
    return type(N) == "number" and N == N and math.abs(N) < 1000000
end
local function Point(V)
    return {X = V.X, Y = V.Y, Z = V.Z}
end
local function Character(Player)
    local C = Player.Character
    if C and C.Health > 0 then return C end
    return nil
end
local function Save()
    if SaveBusy or not Result or SaveState == "Saved" then return end
    SaveBusy = true
    SaveState = "Saving"
    local Pending = Result
    local Ok, Value = pcall(function()
        return Store:UpdateAsync("arena", function(Old)
            Old = Old or {Rounds = 0, Wins = 0, Credits = 0, Receipts = {}}
            assert(type(Old) == "table" and type(Old.Rounds) == "number" and type(Old.Wins) == "number", "Invalid saved progress")
            Old.Receipts = Old.Receipts or {}
            for _, Id in ipairs(Old.Receipts) do if Id == Pending.Id then return Old end end
            Old.Rounds += 1
            Old.Wins += Pending.Won and 1 or 0
            Old.Credits = (Old.Credits or 0) + Pending.Credits
            table.insert(Old.Receipts, Pending.Id)
            if #Old.Receipts > 32 then table.remove(Old.Receipts, 1) end
            return Old
        end)
    end)
    if Ok then Progress = Value; SaveState = "Saved"
    else SaveState = "Save failed; retry before another round"; warn("[Game:Persistence] " .. tostring(Value)) end
    SaveBusy = false
end
local function Finish(Won)
    if Phase ~= "Active" then return end
    Phase = Won and "Victory" or "Defeat"
    Result = {Id = Http:GenerateGUID(false), Won = Won, Credits = (Won and 50 or 10) + Kills * 2}
    SaveState = "Pending"
    task.spawn(Save)
end
local function StartRound()
    if SaveBusy or (Result and SaveState ~= "Saved") then return end
    Round += 1
    Phase = "Active"
    Reactor = 300
    TimeLeft = 150
    Kills = 0
    Relays = {false, false, false}
    Bots = {}
    Result = nil
    SpawnClock = 3
    SaveState = "Progress loaded"
    for _, P in ipairs(Players:GetPlayers()) do
        if P.Character and P.Character.Health <= 0 then P:LoadCharacter() end
        local C = Character(P)
        if C then C.Health = C.MaxHealth; C:PivotTo(CFrame.new(0, 3, 14)) end
        local R = Records[P.UserId]
        if R then R.Ammo = 12; R.Reload = 0 end
    end
end
local function Register(P)
    if Records[P.UserId] then return end
    Records[P.UserId] = {Player = P, Ammo = 12, Reload = 0, LastShot = -10, LastRequest = -10, Deaths = 0, Dead = false}
end
local function Publish()
    local List = {}
    for _, P in ipairs(Players:GetPlayers()) do
        Register(P)
        local R = Records[P.UserId]
        local C = P.Character
        List[#List + 1] = {Id = P.UserId, Name = P.Name, Health = C and C.Health or 0, Ammo = R.Ammo, Reload = R.Reload > 0, Deaths = R.Deaths}
    end
    local Drones = {}
    for _, B in ipairs(Bots) do Drones[#Drones + 1] = {Id = B.Id, Position = Point(B.Position), Health = B.Health} end
    local Snapshot = {Version = 1, Round = Round, Phase = Phase, Time = math.ceil(TimeLeft), Reactor = math.ceil(Reactor), Kills = Kills,
        Relays = Relays, Bots = Drones, Players = List, Shots = game:GetAttribute("ServerShots") or 0, Progress = {Rounds = Progress.Rounds, Wins = Progress.Wins, Credits = Progress.Credits},
        Save = SaveState, Reward = Result and Result.Credits or 0}
    local Encoded = Http:JSONEncode(Snapshot)
    game:SetAttribute("ServerSnapshot", Encoded)
    State:FireAllClients(Encoded)
end
Request.OnServerEvent:Connect(function(P, Action, Epoch, Value)
    if game:GetAttribute("AutomatedFixture") then
        local Count = game:GetAttribute("DebugRequests") or 0
        if Count < 12 then
            game:SetAttribute("DebugRequests", Count + 1)
            print("[Game:Combat] request", Action, Epoch, typeof(Value))
        end
    end
    if type(Action) ~= "string" or Epoch ~= Round then return end
    local R = Records[P.UserId]
    if not R or R.Player ~= P then return end
    local Now = os.clock()
    if Now - R.LastRequest < 0.035 then return end
    R.LastRequest = Now
    if Action == "Again" then
        if Phase == "Victory" or Phase == "Defeat" then StartRound() end
        return
    end
    if Action == "Save" then task.spawn(Save); return end
    if Phase ~= "Active" then return end
    local C = Character(P)
    if not C then return end
    if Action == "Reload" then
        if R.Ammo < 12 and R.Reload == 0 then R.Reload = 1.3 end
    elseif Action == "Interact" then
        for I, Position in ipairs(Terminals) do
            if not Relays[I] and (C.Position - Position).Magnitude < 6 then
                Relays[I] = true
                C:Heal(20)
                break
            end
        end
    elseif Action == "Impulse" then
        local Crate = game.Workspace:FindFirstChild("ImpulseCrate")
        if Crate and (C.Position - Crate.Position).Magnitude < 9 then Crate:ApplyImpulse(Vector3.new(0, 80, 100)) end
    elseif Action == "Shoot" then
        if typeof(Value) ~= "Vector3" or not Finite(Value.X) or not Finite(Value.Y) or not Finite(Value.Z) then return end
        if math.abs(Value.Magnitude - 1) > 0.01 or Now - R.LastShot < 0.22 or R.Reload > 0 or R.Ammo == 0 then return end
        R.LastShot = Now
        R.Ammo -= 1
        -- Query policy belongs to authoritative Luau, independently of the
        -- scene's cooperative player collision choice. Ignore current Character
        -- subtrees; retain all other geometry for eye-origin world occlusion.
        local Origin = C.Position + Vector3.new(0, 1.5, 0)
        local Ignored = {}
        for _, Participant in ipairs(Players:GetPlayers()) do
            if Participant.Character then Ignored[#Ignored + 1] = Participant.Character end
        end
        local Params = RaycastParams.new()
        Params.FilterType = Enum.RaycastFilterType.Exclude
        Params.FilterDescendantsInstances = Ignored
        Params.MaxDistance = 70
        local Hit = game.Workspace:Raycast(Origin, Value, Params)
        local Limit = Hit and Hit.Distance or 70
        if game:GetAttribute("AutomatedFixture") and (game:GetAttribute("RaySamples") or 0) < 6 then
            game:SetAttribute("RaySamples", (game:GetAttribute("RaySamples") or 0) + 1)
            local B = Bots[1]
            print("[Game:Ray]", tostring(Origin), tostring(Value), Limit, Hit and Hit.Instance and Hit.Instance.Name or "clear", B and tostring(B.Position) or "none")
        end
        local Selected = nil
        for _, B in ipairs(Bots) do
            local Offset = B.Position - Origin
            local Along = Offset:Dot(Value)
            if Along > 0 and Along < Limit and (Offset - Value * Along).Magnitude < 1.2 then Selected = B; Limit = Along end
        end
        if Selected then
            Selected.Health -= 35
            if Selected.Health <= 0 then
                for I, B in ipairs(Bots) do if B == Selected then table.remove(Bots, I); break end end
                Kills += 1
            end
        end
        game:SetAttribute("ServerShots", (game:GetAttribute("ServerShots") or 0) + 1)
    end
    if Relays[1] and Relays[2] and Relays[3] and Kills >= 6 then Finish(true) end
end)

Players.PlayerAdded:Connect(Register)
Players.PlayerRemoving:Connect(function(P) Records[P.UserId] = nil end)
Players.RespawnTime = 2
for _, P in ipairs(Players:GetPlayers()) do Register(P) end
game:BindToClose(function() Save() end)

task.spawn(function()
    local Ok, Value = pcall(function() return Store:GetAsync("arena") end)
    if not Ok then
        Phase = "StorageError"; SaveState = "Cannot read progress; restart after correcting storage"
        warn("[Game:Persistence] " .. tostring(Value)); Publish(); return
    end
    if Value ~= nil then Progress = Value end
    Started = true
    StartRound()
    game:SetAttribute("ServerReady", true)
    print("[Game:Rules] Ready", Progress.Rounds, Progress.Wins)
end)
Run.Heartbeat:Connect(function(Delta)
    if not Started then return end
    TickClock += math.min(Delta, 0.2)
    SnapshotClock += Delta
    if TickClock < 0.1 then return end
    local Step = math.min(TickClock, 0.2)
    TickClock = 0
    local Live = Players:GetPlayers()
    for _, P in ipairs(Live) do
        Register(P)
        local R = Records[P.UserId]
        local C = P.Character
        if C ~= R.Character then
            R.Character = C; R.Dead = false; R.Ammo = 12; R.Reload = 0
            R.SpawnUntil = os.clock() + 3
            if C then C.WalkSpeed = 10; C.JumpPower = 14 end
        end
        if C and C.Health <= 0 and not R.Dead then R.Deaths += 1; R.Dead = true end
        if R.Reload > 0 then R.Reload = math.max(0, R.Reload - Step); if R.Reload == 0 then R.Ammo = 12 end end
    end
    if Phase == "Active" and #Live > 0 then
        TimeLeft = math.max(0, TimeLeft - Step)
        SpawnClock += Step
        if SpawnClock >= 4 and #Bots < 6 then
            SpawnClock = 0
            NextBot += 1
            local X = NextBot % 2 == 0 and -18 or 18
            Bots[#Bots + 1] = {Id = NextBot, Position = Vector3.new(X, 1.5, -18 + (NextBot % 4) * 8), Health = 60, Attack = 0}
        end
        for _, B in ipairs(Bots) do
            local Target = Vector3.new(0, 1.5, 0)
            local Victim = nil
            local VictimRecord = nil
            local Distance = 10
            for _, P in ipairs(Live) do
                local C = Character(P)
                if C then
                    local D = (C.Position - B.Position).Magnitude
                    if D < Distance then Victim = C; VictimRecord = Records[P.UserId]; Distance = D; Target = C.Position end
                end
            end
            local Direction = Vector3.new(Target.X - B.Position.X, 0, Target.Z - B.Position.Z)
            local StopDistance = Victim and 2 or 4
            if Direction.Magnitude > StopDistance then B.Position += Direction.Unit * Step * 2.5 end
            B.Attack = math.max(0, B.Attack - Step)
            if Direction.Magnitude < (Victim and 3 or 5) and B.Attack == 0 then
                B.Attack = 1.3
                if Victim then
                    if os.clock() >= (VictimRecord.SpawnUntil or 0) then Victim:TakeDamage(8) end
                else Reactor = math.max(0, Reactor - 5) end
            end
        end
        for _, P in ipairs(Live) do
            local C = Character(P)
            if C then
                local Pos = C.Position
                if Pos.Y < -6 then C:TakeDamage(100) end
                -- Clearly marked red strip pulses every other two seconds.
                if math.abs(Pos.X) < 3 and Pos.Z < -6 and Pos.Z > -12 and math.floor(os.clock() / 2) % 2 == 0 then C:TakeDamage(12 * Step) end
            end
        end
        if TimeLeft <= 0 or Reactor <= 0 then Finish(false) end
    end
    if SnapshotClock >= 0.2 then SnapshotClock = 0; Publish() end
end)
