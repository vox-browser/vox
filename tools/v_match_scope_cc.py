#!/usr/bin/env python3
"""C compiler adapter for V's late-match function-scope compatibility fix."""
import os
from pathlib import Path
import re
import subprocess
import sys


def patch_compiler(source):
    pattern = re.compile(r'void ((?:v__)?transform__Transformer)__lower_remaining_matches_in_used_fns\([^\n]+\) \{.*?^\}', re.M | re.S)
    matches = list(pattern.finditer(source))
    if not matches:
        return source, False  # Ordinary native helper, not the compiler unit.
    if len(matches) != 1:
        raise RuntimeError('Ambiguous V late-match implementation')
    match = matches[0]
    body = match[0]
    if 'vox_outer_match_locals' in body:
        return source, True
    prefix = match[1]
    anchors = ['string old_file = t->cur_file;', 'epoch++;', 't->cur_file = old_file;']
    if any(body.count(anchor) != 1 for anchor in anchors):
        raise RuntimeError('Unsupported V late-match implementation; update V')
    body = body.replace(anchors[0], anchors[0] + f'''
    string vox_outer_match_fn = t->cur_fn_name;
    __typeof__(t->cur_fn_ret_type) vox_outer_match_ret = t->cur_fn_ret_type;
    __auto_type vox_outer_match_locals = {prefix}__detach_function_local_state(t);''')
    body = body.replace(anchors[1], f'''
            t->cur_file = {prefix}__node_file_or(t, i, old_file);
            {prefix}__seed_generated_fn_body_context(t, (i32)i);
            epoch++;''')
    body = body.replace(anchors[2], anchors[2] + f'''
    t->cur_fn_name = vox_outer_match_fn;
    {prefix}__set_cur_fn_ret_type(t, vox_outer_match_ret);
    {prefix}__restore_function_local_state(t, vox_outer_match_locals);''')
    return source[:match.start()] + body + source[match.end():], True


def main():
    for argument in sys.argv[1:]:
        path = Path(argument)
        if path.suffix != '.c' or not path.is_file():
            continue
        source = path.read_text()
        patched, found = patch_compiler(source)
        if found:
            path.write_text(patched)
            Path(os.environ['VOX_MATCH_SCOPE_RECEIPT']).write_text('patched\n')
    return subprocess.call([os.environ['VOX_MATCH_SCOPE_CC'], *sys.argv[1:]])


if __name__ == '__main__':
    sys.exit(main())
