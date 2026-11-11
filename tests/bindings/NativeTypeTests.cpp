#include "Luau/Frontend.h"
#include "Luau/ConfigResolver.h"
#include "Luau/BuiltinDefinitions.h"
#include "Luau/Error.h"
#include "Luau/Module.h"
#include "Luau/TypeArena.h"
#include <fstream>
#include <iostream>
#include <sstream>
#include <unordered_map>

struct Sources : Luau::FileResolver {
    std::unordered_map<std::string,std::string> Files;
    std::optional<Luau::SourceCode> readSource(const Luau::ModuleName& Name) override {
        auto Found=Files.find(Name);
        if (Found==Files.end()) return std::nullopt;
        return Luau::SourceCode{Found->second,Luau::SourceCode::Module};
    }
};
int main(int Count, char** Arguments) {
    if (Count!=2) return 2;
    std::ifstream Input(Arguments[1]); std::stringstream Buffer; Buffer<<Input.rdbuf();
    if (!Input || Buffer.str().empty()) return 2;
    Sources Resolver; Luau::NullConfigResolver Config;
    Config.defaultConfig.mode=Luau::Mode::Strict;
    Luau::Frontend Frontend(&Resolver,&Config);
    Luau::unfreeze(Frontend.globals.globalTypes);
    Luau::registerBuiltinGlobals(Frontend,Frontend.globals);
    auto Definition=Frontend.loadDefinitionFile(Frontend.globals,Frontend.globals.globalScope,
        Buffer.str()+"\ndeclare Parent: NativeNode\n","GodotLuauNative",false);
    if (!Definition.success) {
        for (const auto& Error:Definition.parseResult.errors) std::cerr<<Error.what()<<'\n';
        if (Definition.module) for (const auto& Error:Definition.module->errors)
            std::cerr<<Error.location.begin.line+1<<':'<<Error.location.begin.column+1<<' '<<Luau::toString(Error)<<'\n';
        std::cerr<<"[Bindings:Types] FAIL generated definitions\n"; return 1;
    }
    Luau::freeze(Frontend.globals.globalTypes);
    struct Case { const char* Name; const char* Source; bool Valid; };
    const Case Cases[]={
        {"construct and property",R"(local S=Scene.new(Parent)
local B=S:New("Button",{Text="Native",MinSize=Vector2.new(100,32)})
B.Text="Ready"
local P:boolean=S:Call(B,"IsPressed")
local M=S:New("BoxMesh",{Size=Vector3.new(2,3,4)})
S:Configure(M,{Size=Vector3.new(1,1,1)})
local V:NativeVector3=S:Get(M,"Size")
)",true},
        {"resource references",R"(local S=Scene.new(Parent)
local T=S:Load("Texture2D","res://Image.tres")
local R=S:New("TextureRect",{Texture=T,ExpandMode=Scene.Enums.TextureRect.ExpandMode.EXPAND_IGNORE_SIZE})
local W:number=S:Call(T,"GetWidth")
)",true},
        {"optional calls and typed signal",R"(local S=Scene.new(Parent)
local A=S:New("AudioStreamPlayer",{Stream=S:Tone(440,0.1)})
S:Call(A,"Play")
S:Call(A,"Play",0)
local B=S:New("CheckButton",{Text="Toggle",ToggleMode=true})
local C=S:Connect(B,"Toggled",function(Value:boolean) B.Text=tostring(Value) end)
C:Disconnect()
)",true},
        {"forbidden constructor",R"(local S=Scene.new(Parent) local O=S:New("OS",{}))",false},
        {"wrong typed property",R"(local S=Scene.new(Parent) local B=S:New("Button",{Text=42}))",false},
        {"unknown direct property",R"(local S=Scene.new(Parent) local B=S:New("Button",{}) B.Script="bad")",false},
        {"forbidden method",R"(local S=Scene.new(Parent) local B=S:New("Button",{}) S:Call(B,"set_script",nil))",false},
        {"wrong vector conversion",R"(local S=Scene.new(Parent) local N=S:New("Node3D",{}) S:Call(N,"ToGlobal",Vector2.new(1,2)))",false},
        {"wrong signal payload",R"(local S=Scene.new(Parent) local B=S:New("CheckButton",{}) S:Connect(B,"Toggled",function(Value:string) print(Value) end))",false},
        {"immutable loaded handle",R"(local S=Scene.new(Parent) local M=S:Load("Mesh","res://Mesh.tres") S:Configure(M,{Size=Vector3.new(1,1,1)}))",false},
        {"too many arguments",R"(local S=Scene.new(Parent) local B=S:New("Button",{}) S:Call(B,"IsPressed",true))",false},
    };
    int Failed=0;
    for (int Index=0;Index<int(sizeof(Cases)/sizeof(Cases[0]));++Index) {
        std::string Name="NativeCase"+std::to_string(Index);
        Resolver.Files[Name]=Cases[Index].Source;
        auto Result=Frontend.check(Name);
        bool Passed=Result.errors.empty()==Cases[Index].Valid;
        std::cout<<"[Bindings:Types] "<<(Passed?"PASS ":"FAIL ")<<Cases[Index].Name<<'\n';
        if (!Passed) {
            ++Failed;
            for (const auto& Error:Result.errors) std::cerr<<Luau::toString(Error)<<'\n';
        }
    }
    return Failed?1:0;
}
