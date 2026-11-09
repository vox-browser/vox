module main

import json2 as json
import os

fn parallel_fixture(body string, supported bool) !(string, string, string) {
	root := make_temp_directory(os.temp_dir(), 'vox-parallel-test-')!
	compiler := os.join_path(root, 'compiler with spaces')
	output := os.join_path(root, 'browser output')
	marker := if supported { '# V3_PARALLEL_CC_REQUIRE_SPLIT\n' } else { '' }
	parse := r'while [ "$#" -gt 0 ]; do case "$1" in -o) shift; target=$1;; esac; shift; done' + '\n'
	os.write_file(compiler, '#!/bin/sh\n' + marker + parse + body + '\n')!
	os.chmod(compiler, 0o755)!
	return root, compiler, output
}

fn parallel_arguments(root string, compiler string, output string) []string {
	return ['--receipt', root, '--output', output, '--', compiler, '-prod', 'source file.v']
}

fn parallel_record(root string) !map[string]json.Any {
	return json.parse(os.read_file(os.join_path(root, 'c-compile.json'))!)!.as_map()
}

fn parallel_field(root string, name string) !json.Any {
	record := parallel_record(root)!
	return record[name] or { return error('Missing ${name} in parallel compilation receipt') }
}

fn test_parallel_success_streams_stdout_and_stderr() ! {
	root, compiler, output := parallel_fixture(r'printf "parallel C: 2 units\n"; sleep 0.1; printf "compiler stderr\n" >&2; printf "binary" > "$target"', true)!
	defer { os.rmdir_all(root) or {} }
	assert parallel_cli(root, parallel_arguments(root, compiler, output))! == 0
	assert os.read_file(output)! == 'binary'
	assert parallel_field(root, 'mode')!.str() == 'parallel'
	assert parallel_field(root, 'units')!.int() == 2
	assert parallel_field(root, 'v_prod')!.bool()
}

fn test_incremental_output_keeps_bytes_appended_after_eof() ! {
	result := stream_command(['sh', '-c', r'printf "first\n"; sleep 0.1; printf "second\n" >&2; exit 7'], os.environ())!
	assert result.exit_code == 7
	assert result.stdout == 'first\nsecond\n'
}

fn test_parallel_fallback_requires_explicit_compiler_refusal() ! {
	root, compiler, output := parallel_fixture(r'printf "partial" > "$target"; printf "parallel C: cannot split this program into C units\n  native.h:12: static state\n"; exit 3', true)!
	defer { os.rmdir_all(root) or {} }
	assert parallel_cli(root, parallel_arguments(root, compiler, output))! == 0
	assert !os.exists(output)
	assert parallel_field(root, 'mode')!.str() == 'single'
	assert parallel_field(root, 'reasons')!.as_array().len == 2
	os.write_file(compiler, '#!/bin/sh\n# V3_PARALLEL_CC_REQUIRE_SPLIT\nexit 3\n')!
	assert parallel_cli(root, parallel_arguments(root, compiler, output))! == 3
	assert parallel_field(root, 'mode')!.str() == 'failed'
}

fn test_parallel_unsupported_compiler_is_not_invoked() ! {
	root, compiler, output := parallel_fixture('exit 97', false)!
	defer { os.rmdir_all(root) or {} }
	assert parallel_cli(root, parallel_arguments(root, compiler, output))! == 0
	assert parallel_field(root, 'mode')!.str() == 'single'
	assert !os.exists(output)
}

fn test_parallel_success_without_output_is_an_error() ! {
	root, compiler, output := parallel_fixture('exit 0', true)!
	defer { os.rmdir_all(root) or {} }
	assert parallel_cli(root, parallel_arguments(root, compiler, output))! == 1
	assert parallel_field(root, 'mode')!.str() == 'failed'
}

fn test_streamed_marker_detection_handles_chunk_boundaries() ! {
	root := make_temp_directory(os.temp_dir(), 'vox-marker-test-')!
	defer { os.rmdir_all(root) or {} }
	path := os.join_path(root, 'compiler')
	marker := 'V3_PARALLEL_CC_REQUIRE_SPLIT'
	mut file := os.create(path)!
	padding := []u8{len: 1024 * 1024 + marker.len - 5, init: `x`}
	file.write(padding)!
	file.write_string(marker + 'tail')!
	file.close()
	assert file_contains(path, marker)!
	assert !file_contains(path, 'missing marker')!
}
