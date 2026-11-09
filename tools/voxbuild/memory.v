module main

import json2 as json
import math
import os
import strconv
import time

#include "@DIR/supervisor_native.h"

fn C.vox_build_native_error() &char
fn C.vox_build_restore_caller_vexe() i32
fn C.vox_build_lock(&char, i32) i32
fn C.vox_build_unlock(i32)
fn C.vox_build_create_exclusive(&char) i32
fn C.vox_build_write_all(i32, &char, i64) i32
fn C.vox_build_close(i32) i32
fn C.vox_build_process_snapshot(&i32) &char
fn C.vox_build_free_snapshot(&char)
fn C.vox_build_replace(&char, &char) i32
fn C.vox_build_exchange(&char, &char) i32
fn C.vox_build_spawn(&&char, &&char, &char, &char, i32, &char, i64, i32) i32
fn C.vox_build_poll(i32, &i32, i32) i32
fn C.vox_build_kill(i32, i32) i32
fn C.vox_build_signals_begin() i32
fn C.vox_build_interrupted() i32
fn C.vox_build_signals_end()
fn C.vox_build_terminate(i32) i32

struct FileLock {
mut:
	fd       int = -1
	acquired bool
}

fn native_build_error(context string) IError {
	return error('${context}: ${unsafe { cstring_to_vstring(C.vox_build_native_error()) }}')
}

fn restore_build_environment() ! {
	if C.vox_build_restore_caller_vexe() != 0 {
		return native_build_error('Cannot restore caller VEXE')
	}
}

fn acquire_file_lock(path string, nonblocking bool) !FileLock {
	os.mkdir_all(os.dir(path))!
	fd := int(C.vox_build_lock(&char(path.str), i32(nonblocking)))
	if fd == -2 {
		return FileLock{}
	}
	if fd < 0 {
		return native_build_error('Cannot lock ${path}')
	}
	return FileLock{ fd: fd, acquired: true }
}

fn (mut held FileLock) release() {
	if held.fd >= 0 {
		C.vox_build_unlock(i32(held.fd))
		held.fd = -1
		held.acquired = false
	}
}

struct BuildChild {
mut:
	pid       int
	exited    bool
	exit_code int
}

fn spawn_build_child(command []string, environment map[string]string, cwd string, log string,
	append bool, input string, has_input bool, background bool) !BuildChild {
	if command.len == 0 {
		return error('Cannot launch an empty build command')
	}
	mut argv := []&char{cap: command.len + 1}
	for argument in command { argv << &char(argument.str) }
	argv << unsafe { &char(nil) }
	mut env_strings := []string{cap: environment.len}
	for name, value in environment { env_strings << '${name}=${value}' }
	mut envp := []&char{cap: env_strings.len + 1}
	for value in env_strings { envp << &char(value.str) }
	envp << unsafe { &char(nil) }
	pid := int(C.vox_build_spawn(&&char(argv.data), &&char(envp.data), &char(cwd.str),
		&char(log.str), i32(append), &char(input.str), if has_input {
			i64(input.len)
		} else {
			i64(-1)
		}, i32(background)))
	if pid < 0 { return native_build_error('Cannot launch ${command[0]}') }
	return BuildChild{ pid: pid }
}

fn (mut child BuildChild) poll(blocking bool) !bool {
	if child.exited { return true }
	code := unsafe { &i32(malloc(sizeof(i32))) }
	defer { unsafe { free(code) } }
	result := C.vox_build_poll(i32(child.pid), code, i32(blocking))
	if result < 0 { return native_build_error('Cannot wait for build process ${child.pid}') }
	if result > 0 {
		child.exited = true
		child.exit_code = int(*code)
	}
	return child.exited
}

struct GuardProcess {
	parent  int
	group   int
	rss     u64
	started string
}

struct AdoptedProcess {
	pid     int
	started string
}

fn process_snapshot() !map[int]GuardProcess {
	exit_code := unsafe { &i32(malloc(sizeof(i32))) }
	defer { unsafe { free(exit_code) } }
	buffer := C.vox_build_process_snapshot(exit_code)
	if buffer == unsafe { nil } { return native_build_error('Cannot capture process snapshot') }
	defer { C.vox_build_free_snapshot(buffer) }
	output := unsafe { buffer.vstring() }
	if *exit_code != 0 { return error('Process snapshot failed (exit ${*exit_code}): ${output}') }
	mut lines := output.split_into_lines()
	defer { unsafe { lines.free() } }
	mut processes := map[int]GuardProcess{}
	for line in lines {
		pid, row := parse_guard_process(line) or {
			free_process_snapshot(mut processes)
			return err
		}
		if pid != 0 { processes[pid] = row }
	}
	return processes
}

