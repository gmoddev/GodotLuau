# Luau control of Player.Character

Native Character input remains the default. Put
[PlayerController.luau](../examples/player-controller/PlayerController.luau) in
StarterPlayerScripts to opt into a semantic InputService controller for the actual
Player.Character. Do not create a KinematicMotor3D or another Character body.

```lua
local Character = game.Players.LocalPlayer.Character
Character.ControllerMode = Enum.CharacterControllerMode.Scripted
local Move = game:GetService("InputService"):AddContext("Gameplay")
    :AddAction("Move", {ValueType = Enum.InputActionValueType.Vector2})
Move:BindKeyboardVector2()
Move:BindGamepadStick(Enum.InputStick.Left, {Device = -1})

game:GetService("RunService").Stepped:Connect(function()
    if Character.ControllerInputEnabled then
        local Value = Move:GetPhysicsValue()
        Character:Move(Vector3.new(Value.X, 0, Value.Y), true)
    end
end)
```

Use the complete example for lifecycle, GUI focus and context transitions. A new
Character life needs a new controller lease; subscribe to CharacterAdded.

The supplied example also accepts the optional game attribute
`PlayerControllerSuspended`. A truthy value suspends its existing gameplay
context, neutralizes movement and releases owned capture. Clearing it requires
fresh input, like other context transitions. It defaults false and is only an
additional application pause gate, never a grant of native authority. Relay
Siege uses it for result screens; this is example integration, not a new native
Character property or another controller.

| Member | Contract |
| --- | --- |
| ControllerMode | Native = 0, Scripted = 1. Live local Client selection only. Fresh Scripted assignment replaces the lease. Not replicated/serialized. |
| ControllerActive | Read-only; this execution owner holds the current live lease. |
| ControllerInputEnabled | Read-only; current owner also passes focus, GUI, pause and native menu/free-camera admission. |
| Move(Direction, RelativeToCamera?, Sprint?) | In Scripted mode returns boolean; finite native Vector3, Y = 0, length <= 1; bool options default false. Latest sample is consumed once per physics tick. |
| Jump() | In Scripted mode returns boolean; bounded grounded request, rechecked when consumed. |
| RotateCamera(DeltaRadians) | Scripted boolean result; finite Vector2 components within [-1,1]. Existing active Character camera only; pitch remains bounded. |
| CaptureMouse(Capture) | Scripted boolean result; boolean capture, scoped cleanup for the existing active local camera. |
| ControllerMode = Native | Explicit restoration; only the current owner may stop an active lease. Dormant Scripted control may be explicitly restored. |

Rejected ownership, stale generation or unavailable command admission returns
false for commands. Invalid argument types and forbidden property writes raise
errors. Nonfinite/out-of-range command values reject without changing intent.
No direct velocity, grounded flag, physics handle, health or movement-config
authority is exposed. Existing server movement checks remain in force.

Native mode retains legacy Move/Jump behavior. Scripted Move does not persist
across physics ticks. Legacy movement/NPC entry points are unavailable while
Scripted mode owns the body, preventing competing command paths.

On controller teardown, disconnect or death, movement intent becomes neutral and
capture is released. Selection stays dormant Scripted rather than falling back to
held native hardware. New lives and clones default Native. An explicit fresh
lease or Native selection is required to resume. During GUI focus/menu suspension,
disable the gameplay context so a held pre-transition action is not reused.

The [decision](adr-013-scripted-character-control.md) records ownership and authority;
the [journal](player-controller-development.md) records actual qualification.

