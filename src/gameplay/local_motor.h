#ifndef GL_LOCAL_MOTOR_H
#define GL_LOCAL_MOTOR_H
#include <godot_cpp/classes/character_body3d.hpp>
#include "lua.h"
using namespace godot;

// Independent local body, never a proxy for Player.Character or another body.
// Commands occupy bounded latest-wins slots and run only at the native tick.
class KinematicMotor3D : public CharacterBody3D {
    GDCLASS(KinematicMotor3D, CharacterBody3D);
    int OwnerGuard=0;
    uint64_t CameraId=0, PreviousCamera=0, CameraViewport=0, Ticks=0;
    int PreviousMouse=0;
    bool CameraLease=false, MouseLease=false, HasMove=false, HasTeleport=false;
    Vector3 MoveCommand, TeleportCommand;
    double JumpCommand=0, Yaw=0, Pitch=0;
    void ReleaseMouse();
    void RetireCamera();
protected:
    static void _bind_methods();
    void _notification(int What);
public:
    KinematicMotor3D();
    ~KinematicMotor3D();
    void AdoptOwner(lua_State* Thread);
    bool OwnerAlive() const;
    bool CanCommand() const;
    void _ready() override;
    void _physics_process(double Delta) override;
    bool SetMoveVelocity(Vector3 Velocity);
    bool Jump(double Speed);
    bool Teleport(Vector3 Position);
    bool SetViewAngles(double NextYaw, double NextPitch);
    bool AcquireCamera();
    void ReleaseCamera();
    bool CaptureMouse(bool Capture);
    bool CameraActive() const;
    double GetYaw() const { return Yaw; }
    double GetPitch() const { return Pitch; }
    int64_t GetTicks() const { return int64_t(Ticks); }
};

bool GLMotorIndex(lua_State* Thread, Node* Target, const char* Key);
bool GLMotorWrite(lua_State* Thread, Node* Target, const char* Key);
#endif
