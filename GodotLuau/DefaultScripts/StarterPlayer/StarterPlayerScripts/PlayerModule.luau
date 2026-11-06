-- > GodotLuau — PimpoliDev
-- PlayerModule.lua — LocalScript — StarterPlayerScripts
-- Cerebro del jugador: carga los módulos de Modules/ y los une. Se clona al
-- jugador al nacer (script.Parent = el jugador).
-- /// Player brain: loads the modules in Modules/ and wires them. Cloned onto
-- /// the player on spawn (script.Parent = the player).

local RunService = game:GetService("RunService")

-- This engine template is cloned under the Character with its Modules folder.
local Character = script.Parent
local State = Character:IsA("Character") and Character or (Character:IsA("RobloxPlayer2D") and Character:FindFirstChild("Humanoid"))

if not State then
    dwarn("[Character:PlayerModule] Character state unavailable")
    return
end

-- Cargar los módulos (movimiento, cámara, chat) desde Modules/.
-- /// Load the modules (movement, camera, chat) from Modules/.
local ControlModule = require(script.Parent.Modules.ControlModule)
local CameraModule  = require(script.Parent.Modules.CameraModule)
local ChatModule    = require(script.Parent.Modules.ChatModule)

-- Arrancar cada módulo. /// Start each module.
ControlModule:Initialize()
CameraModule:Apply()
ChatModule:Initialize()

-- El menú de Escape lo dibuja el MOTOR (nativo). Modules/Menu es solo un punto
-- de extensión opcional; el pcall evita fallar si no existe.
-- /// The Escape menu is drawn by the ENGINE (native). Modules/Menu is just an
-- /// optional hook; the pcall avoids errors if it isn't there.
pcall(function()
    local Menu = require(script.Parent.Modules.Menu)
    Menu.Init(game:GetService("Players").LocalPlayer)
end)

-- Pasar la velocidad y el salto del ControlModule al Character.
-- /// Copy the ControlModule's walk speed and jump power to the Character.
-- 3D movement configuration is granted by the native Server authority.
-- Existing 2D controller bindings keep their separate contract.
if not Character:IsA("Character") then
    State.WalkSpeed = ControlModule.WalkSpeed
    State.JumpPower = ControlModule.JumpPower
end

dprint("[Character:PlayerModule] Jugador listo! Speed=" .. ControlModule.WalkSpeed)

State.Died:Connect(function()
    dprint("[Character:PlayerModule] El personaje ha muerto.")
end)

-- Cada frame: el ControlModule calcula la velocidad (sprint suave) y la aplica.
-- /// Each frame: ControlModule computes the speed (smooth sprint) and applies it.
RunService.Heartbeat:Connect(function(dt)
    if State.Health <= 0 then return end

    ControlModule:Update(dt)
    local speed = ControlModule:GetCurrentSpeed()
    if not Character:IsA("Character") and math.abs(State.WalkSpeed - speed) > 0.01 then
        State.WalkSpeed = speed
    end

    -- ══ TU CÓDIGO POR FRAME AQUÍ /// YOUR PER-FRAME CODE HERE ══
    -- local x, z = ControlModule:GetMoveVector()   -- dirección del teclado /// keyboard direction
    -- local st, stMax = ControlModule:GetStamina() -- estamina actual /// current stamina
    -- if ChatModule:IsOpen() then ... end
    -- ══════════════════════════════════════════════════════════
end)