fn parse_guard_process(line string) !(int, GuardProcess) {
	mut fields := line.fields()
	defer { unsafe { fields.free() } }
	if fields.len == 0 { return 0, GuardProcess{} }
	if fields.len < 10 { return error('Invalid process snapshot row: ${line}') }
	if fields[4].starts_with('Z') { return 0, GuardProcess{} }
	return strconv.atoi(fields[0])!, GuardProcess{
		parent:  strconv.atoi(fields[1])!
		group:   strconv.atoi(fields[2])!
		rss:     u64(strconv.atoi(fields[3])!) * 1024
		started: fields[5..].join(' ')
	}
}

fn free_process_snapshot(mut processes map[int]GuardProcess) {
	for _, row in processes {
		unsafe { row.started.free() }
	}
	unsafe { processes.free() }
}

fn free_process_identities(mut processes map[int]string) {
	for _, started in processes {
		unsafe { started.free() }
	}
	unsafe { processes.free() }
}

fn normalized_process_start(started string) string {
	mut fields := started.fields()
	defer { unsafe { fields.free() } }
	return fields.join(' ')
}

fn read_adopted_processes(path string) !map[int]string {
	mut result := map[int]string{}
	if path == '' || !os.exists(path) { return result }
	text := os.read_file(path)!
	defer { unsafe { text.free() } }
	mut rows := json.decode[[]AdoptedProcess](text)!
	defer {
		for row in rows {
			unsafe { row.started.free() }
		}
		unsafe { rows.free() }
	}
	for row in rows {
		started := normalized_process_start(row.started)
		if row.pid <= 1 || row.pid == os.getpid() || started == '' {
			unsafe { started.free() }
			free_process_identities(mut result)
			return error('Invalid adopted process identity')
		}
		if previous := result[row.pid] { unsafe { previous.free() } }
		result[row.pid] = started
	}
	return result
}

fn job_processes(snapshot map[int]GuardProcess, root int, previous map[int]string,
	adopted map[int]string) map[int]string {
	mut owned := map[int]string{}
	for pid, row in snapshot {
		if pid == root || row.group == root || previous[pid] == row.started || adopted[pid] == row.started {
			owned[pid] = row.started.clone()
		}
	}
	for {
		mut added := false
		for pid, row in snapshot {
			if pid !in owned && row.parent in owned {
				owned[pid] = row.started.clone()
				added = true
			}
		}
		if !added { return owned }
	}
	return owned
}

fn stop_guarded_child(mut child BuildChild, owned map[int]string) ! {
	mut snapshot := process_snapshot() or { map[int]GuardProcess{} }
	defer { free_process_snapshot(mut snapshot) }
	for pid, started in owned {
		if pid in snapshot && snapshot[pid].started == started {
			C.vox_build_kill(i32(pid), 0)
		}
	}
	// The initial group also covers children started after the last sample.
	C.vox_build_kill(i32(child.pid), 1)
	child.poll(true)!
}

struct GuardSample {
	rss            u64
	adoption_error string
mut:
	owned   map[int]string
	adopted map[int]string
}

fn sample_guarded_processes(root int, previous map[int]string, adopt_path string) !&GuardSample {
	mut snapshot := process_snapshot()!
	defer { free_process_snapshot(mut snapshot) }
	mut adopted := read_adopted_processes(adopt_path) or {
		return &GuardSample{ adoption_error: err.msg() }
	}
	defer { free_process_identities(mut adopted) }
	owned := job_processes(snapshot, root, previous, adopted)
	mut seen := map[int]string{}
	for pid, started in adopted {
		if pid in snapshot && snapshot[pid].started == started { seen[pid] = started.clone() }
	}
	mut rss := u64(0)
	for pid, _ in owned { rss += snapshot[pid].rss }
	return &GuardSample{ owned: owned, adopted: seen, rss: rss }
}

struct GuardResult {
mut:
	command                 []string
	reason                  string = 'completed'
	child_exit_code         int
	adopted_processes       map[int]string
	adoption_error          string
	limit_bytes             u64
	observed_peak_rss_bytes u64
	elapsed_seconds         f64
}

fn guard_result_json(result GuardResult) string {
	mut command := []json.Any{}
	for argument in result.command { command << json.Any(argument) }
	mut adopted := map[string]json.Any{}
	for pid, started in result.adopted_processes { adopted[pid.str()] = started }
	mut record := map[string]json.Any{}
	record['command'] = command
	record['reason'] = result.reason
	if result.reason == 'busy' { return json.encode(record) }
	record['child_exit_code'] = result.child_exit_code
	record['adopted_processes'] = adopted
	record['adoption_error'] = if result.adoption_error == '' {
		json.Any(json.null)
	} else {
		json.Any(result.adoption_error)
	}
	record['limit_bytes'] = result.limit_bytes
	record['observed_peak_rss_bytes'] = result.observed_peak_rss_bytes
	record['elapsed_seconds'] = result.elapsed_seconds
	record['metric'] = 'sampled sum of process-tree RSS; shared pages may be counted twice'
	return json.encode(record)
}

