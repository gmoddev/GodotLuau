"""Repackage unchanged qualified products after the bounded GL-052 layout repair.

No compilation or publication. All original profile, source, hash, native,
sanitizer and extracted-startup checks remain in ReleaseCandidate.
"""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import subprocess

import ReleaseCandidate as Candidate


def OriginalGates(Repository, Run, Revision):
    def Api(Suffix):
        return json.loads(subprocess.check_output(['gh','api','repos/'+Repository+'/actions/'+Suffix],text=True,timeout=30))
    Record=Api('runs/'+str(Run))
    Candidate.Require(Record['head_sha']==Revision and Record['status']=='completed' and Record['path']=='.github/workflows/release-candidate.yml', 'Qualified run source/workflow mismatch')
    Jobs=Api('runs/'+str(Run)+'/jobs?per_page=100&filter=latest')['jobs']
    Required={
        'Policy':['Candidate rejection and retention checks ('+Runner+')' for Runner in ('windows-2022','ubuntu-24.04')],
        'Profiles':['Source build and qualify ('+Platform+', '+Configuration+')' for Platform,Configuration in Candidate.Profiles],
        'Sanitizer':['Linux production core ASan and LSan'],
    }
    for Names in Required.values():
        for Name in Names:
            Matches=[Job for Job in Jobs if Job['name']==Name]
            Candidate.Require(len(Matches)==1 and Matches[0]['status']=='completed' and Matches[0]['conclusion']=='success', 'Unqualified original gate: '+Name)
    return {Name:{'result':'success'} for Name in Required}


def Main():
    Parser=argparse.ArgumentParser(description=__doc__)
    Parser.add_argument('mode',choices=('package','accept'))
    Parser.add_argument('--repository',default='gmoddev/GodotLuau')
    Parser.add_argument('--run',type=int,required=True)
    Parser.add_argument('--revision',required=True)
    for Name in ('source','inputs','output'):Parser.add_argument('--'+Name,type=Path,required=True)
    Parser.add_argument('--godot',type=Path)
    Args=Parser.parse_args()
    Current=Path(__file__).resolve().parents[1]
    Candidate.Require(not subprocess.check_output(['git','-C',str(Current),'status','--porcelain','--untracked-files=all'],text=True).strip(), 'Dirty repair-tool checkout')
    ToolRevision=subprocess.check_output(['git','-C',str(Current),'rev-parse','HEAD'],text=True).strip()
    Changed=subprocess.check_output(['git','-C',str(Current),'diff','--name-only',Args.revision,ToolRevision],text=True).splitlines()
    Allowed={'tools/ReleaseCandidate.py','tools/RepackageCandidate.py','tests/release/ReleaseCandidateTests.py','.github/workflows/repackage-candidate.yml'}
    Candidate.Require(all(Name in Allowed or Name.startswith('newdocs/') for Name in Changed), 'Repair revision changes qualified runtime, fixture or package inputs')
    Gates=OriginalGates(Args.repository,Args.run,Args.revision)
    Candidate.Source=Args.source.resolve()
    Candidate.Require(Candidate.Hash(Current/'tools/ReleaseCandidatePolicy.json')==Candidate.Hash(Candidate.Source/'tools/ReleaseCandidatePolicy.json'), 'Candidate policy changed')
    # Identity verifies the immutable original checkout and dependency pins.
    Expected=Candidate.Identity(Args.revision)
    Candidate.Require(Candidate.GetFingerprint(Current)==Expected['NativeSource'], 'Changed native inputs')
    if os.name=='nt':ctypes.windll.kernel32.SetErrorMode(0x8003)
    try:
        if Args.mode=='accept':
            Outcomes=json.loads(os.environ['REPACKAGE_RESULTS'])
            Candidate.Require(set(Outcomes)=={'Policy','Packages'} and all(Value['result']=='success' for Value in Outcomes.values()), 'Failed repair workflow gate')
            Gates['Packages']={'result':Outcomes['Packages']['result']}
            os.environ['RC_GATE_RESULTS']=json.dumps(Gates)
            Candidate.Accept(Args)
        else:
            Candidate.Package(Args)
        Candidate.Save(Args.output/'repair.json',{'SourceRun':Args.run,'SourceRevision':Args.revision,'ToolRevision':ToolRevision,
            'ToolSHA256':hashlib.sha256((Current/'tools/ReleaseCandidate.py').read_bytes()).hexdigest(),
            'NativeSource':Expected['NativeSource'],'OriginalGates':Gates,'Repair':'Move only unrecorded supplementary game evidence in extracted copies; original profile artifacts unchanged'})
    finally:Candidate.StopAll()


if __name__=='__main__':Main()
