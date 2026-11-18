#!/usr/bin/env python3
"""Group selected LibJS cache libraries into a fresh macOS cache."""

import argparse
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from contextlib import contextmanager
import fcntl
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

from libjs_capture_native_compiler import C_FLAGS, CLANG, captured_source, digest


SHA256 = re.compile(r"[0-9a-f]{64}")
LIBRARY = re.compile(r"[0-9a-f]{64}\.dylib")
ENTRY = re.compile(r"_vox_native_(0|[1-9][0-9]*)")
DYLD_IMAGE = re.compile(r"dyld\[([1-9][0-9]*)\]: <[^>]+> (/.+)")


def libraries_from_trace(trace, directory, pid=None):
    """Select images opened in this ABI directory by one traced process."""
    raw = trace.read_bytes()
    directory = directory.resolve()
    by_pid = defaultdict(set)
    for line in raw.decode(errors="replace").splitlines():
        match = DYLD_IMAGE.fullmatch(line)
        if match is None or (pid is not None and int(match[1]) != pid):
            continue
        path = Path(match[2])
        if LIBRARY.fullmatch(path.name) and path.parent.resolve() == directory:
            by_pid[int(match[1])].add(path.name)
    if not by_pid:
        raise ValueError(f"No native cache libraries in {trace} for {directory}")
    if len(by_pid) > 1:
        raise ValueError(f"Multiple processes loaded libraries from this cache. Use --trace-pid with {sorted(by_pid)}.")
    owner, selected = next(iter(by_pid.items()))
    return sorted(selected), dict(pid=owner, path=str(trace.resolve()), sha256=hashlib.sha256(raw).hexdigest())


def read_records(directory, abi):
    records, libraries = {}, {}
    symbols = defaultdict(set)
    for path in sorted(directory.glob("*.json")):
        with path.open("rb") as handle:
            raw = handle.read(16385)
        if len(raw) > 16384:
            raise ValueError(f"Native cache record is too large: {path.name}")
        row = json.loads(raw)
        name, sha, symbol = row["library"], row["library_sha256"], row["symbol"]
        if (not SHA256.fullmatch(path.stem) or row["key"] != path.stem or row["abi"] != abi
                or not LIBRARY.fullmatch(name) or not SHA256.fullmatch(sha)
                or type(symbol) not in (int, float) or not 0 <= symbol <= 1_000_000
                or symbol != int(symbol)):
            raise ValueError(f"Invalid native cache record: {path.name}")
        if libraries.setdefault(name, sha) != sha:
            raise ValueError(f"Conflicting library digests for {name}")
        records[path.name] = (raw, row)
        symbols[name].add(int(symbol))
    return records, libraries, symbols


def exports(path):
    output = subprocess.check_output(["/usr/bin/nm", "-gjU", str(path)], text=True)
    names = output.splitlines()
    matches = [ENTRY.fullmatch(name) for name in names]
    if not matches or not all(matches):
        raise ValueError(f"Expected only LibJS entry exports in {path.name}")
    values = {int(match[1]) for match in matches}
    if len(values) != len(names):
        raise ValueError(f"Duplicate exports in {path.name}")
    return values


def link_objects(work, inputs, expected):
    image = work / "group.dylib"
    subprocess.run([CLANG, "-dynamiclib", *map(str, inputs), "-o", str(image)], check=True)
    if exports(image) != expected:
        raise ValueError("Grouped library exports differ from the selected objects")
    return image


