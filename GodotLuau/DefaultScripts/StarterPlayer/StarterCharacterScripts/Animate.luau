-- > GodotLuau — PimpoliDev
-- Animate.lua — Animaciones del personaje. Se clona al nacer (script.Parent = el jugador).
-- /// Character animations. Cloned onto the character on spawn (script.Parent = the player).

local RunService = game:GetService("RunService")

local Character = script.Parent
local State = Character:IsA("Character") and Character or (Character:IsA("RobloxPlayer2D") and Character:FindFirstChild("Humanoid"))
if not State then
    dwarn("[Character:Animation] Character state unavailable")
    return
end

dprint("[Character:Animation] Sistema de animacion listo")

-- ══ TU CÓDIGO DE ANIMACIÓN AQUÍ /// YOUR ANIMATION CODE HERE ══
-- Descomenta para reaccionar a eventos del Character: /// Uncomment to react to Character events:

-- State.Died:Connect(function()
--     print("[Character:Animation] El personaje murio!")
-- end)

-- State.HealthChanged:Connect(function(newHP)
--     if newHP < State.MaxHealth * 0.3 then
--         print("[Character:Animation] Salud baja!")
--     end
-- end)

-- RunService.Heartbeat:Connect(function(dt)
--     -- Logica de animacion por frame
-- end)
-- ═════════════════════════════════════════════════════════════════
