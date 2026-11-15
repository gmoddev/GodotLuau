#include "gl_native_editor_plugin.h"
#include "gl_project_indexer.h"
#include "gl_execution_domain.h"
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/os.hpp>

godot::Dictionary GLNativeEditorPlugin::PollProject(int64_t Generation) {
    using namespace godot;
    Dictionary Report;Report["result"]=ERR_UNAVAILABLE;Report["Pending"]=false;
    Report["Stale"]=Generation>0 && uint64_t(Generation)!=ProjectGeneration;
    if(!Engine::get_singleton()->is_editor_hint() || GLExecutionDomain::IsExecuting() || OS::get_singleton()->get_thread_caller_id()!=OS::get_singleton()->get_main_thread_id() || Generation<=0 || uint64_t(Generation)!=ProjectGeneration || !ProjectIndex)return Report;
    auto Result=ProjectIndex->Poll(uint64_t(Generation));Report["result"]=OK;Report["Generation"]=Generation;Report["Pending"]=!Result;
    if(!Result)return Report;
    auto Convert=[](const GLProjectIndexer::Entry& Value) {
        Dictionary Item;Item["Path"]=String::utf8(Value.Path.c_str());Item["Name"]=String::utf8(Value.Name.c_str());Item["Kind"]=String::utf8(Value.Kind.c_str());
        Item["Target"]=String::utf8(Value.Target.c_str());Item["Type"]=String::utf8(Value.Type.c_str());Item["Line"]=Value.Line;Item["Column"]=Value.Column;
        Item["DefinitionLine"]=Value.DefinitionLine;Item["DefinitionColumn"]=Value.DefinitionColumn;Item["Revision"]=int64_t(Value.Revision);return Item;
    };
    Array Entries,Diagnostics,Documents;Dictionary Groups;
    for(const auto& Value:Result->Entries) {
        Dictionary Item=Convert(Value);Entries.push_back(Item);String Path=String::utf8(Value.Path.c_str());
        Array Group=Groups.get(Path,Array());Group.push_back(Item);Groups[Path]=Group;
    }
    for(const auto& Value:Result->Diagnostics)Diagnostics.push_back(Convert(Value));
    auto Paths=Groups.keys();for(int Index=0;Index<Paths.size();++Index) {
        Dictionary Document;Document["Path"]=Paths[Index];Document["Entries"]=Groups[Paths[Index]];Document["Complete"]=!Result->Incomplete && !Result->More;Documents.push_back(Document);
    }
    Dictionary Dependencies,Revisions;
    for(const auto& Pair:Result->Dependencies) {Array Values;for(const auto& Value:Pair.second)Values.push_back(String::utf8(Value.c_str()));Dependencies[String::utf8(Pair.first.c_str())]=Values;}
    for(const auto& Pair:Result->Revisions)Revisions[String::utf8(Pair.first.c_str())]=String::utf8(Pair.second.c_str());
    Report["References"]=Entries;Report["Entries"]=Entries;Report["Documents"]=Documents;Report["Diagnostics"]=Diagnostics;
    Report["Dependencies"]=Dependencies;Report["Revisions"]=Revisions;Report["Error"]=String::utf8(Result->Error.c_str());
    Report["ScannedFiles"]=int64_t(Result->Files);Report["ParsedFiles"]=int64_t(Result->Parsed);Report["CachedFiles"]=int64_t(Result->Cached);Report["BytesRead"]=int64_t(Result->Bytes);
    Report["Microseconds"]=int64_t(Result->Microseconds);Report["InvalidatedFiles"]=int64_t(Result->Invalidated);Report["Matches"]=int64_t(Result->Matches);
    Report["More"]=Result->More;Report["Truncated"]=Result->Incomplete || Result->More;Report["Incomplete"]=Result->Incomplete;
    Report["ColumnEncoding"]="UTF-8 bytes";Report["Scope"]="Incremental worker index; static imports, lexical bindings and bounded Luau types. Dynamic expressions remain unresolved.";
    return Report;
}
