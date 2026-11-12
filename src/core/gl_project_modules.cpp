#include "gl_project_modules.h"
#include "luau_script.h"
#include "gl_asset.h"
#include <godot_cpp/classes/resource_loader.hpp>
#include <cstring>

using namespace godot;
Error LuauScript::_reload(bool) {
    String Path=get_path();
    if (Path.is_empty()) return OK; // Built-in resources have no file to reload.
    if (!GLProjectResourcePath(Path)) return ERR_INVALID_PARAMETER;
    Ref<FileAccess> File=FileAccess::open(Path,FileAccess::READ);
    if (File.is_null()) return ERR_CANT_OPEN;
    if (File->get_length()>16*1024*1024) return ERR_FILE_CORRUPT;
    _set_source_code(File->get_as_text()); return OK;
}
bool GLProjectModules::Resolve(lua_State* Thread,int Argument,GLModuleSource& Module) {
    if (lua_type(Thread,Argument)!=LUA_TSTRING) return false;
    size_t Bytes=0;const char* Raw=lua_tolstring(Thread,Argument,&Bytes);
    if (!Bytes || Bytes>1024 || std::memchr(Raw,0,Bytes)) return false;
    String Path=String::utf8(Raw,int(Bytes));
    if (!GLProjectResourcePath(Path) || (Path.get_extension()!="luau" && Path.get_extension()!="lua")) return false;
    std::string Key=Path.utf8().get_data();
    auto Found=Resources.find(Key);
    if (Found==Resources.end()) {
        if (Resources.size()>=64) return false;
        Ref<FileAccess> File=FileAccess::open(Path,FileAccess::READ);
        if (File.is_null() || File->get_length()>1024*1024) return false;
        File.unref();
        Ref<LuauScript> Script=ResourceLoader::get_singleton()->load(Path,"LuauScript");
        if (Script.is_null()) return false;
        Found=Resources.emplace(Key,Script).first;
    }
    Ref<LuauScript> Script=Found->second;
    if (Script.is_null() || Script->_get_source_code().utf8().length()>1024*1024) return false;
    Module.Identity=Script->get_instance_id(); Module.ResourceIdentity=Module.Identity;
    Module.Revision=Script->GetSourceRevision(); return true;
}
bool GLProjectModules::Load(GLModuleSource& Module) {
    Ref<LuauScript> Script=Object::cast_to<LuauScript>(ObjectDB::get_instance(Module.ResourceIdentity));
    if (Script.is_null() || Script->GetSourceRevision()!=Module.Revision || Script->_get_source_code().utf8().length()>1024*1024) return false;
    Module.Source=Script->_get_source_code().utf8().get_data();
    Module.ChunkName=(String("@")+Script->get_path()).utf8().get_data();return true;
}
void GLProjectModules::Retire(GLExecutionDomain& Domain) {
    for (const auto& Entry:Resources) Domain.InvalidateModule(Entry.second->get_instance_id());
}