def link_group(source, objects, receipt, selected, libraries, symbols, work):
    by_library = {}
    for row in receipt["object_files"]:
        name = Path(row["separate"]).name
        if name in by_library:
            raise ValueError(f"Duplicate object receipt for {name}")
        by_library[name] = row
    missing = selected - by_library.keys()
    if missing:
        raise ValueError(f"Missing relocatable object receipts: {sorted(missing)}")

    expected = set()
    inputs = []
    for name in (name for name in by_library if name in selected):
        row = by_library[name]
        if row["separate_sha256"] != libraries[name]:
            raise ValueError(f"Object receipt library digest differs: {name}")
        object_name = Path(row["object"]).name
        target = work / object_name
        if target.suffix != ".o" or target.exists():
            raise ValueError(f"Invalid or repeated object file in receipt: {object_name}")
        shutil.copyfile(objects / object_name, target)
        if digest(target) != row["object_sha256"]:
            raise ValueError(f"Object digest mismatch: {object_name}")
        actual = exports(target)
        if actual != exports(source / name) or not symbols[name] <= actual:
            raise ValueError(f"Object and cache entries have different exports: {name}")
        if expected & actual:
            raise ValueError(f"Selected libraries share LibJS entry symbols: {name}")
        expected.update(actual)
        inputs.append(target)

    return link_objects(work, inputs, expected)


def compile_captured_batch(input_c, mapping, name):
    obj = input_c.with_suffix(".o")
    defines = [f"-Dvox_native_{old}=vox_native_{new}" for old, new in mapping.items()]
    subprocess.run([CLANG, *C_FLAGS, "-fPIC", *defines, "-c", str(input_c), "-o", str(obj)], check=True)
    if exports(obj) != set(mapping.values()):
        raise ValueError(f"Captured C has different exports: {name}")
    return obj


def compile_captured_batches(batches, jobs, retain):
    if not batches:
        return
    if jobs == 1:
        for batch in batches:
            retain(batch, compile_captured_batch(*batch))
        return
    with ThreadPoolExecutor(max_workers=min(jobs, len(batches))) as pool:
        futures = {pool.submit(compile_captured_batch, *batch): batch for batch in batches}
        try:
            for future in as_completed(futures):
                retain(futures[future], future.result())
        except BaseException:
            for future in futures:
                future.cancel()
            raise


def object_compiler_inputs():
    compiler = Path(subprocess.check_output(["/usr/bin/xcrun", "--find", "clang"], text=True).strip())
    return dict(flags=[*C_FLAGS, "-fPIC"], compiler_sha256=digest(compiler),
                version=subprocess.check_output([CLANG, "--version"], text=True))


