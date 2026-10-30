extends SceneTree
var Game: Node
var Mode := "read"
var ExpectedHex := ""

func _initialize() -> void:
    var Args := OS.get_cmdline_user_args()
    Mode=Args[0]
    if Args.size()>1: ExpectedHex=Args[1]
    call_deferred("Run")

func Run() -> void:
    var Loaded := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    if Loaded not in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]: quit(2); return
    Game=Node.new(); Game.name="Game"; root.add_child(Game); current_scene=Game
    Game.set_meta("ExpectedHex",ExpectedHex)
    var Source := """
local Service=game:GetService('DataStoreService')
local Store=Service:GetDataStore('GL009Compat')
local Unicode=Service:GetDataStore('GL009Compat_'..utf8.char(0x96ea))
local Scoped=Service:GetDataStore('GL009CompatScope','Alias')
local Ordered=Service:GetOrderedDataStore('GL009Compat')
local function Hex(Value)
    local Parts={}
    for Index=1,#Value do Parts[Index]=string.format('%02x',string.byte(Value,Index)) end
    return table.concat(Parts)
end
"""
    if Mode=="seed":
        Source+="""
Store:SetAsync('Number',123)
Store:SetAsync('Object',{Count=19,Text='legacy',Enabled=true})
Store:SetAsync('False',false)
Store:SetAsync('UnicodeValue',utf8.char(0x96ea))
Unicode:SetAsync('Existing',17)
Scoped:SetAsync('Key',23)
Ordered:SetAsync('Rank',29)
game:SetAttribute('ObservedHex',Hex(Store:GetAsync('UnicodeValue')))
game:SetAttribute('Done',true)
"""
    else:
        Source+="""
assert(Store:GetAsync('Number')==123)
local Object=Store:GetAsync('Object')
assert(Object.Count==19 and Object.Text=='legacy' and Object.Enabled==true)
assert(Store:GetAsync('False')==false)
assert(Hex(Store:GetAsync('UnicodeValue'))==game:GetAttribute('ExpectedHex'))
assert(Unicode:GetAsync('Existing')==17)
assert(Scoped:GetAsync('Key')==23)
assert(Service:GetDataStore('GL009CompatScope_Alias'):GetAsync('Key')==23)
assert(Ordered:GetAsync('Rank')==29)
assert(Store:GetAsync('Bom').Count==31)
assert(Store:GetAsync('Missing')==nil)
game:SetAttribute('Done',true)
"""
    var Actor: Node=ClassDB.instantiate("ServerScript")
    var Code: Script=ClassDB.instantiate("LuauScript")
    Code.source_code=Source; Actor.call("set_codigo_luau",Code); Game.add_child(Actor)
    var Deadline := Time.get_ticks_msec()+20000
    while not Game.has_meta("Done") and Time.get_ticks_msec()<Deadline: await process_frame
    if not Game.has_meta("Done"): quit(1); return
    if Mode=="seed":
        var File := FileAccess.open("user://ds_GL009Compat_Bom.json",FileAccess.WRITE)
        File.store_string("\ufeff{\"Count\":31}"); File.close()
        File=FileAccess.open("user://UnrelatedSentinel.txt",FileAccess.WRITE)
        File.store_string("Preserve unrelated committed bytes"); File.close()
        File=FileAccess.open("res://seed-identity.json",FileAccess.WRITE)
        File.store_string(JSON.stringify({"Root":OS.get_user_data_dir(),"UnicodeHex":Game.get_meta("ObservedHex")})); File.close()
    Game.queue_free(); await process_frame; await process_frame
    print("[Persistence:Compatibility] PASS ",Mode)
    quit(0)
