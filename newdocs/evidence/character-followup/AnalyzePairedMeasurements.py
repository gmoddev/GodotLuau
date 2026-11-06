import argparse,hashlib,itertools,json,math,random,statistics
from pathlib import Path
Parser=argparse.ArgumentParser()
Parser.add_argument('Root',type=Path)
Args=Parser.parse_args()
Root=Args.Root
def Paired(Before,After):
    assert len(Before)==len(After) and len(Before)>=3 and all(Value>0 for Value in Before+After)
    Changes=[(Right/Left-1)*100 for Left,Right in zip(Before,After)]
    Improved=sum(Value<0 for Value in Changes)
    Worse=sum(Value>0 for Value in Changes)
    N=Improved+Worse
    P=min(1.0,2*sum(math.comb(N,K) for K in range(min(Improved,Worse)+1))/(2**N)) if N else 1.0
    Generator=random.Random(73)
    Boot=sorted(statistics.median(Generator.choices(Changes,k=len(Changes))) for Index in range(10000))
    return {'Pairs':len(Before),'Baseline':Before,'Candidate':After,'BaselineMedian':statistics.median(Before),'CandidateMedian':statistics.median(After),'MedianPairedPercentChange':statistics.median(Changes),'PairedPercentChanges':Changes,'Improved':Improved,'Worse':Worse,'Ties':len(Before)-N,'ExactTwoSidedSignP':P,'DescriptiveBootstrapMedianInterval95Percent':[Boot[249],Boot[9749]]}
Evidence={'Scope':'Trial 0 is retained warmup and excluded. Independent units are paired actors, not individual frames. Exact two-sided sign P is exploratory and unadjusted unless explicitly marked. Descriptive bootstrap is not a causal proof. Raw quantities retain original units.','Groups':{},'RawSHA256':{}}
for Directory in sorted(Root.iterdir()):
    File=Directory/'measurements.json'
    if not File.exists() or Directory.name.startswith('network-'): continue
    Data=json.loads(File.read_text())
    if not isinstance(Data,list) or not Data or 'Variant' not in Data[0]: continue
    Evidence['RawSHA256'][File.relative_to(Root).as_posix()]=hashlib.sha256(File.read_bytes()).hexdigest()
    Trials={Variant:sorted([Item for Item in Data if Item['Variant']==Variant and Item['Trial']>0],key=lambda Item:Item['Trial']) for Variant in ['Baseline','Candidate']}
    assert [Item['Trial'] for Item in Trials['Baseline']]==[Item['Trial'] for Item in Trials['Candidate']]
    Rows=[]
    Profiles=Data[0]['Profiles']
    for Prototype in Profiles:
        Count,Mode=Prototype['Characters'],Prototype['Mode']
        Selected={Variant:[next(Item for Item in Actor['Profiles'] if Item['Characters']==Count and Item['Mode']==Mode) for Actor in Actors] for Variant,Actors in Trials.items()}
        for Metric in ['PhysicsSeconds','ProcessSeconds','FrameSeconds','RenderCpuMilliseconds','RenderGpuMilliseconds','HarnessMicroseconds']:
            if not Prototype.get(Metric): continue
            for Stat in ['Mean','Median','P95','P99']:
                Before=[Item[Metric][Stat] for Item in Selected['Baseline']]
                After=[Item[Metric][Stat] for Item in Selected['Candidate']]
                if not all(Value>0 for Value in Before+After): continue
                Rows.append({'Characters':Count,'Mode':Mode,'Metric':Metric,'Statistic':Stat,**Paired(Before,After)})
        for Variant,Items in Selected.items():
            assert len({Item['Objects'] for Item in Items})==1
    for Metric in ['CreationMicroseconds','RespawnMicroseconds']:
        for Stat in ['Mean','Median','P95','P99']:
            Rows.append({'Metric':Metric,'Statistic':Stat,**Paired([Item[Metric][Stat] for Item in Trials['Baseline']],[Item[Metric][Stat] for Item in Trials['Candidate']])})
    Rows.append({'Metric':'WholeActorCpuSeconds','Statistic':'Total',**Paired([Item['ProcessCpuSeconds']['Total'] for Item in Trials['Baseline']],[Item['ProcessCpuSeconds']['Total'] for Item in Trials['Candidate']])})
    Evidence['Groups'][Directory.name]={'Rows':Rows,'Memory':{Variant:[{'Trial':Item['Trial'],'ObjectDelta':Item['RespawnMemory'][-1]['Objects']-Item['RespawnMemory'][0]['Objects'],'ByteDelta':Item['RespawnMemory'][-1]['StaticMemoryBytes']-Item['RespawnMemory'][0]['StaticMemoryBytes']} for Item in Items] for Variant,Items in Trials.items()}}
for Mode in ['all','physics-only','network-only']:
    Files={Variant:sorted(Root.glob('network-'+Mode+'-'+Variant+'-*/measurements.json'),key=lambda File:int(File.parent.name.rsplit('-',1)[1])) for Variant in ['Baseline','Candidate']}
    if not Files['Baseline'] or len(Files['Baseline'])!=len(Files['Candidate']): continue
    Trials={Variant:[json.loads(File.read_text()) for File in Items[1:]] for Variant,Items in Files.items()}
    Rows=[]
    for Role in ['server0','client1','client2']:
        Selected={Variant:[next(Item for Item in Trial if Item['Role']==Role) for Trial in Items] for Variant,Items in Trials.items()}
        for Metric in ['DispatchPhysicsSeconds','DispatchProcessSeconds','FrameSeconds']:
            for Stat in ['Mean','Median','P95','P99']:
                Rows.append({'Role':Role,'Metric':Metric,'Statistic':Stat,**Paired([Item[Metric][Stat] for Item in Selected['Baseline']],[Item[Metric][Stat] for Item in Selected['Candidate']])})
    Evidence['Groups']['network-'+Mode]={'Rows':Rows}
(Root/'followup-analysis.json').write_text(json.dumps(Evidence,indent=2))
print(json.dumps({'Groups':list(Evidence['Groups']),'Rows':sum(len(Group['Rows']) for Group in Evidence['Groups'].values())}),flush=True)
