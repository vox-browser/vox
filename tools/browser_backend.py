#!/usr/bin/env python3
"""Read the browser backend from v.mod for V drivers without manifest defaults."""
from pathlib import Path
import re
import sys


def browser_backend(root):
    source = (Path(root) / 'v.mod').read_text()
    # This is a scalar build setting, not an arbitrary compiler argument list.
    settings = re.findall(r"^\s*backend:\s*(['\"])(\w+)\1\s*,?\s*(?://[^\n]*)?$",
                          source, re.MULTILINE)
    if len(settings) != 1 or settings[0][1] not in {'c', 'fastc'}:
        raise ValueError('v.mod must declare exactly one backend: c or fastc')
    return settings[0][1]


if __name__ == '__main__':
    try:
        print(browser_backend(Path(sys.argv[1]) if len(sys.argv) > 1
                              else Path(__file__).resolve().parents[1]))
    except (OSError, ValueError) as error:
        raise SystemExit(str(error))
