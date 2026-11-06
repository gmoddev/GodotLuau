"""Bounded UDP forwarding for actual ENet latency/reordering qualification."""
import heapq
import ctypes
import os
import select
import socket
import threading
import time


class DelayedDatagrams:
    def __init__(self, ServerPort):
        self.Server = ('127.0.0.1', ServerPort)
        self.Socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.Socket.bind(('127.0.0.1', 0))
        if os.name == 'nt':
            # A late UDP reply to a retired actor is normal. Keep ICMP errors
            # from poisoning this task-owned forwarding socket's next receive.
            Winsock = ctypes.WinDLL('Ws2_32')
            Winsock.WSAIoctl.argtypes = [ctypes.c_size_t, ctypes.c_ulong, ctypes.c_void_p, ctypes.c_ulong,
                ctypes.c_void_p, ctypes.c_ulong, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p]
            Disabled = ctypes.c_ulong(0)
            Returned = ctypes.c_ulong()
            if Winsock.WSAIoctl(self.Socket.fileno(), 0x9800000C, ctypes.byref(Disabled), 4,
                    None, 0, ctypes.byref(Returned), None, None) != 0:
                self.Socket.close()
                raise RuntimeError('Could not configure the task UDP socket')
        self.Port = self.Socket.getsockname()[1]
        self.Stop = threading.Event()
        self.Error = None
        self.Stats = {'Received': 0, 'Forwarded': 0, 'Dropped': 0, 'PeakPending': 0,
                      'ConfiguredDelaySeconds': .2, 'JitterSeconds': [0, .035, .07], 'MinimumObservedSeconds': None}
        self.Thread = threading.Thread(target=self.Run, name='CharacterLatency', daemon=True)
        self.Thread.start()

    def Run(self):
        Pending = []
        Client = None
        Serial = 0
        try:
            while not self.Stop.is_set():
                Now = time.monotonic()
                while Pending and Pending[0][0] <= Now:
                    _, _, Started, Data, Target = heapq.heappop(Pending)
                    self.Socket.sendto(Data, Target)
                    self.Stats['Forwarded'] += 1
                    Delay = time.monotonic() - Started
                    Minimum = self.Stats['MinimumObservedSeconds']
                    self.Stats['MinimumObservedSeconds'] = Delay if Minimum is None else min(Minimum, Delay)
                if not select.select([self.Socket], [], [], .005)[0]:
                    continue
                Data, Sender = self.Socket.recvfrom(65535)
                Now = time.monotonic()
                self.Stats['Received'] += 1
                if Sender == self.Server:
                    Target = Client
                else:
                    Client = Sender
                    Target = self.Server
                if Target is None or len(Pending) >= 4096:
                    self.Stats['Dropped'] += 1
                    continue
                Serial += 1
                Delay = .2 + self.Stats['JitterSeconds'][Serial % 3]
                heapq.heappush(Pending, (Now + Delay, Serial, Now, Data, Target))
                self.Stats['PeakPending'] = max(self.Stats['PeakPending'], len(Pending))
        except Exception as Error:
            self.Error = repr(Error)

    def Close(self):
        self.Stop.set()
        self.Thread.join(timeout=2)
        self.Socket.close()
        if self.Thread.is_alive() or self.Error:
            raise RuntimeError('UDP qualification proxy did not retire: ' + str(self.Error))
