module main

import json2 as json
import os
import strings
import time

fn stream_command(command []string, environment map[string]string) !CommandResult {
	work := make_temp_directory(os.temp_dir(), 'vox-build-output-')!
	defer { os.rmdir_all(work) or {} }
	log := os.join_path(work, 'output')
	mut child := spawn_build_child(command, environment, os.getwd(), log, false, '', false, false)!
	defer {
		if !child.exited {
			stop_guarded_child(mut child, map[int]string{}) or { eprintln(err) }
		}
	}
	mut file := os.open(log)!
	defer { file.close() }
	mut position := i64(0)
	mut output := strings.new_builder(4096)
	mut buffer := []u8{len: 64 * 1024}
	defer {
		unsafe {
			buffer.free()
			output.free()
		}
	}
	for {
		done := child.poll(false)!
		// Seeking clears stdio's EOF state as the child appends more output.
		file.seek(position, .start)!
		for {
			count := file.read(mut buffer) or {
				if err is os.Eof { break }
				return err
			}
			if count == 0 { break }
			output.write(buffer[..count])!
			print(unsafe { tos(buffer.data, count) })
			position += count
		}
		if done { break }
		time.sleep(50 * time.millisecond)
	}
	return CommandResult{ exit_code: child.exit_code, stdout: output.str() }
}

fn file_contains(path string, marker string) !bool {
	if marker.len == 0 { return true }
	mut file := os.open(path)!
	defer { file.close() }
	mut buffer := []u8{len: 1024 * 1024 + marker.len - 1}
	defer { unsafe { buffer.free() } }
	mut tail := 0
	for {
		mut next := unsafe { buffer[tail..] }
		count := file.read(mut next) or {
			if err is os.Eof { return false }
			return err
		}
		if count == 0 { return false }
		length := tail + count
		if unsafe { tos(buffer.data, length) }.contains(marker) { return true }
		tail = if length < marker.len - 1 { length } else { marker.len - 1 }
		copy(mut buffer[..tail], buffer[length - tail..length])
	}
	return false
}

fn parallel_cli(_ string, args []string) !int {
	receipt := required_option(args, '--receipt')!
	output := required_option(args, '--output')!
	command := command_after(args, '--')!
	if command.len < 2 { return error('Expected -- V_COMPILER ... INPUT') }
	compiler := command[0]
	options := command[1..command.len - 1]
	source := command.last()
	mut record := {
		'requested': json.Any('parallel')
		'compiler':  json.Any(compiler)
		'v_prod':    json.Any('-prod' in options)
	}
	path := os.join_path(receipt, 'c-compile.json')
	marker := 'V3_PARALLEL_CC_REQUIRE_SPLIT'
	if !file_contains(compiler, marker)! {
		message := '${compiler} cannot split programs with native project headers (no ${marker} support)'
		record['mode'] = 'single'
		record['fallback'] = message
		atomic_write_json_text(path, json.encode(record))!
		println('Parallel C: ${message}; compiling one C unit.')
		return 0
	}
	mut environment := os.environ()
	environment[marker] = '1'
	result := stream_command([compiler, ...options, '-parallel-cc', '-o', output, source], environment)!
	if result.exit_code == 3 && result.stdout.contains('cannot split this program into C units') {
		if os.exists(output) { os.rm(output)! }
		mut reasons := []json.Any{}
		for line in result.stdout.split_into_lines() {
			if reasons.len >= 41 { break }
			if line.starts_with('parallel C:') || (line.starts_with('  ') && line.contains(':')) {
				reasons << json.Any(line.trim_space())
			}
		}
		record['mode'] = 'single'
		record['fallback'] = 'native code would be duplicated in every C unit'
		record['reasons'] = reasons
		atomic_write_json_text(path, json.encode(record))!
		println('Parallel C: native code cannot be split; compiling one C unit.')
		return 0
	}
	if result.exit_code != 0 {
		record['mode'] = 'failed'
		record['exit'] = result.exit_code
		atomic_write_json_text(path, json.encode(record))!
		return result.exit_code
	}
	if !os.is_file(output) {
		record['mode'] = 'failed'
		record['exit'] = 1
		record['error'] = 'the compiler reported success without ${output}'
		atomic_write_json_text(path, json.encode(record))!
		eprintln('Parallel C: the compiler reported success without ${output}')
		return 1
	}
	record['mode'] = 'parallel'
	record['units'] = json.null
	for line in result.stdout.split_into_lines() {
		if line.starts_with('parallel C: ') && line.contains(' units') {
			record['units'] = line.all_after('parallel C: ').all_before(' units').int()
			break
		}
	}
	atomic_write_json_text(path, json.encode(record))!
	return 0
}
