"""Read-only release admission: refuse reuse or unverifiable release/tag identity."""
import argparse
import os
import re
import subprocess
from urllib.parse import quote


class RetentionError(RuntimeError):
    pass


def GetStatus(Path, Run):
    try:
        Result = Run(['gh', 'api', '--method', 'GET', '--include', Path],
                     capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired) as Error:
        raise RetentionError('Cannot verify release identity; publication is blocked.') from Error
    Statuses = re.findall(r'^HTTP/\S+\s+(\d{3})\b', Result.stdout, re.MULTILINE)
    if not Statuses:
        raise RetentionError('Missing API status; publication is blocked.')
    Status = int(Statuses[-1])
    if (Status == 200 and Result.returncode == 0) or (Status == 404 and Result.returncode != 0): return Status
    raise RetentionError('API verification failed (HTTP %d); publication is blocked.' % Status)


def CheckIdentity(Repository, Tag, Run=subprocess.run):
    if not Repository or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_.-]+', Repository) or Repository.split('/')[-1] in ['.', '..']:
        raise RetentionError('A valid owner/repository is required.')
    if not Tag:
        raise RetentionError('A new release tag is required.')
    try:
        Valid = Run(['git', 'check-ref-format', 'refs/tags/' + Tag], capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired) as Error:
        raise RetentionError('Cannot validate the release tag.') from Error
    if Valid.returncode != 0: raise RetentionError('Invalid release tag.')
    Base = 'repos/' + Repository
    # Distinguish an unreadable/missing repository from absent release identities.
    if GetStatus(Base, Run) != 200: raise RetentionError('Repository is not readable; publication is blocked.')
    Encoded = quote(Tag, safe='')
    for Kind, Path in [('release', Base + '/releases/tags/' + Encoded),
                       ('tag', Base + '/git/ref/tags/' + Encoded)]:
        if GetStatus(Path, Run) != 404:
            raise RetentionError('The %s already exists; preserve it and choose a new Version.' % Kind)


def Main():
    Parser = argparse.ArgumentParser()
    Parser.add_argument('--repository', default=os.environ.get('GITHUB_REPOSITORY'))
    Parser.add_argument('--tag', default=os.environ.get('RELEASE_TAG'))
    Args = Parser.parse_args()
    try:
        if not (os.environ.get('GH_TOKEN') or os.environ.get('GITHUB_TOKEN')):
            raise RetentionError('An authenticated read check is required before publication.')
        CheckIdentity(Args.repository, Args.tag)
    except RetentionError as Error:
        print('[Release:Retention] ' + str(Error))
        return 1
    print('[Release:Retention] New release/tag identity verified; historical publications are retained.')
    return 0


if __name__ == '__main__':
    raise SystemExit(Main())
