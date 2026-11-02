#!/usr/bin/env python3
"""Static URL inventory of the unchanged frozen Reddit fixture.

The inventory preserves missing local assets and non-rendering outbound links.
It does not rewrite content, resolve DNS, fetch URLs, or change engine behavior.
"""
from collections import Counter
import base64
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from urllib.parse import unquote, unquote_to_bytes, urljoin, urlsplit
import xml.etree.ElementTree as ET

REPO = Path(__file__).resolve().parents[2]
FIXTURE = REPO / "pixel_tests/sites/old-reddit-worldnews"
HEX = set("0123456789abcdefABCDEF")


def escaped(text, offset):
    """Consume one CSS escape, including hex and escaped line endings."""
    index = offset + 1
    if index >= len(text):
        return "\ufffd", index
    if text[index] in HEX:
        end = index
        while end < len(text) and end - index < 6 and text[end] in HEX:
            end += 1
        code = int(text[index:end], 16)
        value = chr(code) if 0 < code <= 0x10FFFF and not 0xD800 <= code <= 0xDFFF else "\ufffd"
        if end < len(text) and text[end].isspace():
            end += 2 if text[end:end + 2] == "\r\n" else 1
        return value, end
    if text[index] in "\n\r\f":
        return "", index + (2 if text[index:index + 2] == "\r\n" else 1)
    return text[index], index + 1


def css_string(text, offset):
    quote = text[offset]
    index, output = offset + 1, []
    while index < len(text):
        char = text[index]
        if char == quote:
            return "".join(output), index + 1
        if char == "\\":
            value, index = escaped(text, index)
            output.append(value)
        else:
            output.append(char)
            index += 1
    raise ValueError("Unterminated CSS string at byte " + str(offset))


def css_urls(text):
    """Enumerate URL functions and string imports without splitting data URLs.

    Comments and ordinary strings cannot create fetches. Escaped identifiers,
    quoted parentheses and CSS escapes are handled; image-set string arguments
    are included. Namespace URLs remain metadata, not resource requests.
    """
    index, at_rule, functions = 0, "", []
    while index < len(text):
        if text.startswith("/*", index):
            end = text.find("*/", index + 2)
            if end < 0:
                raise ValueError("Unterminated CSS comment")
            index = end + 2
            continue
        char = text[index]
        if char in "\"'":
            value, index = css_string(text, index)
            if at_rule == "import" or any(name in ("image-set", "-webkit-image-set") for name in functions):
                yield value, "css-import" if at_rule == "import" else "css-image-set"
            continue
        if char == ";" or char == "{":
            at_rule = ""
        if char == ")":
            if functions:
                functions.pop()
            index += 1
            continue
        is_at = char == "@"
        if is_at:
            index += 1
        if index < len(text) and (text[index].isalnum() or text[index] in "_-\\" or ord(text[index]) >= 128):
            name = []
            while index < len(text):
                char = text[index]
                if char == "\\":
                    value, index = escaped(text, index)
                    name.append(value)
                elif char.isalnum() or char in "_-" or ord(char) >= 128:
                    name.append(char)
                    index += 1
                else:
                    break
            name = "".join(name).lower()
            if is_at:
                at_rule = name
            if index < len(text) and text[index] == "(":
                index += 1
                if name != "url":
                    functions.append(name)
                    continue
                while index < len(text) and text[index].isspace():
                    index += 1
                if index < len(text) and text[index] in "\"'":
                    value, index = css_string(text, index)
                    while index < len(text) and text[index].isspace():
                        index += 1
                    if index >= len(text) or text[index] != ")":
                        raise ValueError("Malformed quoted CSS url()")
                else:
                    value = []
                    while index < len(text) and text[index] != ")":
                        if text[index] == "\\":
                            decoded, index = escaped(text, index)
                            value.append(decoded)
                        else:
                            value.append(text[index])
                            index += 1
                    if index >= len(text):
                        raise ValueError("Unterminated CSS url()")
                    value = "".join(value).strip()
                index += 1
                yield value, "css-namespace" if at_rule == "namespace" else "css-url"
            continue
        index += 1


