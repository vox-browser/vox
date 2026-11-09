#!/usr/bin/env python3
"""Capture page CSS or compare repeat parsing with the rule syntax cache on/off.

Build benchmark_stylesheet_rule_cache.v with the same staged compiler modules
and native libraries as Vox. `capture` freezes all linked stylesheets; `measure`
uses those bytes without network access, alternates fresh processes, and checks
full CSSOM plus every computed longhand digest outside the timed intervals.
This is an HTML/CSS parsing and style-computation benchmark, not a page-load or
rendering benchmark. It excludes JavaScript, layout, paint and browser startup.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
from html import escape
from html.parser import HTMLParser
import json
import os
import platform
import re
from pathlib import Path
import statistics
import subprocess
import sys
from urllib.parse import urljoin, urlsplit
from urllib.request import urlopen


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class StylesheetLinks(HTMLParser):
    def __init__(self, source, base_url):
        super().__init__(convert_charrefs=False)
        self.base_url = base_url
        self.links = []
        self.original_styles = 0
        self.base_seen = False
        self.line_starts = [0]
        for line in source.splitlines(keepends=True):
            self.line_starts.append(self.line_starts[-1] + len(line))
        self.feed(source)

    def handle_starttag(self, tag, pairs):
        attrs = dict(pairs)
        if tag == 'style':
            self.original_styles += 1
        if tag == "base" and attrs.get("href") and not self.base_seen:
            self.base_url = urljoin(self.base_url, attrs["href"])
            self.base_seen = True
        rel = attrs.get('rel', '').lower().split()
        if tag != "link" or "stylesheet" not in rel or not attrs.get("href"):
            return
        if "disabled" in attrs or "alternate" in rel or any(attrs.get(name) for name in ('title', 'nonce', 'integrity')):
            raise ValueError("Disabled/alternate/title/nonce/SRI sheets require a dedicated fixture")
        line, column = self.getpos()
        self.links.append(dict(
            url=urljoin(self.base_url, attrs["href"]), media=attrs.get("media", "all"),
            end=self.line_starts[line - 1] + column + len(self.get_starttag_text())))


def fetch(url):
    with urlopen(url, timeout=60) as response:
        if response.status != 200:
            raise ValueError(f"Unexpected HTTP status for {url}: {response.status}")
        return response.read(), response.url, {
            key: response.headers.get(key)
            for key in ("Content-Type", "ETag", "Last-Modified", "Cache-Control")}


def capture(args):
    folder = args.fixture.resolve()
    folder.mkdir(parents=True, exist_ok=True)
    if any(folder.iterdir()):
        raise ValueError("Capture destination must be empty; retain prior snapshots")
    body, url, html_headers = fetch(args.url)
    (folder / "index.html").write_bytes(body)
    markup = body.decode("utf-8")
    parsed = StylesheetLinks(markup, url)
    links = parsed.links
    urls = list(dict.fromkeys(link["url"] for link in links))
    if not urls:
        raise ValueError("No linked stylesheets found")
    with ThreadPoolExecutor(max_workers=5) as executor:
        responses = list(executor.map(fetch, urls))
    sheets, by_url = [], {}
    for index, (source_url, (css, final_url, headers)) in enumerate(zip(urls, responses)):
        name = f"{index:02d}-{Path(urlsplit(source_url).path).name}"
        if not name.endswith(".css"):
            name += ".css"
        text = css.decode("utf-8")
        if "</style" in text.lower():
            raise ValueError("CSS containing an HTML style end tag requires a dedicated fixture")
        if re.search(r'@import\b', text, re.IGNORECASE):
            raise ValueError('Imported CSS requires a dedicated fixture')
        (folder / name).write_bytes(css)
        by_url[source_url] = (text, final_url)
        sheets.append(dict(url=source_url, response_url=final_url, path=name, bytes=len(css),
                           sha256=hashlib.sha256(css).hexdigest(), headers=headers))
    for link in reversed(links):
        css, response_url = by_url[link["url"]]
        style = ('<style data-vox-benchmark-sheet="1" data-libweb-v-source-url="'
                 + escape(response_url, quote=True) + '" media="'
                 + escape(link["media"], quote=True) + '">' + css + '</style>')
        markup = markup[:link["end"]] + style + markup[link["end"]:]
    inline = folder / "inline.html"
    inline.write_text(markup)
    manifest = dict(version=1, url=url, captured_utc=datetime.now(timezone.utc).isoformat(),
                    html_sha256=digest(folder / "index.html"), html_headers=html_headers,
                    stylesheets=sheets,
                    inline=dict(path=inline.name, bytes=inline.stat().st_size,
                                sha256=digest(inline), linked_sheet_instances=len(links),
                                original_style_elements=parsed.original_styles))
    (folder / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(dict(fixture=str(folder), unique_stylesheets=len(sheets),
                          css_bytes=sum(sheet["bytes"] for sheet in sheets),
                          linked_sheet_instances=len(links)), indent=2))


def verify_fixture(folder):
    manifest = json.loads((folder / "manifest.json").read_text())
    if digest(folder / "index.html") != manifest["html_sha256"]:
        raise ValueError("HTML changed after capture")
    for item in [*manifest["stylesheets"], manifest["inline"]]:
        if digest(folder / item["path"]) != item["sha256"]:
            raise ValueError(f"Fixture changed: {item['path']}")
    return manifest


def validate_samples(samples, expected, expected_sheets, warm_repeats):
    if [sample.get("iteration") for sample in samples] != list(range(warm_repeats + 1)):
        raise ValueError("Incomplete or repeated benchmark samples")
    for sample in samples:
        if sample["sheets"] != expected_sheets or sample["rules"] <= 0 or sample["styled_elements"] <= 0:
            raise ValueError("Benchmark did not parse and style the frozen page")
        actual = {key: sample[key] for key in (
            "sheets", "rules", "elements", "styled_elements", "longhands")}
        if expected is None:
            expected = actual
        if any(expected[key] != value for key, value in actual.items()):
            raise ValueError(f"Parsed/styled page counts changed: {actual} != {expected}")
        final = sample['iteration'] == warm_repeats
        if sample.get('validated') != final:
            raise ValueError('Expensive validation must occur only after the final timed sample')
        for key in ('cssom_sha256', 'computed_sha256'):
            if not final:
                if sample[key]:
                    raise ValueError('A validation digest contaminated later timed samples')
                continue
            if not sample[key] or (key in expected and expected[key] != sample[key]):
                raise ValueError(f'CSSOM or computed style changed: {key}')
            expected[key] = sample[key]
    return expected


def measure(args):
    folder, binary, output = args.fixture.resolve(), args.binary.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        raise ValueError("Measurement destination must be empty; retain prior attempts")
    manifest = verify_fixture(folder)
    guard = Path(__file__).with_name("run_memory_bounded.py")
    source = Path(__file__).with_suffix('.v')
    build_info = json.loads(args.build_info.read_text())
    pinned = {str(path.resolve()): digest(path) for path in [binary, *args.runtime_library, guard,
              Path(__file__), source, args.build_info]}
    records, expected = [], None
    host = dict(platform=platform.platform(), machine=platform.machine(),
                processor=platform.processor(), cpu_count=os.cpu_count(),
                started_utc=datetime.now(timezone.utc).isoformat())
    cpuinfo = Path('/proc/cpuinfo')
    if cpuinfo.exists():
        host['cpu_model'] = next((line.split(':', 1)[1].strip() for line in cpuinfo.read_text().splitlines()
                                  if line.startswith('model name')), '')
    for pair in range(args.pairs):
        order = ["disabled", "enabled"] if pair % 2 == 0 else ["enabled", "disabled"]
        for mode in order:
            verify_fixture(folder)
            if any(digest(Path(path)) != sha for path, sha in pinned.items()):
                raise ValueError("Benchmark binary/library changed")
            name = f"pair-{pair:02d}-{mode}"
            environment = dict(os.environ, GC_MARKERS="1")
            environment.pop("VOX_STYLESHEET_RULE_CACHE_DIAGNOSTICS", None)
            environment.pop("VOX_DISABLE_STYLESHEET_RULE_CACHE", None)
            if mode == "disabled":
                environment["VOX_DISABLE_STYLESHEET_RULE_CACHE"] = "1"
            command = [sys.executable, str(guard), "--limit-gib", "3", "--timeout", str(args.timeout),
                       "--lock", str(output / (name + ".lock")),
                       "--report", str(output / (name + "-guard.json")), "--", str(binary),
                       str(folder / manifest["inline"]["path"]), str(args.warm_repeats), manifest['url']]
            log = output / (name + ".log")
            started = datetime.now(timezone.utc).isoformat()
            load_before = os.getloadavg()
            with log.open("w") as stream:
                result = subprocess.run(command, env=environment, stdout=stream, stderr=subprocess.STDOUT)
            samples = []
            for line in log.read_text().splitlines():
                try:
                    value = json.loads(line)
                except ValueError:
                    continue
                if isinstance(value, dict) and "parse_ns" in value:
                    samples.append(value)
            report = json.loads((output / (name + '-guard.json')).read_text())
            record = dict(pair=pair, mode=mode, exit_code=result.returncode, samples=samples, log=log.name,
                          started_utc=started, finished_utc=datetime.now(timezone.utc).isoformat(),
                          load_before=load_before, load_after=os.getloadavg(), guard=report)
            records.append(record)
            (output / "attempts.json").write_text(json.dumps(records, indent=2) + "\n")
            if result.returncode:
                raise RuntimeError(f"Benchmark failed: see {log}")
            expected = validate_samples(samples, expected, manifest["inline"]["linked_sheet_instances"]
                                        + manifest["inline"]["original_style_elements"], args.warm_repeats)
            print(f"{name}: repeat parse median {statistics.median(s['parse_ns'] for s in samples[1:]) / 1e6:.3f} ms", flush=True)
    verify_fixture(folder)
    if any(digest(Path(path)) != sha for path, sha in pinned.items()):
        raise ValueError("Benchmark binary/library changed")
    summary = dict(scope="HTML/CSS parsing and style computation; no JavaScript, layout, paint or startup",
                   input_manifest=manifest, pinned_files_sha256=pinned, build=build_info,
                   pairs=args.pairs, warm_repeats=args.warm_repeats, checks=expected, records=records,
                   host=host, finished_utc=datetime.now(timezone.utc).isoformat())
    summary["medians_ms"] = {}
    for mode in ["disabled", "enabled"]:
        selected = [record for record in records if record["mode"] == mode]
        summary["medians_ms"][mode] = {
            phase + "_" + metric: statistics.median(
                sample[metric + "_ns"] for record in selected
                for sample in (record["samples"][:1] if phase == "first" else record["samples"][1:])) / 1e6
            for phase in ["first", "warm"] for metric in ["parse", "style"]}
    summary['first_parse_scope'] = 'Fresh-process first document parse; repeated links can reuse syntax within this first document'
    disabled, enabled = summary["medians_ms"]["disabled"], summary["medians_ms"]["enabled"]
    summary["warm_parse_reduction_percent"] = 100 * (1 - enabled["warm_parse"] / disabled["warm_parse"])
    summary['median_peak_rss_bytes'] = {
        mode: statistics.median(record['guard']['observed_peak_rss_bytes'] for record in records if record['mode'] == mode)
        for mode in ['disabled', 'enabled']}
    summary['paired_medians_ms'] = []
    for pair in range(args.pairs):
        row = {'pair': pair}
        for mode in ['disabled', 'enabled']:
            samples = next(record['samples'] for record in records if record['pair'] == pair and record['mode'] == mode)
            row[mode] = {metric: statistics.median(
                sample['parse_ns'] + sample['style_ns'] if metric == 'parse_plus_style' else sample[metric + '_ns']
                for sample in samples[1:]) / 1e6 for metric in ['parse', 'style', 'parse_plus_style']}
        row['parse_saved_ms'] = row['disabled']['parse'] - row['enabled']['parse']
        row['parse_plus_style_saved_ms'] = row['disabled']['parse_plus_style'] - row['enabled']['parse_plus_style']
        row['parse_reduction_percent'] = 100 * row['parse_saved_ms'] / row['disabled']['parse']
        summary['paired_medians_ms'].append(row)
    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({key: summary[key] for key in ("medians_ms", "warm_parse_reduction_percent", "checks")}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    capture_parser = commands.add_parser("capture")
    capture_parser.add_argument("--url", default="https://github.com/")
    capture_parser.add_argument("--fixture", type=Path, required=True)
    capture_parser.set_defaults(run=capture)
    measure_parser = commands.add_parser("measure")
    measure_parser.add_argument("--fixture", type=Path, required=True)
    measure_parser.add_argument("--binary", type=Path, required=True)
    measure_parser.add_argument("--output", type=Path, required=True)
    measure_parser.add_argument("--build-info", type=Path, required=True,
                                help='JSON recording compiler/source identities, command, C/GC mode and native inputs')
    measure_parser.add_argument("--pairs", type=int, default=7)
    measure_parser.add_argument("--warm-repeats", type=int, default=2)
    measure_parser.add_argument("--timeout", type=int, default=300)
    measure_parser.add_argument("--runtime-library", type=Path, action="append", default=[])
    measure_parser.set_defaults(run=measure)
    args = parser.parse_args()
    if args.command == "measure" and (args.pairs < 1 or args.warm_repeats < 1):
        parser.error("pairs and warm-repeats must be positive")
    args.run(args)


if __name__ == "__main__":
    main()
