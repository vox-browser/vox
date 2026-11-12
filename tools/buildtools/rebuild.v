module buildtools

import os
import time
import rand
import json2 as json

const build_protocol = 'bundle-lease-v10-vtools'

fn validate_repository(root string) ! {
	if !os.is_dir(join(root, '.git')) || !trimmed_eq(git(root, 'branch', '--show-current')!, 'master') {
		return error('Production builds require master in canonical checkout')
	}
}

fn production_environment() map[string]string {
	mut result := os.environ()
	for key, _ in result {
		if key.starts_with('GIT_') || key.starts_with('VOX_') || (key.starts_with('LADYBIRD_') && key != 'LADYBIRD_SOURCE_DIR') {
			result.delete(key)
		}
	}
	return result
}

fn unique_id() string { return rand.uuid_v4().replace('-', '') }

fn start_worker(root string, mode string) ! {
	state := state_dir(root)
	mkdir(state)!
	mut env := production_environment()
	env['VOX_WORKER_LOG'] = join(state, 'worker.log')
	mut p := os.new_process('sh')
	p.set_args(['-c', 'exec nohup "$@" >>"$VOX_WORKER_LOG" 2>&1 </dev/null', 'sh', 'sh',
		join(root, 'tools/run_v_tool.sh'), 'rebuild_browser', mode])
	p.set_environment(env)
	p.set_work_folder(root)
	p.use_pgroup = true
	p.run()
	if p.pid <= 0 { return error('Cannot start build worker: ${p.err}') }
	p.close()
}

fn enqueue(root string, background bool, c_mode string, prod string, backend string) ! {
	validate_repository(root)!
	state := state_dir(root)
	mut held := acquire(join(state, 'queue.lock'), false)!
	defer { held.release() }
	prior := maybe_load(join(state, 'request.json'))
	started := maybe_load(join(state, 'started.json'))
	mut selected_backend := backend
	if backend == '' && (prior['id'] or { json.Null{} }) != (started['id'] or { json.Null{} }) {
		selected_backend = (prior['backend'] or { json.Null{} }).str()
		if selected_backend == 'null' { selected_backend = '' }
	}
	if selected_backend !in ['', 'c', 'fastc'] {
		return error('Unknown backend: ${selected_backend}')
	}
	v_prod := if prod == '' { (prior['v_prod'] or { json.Null{} }).bool() } else { prod == '1' }
	mut mode := c_mode
	if mode == '' {
		mode = if (prior['v_prod'] or { json.Null{} }).bool() {
			(prior['c_mode'] or { json.Null{} }).str()
		} else if (prior['c_mode'] or { json.Null{} }).str() == 'single' && (prior['id'] or { json.Null{} }) != (started['id'] or { json.Null{} }) {
			'single'
		} else {
			'parallel'
		}
		if mode !in ['single', 'parallel'] { mode = if v_prod { 'single' } else { 'parallel' } }
	}
	request := map[string]json.Any{
		'id':      unique_id()
		'head':    git(root, 'rev-parse', 'HEAD')!.trim_space()
		'c_mode':  mode
		'v_prod':  v_prod
		'backend': if selected_backend == '' {
			json.Any(json.Null{})
		} else {
			json.Any(selected_backend)
		}
	}
	write_json(join(state, 'request.json'), json.Any(request))!
	if background { start_worker(root, '--worker')! }
}

fn same_options(before Record, after Record) bool {
	for key in ['c_mode', 'v_prod', 'backend'] {
		fallback := match key {
			'c_mode' { json.Any('parallel') }
			'v_prod' { json.Any(false) }
			else { json.Any(json.Null{}) }
		}
		if (before[key] or { fallback }) != (after[key] or { fallback }) { return false }
	}
	return true
}

fn publish_unlocked(root string, stage string) ! {
	target := join(root, 'Build', platform())
	mkdir(target)!
	if os.user_os() == 'macos' {
		exchange_directories(join(stage, 'Vox.app'), join(target, 'Vox.app'))!
	}
	for path in listing(stage)! {
		if os.is_file(path) && ['.dylib', '.so'].any(path.ends_with(it)) {
			os.rename(path, join(target, os.file_name(path)))!
		}
	}
	if os.user_os() != 'macos' { os.rename(join(stage, 'vox'), join(target, 'vox'))! }
}

