"""Exercise real archive entry selection, bytes, executable metadata and rejection."""
import hashlib
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
import zipfile

Root=Path(__file__).resolve().parents[2]
Packager=Root/'tools/generar_release.py'


class PackagingTests(unittest.TestCase):
    def setUp(self):
        self.Temporary=tempfile.TemporaryDirectory()
        self.Project=Path(self.Temporary.name)
        self.Binaries=self.Project/'GodotLuau/bin';self.Binaries.mkdir(parents=True)
        self.Files={
            'godot_luau.windows.template_debug.x86_64.dll':b'Windows debug sentinel',
            'godot_luau.windows.template_release.x86_64.dll':b'Windows release sentinel',
            'godot_luau.linux.template_debug.x86_64.so':b'Linux debug sentinel',
            'godot_luau.linux.template_release.x86_64.so':b'Linux release sentinel',
            'godot_luau_store_worker.exe':b'Windows companion sentinel',
            'godot_luau_store_worker':b'Linux companion sentinel',
            'unrelated.exe':b'Must not package arbitrary executables',
        }
        for Name,Data in self.Files.items():(self.Binaries/Name).write_bytes(Data)

    def tearDown(self): self.Temporary.cleanup()

    def RunPackager(self,Platform=None):
        Args=[sys.executable,str(Packager),'--out',str(self.Project/'package.zip')]
        if Platform:Args+=['--only',Platform]
        Options={'creationflags':subprocess.CREATE_NO_WINDOW} if os.name=='nt' else {}
        return subprocess.run(Args,cwd=self.Project,capture_output=True,timeout=10,**Options)

    def CheckArchive(self,Platform):
        Result=self.RunPackager(Platform);self.assertEqual(Result.returncode,0,Result.stderr.decode(errors='replace'))
        Windows={'godot_luau.windows.template_debug.x86_64.dll','godot_luau.windows.template_release.x86_64.dll','godot_luau_store_worker.exe'}
        Linux={'godot_luau.linux.template_debug.x86_64.so','godot_luau.linux.template_release.x86_64.so','godot_luau_store_worker'}
        Expected=Windows if Platform=='windows' else Linux if Platform=='linux' else Windows|Linux
        with zipfile.ZipFile(self.Project/'package.zip') as Archive:
            self.assertEqual(set(Archive.namelist()),{'GodotLuau/bin/'+Name for Name in Expected})
            for Name in Expected:self.assertEqual(Archive.read('GodotLuau/bin/'+Name),self.Files[Name])
            if Platform!='windows':
                Info=Archive.getinfo('GodotLuau/bin/godot_luau_store_worker')
                self.assertEqual(Info.create_system,3)
                self.assertEqual(stat.S_IMODE(Info.external_attr>>16),0o755)

    def test_windows_package(self):self.CheckArchive('windows')
    def test_linux_package(self):self.CheckArchive('linux')
    def test_unified_package(self):self.CheckArchive(None)

    def test_missing_companion_preserves_existing_archive(self):
        for Platform,Companion in [('windows','godot_luau_store_worker.exe'),('linux','godot_luau_store_worker')]:
            with self.subTest(Platform=Platform):
                File=self.Binaries/Companion;Data=File.read_bytes();File.unlink()
                (self.Project/'package.zip').write_bytes(b'previous archive sentinel')
                Result=self.RunPackager(Platform)
                self.assertNotEqual(Result.returncode,0)
                self.assertIn(b'[Persistence:Packaging] Missing required companion',Result.stderr)
                self.assertEqual((self.Project/'package.zip').read_bytes(),b'previous archive sentinel')
                File.write_bytes(Data)

    def test_missing_companion_does_not_create_archive(self):
        (self.Binaries/'godot_luau_store_worker').unlink()
        self.assertNotEqual(self.RunPackager('linux').returncode,0)
        self.assertFalse((self.Project/'package.zip').exists())


if __name__=='__main__':
    for Name,File in [('Packager',Packager),('Tests',Path(__file__))]:
        print('[Persistence:Packaging] '+Name+'SHA256='+hashlib.sha256(File.read_bytes().replace(b'\r\n',b'\n')).hexdigest(),flush=True)
    unittest.main(verbosity=2)
