#include "gl_asset.h"
#include <godot_cpp/classes/resource_uid.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <filesystem>
#include <vector>
#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

// Gameplay has a project-resource capability, not a host-file capability.
// ResourceLoader and serialized dependencies remain trusted engine/project
// content: this check is not an OS sandbox against concurrent project writers.
bool GLProjectResourcePath(String& Path) {
    if (Path.is_empty() || Path.length()>4096) return false;
    for (int Index=0;Index<Path.length();++Index)
        if (Path[Index]<32 || Path[Index]==127 || Path[Index]=='\\') return false;
    if (Path.begins_with("uid://")) {
        auto Uids=ResourceUID::get_singleton();
        int64_t Identity=Uids->text_to_id(Path);
        if (!Uids->has_id(Identity)) return false;
        Path=Uids->get_id_path(Identity);
    }
    if (!Path.begins_with("res://") || Path.length()>4096) return false;
    PackedStringArray Parts=Path.substr(6).split("/",true);
    for (const String& Part:Parts) {
        if (Part.is_empty() || Part=="." || Part==".." || Part.ends_with(".") || Part.ends_with(" ") || Part.contains(":")) return false;
    }
    std::filesystem::path Root=std::filesystem::u8path(ProjectSettings::get_singleton()->globalize_path("res://").utf8().get_data());
    auto Current=Root.root_path();
    std::vector<std::filesystem::path> Components;
    for (const auto& Part:Root.relative_path()) Components.push_back(Part);
    for (const String& Part:Parts) Components.push_back(std::filesystem::u8path(Part.utf8().get_data()));
    for (const auto& Part:Components) {
        Current/=Part;
#ifdef _WIN32
        DWORD Attributes=GetFileAttributesW(Current.c_str());
        if (Attributes!=INVALID_FILE_ATTRIBUTES && (Attributes&FILE_ATTRIBUTE_REPARSE_POINT)) return false;
        if (Attributes==INVALID_FILE_ATTRIBUTES && GetLastError()!=ERROR_FILE_NOT_FOUND && GetLastError()!=ERROR_PATH_NOT_FOUND) return false;
        if (Attributes!=INVALID_FILE_ATTRIBUTES && !(Attributes&FILE_ATTRIBUTE_DIRECTORY)) {
            std::error_code Error;
            if (std::filesystem::hard_link_count(Current,Error)!=1 || Error) return false;
        }
#else
        std::error_code Error;
        auto Status=std::filesystem::symlink_status(Current,Error);
        if (std::filesystem::is_symlink(Status) || (Error && Error!=std::errc::no_such_file_or_directory)) return false;
        if (std::filesystem::is_regular_file(Status) && (std::filesystem::hard_link_count(Current,Error)!=1 || Error)) return false;
#endif
    }
    return true;
}
