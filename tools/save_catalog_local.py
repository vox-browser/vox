#!/usr/bin/env python3
"""Export a sealed, static catalog archive as one offline HTML file.

No server, proxy, download, or browser build is involved. Scripts are removed;
render resources must exist in the verified archive and become data URLs. The
receipt retains the archive's comparison policy (including frozen animation).
"""

import argparse
import base64
import html
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from urllib.parse import urldefrag, urljoin, urlsplit

from page_archive import digest, load_archive, mime

CSP = ("default-src 'none'; img-src data:; style-src 'unsafe-inline' data:; "
       "font-src data:; base-uri 'none'; form-action 'none'")
# Match comments/strings before URL tokens, so examples inside them stay inert.
CSS_TOKEN = re.compile(
    r'/\*.*?\*/|@import\s+(?P<import>"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\')|'
    r'url\(\s*(?P<url>"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|[^)\s]*)\s*\)|'
    r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', re.I | re.S)


def attributes(attrs):
    return ''.join(' ' + k + ('="' + html.escape(v, quote=True) + '"' if v is not None else '')
                   for k, v in attrs)


class Exporter(HTMLParser):
    def __init__(self, archive):
        super().__init__(convert_charrefs=False)
        self.archive = archive.resolve()
        self.manifest = load_archive(self.archive)
        self.base = self.manifest['url']
        self.used, self.cache, self.active = {}, {}, set()
        self.output = []
        self.in_style = False
        self.skip_script = False

    def body(self, url):
        entry = self.manifest['responses'].get(url)
        if entry is None:
            raise ValueError('Missing archived resource: ' + url)
        self.used[url] = dict(sha256=entry['sha256'], bytes=entry['bytes'], status=entry['status'])
        return (self.archive / 'bodies' / entry['sha256']).read_bytes(), mime(entry['headers'])

    def resource(self, value, base, css=False):
        if not value or value.startswith(('#', 'data:')):
            return value
        url, fragment = urldefrag(urljoin(base, value))
        if urlsplit(url).scheme not in {'http', 'https'}:
            raise ValueError('Unsupported resource URL: ' + url)
        key = (url, css)
        if key in self.active:
            raise ValueError('Cyclic stylesheet import: ' + url)
        if key not in self.cache:
            self.active.add(key)
            body, content_type = self.body(url)
            if css:
                body = self.css(body.decode('utf-8'), url).encode('utf-8')
                content_type = 'text/css;charset=utf-8'
            else:
                content_type = content_type.split(';')[0] or 'application/octet-stream'
            self.cache[key] = 'data:' + content_type + ';base64,' + base64.b64encode(body).decode('ascii')
            self.active.remove(key)
        return self.cache[key] + ('#' + fragment if fragment else '')

    def css(self, text, base):
        def replace(match):
            value = match['import'] if match['import'] is not None else match['url']
            if value is None:
                return match[0]
            if value.startswith(('"', "'")):
                value = value[1:-1]
            # This exporter deliberately fails on unsupported syntax instead of
            # leaving a relative URL that would change meaning under file://.
            if '\\' in value:
                raise ValueError('Escaped CSS resource URL is unsupported')
            embedded = self.resource(value, base, css=match['import'] is not None or
                                     text[:match.start()].rstrip().lower().endswith('@import'))
            return ('@import "' + embedded + '"' if match['import'] is not None else
                    'url("' + embedded + '")')
        return CSS_TOKEN.sub(replace, text)

    def handle_starttag(self, tag, attrs):
        if self.skip_script:
            return
        a = dict(attrs)
        if tag == 'script':
            self.skip_script = True
            return
        if tag == 'base':
            if a.get('href'):
                self.base = urljoin(self.base, a['href'])
            return
        if tag == 'meta' and a.get('http-equiv', '').lower() in {
                'refresh', 'content-security-policy'}:
            return
        if tag in {'object', 'embed', 'frame', 'applet'}:
            raise ValueError('Unsupported active element: ' + tag)
        if tag == 'link':
            rel = set(a.get('rel', '').lower().split())
            if 'stylesheet' in rel and a.get('href'):
                url = urljoin(self.base, a['href'])
                body, _ = self.body(url)
                style_attrs = [(k, v) for k, v in attrs if k in {'id', 'class', 'media', 'title'}]
                css = self.css(body.decode('utf-8'), url).replace('</style', '<\\/style')
                self.output.append('<style' + attributes(style_attrs) + '>' + css + '</style>')
                return
            if rel & {'preload', 'modulepreload', 'prefetch', 'dns-prefetch', 'preconnect', 'prerender'}:
                return
        rewritten = []
        for key, value in attrs:
            if key.startswith('on') or key in {'ping', 'srcdoc', 'integrity', 'crossorigin', 'attributionsrc'}:
                continue
            if value:
                if key == 'srcset':
                    # No responsive sources occur in the catalog. Never silently
                    # select a different image or leave remote candidates behind.
                    raise ValueError('Responsive srcset is unsupported')
                if key == 'src' and tag == 'iframe':
                    value = 'about:blank'
                elif key in {'src', 'poster', 'background'} or (key == 'href' and tag == 'link'
                        and set(a.get('rel', '').lower().split()) & {'icon', 'apple-touch-icon'}):
                    value = self.resource(value, self.base)
                elif key == 'style':
                    value = self.css(value, self.base)
                elif key == 'loading' and tag == 'img':
                    # Every byte is already local. Decode the whole frozen
                    # catalog before checking any viewport, including its end.
                    value = 'eager'
                elif key in {'href', 'action'}:
                    if value.lower().startswith('javascript:'):
                        value = '#'
                    elif not value.startswith('#'):
                        value = urljoin(self.base, value)
            rewritten.append((key, value))
        self.output.append('<' + tag + attributes(rewritten) + '>')
        if tag == 'head':
            self.output.append('<meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="' +
                               html.escape(CSP, quote=True) + '">')
        self.in_style = tag == 'style' or self.in_style

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)

    def handle_endtag(self, tag):
        if tag == 'script':
            self.skip_script = False
            return
        if self.skip_script or tag == 'base':
            return
        self.output.append('</' + tag + '>')
        if tag == 'style':
            self.in_style = False

    def handle_data(self, data):
        if not self.skip_script:
            self.output.append(self.css(data, self.base) if self.in_style else data)

    def handle_entityref(self, name):
        self.handle_data('&' + name + ';')

    def handle_charref(self, name):
        self.handle_data('&#' + name + ';')

    def handle_decl(self, decl):
        self.output.append('<!' + decl + '>')

    def handle_comment(self, data):
        if not self.skip_script:
            self.output.append('<!--' + data + '-->')

    def render(self):
        body, content_type = self.body(self.manifest['url'])
        if 'text/html' not in content_type:
            raise ValueError('Archive root must be HTML')
        self.feed(body.decode('utf-8'))
        self.close()
        return ''.join(self.output).encode('utf-8')


def save(archive, output):
    exporter = Exporter(archive)
    body = exporter.render()
    receipt = dict(source_url=exporter.manifest['url'],
                   captured_unix=exporter.manifest['captured_unix'],
                   archive=str(archive.resolve()),
                   archive_manifest_sha256=digest((archive / 'manifest.json').read_bytes()),
                   comparison_policy=exporter.manifest.get('comparison_policy'),
                   offline_policy='Static DOM; scripts removed; render resources embedded; images eager; CSP denies network.',
                   output=str(output.resolve()), sha256=digest(body), bytes=len(body),
                   resources=exporter.used)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open('xb') as file:
        file.write(body)
    output.with_suffix('.json').write_text(json.dumps(receipt, indent=2) + '\n')
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    receipt = save(args.archive, args.output)
    print(f"Saved {receipt['bytes']} bytes, {len(receipt['resources'])} archived resources: {args.output}")


if __name__ == '__main__':
    main()
