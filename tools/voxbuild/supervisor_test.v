module main

import os
import rand
import json2 as json
import time

fn supervisor_test_directory() string {
	path := os.join_path(os.temp_dir(), 'vox-supervisor-test-' + rand.uuid_v4())
	os.mkdir_all(path) or { panic(err) }
	return path
}

fn test_guard_tracks_reparented_children_and_rejects_reused_pids() {
	snapshot := {
		10: GuardProcess{ parent: 1, group: 10, rss: 1024, started: 'root' }
		11: GuardProcess{ parent: 1, group: 10, rss: 2048, started: 'group child' }
		12: GuardProcess{ parent: 1, group: 12, rss: 2048, started: 'detached child' }
		13: GuardProcess{ parent: 12, group: 13, rss: 2048, started: 'grandchild' }
		14: GuardProcess{ parent: 1, group: 14, rss: 2048, started: 'reused pid' }
		15: GuardProcess{ parent: 1, group: 15, rss: 2048, started: 'adopted child' }
	}
	owned := job_processes(snapshot, 10, {
		12: 'detached child'
		14: 'old process'
	}, {
		15: 'adopted child'
	})
	assert owned.len == 5
	assert 10 in owned && 11 in owned && 12 in owned && 13 in owned && 15 in owned
	assert 14 !in owned
}

fn test_guard_preserves_child_exit_and_kills_timeouts() {
	completed := run_memory_guard(['sh', '-c', 'exit 7'], 3 * 1024 * 1024 * 1024, 5, 0.01, '')!
	assert completed.reason == 'completed'
	assert completed.child_exit_code == 7
	timed_out := run_memory_guard(['sh', '-c', 'sleep 10'], 3 * 1024 * 1024 * 1024, 0.1, 0.02, '')!
	assert timed_out.reason == 'timeout'
	assert timed_out.child_exit_code < 0
	assert timed_out.elapsed_seconds < 5
}

fn test_guard_kills_memory_excess_and_remaining_children() {
	memory := run_memory_guard(['sh', '-c', 'sleep 10'], 1, 5, 0.01, '')!
	assert memory.reason == 'memory_limit'
	assert memory.observed_peak_rss_bytes > 1
	remaining := run_memory_guard(['sh', '-c', 'sleep 10 & exit 0'], 3 * 1024 * 1024 * 1024, 5, 0.01, '')!
	assert remaining.reason == 'remaining_children'
	assert remaining.child_exit_code == 0
}

fn test_memory_reports_are_exclusive_and_busy_locks_do_not_launch() {
	root := supervisor_test_directory()
	defer { os.rmdir_all(root) or {} }
	lock_path := os.join_path(root, 'guard.lock')
	report := os.join_path(root, 'report.json')
	assert memory_guard(root, ['--lock', lock_path, '--report', report, '--', 'sh', '-c', 'exit 4'])! == 4
	original := os.read_file(report)!
	mut refused := false
	memory_guard(root, ['--lock', lock_path, '--report', report, '--', 'sh', '-c', 'exit 0']) or { refused = true }
	assert refused
	assert os.read_file(report)! == original
	mut held := acquire_file_lock(lock_path, false)!
	defer { held.release() }
	marker := os.join_path(root, 'should-not-exist')
	busy_report := os.join_path(root, 'busy.json')
	assert memory_guard(root, ['--lock', lock_path, '--report', busy_report, '--', 'touch', marker])! == 125
	assert !os.exists(marker)
	assert json.parse(os.read_file(busy_report)!)!.as_map()['reason']!.str() == 'busy'
}

fn test_invalid_adoption_fails_closed() {
	root := supervisor_test_directory()
	defer { os.rmdir_all(root) or {} }
	registry := os.join_path(root, 'adopt.json')
	os.write_file(registry, '[{"pid":1,"started":"wrong"}]')!
	result := run_memory_guard(['sh', '-c', 'sleep 10'], 3 * 1024 * 1024 * 1024, 5, 0.01, registry)!
	assert result.reason == 'adoption_error'
	assert result.adoption_error.contains('Invalid adopted process identity')
}

