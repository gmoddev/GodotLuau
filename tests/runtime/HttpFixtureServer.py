"""Owned loopback-only HTTP/TLS endpoints; public fixture keys are never production credentials."""
import hashlib
import http.server
import json
from pathlib import Path
import socketserver
import socket
import ssl
import threading
import time
from contextlib import contextmanager


class Fixture:
    def __init__(Self):
        Self.Hits = []
        Self.Lock = threading.Condition()
        Self.Stop = threading.Event()
        Self.Active = 0
        Self.Connections = {}
        Self.Origins = {}

    def Record(Self, Method, Path):
        with Self.Lock:
            if len(Self.Hits) >= 2048:
                raise RuntimeError('[Runtime:HttpTest] Fixture request collection overflow')
            Self.Hits.append({'Method': Method, 'Path': Path[:256]})

    def Connection(Self, Delta):
        with Self.Lock:
            Self.Active += Delta
            Self.Lock.notify_all()


@contextmanager
def Serve(Tls=False):
    State = Fixture()

    class Handler(http.server.BaseHTTPRequestHandler):
        protocol_version = 'HTTP/1.1'

        def setup(Self):
            Self.request.settimeout(2)
            super().setup()
            State.Connection(1)

        def finish(Self):
            try:
                super().finish()
            finally:
                State.Connection(-1)

        def log_message(Self, Format, *Args):
            pass

        def Handle(Self):
            State.Record(Self.command, Self.path)
            try:
                Size = int(Self.headers.get('Content-Length', '0'))
                if Size < 0 or Size > 2 * 1024 * 1024:
                    Self.send_error(413)
                    return
                Body = Self.rfile.read(Size) if Size else b''
                Status = 200
                if Self.path in ['/slow', '/hold']:
                    State.Stop.wait(0.4 if Self.path == '/slow' else 2)
                    Body = b'slow'
                elif Self.path == '/truncated':
                    Self.send_response(200)
                    Self.send_header('Content-Length', '128')
                    Self.send_header('Connection', 'close')
                    Self.end_headers()
                    Self.wfile.write(b'partial')
                    Self.wfile.flush()
                    Self.close_connection = True
                    return
                elif Self.path == '/stream':
                    Self.send_response(200)
                    Self.send_header('Content-Length', '1000000')
                    Self.send_header('Connection', 'close')
                    Self.end_headers()
                    Deadline = time.monotonic() + 7
                    while not State.Stop.is_set() and time.monotonic() < Deadline:
                        Self.wfile.write(b'drip')
                        Self.wfile.flush()
                        State.Stop.wait(0.01)
                    Self.close_connection = True
                    return
                elif Self.path == '/large':
                    Body = b'x' * (4 * 1024 * 1024)
                elif Self.path == '/oversized-length':
                    Self.send_response(200)
                    Self.send_header('Content-Length', str(4 * 1024 * 1024 + 1))
                    Self.send_header('Connection', 'close')
                    Self.end_headers()
                    Self.close_connection = True
                    return
                elif Self.path in ['/chunked', '/chunked-case', '/chunked-keepalive', '/chunk-overflow', '/wire-overflow']:
                    Self.send_response(200)
                    Self.send_header('Transfer-Encoding', 'Chunked' if Self.path in ['/chunked-case', '/chunked-keepalive'] else 'chunked')
                    if Self.path != '/chunked-keepalive': Self.send_header('Connection', 'close')
                    Self.end_headers()
                    if Self.path in ['/chunked', '/chunked-case', '/chunked-keepalive']:
                        for Chunk in [b'chunk', b'ed']:
                            Self.wfile.write(('%x\r\n' % len(Chunk)).encode() + Chunk + b'\r\n')
                        Self.wfile.write(b'0\r\n\r\n')
                    elif Self.path == '/chunk-overflow':
                        Chunk = b'x' * (4 * 1024 * 1024 + 1)
                        Self.wfile.write(('%x\r\n' % len(Chunk)).encode() + Chunk + b'\r\n0\r\n\r\n')
                    else:
                        Self.wfile.write(b'0\r\n')
                        Line = b'X-Trailer: ' + b'x' * 1000 + b'\r\n'
                        for Index in range(9000):
                            if State.Stop.is_set():
                                break
                            Self.wfile.write(Line)
                        Self.wfile.write(b'\r\n')
                    Self.wfile.flush()
                    Self.close_connection = True
                    return
                elif Self.path in ['/invalid-header', '/invalid-length', '/invalid-status', '/ambiguous', '/header-overflow']:
                    Wire = {
                        '/invalid-header': b'HTTP/1.1 200 OK\r\nX-Bad: \xff\r\nContent-Length: 0\r\n\r\n',
                        '/invalid-length': b'HTTP/1.1 200 OK\r\nContent-Length: abc\r\n\r\n',
                        '/invalid-status': b'GARBAGE 200 OK\r\nContent-Length: 0\r\n\r\n',
                        '/ambiguous': b'HTTP/1.1 200 OK\r\nContent-Length: 1\r\nTransfer-Encoding: chunked\r\n\r\n0\r\n\r\n',
                        '/header-overflow': b'HTTP/1.1 200 OK\r\nX-Large: ' + b'x' * 20000 + b'\r\nContent-Length: 0\r\n\r\n',
                    }[Self.path]
                    Self.wfile.write(Wire)
                    Self.wfile.flush()
                    Self.close_connection = True
                    return
                elif Self.path == '/status':
                    Status, Body = 418, b'teapot'
                elif Self.path == '/redirect':
                    Status, Body = 302, b'redirect'
                elif Self.path == '/no-content':
                    Status, Body = 204, b''
                elif Self.path == '/inspect':
                    Body = json.dumps({'Method': Self.command, 'ContentType': Self.headers.get('Content-Type', ''),
                        'CacheControl': Self.headers.get('Cache-Control', ''), 'Pragma': Self.headers.get('Pragma', ''),
                        'Body': Body.decode('utf-8')}).encode()
                elif Self.path in ['/response-headers', '/response-header-count', '/response-header-name', '/response-folded']:
                    if Self.path == '/response-headers':
                        Self.send_response(200, 'Fixture Success')
                        Self.send_header('X-Mixed-Case', 'first')
                        Self.send_header('x-mixed-case', 'second')
                        Self.send_header('Set-Cookie', 'a=1; Expires=Wed, 21 Oct 2030 07:28:00 GMT')
                        Self.send_header('Set-Cookie', 'b=2')
                        Self.send_header('X-Empty', '')
                        Self.send_header('Content-Length', '0')
                        Self.send_header('Connection', 'close')
                        Self.end_headers()
                    elif Self.path == '/response-header-count':
                        Self.wfile.write(b'HTTP/1.1 200 OK\r\n' + b'X: value\r\n' * 129 + b'Content-Length: 0\r\n\r\n')
                    elif Self.path == '/response-header-name':
                        Self.wfile.write(b'HTTP/1.1 200 OK\r\n' + b'X' * 129 + b': value\r\nContent-Length: 0\r\n\r\n')
                    else:
                        Self.wfile.write(b'HTTP/1.1 200 OK\r\nX: value\r\n folded\r\nContent-Length: 0\r\n\r\n')
                    Self.wfile.flush()
                    Self.close_connection = True
                    return
                elif Self.path == '/method':
                    Body = Self.command.encode()
                elif Self.path == '/headers':
                    Body = (Self.headers.get('X-Number', '') + '|' + Self.headers.get('Content-Type', '')).encode()
                elif Self.path != '/echo':
                    Body = b'ok'
                Self.send_response(Status)
                if Status == 302:
                    Self.send_header('Location', State.Origins['Denied'] + '/forbidden/redirect')
                Self.send_header('Content-Length', str(len(Body)))
                Self.send_header('Connection', 'close')
                Self.end_headers()
                if Self.command != 'HEAD':
                    Self.wfile.write(Body)
            except (OSError, ValueError):
                Self.close_connection = True

        do_GET = Handle
        do_POST = Handle
        do_PUT = Handle
        do_PATCH = Handle
        do_DELETE = Handle
        do_HEAD = Handle
        do_OPTIONS = Handle

    class Server(http.server.ThreadingHTTPServer):
        daemon_threads = True

    class TlsServer(Server):
        def get_request(Self):
            Connection, Address = super().get_request()
            Connection.settimeout(2)
            with State.Lock:
                State.Connections[Self.Label] = State.Connections.get(Self.Label, 0) + 1
            try:
                return Self.Context.wrap_socket(Connection, server_side=True), Address
            except OSError:
                Connection.close()
                raise

    class Stall(socketserver.BaseRequestHandler):
        def handle(Self):
            State.Connection(1)
            try:
                with State.Lock:
                    State.Connections['Stall'] = State.Connections.get('Stall', 0) + 1
                State.Stop.wait(8)
            finally:
                State.Connection(-1)

    class StallServer(socketserver.ThreadingTCPServer):
        daemon_threads = True

    class TlsServer6(TlsServer):
        address_family = socket.AF_INET6

    class StallServer6(StallServer):
        address_family = socket.AF_INET6

    Servers, Threads = [], []

    def Start(ServerType, Label, Scheme='http', Host='127.0.0.1', Address='127.0.0.1', Port=0):
        Server = ServerType((Address, Port), Stall if issubclass(ServerType, StallServer) else Handler)
        Servers.append(Server)
        State.Origins[Label] = Scheme + '://' + Host + ':' + str(Server.server_address[1])
        return Server

    Start(Server, 'Http')
    Start(Server, 'Denied')
    Refused = socket.socket()
    Refused.bind(('127.0.0.1', 0))  # Reserved, deliberately not listening.
    State.Origins['Refused'] = 'http://127.0.0.1:' + str(Refused.getsockname()[1])
    State.Origins['Dns'] = 'http://nonexistent.invalid'
    if Tls:
        for Label, Prefix in [('Tls', 'HttpFixture'), ('Untrusted', 'HttpFixtureOther')]:
            Server = Start(TlsServer, Label, 'https', 'localhost')
            Server.Label = Label
            Server.Context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            Server.Context.load_cert_chain(Path(__file__).with_name(Prefix + 'CA.pem'), Path(__file__).with_name(Prefix + 'Key.pem'))
            # localhost may prefer ::1. Own both loopback families on the same
            # port instead of relying on platform-specific refused-IP fallback.
            Peer = Start(TlsServer6, Label, 'https', 'localhost', '::1', Server.server_address[1])
            Peer.Label, Peer.Context = Label, Server.Context
        State.Origins['BadName'] = State.Origins['Tls'].replace('localhost', '127.0.0.1')
        Server = Start(StallServer, 'Stall', 'https', 'localhost')
        Start(StallServer6, 'Stall', 'https', 'localhost', '::1', Server.server_address[1])
    for Server in Servers:
        Thread = threading.Thread(target=lambda Item=Server: Item.serve_forever(poll_interval=0.05), name='GL005Loopback', daemon=True)
        Thread.start()
        Threads.append(Thread)
    try:
        yield State, State.Origins['Http']
    finally:
        State.Stop.set()
        Refused.close()
        for Server in Servers:
            Server.shutdown()
            Server.server_close()
        for Thread in Threads:
            Thread.join(timeout=3)
            if Thread.is_alive():
                raise RuntimeError('[Runtime:HttpTest] Loopback listener did not stop')
        Deadline = time.monotonic() + 3
        with State.Lock:
            while State.Active and time.monotonic() < Deadline:
                State.Lock.wait(timeout=0.05)
            if State.Active:
                raise RuntimeError('[Runtime:HttpTest] Loopback connections did not stop')
