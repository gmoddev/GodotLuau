#include "luau_class_identity.h"

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/string.hpp>
#include <cstring>

using namespace godot;

// ── ClassName / IsA estilo Roblox ────────────────────────────────────────────
// Devuelve el nombre de clase Roblox a partir de la clase Godot interna.
String GetLuauClassName(Object* n) {
    if (!n) return "Instance";
    String c = n->get_class();
    struct M { const char* g; const char* r; };
    static const M map[] = {
        {"RobloxPart","Part"},{"Folder","Folder"},{"Humanoid","Humanoid"},{"Humanoid2D","Humanoid"},
        {"RobloxPlayer","Player"},{"RobloxPlayer2D","Player"},
        {"OmniLight3D","PointLight"},{"SpotLight3D","SpotLight"},{"DirectionalLight3D","DirectionalLight"},
        {"RemoteEventNode","RemoteEvent"},{"RemoteFunctionNode","RemoteFunction"},{"BindableEventNode","BindableEvent"},
        {"RobloxSound","Sound"},{"RobloxSoundGroup","SoundGroup"},{"RobloxTween","Tween"},{"TweenService","TweenService"},
        {"ScreenGui","ScreenGui"},{"RobloxFrame","Frame"},{"RobloxTextLabel","TextLabel"},
        {"RobloxTextButton","TextButton"},{"RobloxTextBox","TextBox"},{"RobloxImageLabel","ImageLabel"},
        {"RobloxScrollingFrame","ScrollingFrame"},{"ServerScript","Script"},{"LocalScript","LocalScript"},
        {"ModuleScript","ModuleScript"},{"RobloxTool","Tool"},{"ClickDetector","ClickDetector"},
        {"ProximityPrompt","ProximityPrompt"},{"SpawnLocation","SpawnLocation"},{"BillboardGui","BillboardGui"},
        {"SurfaceGui","SurfaceGui"},{"Motor6D","Motor6D"},{"AnimationObject","Animation"},{"AnimationTrack","AnimationTrack"},
        {"RobloxWorkspace","Workspace"},{"RobloxWorkspace2D","Workspace"},{"RobloxChat","TextChatService"},
        {"RobloxTerrain","Terrain"},{"RobloxValue","NumberValue"},{"PlayerObject","Player"},
        {"BodyVelocity","BodyVelocity"},{"BodyPosition","BodyPosition"},{"BodyForce","BodyForce"},
        {"BodyAngularVelocity","BodyAngularVelocity"},{"BodyGyro","BodyGyro"},
        {"WeldConstraint","WeldConstraint"},{"HingeConstraint","HingeConstraint"},
        {"BallSocketConstraint","BallSocketConstraint"},{"RodConstraint","RodConstraint"},{"SpringConstraint","SpringConstraint"},
        {nullptr,nullptr}
    };
    for (int i = 0; map[i].g; i++) if (c == map[i].g) return map[i].r;
    // Servicios / nodos no mapeados conservan su nombre (Players, Lighting, ReplicatedStorage...)
    return c;
}

// IsA estilo Roblox: nombre exacto + jerarquía pragmática + compat con clase Godot.
bool IsLuauClass(Object* n, const char* q) {
    if (!n || !q) return false;
    if (strcmp(q, "Instance") == 0) return true;          // todo es Instance
    const CharString ClassName = GetLuauClassName(n).utf8();
    const char* rc = ClassName.get_data();
    if (strcmp(rc, q) == 0) return true;
    if (strcmp(rc, "Part") == 0 && (strcmp(q,"BasePart")==0 || strcmp(q,"PVInstance")==0)) return true;
    bool gui = (strcmp(rc,"Frame")==0||strcmp(rc,"TextLabel")==0||strcmp(rc,"TextButton")==0||
                strcmp(rc,"TextBox")==0||strcmp(rc,"ImageLabel")==0||strcmp(rc,"ScrollingFrame")==0);
    if (gui && (strcmp(q,"GuiObject")==0 || strcmp(q,"GuiBase2d")==0)) return true;
    if ((strcmp(rc,"Script")==0||strcmp(rc,"LocalScript")==0||strcmp(rc,"ModuleScript")==0)
        && strcmp(q,"LuaSourceContainer")==0) return true;
    // Compat: aceptar también el nombre de clase Godot (IsA("RobloxPart"), IsA("Node")...)
    if (n->is_class(q)) return true;
    return false;
}
