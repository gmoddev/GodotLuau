-- > GodotLuau — PimpoliDev
-- Character V2 local presentation hook. Native code handles keyboard, gamepad,
-- mobile movement, camera-relative steering, jumping and the 1.5 sprint factor.
-- Configure WalkSpeed/JumpPower/Gravity from ServerScript or a Character template.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer
if not Player then return end

local Character
local function BindCharacter(Value)
    Character = Value
    if Character and Character:IsA("Character") then
        Character.CameraMode = 1 -- Character follow style: fixed/smooth/combined.
        print("[Character:Controller] Character V2 controller ready")
    end
end
Player.CharacterAdded:Connect(BindCharacter)
BindCharacter(Player.Character)

RunService.Heartbeat:Connect(function(Delta)
    if not Character or Character.IsDead then return end
    -- Add local presentation here. Health/configuration belong to ServerScript.
    -- Character:Move(Direction) can request continuous owner-local movement.
end)
