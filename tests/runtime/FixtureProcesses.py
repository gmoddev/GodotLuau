"""Own fixture process trees: POSIX sessions or Windows kill-on-close jobs."""
import atexit
import ctypes
import os
import signal
import subprocess

Processes = []


def WindowsJob():
    from ctypes import wintypes

    class BasicLimits(ctypes.Structure):
        _fields_ = [('PerProcessUserTimeLimit', ctypes.c_int64), ('PerJobUserTimeLimit', ctypes.c_int64),
                    ('LimitFlags', wintypes.DWORD), ('MinimumWorkingSetSize', ctypes.c_size_t),
                    ('MaximumWorkingSetSize', ctypes.c_size_t), ('ActiveProcessLimit', wintypes.DWORD),
                    ('Affinity', ctypes.c_size_t), ('PriorityClass', wintypes.DWORD), ('SchedulingClass', wintypes.DWORD)]

    class IoCounters(ctypes.Structure):
        _fields_ = [(Name, ctypes.c_uint64) for Name in ['ReadOperationCount', 'WriteOperationCount', 'OtherOperationCount', 'ReadTransferCount', 'WriteTransferCount', 'OtherTransferCount']]

    class ExtendedLimits(ctypes.Structure):
        _fields_ = [('BasicLimitInformation', BasicLimits), ('IoInfo', IoCounters),
                    ('ProcessMemoryLimit', ctypes.c_size_t), ('JobMemoryLimit', ctypes.c_size_t),
                    ('PeakProcessMemoryUsed', ctypes.c_size_t), ('PeakJobMemoryUsed', ctypes.c_size_t)]

    Kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    Kernel.CreateJobObjectW.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR]
    Kernel.CreateJobObjectW.restype = wintypes.HANDLE
    Kernel.SetInformationJobObject.argtypes = [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD]
    Kernel.AssignProcessToJobObject.argtypes = [wintypes.HANDLE, wintypes.HANDLE]
    Kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    Job = Kernel.CreateJobObjectW(None, None)
    if not Job:
        raise ctypes.WinError(ctypes.get_last_error())
    Limits = ExtendedLimits()
    Limits.BasicLimitInformation.LimitFlags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
    if not Kernel.SetInformationJobObject(Job, 9, ctypes.byref(Limits), ctypes.sizeof(Limits)):
        Error = ctypes.get_last_error()
        Kernel.CloseHandle(Job)
        raise ctypes.WinError(Error)
    return Kernel, Job


def StartProcess(Command, Stdout, Stderr, Environment):
    Job = WindowsJob() if os.name == 'nt' else None
    Process = None
    try:
        Options = {'creationflags': subprocess.CREATE_NO_WINDOW | subprocess.CREATE_NEW_PROCESS_GROUP} if Job else {'start_new_session': True}
        Process = subprocess.Popen(Command, stdout=Stdout, stderr=Stderr, env=Environment, **Options)
        if Job and not Job[0].AssignProcessToJobObject(Job[1], int(Process._handle)):
            raise ctypes.WinError(ctypes.get_last_error())
        Process.FixtureJob = Job
        Processes.append(Process)
        return Process
    except BaseException:
        if Process is not None:
            if os.name == 'nt':
                subprocess.run(['taskkill', '/PID', str(Process.pid), '/T', '/F'], capture_output=True, timeout=5, creationflags=subprocess.CREATE_NO_WINDOW)
            else:
                os.killpg(Process.pid, signal.SIGKILL)
            if Process.poll() is None:
                Process.kill()
            Process.wait(timeout=5)
        if Job:
            Job[0].CloseHandle(Job[1])
        raise


def StopProcess(Process):
    if Process in Processes:
        try:
            if Process.FixtureJob:
                if not Process.FixtureJob[0].CloseHandle(Process.FixtureJob[1]):
                    raise ctypes.WinError(ctypes.get_last_error())
            else:
                try:
                    os.killpg(Process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            Process.wait(timeout=5)
        finally:
            Processes.remove(Process)
    elif Process.poll() is None:
        # Check() is also used by the existing independent editor fixture.
        if os.name == 'nt':
            subprocess.run(['taskkill', '/PID', str(Process.pid), '/T', '/F'], capture_output=True, timeout=5, creationflags=subprocess.CREATE_NO_WINDOW)
        if Process.poll() is None:
            Process.kill()
        Process.wait(timeout=5)


def StopAll():
    Errors = []
    for Process in list(Processes):
        try:
            StopProcess(Process)
        except Exception as Error:
            Errors.append(str(Error))
    if Errors:
        raise RuntimeError('[Runtime:Cleanup] ' + '; '.join(Errors))


atexit.register(StopAll)
