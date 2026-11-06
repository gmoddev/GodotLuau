extends Node

var Host
var Front := false

func _physics_process(_Delta: float) -> void:
    if Front: Host.PhysicsBegin = Time.get_ticks_usec()
    elif Host.Recording: Host.PhysicsDispatch.append((Time.get_ticks_usec()-Host.PhysicsBegin)/1000000.0)

func _process(_Delta: float) -> void:
    var Now := Time.get_ticks_usec()
    if Front:
        if Host.Recording: Host.ProcessFrames.append((Now-Host.LastProcess)/1000000.0)
        Host.LastProcess = Now
        Host.ProcessBegin = Now
    elif Host.Recording: Host.ProcessDispatch.append((Now-Host.ProcessBegin)/1000000.0)
