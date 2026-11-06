"""No GitHub writes: mock read-only API results and inspect workflow wiring."""
from pathlib import Path
import re
import subprocess
import sys
import unittest

Source = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Source / 'tools'))
from CheckReleaseIdentity import CheckIdentity, RetentionError


class ApiFixture:
    def __init__(self, Release=404, Tag=404, Repository=200, Failure=None):
        self.Statuses = [Repository, Release, Tag]
        self.Requests = []
        self.Failure = Failure

    def __call__(self, Command, **Options):
        if Command[0] == 'git': return subprocess.run(Command, **Options)
        self.Requests.append(Command)
        if self.Failure is not None: raise self.Failure
        Status = self.Statuses.pop(0)
        return subprocess.CompletedProcess(Command, 0 if Status == 200 else 1, 'HTTP/2.0 %d Fixture\n\n{}' % Status, '')


class ReleaseRetentionTests(unittest.TestCase):
    def test_new_identity_uses_only_three_read_requests(self):
        Fixture = ApiFixture()
        CheckIdentity('gmoddev/GodotLuau', 'GodotLuau-v999', Fixture)
        self.assertEqual(len(Fixture.Requests), 3)
        self.assertTrue(all(Request[1:5] == ['api', '--method', 'GET', '--include'] for Request in Fixture.Requests))
        self.assertTrue(Fixture.Requests[-1][-1].endswith('/git/ref/tags/GodotLuau-v999'))

    def test_existing_release_is_retained(self):
        Fixture = ApiFixture(Release=200)
        with self.assertRaisesRegex(RetentionError, 'release already exists'):
            CheckIdentity('gmoddev/GodotLuau', 'v1', Fixture)
        self.assertEqual(len(Fixture.Requests), 2)

    def test_existing_tag_without_release_is_retained(self):
        with self.assertRaisesRegex(RetentionError, 'tag already exists'):
            CheckIdentity('gmoddev/GodotLuau', 'v1', ApiFixture(Tag=200))

    def test_unreadable_repository_is_not_absent_release(self):
        with self.assertRaisesRegex(RetentionError, 'not readable'):
            CheckIdentity('gmoddev/GodotLuau', 'v1', ApiFixture(Repository=404))

    def test_auth_permission_rate_limit_and_server_errors_block(self):
        for Status in [401, 403, 429, 500, 503]:
            with self.subTest(Status=Status), self.assertRaises(RetentionError):
                CheckIdentity('gmoddev/GodotLuau', 'v1', ApiFixture(Release=Status))

    def test_tag_query_failure_blocks(self):
        with self.assertRaises(RetentionError):
            CheckIdentity('gmoddev/GodotLuau', 'v1', ApiFixture(Tag=503))

    def test_network_failure_blocks(self):
        with self.assertRaises(RetentionError):
            CheckIdentity('gmoddev/GodotLuau', 'v1', ApiFixture(Failure=OSError('offline')))

    def test_timeout_blocks(self):
        with self.assertRaises(RetentionError):
            CheckIdentity('gmoddev/GodotLuau', 'v1', ApiFixture(Failure=subprocess.TimeoutExpired('gh', 15)))

    def test_missing_or_inconsistent_status_blocks(self):
        for Response in ['', 'HTTP/2.0 404 Not Found\n', 'HTTP/2.0 302 Found\n']:
            def Run(Command, **Options):
                if Command[0] == 'git': return subprocess.run(Command, **Options)
                return subprocess.CompletedProcess(Command, 0, Response, '')
            with self.subTest(Response=Response), self.assertRaises(RetentionError):
                CheckIdentity('gmoddev/GodotLuau', 'v1', Run)

    def test_invalid_input_never_queries_api(self):
        for Repository, Tag in [('', 'v1'), ('../repo', 'v1'), ('org/..', 'v1'), ('gmoddev/GodotLuau', ''), ('gmoddev/GodotLuau', 'bad..tag'), ('gmoddev/GodotLuau', 'tag with spaces')]:
            Fixture = ApiFixture()
            with self.subTest(Repository=Repository, Tag=Tag), self.assertRaises(RetentionError):
                CheckIdentity(Repository, Tag, Fixture)
            self.assertEqual(Fixture.Requests, [])

    def test_nested_tag_is_encoded_as_data(self):
        Fixture = ApiFixture()
        CheckIdentity('gmoddev/GodotLuau', 'release/v1', Fixture)
        self.assertTrue(Fixture.Requests[-1][-1].endswith('release%2Fv1'))

    def test_workflow_preserves_history_and_guards_before_writes(self):
        Workflow = (Source / '.github/workflows/build-release.yml').read_text(encoding='utf-8')
        self.assertNotRegex(Workflow, r'gh\s+release\s+delete|--cleanup-tag|git\s+push\s+[^\n]*--delete|git\s+tag\s+-(?:d|f)\b|--method\s+DELETE')
        self.assertIn('overwrite_files: false', Workflow)
        self.assertIn('cancel-in-progress: false', Workflow)
        self.assertIn('GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}', Workflow)
        Guard = Workflow.index('run: python3 tools/CheckReleaseIdentity.py')
        self.assertLess(Guard, Workflow.index('python3 tools/generar_release.py'))
        self.assertLess(Guard, Workflow.index('git add GodotLuau.zip'))
        self.assertLess(Guard, Workflow.index('uses: softprops/action-gh-release@v2'))
        self.assertNotRegex(Workflow, re.compile(r'^  (?:push|pull_request|pull_request_target|workflow_run|workflow_call|schedule):', re.MULTILINE))
        self.assertIn('  contents: read', Workflow)
        self.assertNotIn('contents: write', Workflow)
        self.assertEqual(Workflow.count('if: ${{ false }}'), 2)
        self.assertEqual(Workflow.count('persist-credentials: false'), 2)
        self.assertIn('workflow_dispatch:', Workflow)
        self.assertIn('unzip -o GodotLuau.zip', Workflow) # GL-010 remains explicit.


if __name__ == '__main__':
    unittest.main(verbosity=2)
