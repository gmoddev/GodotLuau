"""Execute the published migration examples with the real native HttpService."""
import hashlib
import json
from pathlib import Path
import time
from HttpFixtureServer import Serve


def Snippets(Root):
    Result = {}
    for Name, File, Marker in [
        ('Http', 'backend/README.md', 'HttpServiceCaller'),
        ('Json', 'newdocs/httpservice-api.md', 'HttpServiceJsonCaller'),
    ]:
        Text = (Root / File).read_text(encoding='utf-8')
        Prefix = '<!-- ' + Marker + ' -->\n```lua\n'
        if Text.count(Prefix) != 1:
            raise ValueError('Missing/ambiguous published example: ' + File)
        Result[Name] = Text.split(Prefix)[1].split('\n```', 1)[0]
    return Result


def Qualify(Args, Output, Environment):
    from RunQualification import Prepare, Start, Check
    Root = Path(__file__).resolve().parents[2]
    Published = Snippets(Root)
    Hashes = {Name: hashlib.sha256(Value.encode()).hexdigest() for Name, Value in Published.items()}
    JsonChecks = '''
assert(DecodeSettings('{"Enabled":false}').Enabled == false)
assert(DecodeSettings('{"Enabled":true}').Enabled == true)
for _, Body in {'', 'not-json', '{"Enabled":', string.rep(' ', 1024*1024+1)} do
    local Value, Error = DecodeSettings(Body)
    assert(Value == nil and Error == 'invalid-json')
end
for _, Body in {'null', 'false', '0', '[]', '{}', '{"Enabled":null}', '{"Enabled":"false"}'} do
    local Value, Error = DecodeSettings(Body)
    assert(Value == nil and Error == 'invalid-settings')
end
local Cycle = {}; Cycle.Self = Cycle
for _, Value in {Cycle, function() end, string.rep('x', 1024*1024)} do
    local Body, Error = EncodePayload(Value)
    assert(Body == nil and Error == 'invalid-payload')
end
assert(EncodePayload({}) == '[]' and EncodePayload(Http:JSONDecode('{}')) == '{}')
assert(EncodePayload(Http.JSONNull) == 'null')
assert(DecodeSettings(EncodePayload({Enabled=false})).Enabled == false)
game:SetAttribute('CallersDone', true)
'''
    Results = []
    for Case in ['status', 'empty', 'denied']:
        Project = Output / Case
        Prepare(Project, Args.extension)
        ActorEnvironment = dict(Environment)
        for Name in ['APPDATA', 'LOCALAPPDATA', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME']:
            Directory = Project / 'profile' / Name
            Directory.mkdir(parents=True)
            ActorEnvironment[Name] = str(Directory)
        State = None
        Label = 'callers-' + Case
        try:
            with Serve() as (State, Origin):
                GetUrl = Origin + ('/no-content' if Case == 'empty' else '/ok')
                RequestUrl = Origin + ('/no-content' if Case == 'empty' else '/status')
                if Case == 'denied':
                    GetUrl = State.Origins['Denied'] + '/forbidden/get'
                    RequestUrl = State.Origins['Denied'] + '/forbidden/request'
                Http = Published['Http']
                for Original, Replacement in [('https://api.github.com/zen', GetUrl), ('http://127.0.0.1:7350/', RequestUrl)]:
                    if Http.count('"' + Original + '"') != 1: raise ValueError('Example endpoint changed')
                    Http = Http.replace('"' + Original + '"', '"' + Replacement + '"')
                Checks = {
                    'status': "assert(GetOk and GetResult == 'ok' and RequestOk and not Result.Success and Result.StatusCode == 418 and Result.Body == 'teapot')",
                    'empty': "assert(GetOk and GetResult == '' and RequestOk and Result.Success and Result.StatusCode == 204 and Result.Body == '')",
                    'denied': "assert(not GetOk and type(GetResult) == 'string' and not RequestOk and type(Result) == 'string')",
                }[Case]
                (Project / 'Callers.luau').write_text(Http + '\n' + Checks + '\n' + Published['Json'] + '\n' + JsonChecks, encoding='utf-8')
                Process = Start(Args.godot, Project, 'HttpServiceCallers.gd', Label, [Origin, Case], ActorEnvironment)
                Result = Check(Process, time.monotonic() + Args.timeout, Project, Label, '[Runtime:HttpCallers] PASS ' + Case)
        finally:
            if State is not None:
                (Project / 'server-results.json').write_text(json.dumps({'Hits': State.Hits}, indent=2))
        Expected = [] if Case == 'denied' else [{'Method': 'GET', 'Path': Path} for Path in (['/no-content', '/no-content'] if Case == 'empty' else ['/ok', '/status'])]
        if State.Hits != Expected: raise ValueError('Unexpected caller I/O: ' + Case)
        Text = '\n'.join((Project / (Label + '.' + Kind + '.log')).read_text(errors='replace') for Kind in ['stdout', 'stderr'])
        if '[Runtime:Script]' in Text: raise ValueError('Unexpected caller exception: ' + Case)
        Results.append(Result)
    (Output / 'native-evidence.json').write_text(json.dumps({'Actors': 3, 'UnauthorizedRequests': 0, 'PublishedSnippetSHA256': Hashes}, indent=2))
    return Results
