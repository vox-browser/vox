#!/usr/bin/env python3
"""Copy only Brave's Reddit session into Vox's private, read-only cookie jar.

Run explicitly when the account owner wants to reuse their Brave login. Brave
decrypts its own cookies in an isolated temporary profile; no Keychain password
or cookie value is printed, and the original profile is never changed.
"""

import argparse
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import tempfile
import time
import urllib.request

from measure_browser_instructions import CDP, chrome_debugger_endpoint, stop_process


def reddit_cookie_lines(cookies):
    lines = ['# Netscape HTTP Cookie File']
    for cookie in cookies:
        domain = cookie['domain'].lower()
        if domain.lstrip('.') != 'reddit.com' and not domain.lstrip('.').endswith('.reddit.com'):
            continue
        # A Netscape jar cannot represent partition keys. Do not flatten them.
        if cookie.get('partitionKey') or cookie.get('partitionKeyOpaque'):
            continue
        if not cookie.get('session') and cookie['expires'] <= time.time():
            continue
        fields = [('#HttpOnly_' if cookie['httpOnly'] else '') + domain,
                  'TRUE' if domain.startswith('.') else 'FALSE', cookie['path'],
                  'TRUE' if cookie['secure'] else 'FALSE',
                  str(max(0, int(cookie['expires']))), cookie['name'], cookie['value']]
        if any(any(char in field for char in '\r\n\t') for field in fields):
            raise ValueError('Cookie contains a control character')
        lines.append('\t'.join(fields))
    return lines


def copy_reddit_database(source, destination):
    """Copy WAL alongside the database, then remove all unrelated cookie rows."""
    for suffix in ['', '-wal', '-shm']:
        path = source.with_name(source.name + suffix)
        if path.exists():
            shutil.copy2(path, destination.with_name(destination.name + suffix))
    with sqlite3.connect(destination) as database:
        if database.execute('PRAGMA quick_check').fetchone() != ('ok',):
            raise RuntimeError('Cookie database changed during copy; retry the import')
        database.execute("DELETE FROM cookies WHERE host_key != 'reddit.com' "
                         "AND host_key NOT LIKE '%.reddit.com'")
        database.commit()
        database.execute('VACUUM')


def export_session(binary, source, output):
    client = process = None
    with tempfile.TemporaryDirectory(prefix='vox-reddit-session-') as temporary:
        profile = Path(temporary)
        (profile / 'Default').mkdir()
        copy_reddit_database(source, profile / 'Default/Cookies')
        try:
            with (profile / 'brave.log').open('w') as log:
                process = subprocess.Popen([
                    str(binary), '--headless=new', '--no-first-run', '--no-default-browser-check',
                    '--disable-background-networking', '--disable-sync', '--remote-debugging-port=0',
                    '--user-data-dir=' + str(profile), 'about:blank'],
                    stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                deadline = time.monotonic() + 30
                while not (endpoint := chrome_debugger_endpoint(profile / 'DevToolsActivePort')):
                    if process.poll() is not None or time.monotonic() >= deadline:
                        raise RuntimeError('Isolated Brave cookie reader did not start')
                    time.sleep(.05)
                opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
                with opener.open(f'http://127.0.0.1:{endpoint[0]}/json/list', timeout=10) as response:
                    targets = json.load(response)
                client = CDP(next(t['webSocketDebuggerUrl'] for t in targets if t['type'] == 'page'))
                cookies = client.call('Network.getCookies', {
                    'urls': ['https://old.reddit.com/', 'https://www.reddit.com/']})['cookies']
                lines = reddit_cookie_lines(cookies)
                if not any(line.split('\t')[5] == 'reddit_session' for line in lines[1:]):
                    raise RuntimeError('Brave has no unexpired Reddit session; sign in there first')
                output.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
                descriptor, staged = tempfile.mkstemp(prefix='.reddit-cookies-', dir=output.parent)
                try:
                    with os.fdopen(descriptor, 'w') as jar:
                        jar.write('\n'.join(lines) + '\n')
                    os.replace(staged, output)
                finally:
                    if os.path.exists(staged):
                        os.unlink(staged)
                client.call('Browser.close')
                process.wait(timeout=10)
                return len(lines) - 1
        finally:
            if client is not None:
                client.sock.close()
            if process is not None:
                stop_process(process)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, default=Path('/Applications/Brave Browser.app/Contents/MacOS/Brave Browser'))
    parser.add_argument('--cookies', type=Path, default=Path.home() / 'Library/Application Support/BraveSoftware/Brave-Browser/Default/Cookies')
    parser.add_argument('--output', type=Path, default=Path.home() / 'Library/Application Support/Vox/imported-cookies.txt')
    args = parser.parse_args()
    count = export_session(args.binary, args.cookies, args.output)
    print(f'Imported {count} Reddit cookies into {args.output} (mode 0600).')


if __name__ == '__main__':
    main()
