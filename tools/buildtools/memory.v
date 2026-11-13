module buildtools

import os
import time
import math
import strconv
import json2 as json

struct ProcessRow {
	parent  int
	group   int
	rss     i64
	started string
}

fn process_snapshot() !map[int]ProcessRow {
	output := capture(['ps', '-axo', 'pid=,ppid=,pgid=,rss=,stat=,lstart='])!
	mut result := map[int]ProcessRow{}
	for line in output.split_into_lines() {
		parts := line.fields()
		if parts.len < 10 { return error('Malformed process snapshot') }
		if parts[4].starts_with('Z') { continue }
		result[parts[0].int()] = ProcessRow{ parent: parts[1].int(), group: parts[2].int(), rss: parts[3].i64() * 1024, started: process_start_identity(line) }
	}
	return result
}

fn process_start_identity(line string) string {
	mut cursor := 0
	for _ in 0 .. 5 {
		for cursor < line.len && line[cursor].is_space() { cursor++ }
		for cursor < line.len && !line[cursor].is_space() { cursor++ }
	}
	for cursor < line.len && line[cursor].is_space() { cursor++ }
	return line[cursor..]
}

fn adopted_processes(path string) !map[int]string {
	mut result := map[int]string{}
	if path == '' || !os.exists(path) { return result }
	value := json.parse(read(path)!)!
	if value !is []json.Any { return error('Adopted process registry must be a list') }
	for item in value.as_array() {
		if item !is map[string]json.Any { return error('Invalid adopted process identity') }
		row := item.as_map()
		pid := row['pid'] or { return error('Missing adopted PID') }
		started := row['started'] or { return error('Missing adopted start identity') }
		if pid !is i64 && pid !is int { return error('Invalid adopted PID') }
		if started !is string || pid.int() <= 1 || pid.int() == os.getpid() || started.str().trim_space().len == 0 {
			return error('Invalid adopted process identity')
		}
		result[pid.int()] = started.str()
	}
	return result
}

fn job_processes(snapshot map[int]ProcessRow, root int, previous map[int]string, adopted map[int]string) map[int]string {
	mut owned := map[int]string{}
	for pid, row in snapshot {
		if row.group == root || pid == root || previous[pid] == row.started || adopted[pid] == row.started {
			owned[pid] = row.started
		}
	}
	for {
		mut added := false
		for pid, row in snapshot {
			if row.parent in owned && pid !in owned {
				owned[pid] = row.started
				added = true
			}
		}
		if !added { return owned }
	}
	return owned
}

fn stop_job(mut process os.Process, owned map[int]string) ! {
	$if windows {
		process.signal_kill()
		process.wait()
		return
	}
	$if !windows {
		snapshot := process_snapshot() or { map[int]ProcessRow{} }
		for pid, started in owned {
			if pid in snapshot && snapshot[pid].started == started { C.kill(i32(pid), 9) }
		}
		C.kill(i32(-process.pid), 9)
		process.wait()
	}
}

fn bounded_run(command []string, limit i64, timeout f64, interval f64, adopt_path string) !Record {
	start := time.sys_mono_now()
	mut process := os.new_process(command[0])
	process.set_args(command[1..])
	process.use_pgroup = true
	process.run()
	if process.pid <= 0 { return error('Cannot start guarded command: ${process.err}') }
	mut owned := map[int]string{}
	mut peak := i64(0)
	mut reason := 'completed'
	mut adopted_seen := map[int]string{}
	mut adoption_error := ''
	for {
		snapshot := process_snapshot() or {
			stop_job(mut process, owned) or {}
			return err
		}
		adopted := adopted_processes(adopt_path) or {
			reason = 'adoption_error'
			adoption_error = err.msg()
			break
		}
		for pid, started in adopted {
			if pid in snapshot && snapshot[pid].started == started { adopted_seen[pid] = started }
		}
		owned = job_processes(snapshot, process.pid, owned, adopted)
		mut rss := i64(0)
		for pid, _ in owned { rss += snapshot[pid].rss }
		if rss > peak { peak = rss }
		if peak > limit {
			reason = 'memory_limit'
			break
		}
		if f64(time.sys_mono_now() - start) / 1e9 > timeout {
			reason = 'timeout'
			break
		}
		if !process.is_alive() {
			next := process_snapshot()!
			owned = job_processes(next, process.pid, owned, adopted)
			owned.delete(process.pid)
			if owned.len > 0 { reason = 'remaining_children' }
			break
		}
		time.sleep(time.Duration(interval * 1e9))
	}
	stop_job(mut process, owned)!
	mut adopted_record := Record{}
	for pid, started in adopted_seen { adopted_record[pid.str()] = started }
	code := process.code
	process.close()
	return map[string]json.Any{
		'command':                 any_strings(command)
		'reason':                  reason
		'child_exit_code':         code
		'adopted_processes':       json.Any(adopted_record)
		'adoption_error':          if adoption_error == '' {
			json.Any(json.Null{})
		} else {
			json.Any(adoption_error)
		}
		'limit_bytes':             limit
		'observed_peak_rss_bytes': peak
		'elapsed_seconds':         f64(time.sys_mono_now() - start) / 1e9
		'metric':                  'sampled sum of process-tree RSS; shared pages may be counted twice'
	}
}

fn positive(text string) !f64 {
	value := strconv.atof64(text)!
	if math.is_nan(value) || math.is_inf(value, 0) || value <= 0 {
		return error('Must be finite and positive: ${text}')
	}
	return value
}

fn memory_command(args []string) !int {
	a := arguments(args, []string{})!
	if a.command.len == 0 { return error('Supply a command after --') }
	limit := i64(positive(a.get('--limit-gib', '12'))! * 1073741824)
	timeout := positive(a.get('--timeout', '1800'))!
	interval := positive(a.get('--interval', '.1'))!
	path := a.required('--report')!
	mkdir(os.dir(path))!
	mut report := os.open_file(path, 'wx', 0o600)!
	defer { report.close() }
	mut held := acquire(a.get('--lock', join(root_dir(), 'Build/.memory-bounded.lock')), true) or {
		result := map[string]json.Any{
			'reason':  'busy'
			'command': any_strings(a.command)
		}
		report.writeln(json.encode(result, prettify: true))!
		eprintln(json.encode(result))
		return 125
	}
	defer { held.release() }
	result := bounded_run(a.command, limit, timeout, interval, a.get('--adopt-pids-from', ''))!
	report.writeln(json.encode(result, prettify: true))!
	eprintln(json.encode(result))
	if (result['reason'] or { json.Null{} }).str() != 'completed' { return 125 }
	code := (result['child_exit_code'] or { json.Null{} }).int()
	return if code >= 0 { code } else { 128 - code }
}
