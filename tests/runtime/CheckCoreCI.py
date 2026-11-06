"""Require discovery and completion of the existing production-core CTest suite."""
import argparse
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET


def CheckDiscovery(Report):
    Tests = json.loads(Report.read_text(encoding='utf-8'))['tests']
    if [Test['name'] for Test in Tests] != ['ExecutionDomains']:
        raise ValueError('Expected exactly the ExecutionDomains CTest entry.')


def CheckReport(Report):
    Tests = list(ET.parse(Report).getroot().iter('testcase'))
    if len(Tests) != 1 or Tests[0].get('name') != 'ExecutionDomains':
        raise ValueError('Missing or unexpected production-core result.')
    Test = Tests[0]
    if Test.get('status') != 'run' or any(Test.find(Name) is not None for Name in ['failure', 'error', 'skipped']):
        raise ValueError('Production-core execution did not pass.')
    Output = Test.findtext('system-out', '')
    Cases = re.findall(r'^\[Runtime:Test\] PASS (.+)$', Output, re.MULTILINE)
    if len(Cases) != 72 or len(set(Cases)) != 72 or '[Runtime:Test] 72 passed, 0 failed' not in Output or '[Runtime:Test] FAIL ' in Output:
        raise ValueError('Expected completion of all 72 distinct production-core cases.')


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    Parser.add_argument('mode', choices=['discovery', 'report'])
    Parser.add_argument('path', type=Path)
    Args = Parser.parse_args()
    try:
        (CheckDiscovery if Args.mode == 'discovery' else CheckReport)(Args.path)
    except (OSError, ValueError, KeyError, TypeError, ET.ParseError) as Error:
        print('[Runtime:CI] ' + str(Error))
        return 1
    print('[Runtime:CI] PASS ' + Args.mode)
    return 0


if __name__ == '__main__':
    raise SystemExit(Main())
