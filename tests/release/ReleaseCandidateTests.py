"""Bounded candidate admission/rejection tests; no source builds or publication."""
import copy
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

Source = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Source/'tools'))
import ReleaseCandidate as Candidate


def Digest(Data): return hashlib.sha256(Data).hexdigest()


class CandidateTests(unittest.TestCase):
    def setUp(self):
        self.Temporary = tempfile.TemporaryDirectory()
        self.Root = Path(self.Temporary.name)
        self.Expected = {'Revision': 'a'*40, 'Tree': 'b'*40, 'Dependencies': Candidate.Policy['Dependencies'], 'NativeSource': {'SHA256': 'c'*64}, 'HarnessHashes': {'Fixture.gd': 'd'*64}, 'PolicySHA256': 'e'*64}

    def tearDown(self): self.Temporary.cleanup()

    def Record(self, Platform='Linux', Configuration='Release'):
        Library, Worker = Candidate.Names(Platform, Configuration)
        HostPolicy = Candidate.Load(Source/'tests/runtime/SanitizerHosts.json')
        Host = {'Exit': 0, 'Platform': Platform, 'Configuration': Configuration,
                **{Name: HostPolicy[Name] for Name in ['EngineRevision','ArchiveSHA256','SCons','QualificationPatch']},
                'RemoteAdmission': Candidate.Load(Source/'tests/runtime/RemoteAdmissionHost.json'),
                'QualificationPatchSourceSHA256LF': HostPolicy['QualificationPatch']['PatchedSHA256'],
                'ExecutableSHA256': Digest(b'unit-host')}
        return {'Schema': 1, 'Platform': Platform, 'Configuration': Configuration, 'Source': self.Expected,
                'RemoteHost': Host,
                'Toolchain': {'SCons': Candidate.Policy['SCons'], 'CompilerVersion': 'unit-fixture'}, 'Commands': [{'Exit': 0}],
                'Gates': {'Core': {'Result': 'PASS', 'Cases': 81}, 'Native': {'Result': 'PASS', 'Actors': 116}},
                'Files': {'products/'+Library: {'SHA256': Digest(Configuration.encode())}, 'products/'+Worker: {'SHA256': Digest(b'worker')}, 'evidence.zip': {}}}

    def Package(self, Change=None):
        Provenance = {'Source': self.Expected, 'Platform': 'Linux', 'Profiles': {Platform+'-'+Configuration: self.Record(Platform, Configuration) for Platform, Configuration in Candidate.Profiles},
                      'Sanitizer': {'Source': self.Expected, 'Result': 'PASS', 'Cases': 81, 'ASanSymbolVerified': True}, 'Limitations': Candidate.Policy['Limitations']}
        Files = {'GodotLuau/bin/'+Candidate.Names('Linux', Configuration)[0]: Configuration.encode() for Configuration in Candidate.Policy['Configurations']}
        Files['GodotLuau/bin/godot_luau_store_worker'] = b'worker'
        Files['GodotLuau/release-provenance.json'] = json.dumps(Provenance).encode()
        if Change: Change(Files)
        ArchivePath = self.Root/'package.zip'
        Members = {}
        with zipfile.ZipFile(ArchivePath, 'w') as Archive:
            for Name, Data in Files.items():
                Info = zipfile.ZipInfo(Name); Info.create_system = 3
                Mode = 0o755 if Name.endswith('godot_luau_store_worker') else 0o644
                Info.external_attr = (stat.S_IFREG | Mode) << 16
                Archive.writestr(Info, Data)
                Members[Name] = {'SHA256': Digest(Data), 'Bytes': len(Data), 'Mode': Mode}
        Actors = []
        for Configuration in Candidate.Policy['Configurations']:
            Directory = self.Root/'startup'/Configuration; Directory.mkdir(parents=True)
            Logs = {}
            Label = 'package-'+Configuration
            for Name, Data in [('stdout', b'[Persistence:DataStore] PASS prototype\n'), ('stderr', b'')]:
                (Directory/(Label+'.'+Name+'.log')).write_bytes(Data); Logs[Name] = Digest(Data)
            Actors.append({'Configuration': Configuration, 'Label': Label, 'Exit': 0, 'ExtensionSHA256': Digest(Configuration.encode()), 'CompanionSHA256': Digest(b'worker'), 'Logs': Logs})
        Record = {'Schema': 1, 'Result': 'PASS', 'Platform': 'Linux', 'Source': self.Expected, 'Package': {'File': 'package.zip', 'SHA256': Candidate.Hash(ArchivePath), 'Bytes': ArchivePath.stat().st_size, 'Members': Members},
                  'ProvenanceSHA256': Digest(Files['GodotLuau/release-provenance.json']), 'Startup': Actors, 'Limitations': Candidate.Policy['Limitations']}
        Candidate.Save(self.Root/'candidate.json', Record)
        return Record

    def test_complete_profile(self): Candidate.CheckProfile(self.Record(), self.Expected, 'Linux', 'Release')

    def test_stock_wrong_patch_and_profile_hosts_rejected(self):
        for Field in ['RemoteAdmission', 'EngineRevision', 'QualificationPatchSourceSHA256LF', 'Configuration']:
            Record = self.Record(); Record['RemoteHost'][Field] = 'wrong'
            with self.subTest(Field=Field), self.assertRaises(ValueError): Candidate.CheckProfile(Record, self.Expected, 'Linux', 'Release')
        Record = self.Record(); del Record['RemoteHost']
        with self.assertRaises(ValueError): Candidate.CheckProfile(Record, self.Expected, 'Linux', 'Release')

    def test_stale_mixed_revision_and_fixture_inputs(self):
        for Field in ['Revision', 'Tree', 'Dependencies', 'NativeSource', 'HarnessHashes', 'PolicySHA256']:
            Record = copy.deepcopy(self.Record()); Record['Source'][Field] = 'wrong'
            with self.subTest(Field=Field), self.assertRaisesRegex(ValueError, 'Stale or mixed'): Candidate.CheckProfile(Record, self.Expected, 'Linux', 'Release')

    def test_wrong_profile_and_missing_companion(self):
        Record = self.Record(); Record['Platform'] = 'Windows'
        with self.assertRaises(ValueError): Candidate.CheckProfile(Record, self.Expected, 'Linux', 'Release')
        Record = self.Record(); del Record['Files']['products/godot_luau_store_worker']
        with self.assertRaisesRegex(ValueError, 'companion'): Candidate.CheckProfile(Record, self.Expected, 'Linux', 'Release')

    def test_failed_skipped_incomplete_gate_and_command(self):
        for Gate in ['Core', 'Native']:
            for Status in ['FAIL', 'SKIPPED', 'TIMED_OUT', 'CANCELLED']:
                Record = copy.deepcopy(self.Record()); Record['Gates'][Gate]['Result'] = Status
                with self.subTest(Gate=Gate, Status=Status), self.assertRaises(ValueError): Candidate.CheckProfile(Record, self.Expected, 'Linux', 'Release')
        Record = copy.deepcopy(self.Record()); Record['Gates']['Core']['Cases'] = 79
        with self.assertRaises(ValueError): Candidate.CheckProfile(Record, self.Expected, 'Linux', 'Release')
        Record = self.Record(); Record['Commands'][0]['Exit'] = 1
        with self.assertRaises(ValueError): Candidate.CheckProfile(Record, self.Expected, 'Linux', 'Release')

    def test_all_required_jobs_and_all_failure_states(self):
        Good = {Name: {'result': 'success'} for Name in Candidate.Policy['RequiredJobs']}
        Candidate.CheckJobs(Good)
        for Name in Good:
            for Status in ['failure', 'skipped', 'cancelled', 'timed_out', 'in_progress', None]:
                Bad = copy.deepcopy(Good); Bad[Name]['result'] = Status
                with self.subTest(Name=Name, Status=Status), self.assertRaises(ValueError): Candidate.CheckJobs(Bad)
        del Good['Sanitizer']
        with self.assertRaises(ValueError): Candidate.CheckJobs(Good)

    def test_missing_dependency_rejected_before_build(self):
        def Git(*Arguments):
            if Arguments == ('rev-parse', 'HEAD'): return self.Expected['Revision']
            if Arguments[0] == 'status': return ''
            if Arguments[0] == 'ls-files': return ''
            return Candidate.Policy['Dependencies']['godot-cpp']
        with patch.object(Candidate, 'Source', self.Root), patch.object(Candidate, 'Git', Git):
            with self.assertRaisesRegex(ValueError, 'Missing pinned dependency'): Candidate.Identity(self.Expected['Revision'])

    def test_only_generated_objects_are_excluded_from_source_dirtiness(self):
        Tracked = {'VM/src/lvmexecute.cpp', 'src/core/register_types.cpp'}
        for Name in ['?? VM/src/lvmexecute.os', '?? VM/src/lvmexecute.windows.template_release.x86_64.obj', '?? src/core/register_types.linux.template_debug.x86_64.o']:
            self.assertTrue(Candidate.GeneratedObject(Name, Tracked))
        for Name in [' M VM/src/lvmexecute.cpp', '?? VM/src/injected.cpp', '?? VM/src/unknown.os', ' M VM/src/lvmexecute.os', '?? VM/src/lvmexecute.h']:
            self.assertFalse(Candidate.GeneratedObject(Name, Tracked))

    def test_real_zip_roundtrip_admission(self):
        self.Package()
        self.assertEqual(Candidate.CheckPackage(self.Root, self.Expected, 'Linux')['Result'], 'PASS')

    def test_corrupted_zip_and_missing_startup(self):
        Record = self.Package()
        (self.Root/'package.zip').write_bytes(b'corrupt')
        with self.assertRaisesRegex(ValueError, 'ZIP hash'): Candidate.CheckPackage(self.Root, self.Expected, 'Linux')
        Candidate.Save(self.Root/'candidate.json', Record)

    def test_tampered_product_even_with_updated_outer_hashes(self):
        self.Package(lambda Files: Files.__setitem__('GodotLuau/bin/'+Candidate.Names('Linux', 'Debug')[0], b'wrong revision library'))
        with self.assertRaisesRegex(ValueError, 'qualified source-built product'): Candidate.CheckPackage(self.Root, self.Expected, 'Linux')

    def test_missing_startup_and_tampered_log(self):
        Record = self.Package(); Record['Startup'].pop()
        Candidate.Save(self.Root/'candidate.json', Record)
        with self.assertRaisesRegex(ValueError, 'startup'): Candidate.CheckPackage(self.Root, self.Expected, 'Linux')

    def test_missing_evidence_and_unsafe_zip_fail_closed(self):
        with self.assertRaises(OSError): Candidate.CheckSanitizer(self.Root, self.Expected)
        for Index, Name in enumerate(['../escape', '/absolute', 'C:/drive', 'a\\b']):
            Archive = self.Root/(str(Index)+'.zip')
            # ZipInfo normally converts Windows separators while constructing
            # a ZIP. Assign the raw name afterward to exercise hostile input.
            with zipfile.ZipFile(Archive, 'w') as Zip:
                Entry = zipfile.ZipInfo('placeholder'); Entry.filename = Name
                Zip.writestr(Entry, b'bad')
            with self.subTest(Name=Name), self.assertRaises(ValueError): Candidate.Extract(Archive, self.Root/str(Index))
            self.assertFalse((self.Root/str(Index)).exists())

    def test_failed_and_timed_out_commands_preserve_logs(self):
        with self.assertRaises(ValueError): Candidate.Execute([sys.executable, '-c', 'raise SystemExit(7)'], self.Root/'failed.log', 5)
        with self.assertRaises(subprocess.TimeoutExpired): Candidate.Execute([sys.executable, '-c', 'import time; time.sleep(5)'], self.Root/'timeout.log', .1)
        self.assertTrue((self.Root/'failed.log').exists() and (self.Root/'timeout.log').exists())
        self.assertFalse((self.Root/'profile.json').exists())

    def test_nonpublishing_workflow_gate_wiring(self):
        Workflow = (Source/'.github/workflows/release-candidate.yml').read_text()
        self.assertIn('needs: [Policy, Profiles, Sanitizer, Packages]', Workflow)
        self.assertIn('if: ${{ always() }}', Workflow)
        self.assertIn('RC_GATE_RESULTS: ${{ toJSON(needs) }}', Workflow)
        self.assertNotRegex(Workflow, r'contents: write|id-token: write|gh release|git push|action-gh-release|secrets\.')
        self.assertIn('Configuration: [Debug, Release]', Workflow)
        self.assertIn('Platform: [Windows, Linux]', Workflow)
        self.assertIn('ref: ${{ github.sha }}', Workflow)

    def test_profile_artifact_preserves_packaging_input_root(self):
        Workflow = (Source/'.github/workflows/release-candidate.yml').read_text()
        Upload = Workflow.split('name: Retain profile products and complete diagnostics\n', 1)[1].split('      - name:', 1)[0]
        Paths = Upload.split('          path: |\n', 1)[1].splitlines()
        self.assertTrue(Paths)
        self.assertTrue(all(Line.strip().startswith('${{ runner.temp }}/profile/') for Line in Paths if Line.strip()),
                        'Outside paths change the artifact common root and break profile.json admission')
        self.assertIn('name: host-${{ matrix.Platform }}-${{ matrix.Configuration }}', Workflow)


if __name__ == '__main__': unittest.main(verbosity=2)
