#!/usr/bin/env python3
"""CI helper (IntelliTile Intel port): print the crashed thread of recent macOS crash reports.

Reads ~/Library/Logs/DiagnosticReports/*.ips written in the last N minutes (default 90) and
prints the exception, application-specific info and the top frames of the triggered thread.
Read-only; used by .github/workflows/intel-macos.yml when unit tests fail.
"""
import glob, json, os, sys, time

minutes = int(sys.argv[1]) if len(sys.argv) > 1 else 90
paths = glob.glob(os.path.expanduser('~/Library/Logs/DiagnosticReports/*.ips'))
recent = [p for p in paths if time.time() - os.path.getmtime(p) < minutes * 60]
print(f"crash reports in the last {minutes} min: {len(recent)}")
for p in sorted(recent, key=os.path.getmtime):
    try:
        with open(p, encoding='utf-8', errors='replace') as f:
            header = json.loads(f.readline())
            body = json.loads(f.read())
    except Exception as e:  # not a JSON .ips (e.g. a hang/cpu report in text form)
        print(f"== {os.path.basename(p)}: unreadable ({e})")
        continue
    print(f"== {os.path.basename(p)}  proc={body.get('procName')}  bug_type={header.get('bug_type')}")
    for key in ('exception', 'termination', 'asi', 'lastExceptionBacktrace'):
        if key in body:
            print(f"  {key}: {json.dumps(body[key])[:1500]}")
    images = body.get('usedImages', [])
    # Which test code was on any thread at the time (attributes a crash on a renderer thread).
    in_flight = set()
    for t in body.get('threads', []):
        for fr in t.get('frames', []):
            i = fr.get('imageIndex', -1)
            if 0 <= i < len(images) and 'DockTileTests' in images[i].get('name', '') and fr.get('symbol'):
                in_flight.add(fr['symbol'])
    for sym in sorted(in_flight):
        print(f"  test frame on some thread: {sym[:200]}")
    for t in body.get('threads', []):
        if not t.get('triggered'):
            continue
        print(f"  triggered thread: {t.get('name') or t.get('queue') or t.get('id')}")
        for fr in t.get('frames', [])[:40]:
            img = images[fr['imageIndex']].get('name', '?') if fr.get('imageIndex', -1) < len(images) else '?'
            loc = f" {fr.get('sourceFile')}:{fr.get('sourceLine')}" if fr.get('sourceFile') else ''
            print(f"    {img:28.28} {fr.get('symbol', hex(fr.get('imageOffset', 0)))}{loc}")