fn run_memory_guard(command []string, limit_bytes u64, timeout f64, interval f64,
	adopt_path string) !GuardResult {
	if C.vox_build_signals_begin() != 0 {
		return native_build_error('Cannot install memory guard signal handlers')
	}
	defer { C.vox_build_signals_end() }
	start := time.sys_mono_now()
	mut child := spawn_build_child(command, os.environ(), '', '', false, '', false, false)!
	mut owned := map[int]string{}
	defer { free_process_identities(mut owned) }
	mut result := GuardResult{ command: command, limit_bytes: limit_bytes }
	mut cleaned := false
	defer { if !cleaned { stop_guarded_child(mut child, owned) or { eprintln(err) } } }
	for {
		if C.vox_build_interrupted() != 0 {
			result.reason = 'interrupted'
			break
		}
		mut sample := sample_guarded_processes(child.pid, owned, adopt_path)!
		if sample.adoption_error != '' {
			result.reason = 'adoption_error'
			result.adoption_error = sample.adoption_error
			free_process_identities(mut sample.owned)
			free_process_identities(mut sample.adopted)
			unsafe { free(sample) }
			break
		}
		for pid, started in sample.adopted {
			if previous := result.adopted_processes[pid] { unsafe { previous.free() } }
			result.adopted_processes[pid] = started.clone()
		}
		free_process_identities(mut sample.adopted)
		free_process_identities(mut owned)
		owned = sample.owned.move()
		// map.move creates an empty replacement; release that storage too.
		free_process_identities(mut sample.owned)
		if sample.rss > result.observed_peak_rss_bytes {
			result.observed_peak_rss_bytes = sample.rss
		}
		unsafe { free(sample) }
		if result.observed_peak_rss_bytes > limit_bytes {
			result.reason = 'memory_limit'
			break
		}
		if f64(time.sys_mono_now() - start) / 1e9 > timeout {
			result.reason = 'timeout'
			break
		}
		if child.poll(false)! {
			mut final_snapshot := process_snapshot()!
			mut remaining := job_processes(final_snapshot, child.pid, owned, result.adopted_processes)
			free_process_snapshot(mut final_snapshot)
			free_process_identities(mut owned)
			owned = remaining.move()
			free_process_identities(mut remaining)
			if started := owned[child.pid] { unsafe { started.free() } }
			owned.delete(child.pid)
			if owned.len > 0 { result.reason = 'remaining_children' }
			break
		}
		time.sleep(time.Duration(interval * f64(time.second)))
	}
	stop_guarded_child(mut child, owned)!
	cleaned = true
	result.child_exit_code = child.exit_code
	result.elapsed_seconds = f64(time.sys_mono_now() - start) / 1e9
	return result
}

fn positive_guard_number(text string) !f64 {
	value := strconv.atof64(text)!
	if value <= 0 || math.is_nan(value) || math.is_inf(value, 0) {
		return error('Memory guard options must be finite and positive')
	}
	return value
}

fn memory_guard(repo string, args []string) !int {
	mut limit_gib := 12.0
	mut timeout := 1800.0
	mut interval := 0.1
	mut report := ''
	mut adopt_path := ''
	mut lock_path := os.join_path(repo, 'Build', '.memory-bounded.lock')
	mut command := []string{}
	mut index := 0
	for index < args.len {
		option := args[index]
		if option == '--' {
			command = args[index + 1..].clone()
			break
		}
		if !option.starts_with('--') {
			command = args[index..].clone()
			break
		}
		if index + 1 >= args.len { return error('Missing value for ${option}') }
		value := args[index + 1]
		match option {
			'--limit-gib' { limit_gib = positive_guard_number(value)! }
			'--timeout' { timeout = positive_guard_number(value)! }
			'--interval' { interval = positive_guard_number(value)! }
			'--report' { report = value }
			'--lock' { lock_path = value }
			'--adopt-pids-from' { adopt_path = value }
			else { return error('Unknown memory guard option: ${option}') }
		}
		index += 2
	}
	if report == '' || command.len == 0 {
		return error('Usage: vox-build memory --report PATH [--limit-gib 12] -- COMMAND ...')
	}
	os.mkdir_all(os.dir(report))!
	report_fd := C.vox_build_create_exclusive(&char(report.str))
	if report_fd < 0 { return native_build_error('Cannot create memory report ${report}') }
	defer { C.vox_build_close(report_fd) }
	mut held := acquire_file_lock(lock_path, true)!
	defer { held.release() }
	mut result := GuardResult{ command: command, reason: 'busy' }
	if held.acquired {
		result = run_memory_guard(command, u64(limit_gib * 1073741824.0), timeout, interval, adopt_path) or {
			GuardResult{ command: command, reason: 'guard_error', adoption_error: err.msg(), child_exit_code: 125 }
		}
	}
	encoded := guard_result_json(result)
	output := encoded + '\n'
	if C.vox_build_write_all(report_fd, &char(output.str), i64(output.len)) != 0 {
		return native_build_error('Cannot write memory report ${report}')
	}
	eprintln(encoded)
	if result.reason != 'completed' { return 125 }
	return if result.child_exit_code < 0 {
		128 - result.child_exit_code
	} else {
		result.child_exit_code
	}
}