fn test_guard_samples_own_process_identities_after_previous_samples_are_freed() {
	root := supervisor_test_directory()
	defer { os.rmdir_all(root) or {} }
	mut child := spawn_build_child(['sh', '-c', 'sleep 10'], os.environ(), '', '', false, '', false, false)!
	defer { stop_guarded_child(mut child, map[int]string{}) or {} }
	mut snapshot := process_snapshot()!
	started := snapshot[child.pid].started.clone()
	defer { unsafe { started.free() } }
	free_process_snapshot(mut snapshot)
	registry := os.join_path(root, 'adopted.json')
	os.write_file(registry, json.encode([AdoptedProcess{ pid: child.pid, started: started }]))!
	mut first := sample_guarded_processes(child.pid, map[int]string{}, registry)!
	assert first.owned[child.pid] == started
	assert first.adopted[child.pid] == started
	mut second := sample_guarded_processes(child.pid, first.owned, registry)!
	free_process_identities(mut first.owned)
	free_process_identities(mut first.adopted)
	unsafe { free(first) }
	defer {
		free_process_identities(mut second.owned)
		free_process_identities(mut second.adopted)
		unsafe { free(second) }
	}
	assert second.owned[child.pid] == started
	assert second.adopted[child.pid] == started
}

fn supervisor_fixture_repository() string {
	root := supervisor_test_directory()
	capture_command(['git', 'init', '-q', '-b', 'master', root]) or { panic(err) }
	os.mkdir_all(os.join_path(root, 'docs')) or { panic(err) }
	os.write_file(os.join_path(root, 'main.v'), 'module main\nfn main() {}\n') or { panic(err) }
	os.write_file(os.join_path(root, 'docs', 'README.md'), 'Build documentation\n') or { panic(err) }
	os.write_file(os.join_path(root, '.gitignore'), 'Build/\n') or { panic(err) }
	capture_command(['git', '-C', root, 'add', '.']) or { panic(err) }
	capture_command(['git', '-C', root, '-c', 'user.name=Vox Build Test', '-c',
		'user.email=test@example.invalid', 'commit', '-qm', 'fixture']) or { panic(err) }
	return root
}

fn test_repository_identity_distinguishes_build_inputs_from_documentation() {
	root := supervisor_fixture_repository()
	defer { os.rmdir_all(root) or {} }
	before := repository_state(root)!
	os.write_file(os.join_path(root, 'docs', 'README.md'), 'New documentation\n')!
	documented := repository_state(root)!
	assert same_build_inputs(before, documented)
	assert before.repository_sha256 != documented.repository_sha256
	os.write_file(os.join_path(root, 'main.v'), 'module main\nfn main() { println("changed") }\n')!
	changed := repository_state(root)!
	assert !same_build_inputs(before, changed)
	assert changed.dirty
}

fn test_enqueue_coalesces_requests_and_preserves_explicit_pending_options() {
	root := supervisor_fixture_repository()
	defer { os.rmdir_all(root) or {} }
	enqueue_build(root, false, true, 'single', true, 'skia', 'fastc')!
	first := read_build_request(production_state_dir(root))!
	enqueue_build(root, false, false, '', false, '', '')!
	second := read_build_request(production_state_dir(root))!
	assert first.id != second.id
	assert second.c_mode == 'single'
	assert second.v_prod
	assert second.renderer == 'skia'
	assert second.backend == 'fastc'
	assert first.head == second.head
}

fn test_failed_publication_cannot_remove_existing_executable() {
	root := supervisor_test_directory()
	defer { os.rmdir_all(root) or {} }
	if os.user_os() != 'linux' { return }
	target := os.join_path(root, 'Build/linux/vox')
	stage := os.join_path(root, 'Build/staging')
	os.mkdir_all(os.dir(target))!
	os.mkdir_all(stage)!
	os.write_file(target, 'last successful executable')!
	mut failed := false
	publish_build_unlocked(root, stage) or { failed = true }
	assert failed
	assert os.read_file(target)! == 'last successful executable'
}

