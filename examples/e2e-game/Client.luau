local Input = game:GetService("InputService")
local Run = game:GetService("RunService")
local Players = game:GetService("Players")
local Network = game:GetService("NetworkService")
local Http = game:GetService("HttpService")
local Snapshot = nil
local Gameplay = Input:AddContext("RelaySiegeWeapon", {Priority = 10})
local Shoot = Gameplay:AddAction("Shoot")
Shoot:AddBinding(Enum.UserInputType.MouseButton1)
Shoot:AddBinding(Enum.KeyCode.ButtonR1, {Device = -1})
local Interact = Gameplay:AddAction("Interact")
Interact:AddBinding(Enum.KeyCode.E)
Interact:AddBinding(Enum.KeyCode.ButtonX, {Device = -1})
local Reload = Gameplay:AddAction("Reload")
Reload:AddBinding(Enum.KeyCode.R)
local Impulse = Gameplay:AddAction("Impulse")
Impulse:AddBinding(Enum.KeyCode.P)
local Cloth = Gameplay:AddAction("Cloth")
Cloth:AddBinding(Enum.KeyCode.O)
local LastShot = -1
local LastState = Network:GetConnectionState()
local function Send(Action, Value)
    if Snapshot then game.ReplicatedStorage.Request:FireServer(Action, Snapshot.Round, Value) end
end
game.ReplicatedStorage.State.OnClientEvent:Connect(function(Encoded)
    Snapshot = Http:JSONDecode(Encoded)
    game:SetAttribute("PlayerControllerSuspended", Snapshot.Phase ~= "Active")
    game:SetAttribute("ClientSnapshot", Encoded)
end)
Interact.Pressed:Connect(function() Send("Interact") end)
Reload.Pressed:Connect(function() Send("Reload") end)
Impulse.Pressed:Connect(function() Send("Impulse") end)
Cloth.Pressed:Connect(function()
    -- Decorative local physics, not gameplay authority or network vertex state.
    game:SetAttribute("ClothReleaseRequested", true)
end)
Run.RenderStepped:Connect(function()
    if Players.LocalPlayer then game:SetAttribute("LocalUserId", Players.LocalPlayer.UserId) end
    local C = Players.LocalPlayer and Players.LocalPlayer.Character
    -- The movement lease belongs to PlayerController, not this weapon owner.
    -- InputService still supplies post-GUI/focus-cancelled values to this context.
    local Enabled = C ~= nil and C.Health > 0 and game:GetAttribute("PlayerControllerRunning") == true and not game:GetAttribute("PlayerControllerMenu") and Snapshot ~= nil and Snapshot.Phase == "Active"
    Gameplay.Enabled = Enabled
    local Request = game:GetAttribute("UIRequest")
    if Request then game:SetAttribute("UIRequest", nil); Send(Request) end
    if Enabled and Shoot:GetValue() and os.clock() - LastShot >= 0.23 then
        LastShot = os.clock()
        local Camera = game.Workspace.CurrentCamera
        if Camera then
            -- Native Node3D CFrame currently exposes matrix fields, not the
            -- stdlib CFrame directional convenience fields (GL-044).
            local Frame = Camera.CFrame
            Send("Shoot", Vector3.new(-Frame.m02, -Frame.m12, -Frame.m22).Unit)
            game:SetAttribute("LocalShot", (game:GetAttribute("LocalShot") or 0) + 1)
        end
    end
    local Current = Network:GetConnectionState()
    if Current ~= LastState then LastState = Current; game:SetAttribute("ConnectionStatus", Current) end
end)
game:SetAttribute("ClientReady", true)
