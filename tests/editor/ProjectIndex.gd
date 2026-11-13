@tool
extends RefCounted

func Run(Runner,Plugin) -> void:
    var Sources={
        'IndexModule.luau':'return {Build=function() return 54 end}\n',
        'IndexOther.luau':'return {Build=function() return 55 end}\n',
        'IndexConsumer.luau':"local M=require('res://IndexModule.luau')\nM.Build()\nlocal Alias=M.Build\nAlias()\n",
        'IndexUnrelated.luau':"local M=require('res://IndexOther.luau')\nM.Build()\n",
        'IndexShadow.luau':"local M=require('res://IndexModule.luau')\ndo local M={Build=function() end}; M.Build() end\n",
        'IndexAssigned.luau':"local M=require('res://IndexModule.luau')\nM={Build=function() end}\nM.Build()\n"
    }
    for Path in Sources:
        var File=FileAccess.open('res://'+Path,FileAccess.WRITE)
        File.store_string(Sources[Path]);File.close()
    var First: Dictionary=Plugin.call('IndexProject','res://IndexModule.luau','Build')
    var Uses: Array=First.get('References',[])
    Runner.Check(First.get('result',ERR_UNAVAILABLE)==OK and not First.get('Truncated',true) and Uses.size()==3,'Project index resolves exact static module and function aliases while excluding shadowed reassigned and unrelated imports')
    Runner.Check(Uses.all(func(Use): return Use.Path=='res://IndexConsumer.luau' and Use.SourceSHA256.length()==64),'Project references retain source identity and locations')
    var Second: Dictionary=Plugin.call('IndexProject','res://IndexModule.luau','Build')
    Runner.Check(Second.get('ParsedFiles',-1)==0 and Second.get('CachedFiles',0)>0 and Second.get('References',[]).size()==3,'Repeated project query reuses unchanged parsed source results')
    var Script: Script=load('res://IndexConsumer.luau')
    EditorInterface.edit_script(Script,-1,0,true)
    for Index in range(5): await Runner.get_tree().process_frame
    var Code=EditorInterface.get_script_editor().get_current_editor().get_base_editor() as CodeEdit
    if Code:
        Code.text=Sources['IndexConsumer.luau']+'local Another=M.Build\n'
        var Changed: Dictionary=Plugin.call('IndexProject','res://IndexModule.luau','Build')
        Runner.Check(Changed.get('References',[]).size()==4 and Changed.get('ParsedFiles',0)==1,'Project index refreshes the active unsaved editor buffer without recompiling unrelated modules')
        Runner.Check(FileAccess.get_file_as_string('res://IndexConsumer.luau')==Sources['IndexConsumer.luau'],'Reference indexing preserves saved source')
        Code.text=Sources['IndexConsumer.luau']
        Runner.Measurements.ProjectIndex={'ColdMicroseconds':First.get('Microseconds',0),'WarmMicroseconds':Second.get('Microseconds',0),'ChangedMicroseconds':Changed.get('Microseconds',0),'Files':First.get('ScannedFiles',0),'Truncated':Changed.get('Truncated',true)}
    else: Runner.Check(false,'Project index can observe the actual Luau CodeEdit')
