extends 'res://DebuggerPeer.gd'

var PreviousNonce=''
var AwaitingAttach=false
var AdmissionRequest=0

func AfterVariables() -> void:
    if Finished: return
    Check(Stops<Expected.size() and CurrentSource==Expected[Stops].Source and CurrentLine==Expected[Stops].Line,'Reattached source stop belongs to its expected admitted generation')
    if Finished: return
    if Stops==0:
        PreviousNonce=Nonce
        Command('Attach',{'Domain':'All'}) # Must reject while suspended/attached.
        Command('Detach',{'Domain':'All'})
        AwaitingAttach=true
    else:
        Check(Nonce!=PreviousNonce and Value('Value')==42 and Errors>=2,'Reattachment rotates session identity, rejects stale commands and inspects the fresh generation')
    Send('continue')
    Stops+=1

func Receive(Message: Array) -> void:
    var StartNew=false
    if Message.size()==3:
        if Message[0]=='debug_exit' and AwaitingAttach:
            AwaitingAttach=false
            Command('Attach',{'Domain':'All'})
        if Message[0]=='godotluau:debugger' and Message[2].size()==1 and Message[2][0] is Dictionary:
            var Reply: Dictionary=Message[2][0]
            if Reply.get('Event')=='Hello' and not PreviousNonce.is_empty() and Reply.get('Session')!=PreviousNonce and Nonce==PreviousNonce:
                RequestId=0
                Nonce=Reply.Session
                Command('Breakpoint',{'Domain':'Server','Source':'res://DebuggerReattachNew.luau','Line':int(Inputs.NewLine),'Enabled':true})
                AdmissionRequest=RequestId
                Command('Status',{'Session':PreviousNonce})
            if Reply.get('Event')=='Reply' and AdmissionRequest>0 and Reply.get('Request')==AdmissionRequest:
                StartNew=true
    super.Receive(Message)
    if StartNew and not Finished:
        var File=FileAccess.open(Inputs.Coordination+'/new-generation.json.pending',FileAccess.WRITE)
        File.store_string('{}')
        File.close()
        Check(DirAccess.rename_absolute(Inputs.Coordination+'/new-generation.json.pending',Inputs.Coordination+'/new-generation.json')==OK,'Fresh generation starts only after native breakpoint admission')
