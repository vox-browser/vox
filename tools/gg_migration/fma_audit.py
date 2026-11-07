#!/usr/bin/env python3
"""Fail if clang fuses multiply-adds in a module's generated C functions.

Skia is compiled with -ffp-contract=off, so V ports of its arithmetic must not
contain expressions that clang's default -ffp-contract=on turns into FMAs.
Compiles V's generated C (with the V compiler's own flags) to arm64 assembly
and reports every fmadd/fmsub/fnmadd/fnmsub instruction in functions whose
name starts with the given prefix. With --contracted-only it compiles the C a
second time with -ffp-contract=off and reports only the functions with more
fused instructions under clang's default, so explicit fma()/fmaf() calls,
which stay fused either way, are not listed.
"""
import collections
import argparse
import re
import shlex
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('c_file')
    parser.add_argument('cc_command', help='file with the C compiler command printed by v -showcc')
    parser.add_argument('--prefix', default='canvas__')
    parser.add_argument('--asm', default=None)
    parser.add_argument('--contracted-only', action='store_true')
    args = parser.parse_args()
    words = shlex.split(open(args.cc_command).read())
    keep = []
    i = 1
    while i < len(words):
        w = words[i]
        if w in ('-I', '-D', '-isystem', '-include') and i + 1 < len(words):
            keep += [w, words[i + 1]]
            i += 2
            continue
        if w.startswith(('-I', '-D', '-std=', '-fobjc', '-fwrapv')):
            keep.append(w)
        i += 1
    out = args.asm or args.c_file + '.s'
    findings = fused_instructions(keep, args.c_file, out, args.prefix, [])
    if args.contracted_only:
        explicit = collections.Counter(function for function, _ in fused_instructions(keep,
            args.c_file, out + '.nocontract.s', args.prefix, ['-ffp-contract=off']))
        counts = collections.Counter(function for function, _ in findings)
        extra = {f: n - explicit[f] for f, n in counts.items() if n > explicit[f]}
        for function, count in sorted(extra.items()):
            print(f'{function}: {count} contracted multiply-adds')
        print(f'{sum(extra.values())} contracted multiply-add instructions in {args.prefix}* functions '
              f'({sum(explicit.values())} explicit)')
        return 1 if extra else 0
    for function, instruction in findings:
        print(f'{function}: {instruction}')
    print(f'{len(findings)} fused multiply-add instructions in {args.prefix}* functions')
    return 1 if findings else 0


def fused_instructions(keep, c_file, out, prefix, extra_flags):
    command = ['clang', '-S', '-O2', '-w', '-x', 'objective-c', *keep, *extra_flags, '-o', out, c_file]
    subprocess.run(command, check=True)
    fused = re.compile(r'^\s+(fmadd|fmsub|fnmadd|fnmsub|fmla|fmls)\b')
    function = None
    findings = []
    for line in open(out):
        m = re.match(r'^(_?)([A-Za-z0-9_]+):', line)
        if m:
            # Assembler-local labels (LBB0_3, Ltmp4, Lloh12, lCPI0_0) mark
            # branch targets and constants inside the current function.
            if not m.group(1) and m.group(2).startswith(('L', 'l')):
                continue
            function = m.group(2)
            continue
        if function and function.startswith(prefix) and fused.match(line):
            findings.append((function, line.strip()))
    return findings


if __name__ == '__main__':
    sys.exit(main())
