extends RefCounted

# Execute the shipped template in the real Server domain. The fixture preparer
# also requires its disk source and compiled fallback text to match exactly.
func Run(Host: SceneTree, Game: Node) -> void:
    var Runner = Host
    var Players := Game.get_node_or_null("Players")
    var OwnPlayers := Players == null
    if OwnPlayers:
        Players = ClassDB.instantiate("Players")
        Players.name = "Players"
        Players.set("CharacterAutoLoads", false)
        Game.add_child(Players)
    var Victim: Node = ClassDB.instantiate("RBXCharacter")
    Victim.name = "TemplateVictim"
    Game.add_child(Victim)
    var Source: Script = load("res://DefaultGameManager.luau")
    var Manager: Node = Runner.CreateScript("ServerScript", "DefaultGameManager", Source.source_code + """
assert(game.TemplateVictim.Health == 100)
game.TemplateVictim:TakeDamage(5)
assert(game.TemplateVictim.Health == 95)
game:SetAttribute('DefaultManagerReady', true)
""", Game)
    if not await Runner.Until("DefaultManagerReady"): return
    Runner.Check(Game.get_node("ReplicatedStorage").get_node_or_null("DamageEvent") == null, "Default GameManager publishes no unconfigured damage endpoint")
    var Client: Node = Runner.CreateScript("LocalScript", "DefaultDamageRequests", """
local Victim = game.TemplateVictim
for _, Payload in ipairs({{'TemplateVictim', 999999}, {Victim, 35}, {{Target = 'TemplateVictim'}, -1}}) do
    local Accepted = pcall(function()
        game.ReplicatedStorage.DamageEvent:FireServer(Payload[1], Payload[2])
    end)
    assert(not Accepted, 'Default client-selected damage route remains available')
end
Victim:TakeDamage(10)
Victim.Health = 1
assert(Victim.Health == 95, 'Client mutated authoritative health')
game:SetAttribute('DefaultDamageRejected', true)
""", Game)
    await Runner.Until("DefaultDamageRejected")
    Runner.Check(Victim.call("get_health") == 95.0, "Default damage requests preserve health; trusted Server damage remains supported")
    Manager.queue_free()
    Client.queue_free()
    Victim.queue_free()
    if OwnPlayers: Players.queue_free()
    await Host.process_frame
    await Host.process_frame
    if not Runner.Failed: print("[Runtime:DefaultScripts] PASS")
