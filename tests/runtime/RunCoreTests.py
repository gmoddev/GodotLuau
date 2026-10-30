"""Run production core plus separately owned, bounded non-yielding failures."""
import argparse
import ctypes
import os
from pathlib import Path
import subprocess
import sys
import time
from FixtureProcesses import StartProcess, StopProcess

Parser = argparse.ArgumentParser()
Parser.add_argument('--binary', type=Path, required=True)
Parser.add_argument('--output', type=Path, required=True)
Args = Parser.parse_args()
if os.name == 'nt':
    ctypes.windll.kernel32.SetErrorMode(0x8003)
Output = Args.output / (str(time.time_ns()) + '-' + str(os.getpid()))
Output.mkdir(parents=True)
Cases = ['infinite', 'nested', 'pcall', 'finite-exceeded', 'finite-within', 'module', 'callback', 'marshal', 'invoke', 'native', 'cross-time', 'cross-count', 'cross-reentry', 'cross-memory', 'memory-catch', 'shutdown']
for Case in ['normal', *Cases]:
    with (Output / (Case + '.stdout.log')).open('w') as Stdout, (Output / (Case + '.stderr.log')).open('w') as Stderr:
        Command = [str(Args.binary.resolve())] + ([] if Case == 'normal' else ['--limit-case', Case])
        if os.name == 'posix':
            # ASan reserves a large virtual address space; bound CPU/core dumps
            # here and actual VM allocation in production, not RLIMIT_AS.
            Command = [sys.executable, '-c',
                       'import os,resource,sys; resource.setrlimit(resource.RLIMIT_CPU,(10,10)); resource.setrlimit(resource.RLIMIT_CORE,(0,0)); os.execv(sys.argv[1],sys.argv[1:])', *Command]
        Process = StartProcess(Command, Stdout, Stderr, dict(os.environ))
        try:
            Result = Process.wait(timeout=10 if Case == 'normal' else 3)
        except subprocess.TimeoutExpired:
            Result = -1
        finally:
            StopProcess(Process)
    Text = (Output / (Case + '.stdout.log')).read_text(errors='replace')
    Errors = (Output / (Case + '.stderr.log')).read_text(errors='replace')
    print(Text, end='')
    Marker = '[Runtime:Test] 56 passed, 0 failed' if Case == 'normal' else '[Runtime:LimitTest] PASS ' + Case
    if Result != 0 or Marker not in Text:
        print(Errors)
        raise SystemExit('[Runtime:Test] Failure or watchdog containment: ' + Case)
    if Case != 'normal':
        print('[Runtime:Test] PASS Isolated execution resource case ' + Case)
print('[Runtime:Test] 72 passed, 0 failed')
