extends 'res://DebuggerPeer.gd'

var Reason=''

func AfterVariables() -> void:
    if Finished: return
    if not Measurements.has('ConditionalObservations'): Measurements.ConditionalObservations=[]
    Measurements.ConditionalObservations.append({'Stop':Stops,'Source':CurrentSource,'Line':CurrentLine,'Reason':Reason,'Index':Value('Index')})
    Check(Stops<Expected.size() and CurrentSource==Expected[Stops].Source and CurrentLine==Expected[Stops].Line,'Conditional source stop '+str(Stops)+' matches expected executable line; actual '+CurrentSource+':'+str(CurrentLine)+' reason '+Reason)
    if Finished: return
    if Stops==0:
        for Probe in [
            {'Line':Inputs.Lines.True,'Expression':'Index == 3'},
            {'Line':Inputs.Lines.False,'Expression':'false'},
            {'Line':Inputs.Lines.Error,'Expression':"(function() game:SetAttribute('Bypass',true) end)()"}
        ]:
            Command('Breakpoint',{'Domain':'Server','Source':CurrentSource,'Line':int(Probe.Line),'Enabled':true,'Expression':Probe.Expression})
    elif Stops==1:
        Check(Reason=='ConditionError' and Value('Index')==1,'Forbidden condition pauses with an explicit error without executing its call')
        Command('Breakpoint',{'Domain':'Server','Source':CurrentSource,'Line':int(Inputs.Lines.Error),'Enabled':false})
    elif Stops==2:
        Check(Reason=='Breakpoint' and Value('Index')==3,'True condition observes the actual live local after false visits')
        Check(Errors==0,'Closed typed conditional commands are admitted without protocol errors')
    Send('continue')
    Stops+=1

func Receive(Message: Array) -> void:
    if Message.size()==3 and Message[0]=='godotluau:debugger' and Message[2].size()==1 and Message[2][0] is Dictionary:
        var Reply: Dictionary=Message[2][0]
        if Reply.get('Event')=='Suspending': Reason=Reply.get('Reason','')
    super.Receive(Message)
