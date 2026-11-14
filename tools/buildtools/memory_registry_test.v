module buildtools

import os
import time
import json2 as json

fn test_adoption_accepts_integral_json_numbers_and_preserves_start_identity() ! {
	root := temporary(os.temp_dir(), 'vox-adoption-valid-')!
	defer { remove(root) or {} }
	path := join(root, 'pids.json')
	base := if os.getpid() == 75826 { '75827' } else { '75826' }
	for number in [base, base + '.0', base + 'e0', '2147483647'] {
		os.write_file(path, '[{"pid":${number},"started":"identity    "}]')!
		identities := adopted_processes(path)!
		assert identities.len == 1
		assert identities[int(number.f64())] == 'identity    '
	}
}

fn test_adoption_rejects_nonintegral_out_of_range_and_non_numeric_pids() ! {
	root := temporary(os.temp_dir(), 'vox-adoption-invalid-')!
	defer { remove(root) or {} }
	path := join(root, 'pids.json')
	for number in ['true', 'null', '"75826"', '[]', '{}', '0', '1', '-1',
		'2.5', '2147483648', '1e30', os.getpid().str()] {
		os.write_file(path, '[{"pid":${number},"started":"identity"}]')!
		mut rejected := false
		adopted_processes(path) or { rejected = true }
		assert rejected, number
	}
}

fn test_adopted_process_is_counted_by_rss_and_stopped_with_its_job() ! {
	root := temporary(os.temp_dir(), 'vox-adoption-owned-')!
	defer { remove(root) or {} }
	path := join(root, 'pids.json')
	python := os.find_abs_path_of_executable('python3')!
	mut external := os.new_process(python)
	external.set_args(['-c', 'import time; data=bytearray(64*1024*1024); time.sleep(10)'])
	external.use_pgroup = true
	external.run()
	defer {
		if external.is_alive() { external.signal_kill() }
		external.wait()
		external.close()
	}
	deadline := time.sys_mono_now() + 2 * time.second
	mut started := ''
	for time.sys_mono_now() < deadline {
		if row := process_snapshot()![external.pid] {
			if row.rss > 48 * 1024 * 1024 { started = row.started; break }
		}
		time.sleep(5 * time.millisecond)
	}
	if started == '' { panic('owned test process did not allocate its buffer') }
	os.write_file(path, '[{"pid":${external.pid},"started":${json.encode(started)}}]')!
	result := bounded_run(['/bin/sleep', '.1'], 3 * 1073741824, 3, .01, path)!
	reason := (result['reason'] or { panic('reason') }).str()
	peak := (result['observed_peak_rss_bytes'] or { panic('peak') }).i64()
	adopted := (result['adopted_processes'] or { panic('adopted') }).as_map()
	assert reason == 'remaining_children'
	assert peak > 48 * 1024 * 1024
	assert adopted[external.pid.str()] or { json.Null{} } == json.Any(started)
	external.wait()
	assert external.code != 0
	assert !external.is_alive()
}

fn test_invalid_registry_still_stops_newly_observed_detached_children() ! {
	root := temporary(os.temp_dir(), 'vox-adoption-error-')!
	defer { remove(root) or {} }
	path := join(root, 'invalid.json')
	identity_path := join(root, 'owned.json')
	python := os.find_abs_path_of_executable('python3')!
	script := 'import json,subprocess,sys,time\ntime.sleep(.07)\np=subprocess.Popen(["/bin/sleep","10"],start_new_session=True)\nbirth=subprocess.check_output(["ps","-p",str(p.pid),"-o","lstart="],text=True).lstrip().rstrip("\\n")\nopen(sys.argv[1],"w").write(json.dumps([dict(pid=p.pid,started=birth)]))\nopen(sys.argv[2],"w").write("[{\\"pid\\":true,\\"started\\":\\"identity\\"}]")\ntime.sleep(10)'
	result := bounded_run([python, '-c', script, identity_path, path], 3 * 1073741824, 3, .25, path)!
	identities := adopted_processes(identity_path)!
	defer {
		snapshot := process_snapshot() or { map[int]ProcessRow{} }
		for pid, birth in identities {
			if pid in snapshot && snapshot[pid].started == birth { C.kill(i32(pid), 9) }
		}
	}
	reason := (result['reason'] or { panic('reason') }).str()
	assert reason == 'adoption_error'
	deadline := time.sys_mono_now() + time.second
	for time.sys_mono_now() < deadline {
		snapshot := process_snapshot()!
		mut alive := false
		for pid, birth in identities {
			if pid in snapshot && snapshot[pid].started == birth { alive = true }
		}
		if !alive { return }
		time.sleep(5 * time.millisecond)
	}
	panic('guard left its detached child running after a registry error')
}
