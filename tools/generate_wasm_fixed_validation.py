#!/usr/bin/env python3
"""Copy closed-form stack operation bodies from the pinned Wasm validator.

Only the explicit source statement forms below are accepted. Any body
with control flow, operands or context lookup is left for its separate direct
translation; no type effects are inferred from opcode names.
"""
import argparse
import hashlib
from pathlib import Path
import re

PIN = "963d46a829f3e1b79f44dba9d02afb70654300fa"
SOURCE_SHA256 = "35726520480275678490d4b4aaf600a2d1b33480d79eac99ab9b5c91d1bc405f"
KINDS = {"I32": "i32", "I64": "i64", "F32": "f32", "F64": "f64", "V128": "v128"}


def translate(body):
    body = re.sub(r"//[^\n]*", "", body)
    statements = [part.strip() for part in body.split(";") if part.strip()]
    steps = []
    constant = False
    terminal = False
    for position, statement in enumerate(statements):
        if statement == "return {}":
            if position != len(statements) - 1:
                return None
            terminal = True
        elif statement == "is_constant = true":
            constant = True
        elif match := re.fullmatch(r"stack\.append\(ValueType\(ValueType::(\w+)\)\)", statement):
            if match[1] not in KINDS:
                return None
            steps.append(f"stack.append_type(BinaryValueType{{ kind: .{KINDS[match[1]]} }})")
        elif match := re.fullmatch(r"TRY\(\(?stack\.take<([^>]+)>\(\)\)?\)", statement):
            kinds = re.findall(r"ValueType::(\w+)", match[1])
            if not kinds or re.sub(r"ValueType::\w+|\s|,", "", match[1]) or any(k not in KINDS for k in kinds):
                return None
            values = ", ".join(f".{KINDS[k]}" for k in kinds)
            steps.append(f"stack.take_kinds([BinaryValueKind{values}])!")
        elif match := re.fullmatch(r"(?:TRY\(|return )stack\.take_and_put<([^>]+)>\(ValueType::(\w+)\)\)?", statement):
            # Both accepted wrappers below are complete source statements;
            # reject partially balanced or non-terminal return forms.
            call = f"stack.take_and_put<{match[1]}>(ValueType::{match[2]})"
            if statement == "return " + call:
                if position != len(statements) - 1:
                    return None
                terminal = True
            elif statement != "TRY(" + call + ")":
                return None
            kinds = re.findall(r"ValueType::(\w+)", match[1])
            if not kinds or re.sub(r"ValueType::\w+|\s|,", "", match[1]) or any(k not in KINDS for k in kinds) or match[2] not in KINDS:
                return None
            values = ", ".join(f".{KINDS[k]}" for k in kinds)
            steps.append(f"stack.take_and_put([BinaryValueKind{values}], .{KINDS[match[2]]})!")
        else:
            return None
    if not terminal:
        return None
    return tuple(steps), constant


def generate(source):
    groups = {}
    for match in re.finditer(r"VALIDATE_INSTRUCTION\((\w+)\)\s*\{", source):
        start = match.end()
        position, depth = start, 1
        while depth:
            if source[position] == "{":
                depth += 1
            elif source[position] == "}":
                depth -= 1
            position += 1
        translated = translate(source[start:position - 1])
        if translated is not None:
            groups.setdefault(translated, []).append(match[1])
    rows = [
        "// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>",
        "// SPDX-License-Identifier: BSD-2-Clause",
        "// Generated direct statement translations; no effects inferred from names.",
        f"// Ladybird {PIN}, AbstractMachine/Validator.cpp",
        f"// Source SHA256: {hashlib.sha256(source.encode()).hexdigest()}",
        "// Regenerate with tools/generate_wasm_fixed_validation.py.",
        "module webassembly", "",
        "fn validate_binary_fixed_stack_instruction(instruction BinaryInstruction, mut stack BinaryValidationStack) !bool {",
        "\tmatch instruction.opcode {",
    ]
    for (steps, constant), names in groups.items():
        rows.append("\t\t" + ", ".join("binary_op_" + name for name in names) + " {")
        rows.extend("\t\t\t" + step for step in steps)
        rows.append("\t\t\treturn " + str(constant).lower())
        rows.append("\t\t}")
    rows += [
        "\t\telse { return error('instruction is outside the fixed-stack validation slice') }",
        "\t}", "}", "",
    ]
    return "\n".join(rows), sum(len(names) for names in groups.values())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--upstream", type=Path, default=Path.home() / "code/3rd/ladybird")
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "webassembly/fixed_stack_validation.v")
    args = parser.parse_args()
    source = (args.upstream / "Libraries/LibWasm/AbstractMachine/Validator.cpp").read_text()
    if hashlib.sha256(source.encode()).hexdigest() != SOURCE_SHA256:
        raise SystemExit("Validator.cpp differs from the pinned source; review the translation before refreshing it")
    generated, count = generate(source)
    args.output.write_text(generated)
    print(f"Copied {count} complete fixed-stack instruction bodies to {args.output}")


if __name__ == "__main__":
    main()
