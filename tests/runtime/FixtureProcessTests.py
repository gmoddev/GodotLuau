"""Bounded launcher regressions; no alternative runtime or native fixture logic."""
import ctypes
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

from FixtureProcesses import StartProcess, StopProcess, StopAll
from RunQualification import Check


def Alive(Pid):
    if os.name == 'nt':
        Kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        Kernel.OpenProcess.argtypes = [ctypes.c_ulong, ctypes.c_int, ctypes.c_ulong]
        Kernel.OpenProcess.restype = ctypes.c_void_p
        Kernel.WaitForSingleObject.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
        Kernel.CloseHandle.argtypes = [ctypes.c_void_p]
        Handle = Kernel.OpenProcess(0x100000, False, Pid)
        if not Handle:
            return False
        try:
            return Kernel.WaitForSingleObject(Handle, 0) == 258
        finally:
            Kernel.CloseHandle(Handle)
    try:
        if Path('/proc/%d/stat' % Pid).exists() and Path('/proc/%d/stat' % Pid).read_text().split()[2] == 'Z':
            return False
        os.kill(Pid, 0)
        return True
    except ProcessLookupError:
        return False


class FixtureProcessTests(unittest.TestCase):
    def setUp(self):
        self.Temporary = tempfile.TemporaryDirectory(prefix='GodotLuauProcesses-')
        self.Output = Path(self.Temporary.name)
        if os.name == 'nt':
            ctypes.windll.kernel32.SetErrorMode(0x8003)

    def tearDown(self):
        StopAll()
        self.Temporary.cleanup()

    def Start(self, Source):
        with (self.Output / 'actor.stdout.log').open('w') as Stdout, (self.Output / 'actor.stderr.log').open('w') as Stderr:
            return StartProcess([sys.executable, '-c', Source], Stdout, Stderr, dict(os.environ))

    def Tree(self, Exit=False):
        Process = self.Start("import subprocess,sys,time; Child=subprocess.Popen([sys.executable,'-c','import time; time.sleep(60)']); print(Child.pid,flush=True); " + ("sys.exit(0)" if Exit else "time.sleep(60)"))
        Deadline = time.monotonic() + 5
        while not (self.Output / 'actor.stdout.log').read_text().strip():
            if time.monotonic() > Deadline:
                self.fail('Child did not start')
            time.sleep(0.02)
        return Process, int((self.Output / 'actor.stdout.log').read_text().strip())

    def Dead(self, Pid):
        Deadline = time.monotonic() + 3
        while Alive(Pid) and time.monotonic() < Deadline:
            time.sleep(0.02)
        self.assertFalse(Alive(Pid), 'Owned descendant remained alive')

    def test_forced_cleanup_terminates_descendants(self):
        Process, Child = self.Tree()
        self.assertTrue(Alive(Child))
        StopProcess(Process)
        self.Dead(Child)

    def test_normal_parent_exit_still_cleans_descendants(self):
        Process, Child = self.Tree(Exit=True)
        Process.wait(timeout=5)
        StopProcess(Process)
        self.Dead(Child)

    def test_partial_startup_failure_cleans_prior_actor(self):
        Process, Child = self.Tree()
        with (self.Output / 'unused.log').open('w') as Log:
            with self.assertRaises(OSError):
                StartProcess([str(self.Output / 'missing-executable')], Log, Log, dict(os.environ))
        StopAll()
        self.assertIsNotNone(Process.poll())
        self.Dead(Child)

    def test_timeout_cleans_tree(self):
        Process, Child = self.Tree()
        with self.assertRaisesRegex(RuntimeError, 'Timeout'):
            Check(Process, time.monotonic() + 0.1, self.Output, 'actor', '[Runtime:Integration] PASS')
        self.Dead(Child)

    def test_missing_pass_fails(self):
        Process = self.Start("print('No fixture completion')")
        with self.assertRaises(RuntimeError):
            Check(Process, time.monotonic() + 5, self.Output, 'actor', '[Runtime:Integration] PASS')

    def test_failure_marker_cannot_be_hidden_by_pass(self):
        Process = self.Start("print('[Runtime:Integration] FAIL assertion'); print('[Runtime:Integration] PASS')")
        with self.assertRaises(RuntimeError):
            Check(Process, time.monotonic() + 5, self.Output, 'actor', '[Runtime:Integration] PASS')

    def test_sanitizer_finding_cannot_be_hidden_by_pass(self):
        Process = self.Start("print('ERROR: AddressSanitizer: fixture'); print('[Runtime:Integration] PASS')")
        with self.assertRaises(RuntimeError):
            Check(Process, time.monotonic() + 5, self.Output, 'actor', '[Runtime:Integration] PASS')

    def test_nonzero_exit_cannot_be_hidden_by_pass(self):
        Process = self.Start("import sys; print('[Runtime:Integration] PASS'); sys.exit(1)")
        with self.assertRaises(RuntimeError):
            Check(Process, time.monotonic() + 5, self.Output, 'actor', '[Runtime:Integration] PASS')


if __name__ == '__main__':
    unittest.main(verbosity=2)
