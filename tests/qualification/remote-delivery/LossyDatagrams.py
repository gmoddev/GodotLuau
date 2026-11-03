"""Bounded fixture-only UDP faults selected by synthetic payload markers."""
import ctypes
import heapq
import os
import select
import socket
import threading
import time


class LossyDatagrams:
    def __init__(Self, ServerPort):
        Self.Server = ('127.0.0.1', ServerPort)
        Self.Socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        Self.Socket.bind(('127.0.0.1', 0))
        if os.name == 'nt':
            Winsock = ctypes.WinDLL('Ws2_32')
            Winsock.WSAIoctl.argtypes = [ctypes.c_size_t, ctypes.c_ulong, ctypes.c_void_p, ctypes.c_ulong,
                ctypes.c_void_p, ctypes.c_ulong, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p]
            Disabled = ctypes.c_ulong(0); Returned = ctypes.c_ulong()
            if Winsock.WSAIoctl(Self.Socket.fileno(), 0x9800000C, ctypes.byref(Disabled), 4, None, 0, ctypes.byref(Returned), None, None):
                Self.Socket.close(); raise RuntimeError('Could not configure fixture UDP socket')
        Self.Port = Self.Socket.getsockname()[1]
        Self.Stop = threading.Event(); Self.Error = None
        Self.Stats = {'Received': 0, 'Forwarded': 0, 'ReliableDropped': 0, 'ReliableMatchingDatagrams': 0,
                      'UnorderedDropped': 0, 'Delayed': 0, 'Duplicated': 0, 'CapacityDrops': 0,
                      'PeakPending': 0, 'PeakPendingBytes': 0}
        Self.Thread = threading.Thread(target=Self.Run, name='GL029WireFaults', daemon=True)
        Self.Thread.start()

    def Run(Self):
        Pending = []; PendingBytes = 0; Serial = 0; Client = None
        try:
            while not Self.Stop.is_set():
                Now = time.monotonic()
                while Pending and Pending[0][0] <= Now:
                    _, _, Data, Target = heapq.heappop(Pending); PendingBytes -= len(Data)
                    Self.Socket.sendto(Data, Target); Self.Stats['Forwarded'] += 1
                if not select.select([Self.Socket], [], [], .005)[0]: continue
                Data, Sender = Self.Socket.recvfrom(65535); Self.Stats['Received'] += 1
                FromClient = Sender != Self.Server
                if FromClient: Client = Sender
                Target = Self.Server if FromClient else Client
                if Target is None: raise RuntimeError('Fixture received server data before client identity')
                Delay = 0.0; Copies = 1
                if FromClient:
                    if b'GL029DropUnordered' in Data:
                        Self.Stats['UnorderedDropped'] += 1; continue
                    if b'GL029DropReliableOnce' in Data:
                        Self.Stats['ReliableMatchingDatagrams'] += 1
                        if Self.Stats['ReliableDropped'] == 0:
                            Self.Stats['ReliableDropped'] += 1; continue
                    if b'GL029ReorderA' in Data or b'GL029SeqOld' in Data:
                        Delay = .12; Self.Stats['Delayed'] += 1
                    if b'GL029Duplicate' in Data:
                        Copies = 2; Self.Stats['Duplicated'] += 1
                if len(Pending) + Copies > 256 or PendingBytes + len(Data) * Copies > 1024 * 1024:
                    Self.Stats['CapacityDrops'] += 1; continue
                for Copy in range(Copies):
                    Serial += 1
                    heapq.heappush(Pending, (time.monotonic() + Delay + Copy * .001, Serial, Data, Target)); PendingBytes += len(Data)
                Self.Stats['PeakPending'] = max(Self.Stats['PeakPending'], len(Pending))
                Self.Stats['PeakPendingBytes'] = max(Self.Stats['PeakPendingBytes'], PendingBytes)
        except Exception as Error: Self.Error = repr(Error)

    def Close(Self):
        Self.Stop.set(); Self.Thread.join(timeout=2); Self.Socket.close()
        if Self.Thread.is_alive() or Self.Error: raise RuntimeError('Fixture UDP proxy failed: '+str(Self.Error))
