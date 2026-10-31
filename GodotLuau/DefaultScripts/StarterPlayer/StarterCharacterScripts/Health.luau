-- > GodotLuau — PimpoliDev
-- Health.lua — ServerScript — StarterCharacterScripts
-- Regenera la vida con el tiempo. Se clona al personaje al nacer (script.Parent = el jugador).
-- /// Regenerates health over time. Cloned onto the character on spawn (script.Parent = the player).

local RunService = game:GetService("RunService")

local Character = script.Parent
local State = Character:IsA("Character") and Character or (Character:IsA("RobloxPlayer2D") and Character:FindFirstChild("Humanoid"))
if not State then
    dwarn("[Character:Health] Character state unavailable")
    return
end

dprint("[Character:Health] Regeneracion activa: " .. script.Parent.Name)

-- La regeneración empieza REGEN_DELAY s tras el ÚLTIMO daño (recibir daño reinicia el contador).
-- /// Regen starts REGEN_DELAY s after the LAST hit (taking damage resets the timer).
local REGEN_DELAY = 3.0    -- s sin daño para regenerar /// seconds without damage before regen
local REGEN_RATE  = 0.01   -- fracción de MaxHealth por segundo (1%) /// fraction of MaxHealth per second (1%)

local last_health = State.Health
local since_damage = REGEN_DELAY  -- permite regenerar desde el inicio /// allow regen from the start

State.HealthChanged:Connect(function(newHP)
    if newHP < last_health then
        since_damage = 0.0  -- recibió daño → reinicia el contador /// took damage → reset the timer
    end
    last_health = newHP
end)

State.Died:Connect(function()
    dprint("[Character:Health] " .. script.Parent.Name .. " ha muerto.")
end)

-- Cada frame: si pasó el retardo y falta vida, sube un poco hacia MaxHealth.
-- /// Each frame: if the delay passed and health is missing, ramp up toward MaxHealth.
RunService.Heartbeat:Connect(function(dt)
    since_damage = since_damage + dt
    if since_damage < REGEN_DELAY then return end
    if State.Health > 0 and State.Health < State.MaxHealth then
        local nuevo = State.Health + State.MaxHealth * REGEN_RATE * dt
        State.Health = math.min(State.MaxHealth, nuevo)
        last_health = State.Health
    end
end)