fn try_publish(root string, stage string) !bool {
	mut held := acquire(join(state_dir(root), 'bundle.lock'), true) or { return false }
	defer { held.release() }
	publish_unlocked(root, stage)!
	return true
}

fn supervised_command(root string, command []string, environment map[string]string, log string) !int {
	mut env := environment.clone()
	env['VOX_TOOL_LOG'] = log
	mut p := os.new_process('sh')
	p.set_args(['-c', 'exec "$@" >"$VOX_TOOL_LOG" 2>&1', 'sh', ...command])
	p.set_work_folder(root)
	p.set_environment(env)
	p.run()
	p.wait()
	code := p.code
	p.close()
	return code
}

fn run_build(root string, stage string, receipt string, environment map[string]string) !int {
	mut env := environment.clone()
	for key, _ in env { if key.starts_with('GIT_') { env.delete(key) } }
	env['VOX_BUILD_SUPERVISED'] = '1'
	env['VOX_BUILD_OUTPUT_DIR'] = stage
	env['VOX_BUILD_COMPILE_PROTOCOL'] = build_protocol
	env['VOX_BUILD_RECEIPT_DIR'] = receipt
	script := join(root, if os.user_os() == 'linux' {
		'build-linux-browser.sh'
	} else {
		'build-prod-browser.sh'
	})
	script_bytes := read(script)!
	write_json(join(receipt, 'build-script.json'), json.Any(map[string]json.Any{
		'path':     script
		'bytes':    script_bytes.len
		'sha256':   hash(script_bytes)
		'delivery': 'memory through command argument'
	}))!
	guard := ['sh', join(root, 'tools/run_v_tool.sh'), 'run_memory_bounded']
	command := [...guard, '--lock', join(state_dir(root), 'memory.lock'), '--report',
		join(receipt, 'memory.json'), '--timeout', '2700', '--', 'sh', '-c', script_bytes, script]
	code := supervised_command(root, command, env, join(receipt, 'build.log'))!
	if code != 0 { return code }
	executable := join(stage, if os.user_os() == 'macos' {
		'Vox.app/Contents/MacOS/Vox'
	} else {
		'vox'
	})
	env['VOX_PROFILE_DIR'] = join(stage, 'smoke-profile')
	env['VOX_TEST_WINDOW'] = '1'
	return supervised_command(root, [...guard, '--limit-gib', '3', '--lock',
		join(state_dir(root), 'smoke.lock'), '--report', join(receipt, 'smoke-memory.json'), '--',
		executable, '--headless-smoke'], env, join(receipt, 'smoke.log'))
}

