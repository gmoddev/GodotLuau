@tool
extends RefCounted

func Report(Runner, Plugin, Module: String, Member: String, Offset: int=0) -> Dictionary:
    var Submission: Dictionary=Plugin.call('QueryProject',{'Query':'Symbols' if Module.is_empty() else 'References','Module':Module,'Member':Member,'Offset':Offset})
    if Submission.get('result',ERR_UNAVAILABLE)!=OK: return Submission
    var Deadline=Time.get_ticks_msec()+30000
    while Time.get_ticks_msec()<Deadline:
        var Result: Dictionary=Plugin.call('PollProject',Submission.Generation)
        if not Result.get('Pending',false): return Result
        await Runner.get_tree().process_frame
    return {'result':ERR_TIMEOUT}

func Run(Runner,Plugin) -> void:
    var Old='local Scope=Scene.new(script.Parent)\nScope:New("Node3D",{Name="BeforeReload"})\n'
    for Name in ['ReloadA','ReloadB']:
        var InitialFile=FileAccess.open('res://'+Name+'.luau',FileAccess.WRITE)
        InitialFile.store_string(Old)
        InitialFile.close()
    var A: Script=load('res://ReloadA.luau')
    var B: Script=load('res://ReloadB.luau')
    Runner.Check(Plugin.call('PreviewScript',A).get('Passed',false),'Reload baseline constructs actual native preview')
    var ReloadFile=FileAccess.open('res://ReloadA.luau',FileAccess.WRITE)
    var Next=Old.replace('BeforeReload','AfterReload')
    ReloadFile.store_string(Next)
    ReloadFile.close()
    ReloadFile=FileAccess.open('res://ReloadB.luau',FileAccess.WRITE)
    ReloadFile.store_string('local = invalid syntax')
    ReloadFile.close()
    Runner.Check(Plugin.call('ReloadScripts',[A,B])==ERR_PARSE_ERROR and A.source_code==Old and B.source_code==Old,'Failed batch reload preserves every prior source generation')
    ReloadFile=FileAccess.open('res://ReloadB.luau',FileAccess.WRITE)
    ReloadFile.store_string(Next)
    ReloadFile.close()
    Runner.Check(Plugin.call('ReloadScripts',[A,B])==OK and A.source_code==Next and B.source_code==Next,'Corrected batch reload publishes exact validated source snapshots')
    for Cycle in range(6):
        Runner.Check(Plugin.call('PreviewScript',A).get('Passed',false),'Preview reconstructs after validated reload cycle '+str(Cycle))
        Runner.Check(Plugin.call('ReloadScripts',[A,B])==OK,'Repeated unchanged reload succeeds without new generation '+str(Cycle))
    Plugin.call('StopPreview')
    var Sources={
        'IndexModule.luau':'export type Product = {Value: number}\nlocal function Build(Value: number): Product return {Value=Value} end\nreturn {Build=Build}\n',
        'IndexOther.luau':'return {Build=function() return 55 end}\n',
        'IndexConsumer.luau':"local M=require('res://IndexModule.luau')\nM.Build()\nlocal Alias=M.Build\nAlias()\n",
        'IndexUnrelated.luau':"local M=require('res://IndexOther.luau')\nM.Build()\n",
        'IndexShadow.luau':"local M=require('res://IndexModule.luau')\ndo local M={Build=function() end}; M.Build() end\n",
        'IndexAssigned.luau':"local M=require('res://IndexModule.luau')\nM={Build=function() end}\nM.Build()\n"
    }
    for Path in Sources:
        var File=FileAccess.open('res://'+Path,FileAccess.WRITE)
        File.store_string(Sources[Path]);File.close()
    var First: Dictionary=await Report(Runner,Plugin,'res://IndexModule.luau','Build')
    var Uses: Array=First.get('References',[])
    Runner.Check(First.get('result',ERR_UNAVAILABLE)==OK and not First.get('Truncated',true) and Uses.size()==3,'Project index resolves exact static module and function aliases while excluding shadowed reassigned and unrelated imports')
    Runner.Check(Uses.all(func(Use): return Use.Path=='res://IndexConsumer.luau' and Use.Revision>0 and Use.Line>0 and Use.Column>0),'Project references retain snapshot revision and locations')
    var Second: Dictionary=await Report(Runner,Plugin,'res://IndexModule.luau','Build')
    Runner.Check(Second.get('ParsedFiles',-1)==0 and Second.get('CachedFiles',0)>0 and Second.get('References',[]).size()==3,'Repeated project query reuses unchanged parsed source results')
    var Navigation: Dictionary=await Report(Runner,Plugin,'','')
    var Documents: Array=Navigation.get('Documents',[])
    Runner.Measurements.ProjectNavigation={'Result':Navigation.get('result',ERR_UNAVAILABLE),'Files':Navigation.get('ScannedFiles',0),'Matches':Navigation.get('Matches',0),'More':Navigation.get('More',false),'Paths':Documents.map(func(Item): return Item.Path)}
    var Offset=256
    var Page=Navigation
    while Page.get('More',false) and Offset<8192:
        Page=await Report(Runner,Plugin,'','',Offset)
        for Document in Page.get('Documents',[]):
            var Existing=Documents.filter(func(Item): return Item.Path==Document.Path)
            if Existing.is_empty(): Documents.append(Document)
            else: Existing[0].Entries.append_array(Document.Entries)
        Offset+=256
    var Module=Documents.filter(func(Item): return Item.Path=='res://IndexModule.luau')
    var Consumer=Documents.filter(func(Item): return Item.Path=='res://IndexConsumer.luau')
    Runner.Check(Navigation.get('result',ERR_UNAVAILABLE)==OK and Module.size()==1 and Consumer.size()==1,'Project navigation shares the bounded cached module scan')
    if Module.size()==1 and Consumer.size()==1:
        var Entries: Array=Module[0].Entries
        Runner.Check(Entries.any(func(Item): return Item.Kind=='ExportedType' and Item.Name=='Product' and Item.Line==1) and Entries.any(func(Item): return Item.Kind=='Function' and Item.Name=='Build' and Item.Line==2),'Project index records actual Luau type and function definitions')
        Runner.Check(Entries.any(func(Item): return Item.Kind=='LocalReference' and Item.Name=='Build' and Item.get('DefinitionLine')==2),'Lexical local references retain their exact definition location')
        Runner.Check(Consumer[0].Entries.any(func(Item): return Item.Kind=='Import' and Item.get('Target')=='res://IndexModule.luau') and Consumer[0].Entries.any(func(Item): return Item.Kind=='ImportedMember' and Item.Name=='Build'),'Project import graph and static member locations preserve module identity')
    var Resource: Script=load('res://IndexConsumer.luau')
    EditorInterface.edit_script(Resource,-1,0,true)
    for Index in range(5): await Runner.get_tree().process_frame
    var Code=EditorInterface.get_script_editor().get_current_editor().get_base_editor() as CodeEdit
    if Code:
        Code.text=Sources['IndexConsumer.luau']+'local Another=M.Build\n'
        var Changed: Dictionary=await Report(Runner,Plugin,'res://IndexModule.luau','Build')
        Runner.Check(Changed.get('References',[]).size()==4 and Changed.get('ParsedFiles',0)==1,'Project index refreshes the active unsaved editor buffer without recompiling unrelated modules')
        Runner.Check(FileAccess.get_file_as_string('res://IndexConsumer.luau')==Sources['IndexConsumer.luau'],'Reference indexing preserves saved source')
        Code.text=Sources['IndexConsumer.luau']
        Runner.Measurements.ProjectIndex={'ColdMicroseconds':First.get('Microseconds',0),'WarmMicroseconds':Second.get('Microseconds',0),'ChangedMicroseconds':Changed.get('Microseconds',0),'NavigationMicroseconds':Navigation.get('Microseconds',0),'Files':First.get('ScannedFiles',0),'Truncated':Changed.get('Truncated',true)}
    else: Runner.Check(false,'Project index can observe the actual Luau CodeEdit')