fn test_native_pre_commit_rejects_generated_artifacts_and_allows_runtime_fixtures() {
	root := supervisor_fixture_repository()
	defer { os.rmdir_all(root) or {} }
	os.mkdir_all(os.join_path(root, 'docs/performance'))!
	os.mkdir_all(os.join_path(root, 'adblock'))!
	os.write_file(os.join_path(root, 'docs/performance/raw.json'), '{}')!
	os.write_file(os.join_path(root, 'evidence.zip'), 'local evidence')!
	os.write_file(os.join_path(root, 'adblock/fixture.zip'), 'runtime fixture')!
	capture_command(['git', '-C', root, 'add', 'docs/performance/raw.json', 'evidence.zip',
		'adblock/fixture.zip'])!
	problems := pre_commit_violations(root, 32 * 1024 * 1024)!
	assert problems.len == 2
	assert problems.any(it.contains('measurement dumps stay local'))
	assert problems.any(it.starts_with('evidence.zip: archives stay local'))
	assert !problems.any(it.starts_with('adblock/'))
}

fn test_git_identity_ignores_environment_left_by_a_hook() {
	root := supervisor_fixture_repository()
	defer { os.rmdir_all(root) or {} }
	prior := os.getenv_opt('GIT_DIR')
	os.setenv('GIT_DIR', os.join_path(root, 'wrong.git'), true)
	defer {
		if value := prior { os.setenv('GIT_DIR', value, true) } else { os.unsetenv('GIT_DIR') }
	}
	assert supervisor_git(root, ['branch', '--show-current'])!.trim_space() == 'master'
}

fn test_hook_installation_upgrades_only_exact_managed_python_hooks() {
	root := supervisor_fixture_repository()
	defer { os.rmdir_all(root) or {} }
	hooks := os.join_path(root, '.git/hooks')
	for name in ['pre-commit', 'post-commit'] {
		os.write_file(os.join_path(hooks, name), legacy_build_hook(name))!
	}
	install_native_build_hooks(root)!
	for name in ['pre-commit', 'post-commit'] {
		content := os.read_file(os.join_path(hooks, name))!
		assert content.contains('tools/vox-build.sh')
		assert !content.contains('python')
	}
	custom := '#!/bin/sh\necho custom hook\n'
	os.write_file(os.join_path(hooks, 'post-commit'), custom)!
	mut refused := false
	install_native_build_hooks(root) or { refused = true }
	assert refused
	assert os.read_file(os.join_path(hooks, 'post-commit'))! == custom
}

fn supervisor_integration_environment(root string, tool string) map[string]string {
	mut environment := os.environ()
	os.mkdir_all(os.join_path(root, 'Build')) or { panic(err) }
	poison := os.join_path(root, 'forbidden interpreters')
	os.mkdir_all(poison) or { panic(err) }
	for name in ['python', 'python3'] {
		path := os.join_path(poison, name)
		os.write_file(path, '#!/bin/sh\nprintf forbidden > ' + shell_quote(os.join_path(root, 'python-was-called')) + '\nexit 88\n') or { panic(err) }
		os.chmod(path, 0o755) or { panic(err) }
	}
	environment['PATH'] = poison + os.path_delimiter + environment['PATH']
	environment['VOX_BUILD_ROOT'] = root
	environment['VOX_BUILD_TOOL'] = tool
	return environment
}

fn write_supervisor_fixture_script(root string, prefix string, smoke_exit int) {
	path := os.join_path(root, 'build-linux-browser.sh')
	text := '#!/bin/sh\nset -eu\n[ "$VOX_BUILD_SUPERVISED" = 1 ]\n[ "$VOX_BUILD_COMPILE_PROTOCOL" = ' + build_protocol + ' ]\n' + prefix + '\nmkdir -p "$VOX_BUILD_OUTPUT_DIR"\ncat > "$VOX_BUILD_OUTPUT_DIR/vox" <<\'VOX_TEST_BINARY\'\n#!/bin/sh\n[ "$1" = --headless-smoke ] || exit 77\nexit ' + smoke_exit.str() + '\nVOX_TEST_BINARY\nchmod 755 "$VOX_BUILD_OUTPUT_DIR/vox"\n'
	os.write_file(path, text) or { panic(err) }
}

fn run_supervisor_fixture(root string, tool string) int {
	mut child := spawn_build_child([tool, 'supervise', '--build'], supervisor_integration_environment(root, tool), root,
		os.join_path(root, 'Build/fixture-supervisor.log'), false, '', false, false) or { panic(err) }
	start := time.sys_mono_now()
	for !child.poll(false) or { panic(err) } {
		if time.sys_mono_now() - start > u64(15 * time.second) {
			stop_guarded_child(mut child, map[int]string{}) or {}
			panic('Supervisor fixture timed out: ' + (os.read_file(os.join_path(root, 'Build/fixture-supervisor.log')) or { '' }))
		}
		time.sleep(20 * time.millisecond)
	}
	return child.exit_code
}

