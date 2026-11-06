"""Exercise the actual enabled EditorPlugin in a bounded, isolated headless editor."""
import argparse
import ctypes
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import threading
import time
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'runtime'))
from RunQualification import Check


def Main():
    Parser = argparse.ArgumentParser()
    Parser.add_argument('--godot', type=Path, required=True)
    Parser.add_argument('--output', type=Path, required=True)
    Parser.add_argument('--timeout', type=float, default=60)
    Args = Parser.parse_args()
    Source = Path(__file__).resolve().parents[2]
    Output = Args.output.resolve()
    Output.mkdir(parents=True, exist_ok=False)
    PluginSource = Source / 'addons/GodotLuauUpdater'
    Text = (PluginSource / 'plugin.gd').read_text(encoding='utf-8')
    # Preflight prevents testing an unguarded inherited downloader/restart path.
    assert re.search(r'func RuntimeUpdatesAllowed\(\) -> bool:\s*return false', Text)
    for Name in ['_check_for_update', '_start_download', '_apply_update', '_do_editor_restart', '_apply_windows_update_legacy']:
        assert re.search(r'^func ' + Name + r'\([^\n]*\n\tif RejectRuntimeUpdate\(\): return', Text, re.M), Name
    shutil.copytree(PluginSource, Output / 'addons/GodotLuauUpdater')
    Fixture = Output / 'addons/UpdaterFixture'
    Fixture.mkdir()
    shutil.copyfile(Path(__file__).with_name('UpdaterIsolation.gd'), Fixture / 'plugin.gd')
    (Fixture / 'plugin.cfg').write_text('[plugin]\nname="UpdaterFixture"\ndescription="Controlled updater isolation fixture"\nauthor="GodotLuau"\nversion="1"\nscript="plugin.gd"\n')
    Files = ['GodotLuau/bin/fork.dll', 'GodotLuau/bin/fork.dll.old', 'GodotLuau/bin/fork.dll.new', 'GodotLuau/bin/update.TMP', 'bin/legacy.dll', 'icons/Keep.txt', 'DefaultScripts/Keep.txt', 'assets/avatars/r6/Keep.txt', '.luau_backup/files/GodotLuau/bin/fork.dll', '.luau_backup/version.txt', 'addons/GodotLuauUpdater/installed_version.txt', 'Version']
    for Name in Files:
        Target = Output / Name
        Target.parent.mkdir(parents=True, exist_ok=True)
        Target.write_text('FORK PRESERVE ' + Name)
    with zipfile.ZipFile(Output / 'candidate.zip', 'w') as Archive:
        Archive.writestr('GodotLuau/bin/fork.dll', 'UPSTREAM REPLACEMENT')
        Archive.writestr('GodotLuau/godot_luau.gdextension', 'unverified descriptor')
        Archive.writestr('Version', 'v999')
    Requests = []

    class Handler(BaseHTTPRequestHandler):
        protocol_version = 'HTTP/1.1'

        def do_GET(self):
            Requests.append(self.path)
            Body = b'[]' if self.path == '/autocomplete.json' else b'{"bigrams": {}}'
            self.send_response(200 if self.path in ['/autocomplete.json', '/model.json'] else 404)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(Body)))
            self.send_header('Connection', 'close')
            self.end_headers()
            self.wfile.write(Body)

        def log_message(self, Format, *Arguments):
            pass

    Server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    Thread = threading.Thread(target=Server.serve_forever, daemon=True)
    Thread.start()
    (Output / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="UpdaterIsolation"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="UpdaterIsolation"\n[editor_plugins]\nenabled=PackedStringArray("res://addons/GodotLuauUpdater/plugin.cfg", "res://addons/UpdaterFixture/plugin.cfg")\n[threading]\nworker_pool/max_threads=2\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n[updater_test]\nport=' + str(Server.server_port) + '\n')
    Environment = dict(os.environ, GODOT_SILENCE_ROOT_WARNING='1')
    for Name in ['APPDATA', 'LOCALAPPDATA', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME']:
        Directory = Output / 'profile' / Name
        Directory.mkdir(parents=True)
        Environment[Name] = str(Directory)
    (Output / 'profile/.gdignore').write_text('')
    if os.name == 'nt': ctypes.windll.kernel32.SetErrorMode(0x8003)
    Command = [str(Args.godot.resolve()), '--headless', '--disable-crash-handler', '--single-threaded-scene', '--editor', '--path', str(Output)]
    Flags = {'creationflags': subprocess.CREATE_NO_WINDOW} if os.name == 'nt' else {}
    try:
        with (Output / 'editor.stdout.log').open('w') as Stdout, (Output / 'editor.stderr.log').open('w') as Stderr:
            Process = subprocess.Popen(Command, stdout=Stdout, stderr=Stderr, env=Environment, **Flags)
        Result = Check(Process, time.monotonic() + Args.timeout, Output, 'editor', '[Editor:UpdaterTest] PASS')
        Errors = (Output / 'editor.stderr.log').read_text(errors='replace')
        assert 'SCRIPT ERROR:' not in Errors and 'Parse Error:' not in Errors, Errors
        assert sorted(Requests) == ['/autocomplete.json', '/model.json'], Requests
        FixtureResults = json.loads((Output / 'fixture-results.json').read_text())
        assert FixtureResults['Passed']
        assert (Output / 'addons/GodotLuauUpdater/plugin.cfg').read_bytes() == (PluginSource / 'plugin.cfg').read_bytes()
        Result.update(FixtureResults, Requests=Requests, Command=Command,
                      SourceHashes={Name: hashlib.sha256((PluginSource / Name).read_bytes().replace(b'\r\n', b'\n')).hexdigest() for Name in ['plugin.gd', 'plugin.cfg']},
                      LogHashes={Name: hashlib.sha256((Output / Name).read_bytes()).hexdigest() for Name in ['editor.stdout.log', 'editor.stderr.log']})
        (Output / 'results.json').write_text(json.dumps(Result, indent=2))
        print('[Editor:UpdaterQualification] PASS', Output)
    finally:
        if 'Process' in locals() and Process.poll() is None:
            Process.kill()
            Process.wait()
        Server.shutdown()
        Thread.join(timeout=5)
        Server.server_close()


if __name__ == '__main__':
    Main()