class InventoryHTML(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.references, self.styles, self.handlers = [], [], []
        self.base, self.scripts, self.srcsets = None, 0, []
        self.in_style, self.style_parts = False, []

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if tag == "base" and self.base is None and values.get("href"):
            self.base = values["href"]
        if tag == "script":
            self.scripts += 1
        if tag == "style":
            self.in_style, self.style_parts = True, []
        if values.get("style"):
            self.styles.append(("inline-style:" + tag, values["style"]))
        for name, value in attrs:
            if name.startswith("on"):
                self.handlers.append({"tag": tag, "event": name, "code_sha256": hashlib.sha256((value or "").encode()).hexdigest()})
            if name in ("srcset", "imagesrcset"):
                self.srcsets.append({"tag": tag, "attribute": name, "value": value})
            if name not in ("src", "href", "xlink:href", "poster", "data", "action", "ping", "background"):
                continue
            kind = "metadata"
            if name in ("src", "poster", "background") or (name == "data" and tag == "object"):
                kind = "rendering-resource"
            elif name in ("href", "xlink:href") and tag in ("image", "use", "feimage"):
                kind = "rendering-resource"
            elif tag == "link":
                relations = set(values.get("rel", "").lower().split())
                if relations & {"stylesheet", "icon", "apple-touch-icon", "preload", "modulepreload", "prefetch"}:
                    kind = "rendering-resource"
                elif relations & {"dns-prefetch", "preconnect"}:
                    kind = "network-hint"
                elif "manifest" in relations:
                    kind = "manifest-declaration"
            elif tag in ("a", "area"):
                kind = "interaction-only-link"
            elif name == "action":
                kind = "interaction-only-form"
            self.references.append({"tag": tag, "attribute": name, "relations": values.get("rel", ""),
                                    "value": value or "", "kind": kind})
        if tag == "meta" and values.get("http-equiv", "").lower() == "refresh":
            self.references.append({"tag": tag, "attribute": "content", "value": values.get("content", ""),
                                    "kind": "unsupported-refresh"})
        elif tag == "meta" and values.get("content", "").startswith(("http:", "https:", "//", "reddit:")):
            self.references.append({"tag": tag, "attribute": "content", "value": values["content"], "kind": "metadata"})

    def handle_endtag(self, tag):
        if tag == "style" and self.in_style:
            self.styles.append(("style-element", "".join(self.style_parts)))
            self.in_style = False

    def handle_data(self, data):
        if self.in_style:
            self.style_parts.append(data)


def build_inventory():
    html = FIXTURE / "index.html"
    parser = InventoryHTML()
    parser.feed(html.read_text())
    base = urljoin(html.resolve().as_uri(), parser.base or "")
    records, errors, scanned_data = [], [], set()

    def add(value, source, kind, resource_base, **extra):
        value = value.strip()
        row = {"source": source, "kind": kind, **extra}
        if value.lower().startswith("data:"):
            prefix, separator, payload = value.partition(",")
            row.update(value=prefix + ",<inline-payload>", url_sha256=hashlib.sha256(value.encode()).hexdigest(),
                       url_bytes=len(value.encode()), route="inline-data", exists=True)
            records.append(row)
            if prefix.lower().startswith("data:image/svg+xml") and separator and row["url_sha256"] not in scanned_data:
                scanned_data.add(row["url_sha256"])
                try:
                    raw = base64.b64decode(payload) if prefix.lower().endswith(";base64") else unquote_to_bytes(payload)
                    scan_svg(raw.decode("utf-8"), source + "#data-svg:" + row["url_sha256"], resource_base)
                except (ValueError, UnicodeError, ET.ParseError) as error:
                    errors.append({"source": source, "kind": "invalid-inline-svg", "error": str(error)})
            return
        absolute = urljoin(resource_base, value)
        parsed = urlsplit(absolute)
        row.update(value=value, resolved=absolute)
        if not value or value.startswith("#"):
            row.update(route="empty-or-document-fragment", exists=True)
        elif parsed.scheme in ("http", "https"):
            row.update(route="http-network" if parsed.hostname else "invalid-http-url", exists=None)
        elif parsed.scheme == "file":
            if parsed.netloc not in ("", "localhost"):
                row.update(route="file-nonlocal-authority", exists=False,
                           note="File-base scheme-relative URL does not become HTTP; native local file routes reject or fail locally")
            else:
                path = Path(unquote(parsed.path)).resolve()
                exists = path.is_file()
                row.update(route="local-file", local_path=str(path), exists=exists)
                if exists:
                    row["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
                else:
                    row["note"] = "Missing local file is retained unchanged; local resource loaders do not retry HTTP"
        else:
            row.update(route="other-scheme:" + parsed.scheme, exists=None)
        records.append(row)

    def scan_css(text, source, resource_base):
        try:
            for value, kind in css_urls(text):
                add(value, source, kind, resource_base)
        except ValueError as error:
            errors.append({"source": source, "kind": "css-inventory-error", "error": str(error)})

    def scan_svg(text, source, resource_base):
        root = ET.fromstring(text)
        for element in root.iter():
            tag = element.tag.rsplit("}", 1)[-1].lower()
            for name, value in element.attrib.items():
                name = name.rsplit("}", 1)[-1].lower()
                if name == "href":
                    add(value, source, "svg-resource" if tag in ("image", "use", "feimage") else "svg-metadata", resource_base)
                elif name == "style" or "url(" in value.lower():
                    scan_css(value, source + "#" + tag + "/" + name, resource_base)
            if tag == "style" and element.text:
                scan_css(element.text, source + "#style", resource_base)

    for item in parser.references:
        add(item["value"], "index.html", item["kind"], base,
            **{key: value for key, value in item.items() if key not in ("value", "kind")})
    for index, (kind, text) in enumerate(parser.styles):
        scan_css(text, "index.html#" + kind + ":" + str(index), base)
    for path in sorted(FIXTURE.rglob("*.css")):
        scan_css(path.read_text(), str(path.relative_to(FIXTURE)), path.resolve().as_uri())
    for path in sorted(FIXTURE.rglob("*.svg")):
        try:
            scan_svg(path.read_text(), str(path.relative_to(FIXTURE)), path.resolve().as_uri())
        except ET.ParseError as error:
            errors.append({"source": str(path.relative_to(FIXTURE)), "kind": "invalid-local-svg", "error": str(error)})
    autoload = {"rendering-resource", "css-url", "css-import", "css-image-set", "svg-resource", "manifest-declaration"}
    active_http = [row for row in records if row["kind"] in autoload and row["route"] in ("http-network", "invalid-http-url")]
    auto_handlers = [row for row in parser.handlers if row["event"] not in ("onclick", "onsubmit")]
    malformed = [row for row in records if row["kind"] == "unsupported-refresh"]
    missing = [row for row in records if row["route"] == "local-file" and row["exists"] is False and row["kind"] in autoload]
    # Malformed SVG data fails as an image, not as a network fallback. CSS syntax
    # inventory errors, executable scripts and unfamiliar automatic handlers are
    # uncertainty and therefore block an offline acceptance claim.
    blocking_errors = [row for row in errors if row["kind"] == "css-inventory-error"]
    valid = not (active_http or parser.scripts or auto_handlers or parser.srcsets or malformed or blocking_errors)
    return {"valid_for_frozen_offline_capture": valid, "fixture_url": html.resolve().as_uri(),
            "base_url": base, "script_elements": parser.scripts, "inline_handlers": parser.handlers,
            "automatic_or_unclassified_handlers": auto_handlers, "unclassified_srcsets": parser.srcsets,
            "reference_count": len(records), "counts_by_kind": dict(sorted(Counter(row["kind"] for row in records).items())),
            "counts_by_route": dict(sorted(Counter(row["route"] for row in records).items())),
            "autoload_http_references": active_http,
            "missing_local_autoload_reference_count": len(missing),
            "missing_local_autoload_unique_paths": sorted({row["local_path"] for row in missing}),
            "nonlocal_file_declarations": [row for row in records if row["route"] == "file-nonlocal-authority"],
            "errors": errors, "references": records,
            "policy": "No fixture rewriting. All HTTP(S) transports also use the same reserved non-listening loopback proxy for both variants.",
            "limitations": "Static URL inventory; interaction-only handlers/links are not exercised. Missing unused local CSS assets remain missing in both variants."}


if __name__ == "__main__":
    output = REPO / "Build/reddit-optimization/resource-network-inventory.json"
    if output.exists():
        raise SystemExit("Inventory evidence already exists: " + str(output))
    result = build_inventory()
    output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps({key: value for key, value in result.items() if key not in ("references", "inline_handlers")}))
    raise SystemExit(0 if result["valid_for_frozen_offline_capture"] else 1)