fn build_attempt(root string, state string, request Record, before Record, receipt string) !Record {
	stage := temporary(join(root, 'Build'), '.production-output-')!
	defer { remove(stage) or {} }
	write_json(join(receipt, 'inputs-before.json'), json.Any(before))!
	mut env := os.environ()
	env['VOX_BUILD_C_MODE'] = (request['c_mode'] or { json.Null{} }).str()
	env['VOX_BUILD_V_PROD'] = if (request['v_prod'] or { json.Null{} }).bool() { '1' } else { '0' }
	if (request['backend'] or { json.Null{} }) is string {
		env['VOX_BUILD_BACKEND'] = (request['backend'] or { json.Null{} }).str()
	} else {
		env.delete('VOX_BUILD_BACKEND')
	}
	code := run_build(root, stage, receipt, env)!
	mut record := map[string]json.Any{
		'request': json.Any(request)
		'inputs':  json.Any(before)
		'exit':    code
	}
	if exists(join(receipt, 'c-compile.json')) {
		record['c_compile'] = json.Any(load(join(receipt, 'c-compile.json'))!)
	}
	if code != 0 { return record }
	after := repository_state(root)!
	record['verified_inputs'] = json.Any(after)
	mut frozen := Record{}
	if exists(join(receipt, 'frozen-compile.json')) {
		frozen = validate_frozen(receipt, before, true) or {
			record['exit'] = 1
			record['frozen_input_error'] = err.msg()
			return record
		}
		record['frozen_compilation'] = join(receipt, 'frozen-compile.json')
		record['repository_after_build'] = json.Any(after)
		record['verified_inputs'] = frozen['source_inputs_at_sealing'] or { frozen['source_inputs'] or { json.Any(Record{}) } }
	} else if !same_inputs(before, after) {
		record['superseded'] = true
		return record
	}
	ready := join(stage, if os.user_os() == 'macos' { 'Vox.app/Contents/MacOS/Vox' } else { 'vox' })
	mut ready_record := record.clone()
	ready_record['ready_executable'] = ready
	ready_record['ready_executable_sha256'] = digest(ready)!
	write_json(join(receipt, 'ready.json'), json.Any(ready_record))!
	ready_time := time.sys_mono_now()
	for {
		mut artifact := acquire(join(receipt, 'artifact.lock'), true) or {
			time.sleep(250 * time.millisecond)
			continue
		}
		published := try_publish(root, stage) or {
			artifact.release()
			return err
		}
		artifact.release()
		if published { break }
		mut queue := acquire(join(state, 'queue.lock'), false)!
		latest := load(join(state, 'request.json'))!
		queue.release()
		if (latest['id'] or { json.Null{} }) != (request['id'] or { json.Null{} }) {
			matches := if frozen.len > 0 {
				matches_checkout(root, frozen)
			} else {
				same_inputs(repository_state(root)!, before)
			}
			if (!matches || !same_options(latest, request)) && time.sys_mono_now() - ready_time >= 5 * time.second {
				record['superseded'] = true
				record['publication_deferred'] = 'reader lease held; newer source requested'
				return record
			}
		}
		time.sleep(250 * time.millisecond)
	}
	executable := join(root, 'Build', platform(), if os.user_os() == 'macos' {
		'Vox.app/Contents/MacOS/Vox'
	} else {
		'vox'
	})
	record['executable'] = executable
	record['executable_sha256'] = digest(executable)!
	return record
}

fn build_pending(root string, foreground bool) !int {
	validate_repository(root)!
	state := state_dir(root)
	mut build_lock := acquire(join(state, 'build.lock'), true) or {
		println('Production build already running; latest request is recorded.')
		return if foreground { 75 } else { 0 }
	}
	defer { build_lock.release() }
	for {
		request := load(join(state, 'request.json'))!
		write_json(join(state, 'started.json'), json.Any(map[string]json.Any{
			'id': (request['id'] or { json.Null{} })
		}))!
		before := repository_state(root)!
		name := time.now().custom_format('YYYYMMDD-HHmmss-') + unique_id()[..8]
		receipt := join(state, 'receipts', name)
		mkdir(receipt)!
		prune_receipts(os.dir(state), false) or { eprintln('Receipt pruning: ${err}') }
		record := build_attempt(root, state, request, before, receipt)!
		write_json(join(receipt, 'result.json'), json.Any(record))!
		mut queue := acquire(join(state, 'queue.lock'), false)!
		latest := load(join(state, 'request.json'))!
		if (record['exit'] or { json.Null{} }).int() != 0 {
			println('Production build failed; previous bundle retained. See ${receipt}')
			if (latest['id'] or { json.Null{} }) != (request['id'] or { json.Null{} }) || !same_inputs(repository_state(root)!, before) {
				queue.release()
				continue
			}
			build_lock.release()
			queue.release()
			return (record['exit'] or { json.Null{} }).int()
		}
		if (record['superseded'] or { json.Null{} }).bool() {
			queue.release()
			continue
		}
		write_json(join(state, 'latest.json'), json.Any(record))!
		frozen := maybe_load(join(receipt, 'frozen-compile.json'))
		if (latest['id'] or { json.Null{} }) == (request['id'] or { json.Null{} }) || (same_options(latest, request) && (same_inputs(repository_state(root)!, (record['verified_inputs'] or { json.Null{} }).as_map()) || (frozen.len > 0 && matches_checkout(root, frozen)))) {
			build_lock.release()
			queue.release()
			println('Published canonical production browser: ' + (before['head'] or { json.Null{} }).str())
			return 0
		}
		queue.release()
	}
	return 0
}

