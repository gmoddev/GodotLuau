-- Independent local controller. No hardware polling or Player.Character writes.
local Input = game:GetService("InputService")
local Clock = game:GetService("RunService")
local UI = Input:AddContext("ControllerUI", {Priority = 200})
local ToggleMenu = UI:AddAction("ToggleMenu")
ToggleMenu:AddBinding(Enum.KeyCode.Escape)
ToggleMenu:AddBinding(Enum.KeyCode.ButtonStart, {Device = -1})
local Remap = UI:AddAction("RemapJump")
Remap:AddBinding(Enum.KeyCode.F6)
local Restart = UI:AddAction("RestartController")
Restart:AddBinding(Enum.KeyCode.F8)

local State = {Running = false, Menu = false, Remapped = false, Yaw = 0, Pitch = 0}
local Connections = {}

local function Capture(Enabled)
    -- Automated fixtures never grab a worker's physical mouse.
    if not game:GetAttribute("AutomatedFixture") then
        assert(State.Body:CaptureMouse(Enabled))
    end
end

local function Menu(Open)
    if not State.Running then return end
    State.Menu = Open
    State.Context.Enabled = not Open
    Capture(not Open)
    game:SetAttribute("MenuOpen", Open)
end

local function Stop()
    if not State.Running then return end
    for _, Connection in Connections do Connection:Disconnect() end
    table.clear(Connections)
    State.Body:ReleaseCamera()
    State.Body:Destroy()
    State.Context:Destroy()
    State.Running = false
    game:SetAttribute("ControllerRunning", false)
end

local function Start()
    local Context = Input:AddContext("ControllerGameplay")
    local Move = Context:AddAction("Move", {ValueType = Enum.InputActionValueType.Vector2})
    Move:BindKeyboardVector2() -- WASD; supply Up/Down/Left/Right to use arrows.
    Move:BindGamepadStick(Enum.InputStick.Left, {Device = -1, Deadzone = 0.2})
    local Look = Context:AddAction("Look", {ValueType = Enum.InputActionValueType.Vector2})
    Look:BindMouseMotion({Scale = 0.002})
    local LookStick = Context:AddAction("LookStick", {ValueType = Enum.InputActionValueType.Vector2})
    LookStick:BindGamepadStick(Enum.InputStick.Right, {Device = -1})
    local Sprint = Context:AddAction("Sprint")
    Sprint:AddBinding(Enum.KeyCode.LeftShift)
    Sprint:AddBinding(Enum.KeyCode.ButtonL3, {Device = -1})
    local Jump = Context:AddAction("Jump")
    local JumpBinding = Jump:AddBinding(State.Remapped and Enum.KeyCode.E or Enum.KeyCode.Space)
    Jump:AddBinding(Enum.KeyCode.ButtonA, {Device = -1})
    local Body = Instance.new("KinematicMotor3D", game.Workspace)
    Body.Name = "LuauController"
    assert(Body:Teleport(Vector3.new(0, 2, 5)))
    if not Body:AcquireCamera() then
        Body:Destroy()
        Context:Destroy()
        error("[Input:Example] Viewport camera is already leased")
    end
    State.Context, State.Body, State.JumpBinding = Context, Body, JumpBinding
    State.Running, State.Menu, State.Yaw, State.Pitch = true, false, 0, 0
    Capture(true)
    table.insert(Connections, Jump.Pressed:Connect(function() Body:Jump(5) end))
    table.insert(Connections, Clock.Stepped:Connect(function()
        local Value = Move:GetPhysicsValue()
        local Speed = Sprint:GetPhysicsValue() and 8 or 5
        local Cos, Sin = math.cos(State.Yaw), math.sin(State.Yaw)
        assert(Body:SetMoveVelocity(Vector3.new(
            (Value.X * Cos + Value.Y * Sin) * Speed, 0,
            (-Value.X * Sin + Value.Y * Cos) * Speed)))
    end))
    table.insert(Connections, Clock.RenderStepped:Connect(function(Delta)
        local Mouse, Stick = Look:GetValue(), LookStick:GetValue()
        State.Yaw -= Mouse.X + Stick.X * 2 * math.min(Delta, 0.1)
        State.Pitch = math.clamp(State.Pitch - Mouse.Y - Stick.Y * 2 * math.min(Delta, 0.1), -1.45, 1.45)
        assert(Body:SetViewAngles(State.Yaw, State.Pitch))
        game:SetAttribute("ControllerPosition", Body.Position)
        game:SetAttribute("ControllerGrounded", Body.Grounded)
    end))
    game:SetAttribute("MenuOpen", false)
    game:SetAttribute("ControllerRunning", true)
end

local function Rebind()
    State.Remapped = not State.Remapped
    if State.Running then State.JumpBinding.KeyCode = State.Remapped and Enum.KeyCode.E or Enum.KeyCode.Space end
    game:SetAttribute("JumpBinding", State.Remapped and "E" or "Space")
end

ToggleMenu.Pressed:Connect(function() Menu(not State.Menu) end)
Remap.Pressed:Connect(Rebind)
Restart.Pressed:Connect(function() if State.Running then Stop() else Start() end end)
-- Native GUI commands are ordinary UI actions, never a second hardware evaluator.
Clock.Heartbeat:Connect(function()
    if game:GetAttribute("ResumeRequested") then game:SetAttribute("ResumeRequested", false); Menu(false) end
    if game:GetAttribute("RemapRequested") then game:SetAttribute("RemapRequested", false); Rebind() end
    if game:GetAttribute("RestartRequested") then
        game:SetAttribute("RestartRequested", false)
        if State.Running then Stop() else Start() end
    end
end)
game:SetAttribute("JumpBinding", "Space")
Start()
