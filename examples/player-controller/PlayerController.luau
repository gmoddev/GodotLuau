-- Put this LocalScript in StarterPlayerScripts. It uses the existing Character body.
local Input = game:GetService("InputService")
local Run = game:GetService("RunService")
local Players = game:GetService("Players")
local Network = game:GetService("NetworkService")
local Player = Players.LocalPlayer
assert(Player, "[Character:Example] PlayerController requires Client execution")

local UI = Input:AddContext("PlayerControllerUI", {Priority = 200})
local Gameplay = Input:AddContext("PlayerControllerGameplay")
local Move = Gameplay:AddAction("Move", {ValueType = Enum.InputActionValueType.Vector2})
Move:BindKeyboardVector2()
Move:BindGamepadStick(Enum.InputStick.Left, {Device = -1})
local Sprint = Gameplay:AddAction("Sprint")
Sprint:AddBinding(Enum.KeyCode.LeftShift)
Sprint:AddBinding(Enum.KeyCode.ButtonL3, {Device = -1})
local Jump = Gameplay:AddAction("Jump")
local JumpBinding = Jump:AddBinding(Enum.KeyCode.Space)
Jump:AddBinding(Enum.KeyCode.ButtonA, {Device = -1})
local MouseLook = Gameplay:AddAction("MouseLook", {ValueType = Enum.InputActionValueType.Vector2})
MouseLook:BindMouseMotion({Scale = 0.0022})
local PadLook = Gameplay:AddAction("PadLook", {ValueType = Enum.InputActionValueType.Vector2})
PadLook:BindGamepadStick(Enum.InputStick.Right, {Device = -1})
local Capture = Gameplay:AddAction("Capture")
Capture:AddBinding(Enum.UserInputType.MouseButton2)
local MenuAction = UI:AddAction("Menu")
MenuAction:AddBinding(Enum.KeyCode.Escape)
MenuAction:AddBinding(Enum.KeyCode.ButtonStart, {Device = -1})
local RemapAction = UI:AddAction("Remap")
RemapAction:AddBinding(Enum.KeyCode.F6)
local ReplaceAction = UI:AddAction("Replace")
ReplaceAction:AddBinding(Enum.KeyCode.F8)
local NativeAction = UI:AddAction("Native")
NativeAction:AddBinding(Enum.KeyCode.F9)

local Connections = {}
local Retired = false
local function Connect(Signal, Callback)
    local Connection = Signal:Connect(Callback)
    table.insert(Connections, Connection)
end
local Retire
local Current = nil
local StepConnection = nil
local Wanted = true
local MenuOpen = false
local Remapped = false
local LastNetworkState = Network:GetConnectionState()

local function Detach(RestoreNative)
    local Old = Current
    Current = nil
    if StepConnection then StepConnection:Disconnect(); StepConnection = nil end
    Gameplay.Enabled = false
    if Old then
        -- Character departure or another controller can retire this exact lease.
        pcall(function()
            Old:CaptureMouse(false)
            if RestoreNative then Old.ControllerMode = Enum.CharacterControllerMode.Native end
        end)
    end
    game:SetAttribute("PlayerControllerRunning", false)
end

Retire = function()
    if Retired then return end
    Retired = true
    Detach(false)
    for _, Connection in ipairs(Connections) do Connection:Disconnect() end
    table.clear(Connections)
    UI:Destroy()
    Gameplay:Destroy()
end