fn test_native_supervisor_build_smoke_and_failure_retention_without_python() {
	tool := os.getenv('VOX_BUILD_TEST_TOOL')
	if tool == '' || os.user_os() != 'linux' { return }
	assert os.is_file(tool)
	root := supervisor_fixture_repository()
	defer { os.rmdir_all(root) or {} }
	write_supervisor_fixture_script(root, '', 0)
	assert run_supervisor_fixture(root, tool) == 0, os.read_file(os.join_path(root, 'Build/fixture-supervisor.log'))!
	target := os.join_path(root, 'Build/linux/vox')
	successful := os.read_file(target)!
	latest := os.read_file(os.join_path(root, 'Build/linux/production-build/latest.json'))!
	write_supervisor_fixture_script(root, 'exit 23', 0)
	assert run_supervisor_fixture(root, tool) == 23
	assert os.read_file(target)! == successful
	assert os.read_file(os.join_path(root, 'Build/linux/production-build/latest.json'))! == latest
	write_supervisor_fixture_script(root, '', 9)
	assert run_supervisor_fixture(root, tool) == 9
	assert os.read_file(target)! == successful
	assert !os.exists(os.join_path(root, 'python-was-called'))
	assert !os.ls(os.join_path(root, 'Build'))!.any(it.starts_with('.production-output-'))
	state := os.join_path(root, 'Build/linux/production-build')
	for name in os.ls(os.join_path(state, 'receipts'))! {
		receipt := os.join_path(state, 'receipts', name)
		assert os.is_file(os.join_path(receipt, 'memory.json'))
		assert os.is_file(os.join_path(receipt, 'result.json'))
	}
}

fn test_native_supervisor_retries_when_build_inputs_change() {
	tool := os.getenv('VOX_BUILD_TEST_TOOL')
	if tool == '' || os.user_os() != 'linux' { return }
	root := supervisor_fixture_repository()
	defer { os.rmdir_all(root) or {} }
	prefix := 'if [ ! -f Build/changed-once ]; then\n  touch Build/changed-once\n  printf "\\n// changed during compilation\\n" >> main.v\nfi'
	write_supervisor_fixture_script(root, prefix, 0)
	assert run_supervisor_fixture(root, tool) == 0, os.read_file(os.join_path(root, 'Build/fixture-supervisor.log'))!
	receipts := os.join_path(root, 'Build/linux/production-build/receipts')
	mut superseded := 0
	for name in os.ls(receipts)! {
		record := read_build_object(os.join_path(receipts, name, 'result.json'))
		value := record['superseded'] or { json.Any(false) }
		if value.bool() { superseded++ }
	}
	assert superseded == 1
	assert !os.exists(os.join_path(root, 'python-was-called'))
}

fn test_native_supervisor_preserves_frozen_source_provenance_in_final_receipts() {
	tool := os.getenv('VOX_BUILD_TEST_TOOL')
	if tool == '' || os.user_os() != 'linux' { return }
	root := supervisor_fixture_repository()
	defer { os.rmdir_all(root) or {} }
	supervisor_integration_environment(root, tool)
	write_supervisor_fixture_script(root,
		'cp "$VOX_BUILD_ROOT/Build/frozen-fixture.json" "$VOX_BUILD_RECEIPT_DIR/frozen-compile.json"', 0)
	expected := repository_state(root)!
	sealed := os.join_path(root, 'Build/browser.i')
	live := os.join_path(root, 'Build/native.a')
	os.write_file(sealed, 'sealed generated C')!
	os.write_file(live, 'sealed native library')!
	marker := 'verified parsed buffers and sealed native inputs'
	frozen := FrozenCompile{
		protocol:                 frozen_protocol
		source_inputs:            expected
		source_inputs_at_sealing: {
			'head':                json.Any(expected.head)
			'dirty':               json.Any(true)
			'source_kind':         json.Any(marker)
			'build_inputs_sha256': json.Any('verified-parsed-source-hash')
		}
		cwd:                      root
		compiler_command:         ['cc', sealed]
		sealed_inputs:            fingerprint([sealed])!
		live_inputs:              fingerprint([live])!
		complete:                 true
		compiler_exit:            0
	}
	os.write_file(os.join_path(root, 'Build/frozen-fixture.json'), json.encode(frozen))!
	assert 'source_kind' !in json.parse(json.encode(expected))!.as_map()
	assert run_supervisor_fixture(root, tool) == 0, os.read_file(os.join_path(root, 'Build/fixture-supervisor.log'))!
	state := production_state_dir(root)
	latest := read_build_object(os.join_path(state, 'latest.json'))
	assert 'source_kind' !in latest['inputs']!.as_map()
	assert 'source_kind' !in latest['repository_after_build']!.as_map()
	verified := latest['verified_inputs']!.as_map()
	assert verified['source_kind']!.str() == marker
	assert verified['build_inputs_sha256']!.str() == 'verified-parsed-source-hash'
	for name in os.ls(os.join_path(state, 'receipts'))! {
		for filename in ['ready.json', 'result.json'] {
			record := read_build_object(os.join_path(state, 'receipts', name, filename))
			assert record['verified_inputs']!.as_map()['source_kind']!.str() == marker
		}
	}
	assert !os.exists(os.join_path(root, 'python-was-called'))
}