fn hook_content(pre bool) string {
	return if pre {
		'#!/bin/sh\n# Vox staged-file check; managed by tools/rebuild_browser.vsh.\nset -eu\nrepo=$(git rev-parse --show-toplevel)\n[ -f "$repo/tools/pre_commit_check.vsh" ] || exit 0\nexec sh "$repo/tools/run_v_tool.sh" pre_commit_check\n'
	} else {
		'#!/bin/sh\n# Vox canonical production rebuild hook; managed by tools/rebuild_browser.vsh.\nset -eu\nrepo=$(git rev-parse --show-toplevel)\nexec sh "$repo/tools/run_v_tool.sh" rebuild_browser --request --backend c --prod\n'
	}
}

fn install_hook(root string) ! {
	validate_repository(root)!
	hook_path := git(root, 'rev-parse', '--git-path', 'hooks/post-commit')!.trim_space()
	path := if os.is_abs_path(hook_path) { hook_path } else { join(root, hook_path) }
	hooks := os.dir(path)
	if !real(hooks).starts_with(real(root) + '/') {
		return error('Shared external hooks directory retained; install Vox request manually')
	}
	mkdir(hooks)!
	for pre in [false, true] {
		hook := join(hooks, if pre { 'pre-commit' } else { 'post-commit' })
		if exists(hook) {
			text := read(hook)!
			legacy := if pre {
				$embed_file('legacy_pre_commit_hook.txt').to_string()
			} else {
				$embed_file('legacy_post_commit_hook.txt').to_string()
			}
			if text != hook_content(pre) && text != legacy && (pre || (text != legacy.replace(' --prod', '') && text != legacy.replace(' --backend c --prod', ''))) {
				return error('Existing custom hook retained: ${hook}')
			}
		}
	}
	for pre in [false, true] {
		hook := join(hooks, if pre { 'pre-commit' } else { 'post-commit' })
		atomic_write(hook, hook_content(pre))!
		os.chmod(hook, 0o755)!
	}
	println('Installed canonical master rebuild and staged-file hooks in ${hooks}')
}

fn rebuild_command(args []string) !int {
	a := arguments(args, ['--install-hook', '--request', '--worker', '--build', '--upgrade-worker',
		'--worker-after-current', '--no-parallel-cc', '--parallel-cc', '--prod'])!
	modes := ['--install-hook', '--request', '--worker', '--build', '--upgrade-worker',
		'--worker-after-current'].filter(a.has(it))
	if modes.len != 1 { return error('Select exactly one build action; use --help') }
	if a.has('--parallel-cc') && a.has('--no-parallel-cc') {
		return error('--parallel-cc and --no-parallel-cc are mutually exclusive')
	}
	if (a.has('--prod') || a.has('--backend')) && !a.has('--request') && !a.has('--build') {
		return error('--prod/--backend require --request or --build')
	}
	if (a.has('--parallel-cc') || a.has('--no-parallel-cc')) && !a.has('--build') {
		return error('C compilation mode requires --build')
	}
	root := root_dir()
	match modes[0] {
		'--install-hook' {
			install_hook(root)!
			return 0
		}
		'--request' {
			enqueue(root, true, if a.has('--prod') { 'single' } else { '' }, if a.has('--prod') {
				'1'
			} else {
				''
			}, a.get('--backend', ''))!
			return 0
		}
		'--upgrade-worker' {
			start_worker(root, '--worker-after-current')!
			return 0
		}
		'--worker-after-current' {
			mut upgrade := acquire(join(state_dir(root), 'upgrade-' + build_protocol + '.lock'), true) or { return 0 }
			defer { upgrade.release() }
			mut prior := acquire(join(state_dir(root), 'build.lock'), false)!
			prior.release()
			return build_pending(root, false)
		}
		'--build' {
			enqueue(root, false, if a.has('--parallel-cc') {
				'parallel'
			} else if a.has('--no-parallel-cc') || a.has('--prod') {
				'single'
			} else {
				'parallel'
			}, if a.has('--prod') { '1' } else { '0' }, a.get('--backend', ''))!
		}
		else {}
	}
	code := build_pending(root, a.has('--build'))!
	prune_build(root, 12, false, false) or { eprintln('Build/ pruning skipped: ${err}') }
	return code
}