local function Attach(Character)
    if Retired then return end
    -- Initial native PlayerAdded can announce the already-bound Character later.
    -- Keep its live lease/context rather than canceling a held semantic action.
    if Current == Character and Current and Current.ControllerActive then return end
    Detach(false)
    if not Wanted or not Character or Character.Health <= 0 then return end
    Character.ControllerMode = Enum.CharacterControllerMode.Scripted
    Current = Character
    Gameplay.Enabled = false
    StepConnection = Run.Stepped:Connect(function()
        if not Current then return end
        if not Current.ControllerActive then
            if Current.Health > 0 and Network:GetConnectionState() == LastNetworkState then Retire()
            else Detach(false) end
            return
        end
        local Enabled = not MenuOpen and not game:GetAttribute("PlayerControllerSuspended") and Current.ControllerInputEnabled
        if Gameplay.Enabled ~= Enabled then
            Gameplay.Enabled = Enabled
            Current:Move(Vector3.new())
            if not Enabled then Current:CaptureMouse(false) end
            return -- do not reuse a sample from before this context transition
        end
        if not Enabled then return end
        local Value = Move:GetPhysicsValue()
        assert(Current:Move(Vector3.new(Value.X, 0, Value.Y), true, Sprint:GetPhysicsValue()))
    end)
    game:SetAttribute("PlayerControllerRunning", true)
end

local function SetMenu(Open)
    MenuOpen = Open
    Gameplay.Enabled = false
    if Current then Current:CaptureMouse(false) end
    game:SetAttribute("PlayerControllerMenu", Open)
end
local function Remap()
    Remapped = not Remapped
    JumpBinding.KeyCode = Remapped and Enum.KeyCode.E or Enum.KeyCode.Space
    game:SetAttribute("PlayerControllerJumpBinding", Remapped and "E" or "Space")
end
local function Replace()
    Detach(true)
    Wanted = true
    Attach(Player.Character)
    game:SetAttribute("PlayerControllerReplacements", (game:GetAttribute("PlayerControllerReplacements") or 0) + 1)
end
local function ToggleNative()
    Wanted = not Wanted
    if Wanted then Attach(Player.Character) else Detach(true) end
end

Connect(Jump.Pressed, function()
    if Current and Current.ControllerActive and not MenuOpen then Current:Jump() end
end)
Connect(Capture.Pressed, function()
    if Current and Current.ControllerActive and not MenuOpen and not game:GetAttribute("AutomatedFixture") then
        Current:CaptureMouse(true)
    end
end)
Connect(Capture.Released, function()
    if Current and Current.ControllerActive then Current:CaptureMouse(false) end
end)
Connect(MenuAction.Pressed, function() SetMenu(not MenuOpen) end)
Connect(RemapAction.Pressed, Remap)
Connect(ReplaceAction.Pressed, Replace)
Connect(NativeAction.Pressed, ToggleNative)
Connect(Player.CharacterAdded, Attach)
Connect(Player.CharacterRemoving, function(Character)
    if Current == Character then Detach(false) end
end)

Connect(Run.RenderStepped, function(Delta)
    local NetworkState = Network:GetConnectionState()
    if NetworkState ~= LastNetworkState then
        LastNetworkState = NetworkState
        if NetworkState == "Connected" or NetworkState == "Server" then
            Attach(Player.Character) -- acquire a new lease from the new native transport
        else
            Detach(false) -- disconnect never falls back to held hardware
        end
    end
    -- Optional native UI buttons in the runnable example.
    if game:GetAttribute("PlayerControllerResumeRequested") then
        game:SetAttribute("PlayerControllerResumeRequested", false); SetMenu(false)
    end
    if game:GetAttribute("PlayerControllerRemapRequested") then
        game:SetAttribute("PlayerControllerRemapRequested", false); Remap()
    end
    if game:GetAttribute("PlayerControllerReplaceRequested") then
        game:SetAttribute("PlayerControllerReplaceRequested", false); Replace()
    end
    if not Current or not Current.ControllerActive or MenuOpen or game:GetAttribute("PlayerControllerSuspended") or not Current.ControllerInputEnabled then return end
    local Pad = PadLook:GetValue()
    local Mouse = Capture:GetValue() and MouseLook:GetValue() or Vector2.new()
    Current:RotateCamera(Mouse + Pad * (1.8 * math.min(Delta, 0.1)))
end)

game:SetAttribute("PlayerControllerJumpBinding", "Space")
game:SetAttribute("PlayerControllerMenu", false)
if LastNetworkState ~= "Connecting" then Attach(Player.Character) end