fn test_native_supervisor_waits_for_a_publication_lease() {
	tool := os.getenv('VOX_BUILD_TEST_TOOL')
	if tool == '' || os.user_os() != 'linux' { return }
	root := supervisor_fixture_repository()
	defer { os.rmdir_all(root) or {} }
	write_supervisor_fixture_script(root, '', 0)
	target := os.join_path(root, 'Build/linux/vox')
	os.mkdir_all(os.dir(target))!
	os.write_file(target, 'leased executable')!
	state := production_state_dir(root)
	mut lease := acquire_file_lock(os.join_path(state, 'bundle.lock'), false)!
	defer { lease.release() }
	mut child := spawn_build_child([tool, 'supervise', '--build'], supervisor_integration_environment(root, tool), root,
		os.join_path(root, 'Build/fixture-supervisor.log'), false, '', false, false)!
	defer { if !child.exited { stop_guarded_child(mut child, map[int]string{}) or {} } }
	start := time.sys_mono_now()
	mut ready := false
	for time.sys_mono_now() - start < u64(10 * time.second) {
		if child.poll(false)! { break }
		receipts := os.join_path(state, 'receipts')
		for name in os.ls(receipts) or { []string{} } {
			if os.is_file(os.join_path(receipts, name, 'ready.json')) {
				ready = true
				break
			}
		}
		if ready { break }
		time.sleep(20 * time.millisecond)
	}
	assert ready, os.read_file(os.join_path(root, 'Build/fixture-supervisor.log'))!
	assert os.read_file(target)! == 'leased executable'
	assert !child.poll(false)!
	lease.release()
	child.poll(true)!
	assert child.exit_code == 0
	assert os.read_file(target)! != 'leased executable'
	assert !os.exists(os.join_path(root, 'python-was-called'))
}

fn test_native_memory_guard_cancellation_reaps_the_command() {
	tool := os.getenv('VOX_BUILD_TEST_TOOL')
	if tool == '' || os.user_os() != 'linux' { return }
	root := supervisor_test_directory()
	defer { os.rmdir_all(root) or {} }
	pid_file := os.join_path(root, 'command.pid')
	report := os.join_path(root, 'guard.json')
	program := 'printf "%s" "$$" > ' + shell_quote(pid_file) + '; sleep 10'
	mut child := spawn_build_child([tool, 'memory', '--report', report, '--lock',
		os.join_path(root, 'guard.lock'), '--', 'sh', '-c', program], supervisor_integration_environment(root, tool), root, os.join_path(root, 'Build/guard.log'),
		false, '', false, false)!
	defer { if !child.exited { stop_guarded_child(mut child, map[int]string{}) or {} } }
	start := time.sys_mono_now()
	for !os.is_file(pid_file) && time.sys_mono_now() - start < u64(5 * time.second) {
		time.sleep(10 * time.millisecond)
	}
	assert os.is_file(pid_file)
	pid := os.read_file(pid_file)!.int()
	C.vox_build_terminate(i32(child.pid))
	child.poll(true)!
	assert child.exit_code == 125
	assert pid !in process_snapshot()!
	assert read_build_object(report)['reason']!.str() == 'interrupted'
}