@contextmanager
def locked_object_checkpoint(directory, abi, selected):
    if directory is None:
        yield None
        return
    directory.mkdir(parents=True, mode=0o700, exist_ok=True)
    with (directory / ".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        path = directory / "objects.json"
        expected = dict(abi=abi, selected=sorted(selected), compiler=object_compiler_inputs())
        receipt = json.loads(path.read_bytes()) if path.is_file() else dict(expected, verified_objects={})
        if any(receipt.get(key) != value for key, value in expected.items()):
            raise ValueError("Object checkpoint has different ABI, library selection or compiler inputs")
        if set(receipt["verified_objects"]) - selected:
            raise ValueError("Object checkpoint contains unselected libraries")
        yield receipt


def link_captured_group(source, captures, selected, libraries, symbols, work, compiler_batches, jobs,
                        checkpoint, receipt):
    exported = {name: exports(source / name) for name in sorted(selected)}
    # Keep the renamed numbers outside every original range. The preprocessor
    # then expands each definition once, without another rename matching it.
    next_symbol = max(max(numbers) for numbers in exported.values()) + 1
    if next_symbol + sum(map(len, exported.values())) - 1 > 1_000_000:
        raise ValueError("Grouped symbols would exceed the native cache record limit")
    remaps, batches, inputs, source_hashes, expected = {}, [], [], {}, set()
    saved = receipt["verified_objects"] if receipt is not None else {}
    for index, (name, original) in enumerate(exported.items()):
        if not symbols[name] <= original:
            raise ValueError(f"Capture and cache library differ: {name}")
        captured, source_sha = captured_source(captures, libraries[name])
        if compiler_batches is not None and compiler_batches.get(name) != dict(
                library_sha256=libraries[name], source_sha256=source_sha):
            raise ValueError(f"Compiler capture differs from the seed results: {name}")
        input_c = work / f"batch-{index}.c"
        mapping = {number: next_symbol + offset for offset, number in enumerate(sorted(original))}
        next_symbol += len(mapping)
        remaps[name] = mapping
        obj = input_c.with_suffix(".o")
        inputs.append(obj)
        source_hashes[name] = source_sha
        if name in saved:
            row = saved[name]
            if (row["object"] != obj.name or row["source_sha256"] != source_sha
                    or row["original_symbols"] != sorted(original)
                    or row["first_remapped_symbol"] != min(mapping.values())):
                raise ValueError(f"Checkpoint object inputs changed: {name}")
            shutil.copyfile(checkpoint / obj.name, obj)
            if digest(captured) != source_sha or digest(obj) != row["object_sha256"]:
                raise ValueError(f"Checkpoint object or captured C digest mismatch: {name}")
            if exports(obj) != set(mapping.values()):
                raise ValueError(f"Checkpoint object exports differ: {name}")
        else:
            shutil.copyfile(captured, input_c)
            if digest(input_c) != source_sha:
                raise ValueError(f"Captured C digest mismatch: {name}")
            batches.append((input_c, mapping, name))
        expected.update(mapping.values())

    def retain(batch, obj):
        if checkpoint is None:
            return
        _, mapping, name = batch
        saved_object = checkpoint / obj.name
        shutil.copyfile(obj, saved_object)
        saved[name] = dict(object=obj.name, object_sha256=digest(saved_object),
                           source_sha256=source_hashes[name], original_symbols=sorted(mapping),
                           first_remapped_symbol=min(mapping.values()))
        temporary = checkpoint / "objects.json.tmp"
        temporary.write_text(json.dumps(receipt, indent=2) + "\n")
        temporary.replace(checkpoint / "objects.json")

    compile_captured_batches(batches, jobs, retain)
    # The linker takes the same ordered inputs regardless of compile completion order.
    return link_objects(work, inputs, expected), remaps, len(batches)


def pack_cache(cache, abi, objects, receipt_path, libraries_to_group, output, *,
               captures=None, trace=None, trace_pid=None, cache_pins=None, compiler_batches=None, jobs=1,
               object_checkpoint=None):
    if sys.platform != "darwin":
        raise ValueError("Native cache grouping requires macOS")
    if type(jobs) is not int or jobs < 1 or (jobs != 1 and captures is None):
        raise ValueError("Parallel compilation requires captured C batches and a positive job count")
    if not SHA256.fullmatch(abi):
        raise ValueError("Expected a 64-character native cache ABI digest")
    if output.resolve().is_relative_to(cache.resolve()):
        raise ValueError("Choose an output outside the source cache")
    if output.exists() or output.is_symlink():
        raise FileExistsError(f"Output already exists: {output}")
    if object_checkpoint is not None:
        object_checkpoint = object_checkpoint.resolve()
        if (captures is None or object_checkpoint.is_relative_to(cache.resolve())
                or object_checkpoint.is_relative_to(output.resolve())
                or output.resolve().is_relative_to(object_checkpoint)):
            raise ValueError("Use a separate object checkpoint directory with captured C batches")
    source = cache / abi
    trace_receipt = None
    if trace is not None:
        libraries_to_group, trace_receipt = libraries_from_trace(trace, source, trace_pid)
    selected = set(libraries_to_group)
    if len(selected) < 2 or len(selected) != len(libraries_to_group):
        raise ValueError("Select at least two distinct libraries")
    records, libraries, symbols = read_records(source, abi)
    if selected - libraries.keys():
        raise ValueError(f"Selected libraries lack cache records: {sorted(selected - libraries.keys())}")
    if cache_pins is not None:
        traced_records = {name: sha for name, sha in cache_pins.items() if name.endswith(".json")}
        record_digests = {name: hashlib.sha256(raw).hexdigest() for name, (raw, _) in records.items()}
        if record_digests != traced_records or any(cache_pins.get(name) != sha for name, sha in libraries.items()):
            raise ValueError("Native cache differs from the trace results")
    for name, sha in libraries.items():
        if digest(source / name) != sha:
            raise ValueError(f"Library digest mismatch: {name}")
    if captures is None:
        receipt = json.loads(receipt_path.read_bytes())
        if receipt["abi"] != abi:
            raise ValueError("Object receipt uses a different native cache ABI")

    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".libjs-pack-", dir=output.parent) as scratch:
        work = Path(scratch)
        stage = work / abi
        stage.mkdir()
        remaps = {}
        if captures is None:
            image = link_group(source, objects, receipt, selected, libraries, symbols, work)
        else:
            with locked_object_checkpoint(object_checkpoint, abi, selected) as checkpoint_receipt:
                image, remaps, compiled = link_captured_group(source, captures, selected, libraries, symbols, work,
                    compiler_batches, jobs, object_checkpoint, checkpoint_receipt)
        sha = digest(image)
        grouped = sha + ".dylib"
        image.rename(stage / grouped)
        for name in libraries.keys() - selected:
            if name == grouped:
                raise ValueError(f"Grouped library conflicts with an existing name: {name}")
            shutil.copyfile(source / name, stage / name)
            if digest(stage / name) != libraries[name]:
                raise ValueError(f"Library changed while copying: {name}")

        grouped_entries = 0
        for name, (raw, row) in records.items():
            if row["library"] in selected:
                mapping = remaps.get(row["library"])
                row = dict(row, library=grouped, library_sha256=sha)
                if mapping is not None:
                    row["symbol"] = mapping[int(row["symbol"])]
                raw = (json.dumps(row, separators=(",", ":")) + "\n").encode()
                if len(raw) > 16384:
                    raise ValueError(f"Grouped native cache record is too large: {name}")
                grouped_entries += 1
            (stage / name).write_bytes(raw)
        current, _, _ = read_records(source, abi)
        if (current != records
                or any(digest(source / name) != pin for name, pin in libraries.items())):
            raise ValueError("Source cache changed while grouping")

        # Reserve the output just before publishing the completed ABI directory.
        # mkdir also prevents concurrent packers from replacing each other's output.
        output.mkdir(mode=0o700)
        try:
            stage.rename(output / abi)
        except OSError:
            output.rmdir()
            raise
    result = dict(abi=abi, records=len(records), grouped_records=grouped_entries,
                  libraries=len(libraries) - len(selected) + 1,
                  group_libraries=sorted(selected), group_sha256=sha, library=grouped)
    if captures is not None:
        result.update(compiler_jobs=min(jobs, compiled), compiled_objects=compiled,
                      reused_objects=len(selected) - compiled)
    if trace_receipt is not None:
        result["trace"] = trace_receipt
    return result


