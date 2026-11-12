-- GameManager.lua — ServerScript
-- El cerebro del servidor: jugadores, eventos remotos y rondas.
-- TODO lo que pase aqui es autoridad del servidor (anti-exploit).
local Players    = game:GetService("Players")

dprint("[Server] GameManager iniciado!")

-- ── Jugadores: entrada y salida ───────────────────────────────────
Players.PlayerAdded:Connect(function(player)
    dprint("[Server] + " .. player.Name .. " entro a la partida")
end)

Players.PlayerRemoving:Connect(function(player)
    dprint("[Server] - " .. player.Name .. " salio de la partida")
end)

-- Combat is game-specific; this template publishes no damage request endpoint.
-- Before accepting attack intent, implement server-owned weapon state, cooldowns,
-- hit/range checks and target eligibility. The server determines damage and target.
-- A client-selected name/object or clamped amount does not authorize a hit.

-- ── Sistema de rondas (esqueleto) ─────────────────────────────────
local ROUND_TIME = 120  -- segundos por ronda

task.spawn(function()
    while true do
        dprint("[Server] Ronda nueva! (" .. ROUND_TIME .. "s)")
        task.wait(ROUND_TIME)
        dprint("[Server] Fin de la ronda.")
        task.wait(5)  -- intermedio entre rondas
    end
end)

dprint("[Server] Juego listo!")