def benchmark_results(path):
    raw = path.read_bytes()
    report = json.loads(raw)
    if not isinstance(report, dict) or report.get("complete") is not True:
        raise ValueError(f"Incomplete benchmark results: {path}")
    return report, dict(path=str(path.resolve()), sha256=hashlib.sha256(raw).hexdigest())


def pack_from_benchmark(seed_results, trace_results, output, trace_pid=None, *, jobs=1, object_checkpoint=None):
    seed, seed_input = benchmark_results(seed_results)
    traced, trace_input = benchmark_results(trace_results)
    if seed.get("prepare_native_cache") is not True or traced.get("trace_native_libraries") is not True:
        raise ValueError("Expected compiler-capture seed results and a traced native reopen")
    seeds = [row for row in seed["attempts"] if row.get("compiler_captures")]
    reopens = [row for row in traced["attempts"] if row.get("native_library_trace")
               and (trace_pid is None or row["pid"] == trace_pid)]
    if len(seeds) != 1 or len(reopens) != 1:
        raise ValueError("Expected one compiler-capture seed and one traced attempt. Use --trace-pid to select a trace.")
    prepared, reopened = seeds[0], reopens[0]
    for row in (prepared, reopened):
        if row["engine"] != "libjs-native" or row["valid"] is not True or row["exit"] != 0:
            raise ValueError("Expected successful LibJS native cache attempts")
    captured, trace = prepared["compiler_captures"], reopened["native_library_trace"]
    abi = captured["abi"]
    cache = Path(prepared["browser_overrides"]["VOX_LIBJS_NATIVE_CACHE"]).resolve()
    if (not SHA256.fullmatch(abi) or trace["abi"] != abi or trace["pid"] != reopened["pid"]
            or Path(reopened["browser_overrides"]["VOX_LIBJS_NATIVE_CACHE"]).resolve() != cache):
        raise ValueError("Seed and trace must use the same native cache and ABI")

    folder, recorded_log = Path(reopened["folder"]), Path(trace["path"])
    if not folder.is_absolute() or folder.name in ("", "..") or recorded_log != folder / "native-library-trace.log":
        raise ValueError("Invalid benchmark trace path")
    # The benchmark directory can move with its attempt folders and logs.
    log = Path(trace_input["path"]).parent / folder.name / recorded_log.name
    source = cache / abi
    selected, log_input = libraries_from_trace(log, source, trace["pid"])
    if log_input["sha256"] != trace["sha256"] or selected != trace["libraries"]:
        raise ValueError("Loader log differs from the trace results")
    pins = {Path(path).name: sha for path, sha in traced["inputs"].items() if Path(path).parent == source}
    result = pack_cache(cache, abi, None, None, selected, output, captures=Path(captured["directory"]),
                        cache_pins=pins, compiler_batches=captured["batches"], jobs=jobs,
                        object_checkpoint=object_checkpoint)
    result.update(trace=log_input, benchmark=dict(seed=seed_input, trace=trace_input))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, help="source cache root containing the ABI directory")
    parser.add_argument("--abi", help="native cache ABI digest")
    parser.add_argument("--objects", type=Path, help="directory of retained relocatable object files")
    parser.add_argument("--receipt", type=Path, help="link receipt with object_files and ABI")
    parser.add_argument("--captures", type=Path, help="directory saved by libjs_capture_native_compiler.py")
    parser.add_argument("--seed-results", type=Path, help="GitHub benchmark results from a compiler-capture seed")
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--library", action="append", help="cache library basename to group (repeatable)")
    selection.add_argument("--trace", type=Path, help="completed DYLD_PRINT_LIBRARIES log from this cache")
    selection.add_argument("--trace-results", type=Path, help="GitHub benchmark results from a traced reopen")
    parser.add_argument("--trace-pid", type=int, help="process to select when the trace covers multiple launches")
    parser.add_argument("--output", required=True, type=Path, help="new private cache root")
    parser.add_argument("--jobs", type=int, default=1, help="maximum concurrent captured C compilers (default 1)")
    parser.add_argument("--object-checkpoint", type=Path, help="private directory for saving and reusing compiled objects")
    args = parser.parse_args()
    benchmark = args.seed_results is not None or args.trace_results is not None
    if args.jobs < 1 or (args.jobs != 1 and not (benchmark or args.captures)):
        parser.error("--jobs requires a positive compiler count and captured C batches")
    if benchmark:
        if args.seed_results is None or args.trace_results is None:
            parser.error("supply both --seed-results and --trace-results")
        if any((args.cache, args.abi, args.captures, args.objects, args.receipt)):
            parser.error("benchmark results supply the source cache, ABI, captures and trace")
    else:
        if not args.cache or not args.abi or (args.library is None and args.trace is None):
            parser.error("supply --cache, --abi, and --library or --trace")
        if args.captures is None and (args.objects is None or args.receipt is None):
            parser.error("use --captures or both --objects and --receipt")
        if args.captures is not None and (args.objects is not None or args.receipt is not None):
            parser.error("--captures is an alternative to --objects and --receipt")
    if args.trace_pid is not None and (args.trace_pid <= 0 or not (args.trace or args.trace_results)):
        parser.error("--trace-pid requires a positive PID and --trace or --trace-results")
    try:
        if benchmark:
            receipt = pack_from_benchmark(args.seed_results, args.trace_results, args.output, args.trace_pid,
                                          jobs=args.jobs, object_checkpoint=args.object_checkpoint)
        else:
            receipt = pack_cache(args.cache, args.abi, args.objects, args.receipt, args.library, args.output,
                                 captures=args.captures, trace=args.trace, trace_pid=args.trace_pid, jobs=args.jobs,
                                 object_checkpoint=args.object_checkpoint)
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        print(f"libjs_pack_native_cache: {error}", file=sys.stderr)
        return 1
    print(json.dumps(receipt, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
