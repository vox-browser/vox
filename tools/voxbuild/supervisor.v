module main

import crypto.sha256
import json2 as json
import os
import rand
import time

const build_protocol = 'native-build-v8'

struct RepositoryState {
	head                string
	repository_sha256   string
	build_inputs_sha256 string
	dirty               bool
	source_kind         string @[omitempty]
}

fn repository_state_object(state RepositoryState) map[string]json.Any {
	mut result := json.map_from(state)
	// map_from does not apply encoder attributes. Ordinary checkout receipts
	// keep their original shape; frozen inputs retain their explicit provenance.
	if state.source_kind == '' { result.delete('source_kind') }
	return result
}

struct BuildRequest {
	id       string
	head     string
	c_mode   string = 'parallel'
	v_prod   bool
	renderer string = 'gg'
	backend  string
}

fn atomic_write_json_text(path string, text string) ! {
	os.mkdir_all(os.dir(path))!
	temporary := path + '.tmp-' + rand.uuid_v4()
	fd := C.vox_build_create_exclusive(&char(temporary.str))
	if fd < 0 { return native_build_error('Cannot create ${temporary}') }
	output := text.trim_right('\n') + '\n'
	if C.vox_build_write_all(fd, &char(output.str), i64(output.len)) != 0 {
		C.vox_build_close(fd)
		os.rm(temporary) or {}
		return native_build_error('Cannot write ${temporary}')
	}
	C.vox_build_close(fd)
	defer { if os.exists(temporary) { os.rm(temporary) or {} } }
	if C.vox_build_replace(&char(temporary.str), &char(path.str)) != 0 {
		return native_build_error('Cannot replace ${path}')
	}
}

fn production_state_dir(root string) string {
	return os.join_path(root, if os.user_os() == 'linux' {
		'Build/linux/production-build'
	} else {
		'Build/production-build'
	})
}

fn supervisor_git(root string, args []string) !string {
	mut command := ['env']
	for name, _ in os.environ() {
		if name.starts_with('GIT_') { command << ['-u', name] }
	}
	command << ['git', '-C', root, ...args]
	return capture_command(command)
}

fn validate_build_repository(root string) ! {
	if !os.is_dir(os.join_path(root, '.git')) || supervisor_git(root, ['branch', '--show-current'])!.trim_space() != 'master' {
		return error('Production builds require master in the canonical checkout')
	}
}

fn production_input_path(relative string) bool {
	extension := os.file_ext(relative).to_lower()
	stem := os.file_name(relative).all_before_last('.')
	test_tool := relative.starts_with('tools/') && extension in ['.py', '.v', '.c', '.cpp', '.m',
		'.mm']
		&& (stem.ends_with('_test') || stem.starts_with('test_'))
	return !(relative.starts_with('docs/') || relative.starts_with('Tests/') || extension == '.md'
		|| relative.ends_with('_test.v') || test_tool || relative in ['AGENTS.md', 'OPTIMIZED_SITES.md'])
}

fn repository_state(root string) !RepositoryState {
	mut digest := sha256.new()
	mut build_digest := sha256.new()
	mut names := supervisor_git(root, ['ls-files', '-z', '--cached', '--others', '--exclude-standard'])!.split('\x00')
	names.sort()
	mut previous := ''
	mut buffer := []u8{len: 1024 * 1024}
	defer { unsafe { buffer.free() } }
	for name in names {
		if name == '' || name == previous || name.ends_with('.swp') || name.contains('.v3cc.') {
			continue
		}
		previous = name
		production := production_input_path(name)
		prefix := (name + '\x00').bytes()
		digest.write(prefix)!
		if production { build_digest.write(prefix)! }
		path := os.join_path(root, name)
		if os.is_link(path) {
			data := os.readlink(path)!.bytes()
			digest.write(data)!
			if production { build_digest.write(data)! }
		} else if os.is_file(path) {
			mut file := os.open(path)!
			for {
				read := file.read(mut buffer) or {
					if err is os.Eof { break }
					file.close()
					return err
				}
				if read == 0 { break }
				digest.write(buffer[..read])!
				if production { build_digest.write(buffer[..read])! }
			}
			file.close()
		} else {
			digest.write('missing'.bytes())!
			if production { build_digest.write('missing'.bytes())! }
		}
	}
	return RepositoryState{
		head:                supervisor_git(root, ['rev-parse', 'HEAD'])!.trim_space()
		repository_sha256:   digest.sum([]u8{}).hex()
		build_inputs_sha256: build_digest.sum([]u8{}).hex()
		dirty:               supervisor_git(root, ['status', '--porcelain'])!.trim_space() != ''
	}
}

fn same_build_inputs(before RepositoryState, after RepositoryState) bool {
	return before.build_inputs_sha256 == after.build_inputs_sha256
}

fn read_build_object(path string) map[string]json.Any {
	text := os.read_file(path) or { return map[string]json.Any{} }
	parsed := json.parse(text) or { return map[string]json.Any{} }
	return parsed.as_map()
}

fn build_string(values map[string]json.Any, name string, fallback string) string {
	value := values[name] or { return fallback }
	if value is string { return value }
	return fallback
}

fn read_build_request(state string) !BuildRequest {
	path := os.join_path(state, 'request.json')
	values := read_build_object(path)
	id := build_string(values, 'id', '')
	if id == '' { return error('Missing or invalid production request: ${path}') }
	prod := values['v_prod'] or { json.Any(false) }
	return BuildRequest{
		id:       id
		head:     build_string(values, 'head', '')
		c_mode:   build_string(values, 'c_mode', 'parallel')
		v_prod:   prod.bool()
		renderer: build_string(values, 'renderer', 'gg')
		backend:  build_string(values, 'backend', '')
	}
}

fn build_request_object(request BuildRequest) map[string]json.Any {
	mut values := json.map_from(request)
	if request.backend == '' { values['backend'] = json.null }
	return values
}

fn production_environment(environment map[string]string) map[string]string {
	mut retained := map[string]string{}
	for key, value in environment {
		if !(key.starts_with('GIT_') || key.starts_with('VOX_') || key.starts_with('LADYBIRD_'))
			|| key in ['LADYBIRD_SOURCE_DIR', 'LADYBIRD_VCPKG_TRIPLET', 'VOX_BUILD_ROOT',
				'VOX_BUILD_TOOL'] {
			retained[key] = value
		}
	}
	return retained
}

fn build_tool_executable() string {
	return os.getenv_opt('VOX_BUILD_TOOL') or { os.executable() }
}

fn start_build_worker(root string, mode string) ! {
	state := production_state_dir(root)
	os.mkdir_all(state)!
	spawn_build_child([build_tool_executable(), 'supervise', mode], production_environment(os.environ()), root,
		os.join_path(state, 'worker.log'), true, '', false, true)!
}

fn enqueue_build(root string, background bool, explicit bool, c_mode string, v_prod bool,
	renderer string, backend string) ! {
	validate_build_repository(root)!
	state := production_state_dir(root)
	mut held := acquire_file_lock(os.join_path(state, 'queue.lock'), false)!
	defer { held.release() }
	prior := read_build_request(state) or { BuildRequest{} }
	started := read_build_object(os.join_path(state, 'started.json'))
	pending := prior.id != build_string(started, 'id', '')
	prod := if explicit { v_prod } else { prior.v_prod }
	mode := if explicit {
		c_mode
	} else if prod || (prior.c_mode == 'single' && pending) {
		prior.c_mode
	} else {
		'parallel'
	}
	selected_renderer := if explicit {
		renderer
	} else if pending {
		prior.renderer
	} else {
		'gg'
	}
	selected_backend := if backend != '' {
		backend
	} else if pending {
		prior.backend
	} else {
		''
	}
	request := BuildRequest{
		id:       rand.uuid_v4().replace('-', '')
		head:     supervisor_git(root, ['rev-parse', 'HEAD'])!.trim_space()
		c_mode:   mode
		v_prod:   prod
		renderer: selected_renderer
		backend:  selected_backend
	}
	atomic_write_json_text(os.join_path(state, 'request.json'), json.encode(build_request_object(request)))!
	if background { start_build_worker(root, '--worker')! }
}

fn run_supervised_build(root string, stage string, receipt string, request BuildRequest) !int {
	mut environment := os.environ()
	for key, _ in environment.clone() {
		if key.starts_with('GIT_') { environment.delete(key) }
	}
	environment['VOX_BUILD_SUPERVISED'] = '1'
	environment['VOX_BUILD_OUTPUT_DIR'] = stage
	environment['VOX_BUILD_COMPILE_PROTOCOL'] = build_protocol
	environment['VOX_BUILD_RECEIPT_DIR'] = receipt
	environment['VOX_BUILD_C_MODE'] = request.c_mode
	environment['VOX_BUILD_V_PROD'] = if request.v_prod { '1' } else { '0' }
	environment['VOX_USE_SKIA'] = if request.renderer == 'skia' { '1' } else { '0' }
	if request.backend != '' {
		environment['VOX_BUILD_BACKEND'] = request.backend
	} else {
		environment.delete('VOX_BUILD_BACKEND')
	}
	script := os.join_path(root, if os.user_os() == 'linux' {
		'build-linux-browser.sh'
	} else {
		'build-prod-browser.sh'
	})
	script_bytes := os.read_file(script)!
	atomic_write_json_text(os.join_path(receipt, 'build-script.json'), json.encode({
		'path':     json.Any(script)
		'bytes':    json.Any(script_bytes.len)
		'sha256':   json.Any(sha256.hexhash(script_bytes))
		'delivery': json.Any('memory through stdin')
	}))!
	state := production_state_dir(root)
	mut child := spawn_build_child([build_tool_executable(), 'memory', '--lock',
		os.join_path(state, 'memory.lock'), '--report', os.join_path(receipt, 'memory.json'),
		'--timeout', '2700', '--', 'sh', '-c', 'exec sh -c "$(cat)" "$0"', script],
		environment, root, os.join_path(receipt, 'build.log'), false, script_bytes, true, false)!
	wait_supervised_guard(mut child)!
	if child.exit_code != 0 { return child.exit_code }
	browser_executable := os.join_path(stage, if os.user_os() == 'macos' {
		'Vox.app/Contents/MacOS/Vox'
	} else {
		'vox'
	})
	environment['VOX_PROFILE_DIR'] = os.join_path(stage, 'smoke-profile')
	environment['VOX_TEST_WINDOW'] = '1'
	mut smoke := spawn_build_child([build_tool_executable(), 'memory', '--limit-gib', '3', '--lock',
		os.join_path(state, 'smoke.lock'), '--report', os.join_path(receipt, 'smoke-memory.json'),
		'--', browser_executable, '--headless-smoke'], environment, root, os.join_path(receipt, 'smoke.log'), false, '', false, false)!
	wait_supervised_guard(mut smoke)!
	return smoke.exit_code
}

fn wait_supervised_guard(mut child BuildChild) ! {
	mut interrupted := false
	for !child.poll(false)! {
		if !interrupted && C.vox_build_interrupted() != 0 {
			// Let the memory guard reap its isolated compiler group before the
			// supervisor releases locks or removes its private output directory.
			C.vox_build_terminate(i32(child.pid))
			interrupted = true
		}
		time.sleep(50 * time.millisecond)
	}
}

fn publish_build_unlocked(root string, stage string) ! {
	platform := if os.user_os() == 'macos' { 'v' } else { 'linux' }
	target := os.join_path(root, 'Build', platform)
	os.mkdir_all(target)!
	if os.user_os() == 'macos' {
		source_app := os.join_path(stage, 'Vox.app')
		target_app := os.join_path(target, 'Vox.app')
		result := if os.exists(target_app) {
			C.vox_build_exchange(&char(source_app.str), &char(target_app.str))
		} else {
			C.vox_build_replace(&char(source_app.str), &char(target_app.str))
		}
		if result != 0 { return native_build_error('Atomic application publication failed') }
	}
	for name in os.ls(stage)! {
		source := os.join_path(stage, name)
		if os.is_file(source) && os.file_ext(source) in ['.so', '.dylib'] {
			destination := os.join_path(target, name)
			if C.vox_build_replace(&char(source.str), &char(destination.str)) != 0 {
				return native_build_error('Cannot publish ${name}')
			}
		}
	}
	if platform == 'linux' {
		source := os.join_path(stage, 'vox')
		destination := os.join_path(target, 'vox')
		if C.vox_build_replace(&char(source.str), &char(destination.str)) != 0 {
			return native_build_error('Atomic executable publication failed')
		}
	}
}

fn try_publish_build(root string, stage string) !bool {
	mut lease := acquire_file_lock(os.join_path(production_state_dir(root), 'bundle.lock'), true)!
	defer { lease.release() }
	if !lease.acquired { return false }
	publish_build_unlocked(root, stage)!
	return true
}

fn same_build_options(first BuildRequest, second BuildRequest) bool {
	return first.renderer == second.renderer && first.c_mode == second.c_mode
		&& first.v_prod == second.v_prod && first.backend == second.backend
}

fn build_pending(root string, foreground bool) !int {
	validate_build_repository(root)!
	state := production_state_dir(root)
	mut build_lock := acquire_file_lock(os.join_path(state, 'build.lock'), true)!
	defer { build_lock.release() }
	if !build_lock.acquired {
		println('Production build already running; latest request is recorded.')
		return if foreground { 75 } else { 0 }
	}
	for {
		if C.vox_build_interrupted() != 0 { return 128 + int(C.vox_build_interrupted()) }
		request := read_build_request(state)!
		atomic_write_json_text(os.join_path(state, 'started.json'), json.encode({
			'id': request.id
		}))!
		before := repository_state(root)!
		name := time.now().custom_format('YYYYMMDD-HHmmss') + '-' + rand.uuid_v4()[..8]
		receipt := os.join_path(state, 'receipts', name)
		os.mkdir_all(receipt)!
		prune_production_receipts(state)!
		stage := os.join_path(root, 'Build', '.production-output-' + rand.uuid_v4())
		os.mkdir(stage, mode: 0o700)!
		// Stage ownership is per iteration. Explicit cleanup below also handles
		// errors; no partial build is ever written over the published executable.
		outcome := build_one_request(root, state, stage, receipt, request, before) or {
			os.rmdir_all(stage) or {}
			return err
		}
		os.rmdir_all(stage) or {}
		if C.vox_build_interrupted() != 0 { return 128 + int(C.vox_build_interrupted()) }
		if outcome == -1 { continue }
		mut queue_lock := acquire_file_lock(os.join_path(state, 'queue.lock'), false)!
		latest := read_build_request(state) or {
			queue_lock.release()
			return err
		}
		current := repository_state(root) or {
			queue_lock.release()
			return err
		}
		if latest.id == request.id && (outcome == 0 || same_build_inputs(current, before)) {
			build_lock.release()
			queue_lock.release()
			if outcome == 0 { println('Published canonical production browser: ${before.head}') }
			return outcome
		}
		matches := same_build_inputs(current, before) || frozen_checkout_matches(root, receipt)
		if outcome == 0 && same_build_options(latest, request) && matches {
			build_lock.release()
			queue_lock.release()
			println('Published canonical production browser: ${before.head}')
			return 0
		}
		queue_lock.release()
	}
	return 0
}

fn build_one_request(root string, state string, stage string, receipt string, request BuildRequest,
	before RepositoryState) !int {
	atomic_write_json_text(os.join_path(receipt, 'inputs-before.json'), json.encode(before))!
	code := run_supervised_build(root, stage, receipt, request)!
	mut record := map[string]json.Any{}
	record['request'] = build_request_object(request)
	record['inputs'] = repository_state_object(before)
	record['exit'] = code
	for name in ['c-compile', 'renderer'] {
		path := os.join_path(receipt, name + '.json')
		if os.exists(path) {
			parsed := json.parse(os.read_file(path)!)!
			record[if name == 'c-compile' { 'c_compile' } else { name }] = parsed
		}
	}
	if code != 0 {
		atomic_write_json_text(os.join_path(receipt, 'result.json'), json.encode(record))!
		println('Production build failed; previous bundle retained. See ${receipt}')
		return if code < 0 { 128 - code } else { code }
	}
	after := repository_state(root)!
	record['verified_inputs'] = repository_state_object(after)
	frozen_path := os.join_path(receipt, 'frozen-compile.json')
	frozen := os.is_file(frozen_path)
	if frozen {
		accepted := accepted_frozen_source(root, receipt, before) or {
			record['exit'] = 1
			record['frozen_input_error'] = err.msg()
			atomic_write_json_text(os.join_path(receipt, 'result.json'), json.encode(record))!
			eprintln('Frozen production inputs rejected: ${err}')
			return 1
		}
		record['frozen_compilation'] = frozen_path
		record['repository_after_build'] = repository_state_object(after)
		record['verified_inputs'] = repository_state_object(accepted)
	} else if !same_build_inputs(before, after) {
		record['superseded'] = true
		atomic_write_json_text(os.join_path(receipt, 'result.json'), json.encode(record))!
		return -1
	}
	ready_executable := os.join_path(stage, if os.user_os() == 'macos' {
		'Vox.app/Contents/MacOS/Vox'
	} else {
		'vox'
	})
	mut ready := record.clone()
	ready['ready_executable'] = ready_executable
	ready['ready_executable_sha256'] = hash_file(ready_executable)!
	atomic_write_json_text(os.join_path(receipt, 'ready.json'), json.encode(ready))!
	ready_time := time.sys_mono_now()
	for {
		if C.vox_build_interrupted() != 0 { return 128 + int(C.vox_build_interrupted()) }
		mut artifact := acquire_file_lock(os.join_path(receipt, 'artifact.lock'), true)!
		if artifact.acquired {
			published := try_publish_build(root, stage) or {
				artifact.release()
				return err
			}
			if published {
				artifact.release()
				break
			}
			mut queue := acquire_file_lock(os.join_path(state, 'queue.lock'), false)!
			latest := read_build_request(state) or {
				queue.release()
				artifact.release()
				return err
			}
			queue.release()
			matches := if frozen {
				frozen_checkout_matches(root, receipt)
			} else {
				same_build_inputs(repository_state(root)!, before)
			}
			if latest.id != request.id && time.sys_mono_now() - ready_time >= u64(5 * time.second)
				&& (!same_build_options(latest, request) || !matches) {
				record['superseded'] = true
				record['publication_deferred'] = 'reader lease held; newer source requested'
				atomic_write_json_text(os.join_path(receipt, 'result.json'), json.encode(record))!
				artifact.release()
				println('Superseded an unpublished build; the leased browser is unchanged.')
				return -1
			}
		}
		artifact.release()
		time.sleep(250 * time.millisecond)
	}
	browser_executable := os.join_path(root, if os.user_os() == 'macos' {
		'Build/v/Vox.app/Contents/MacOS/Vox'
	} else {
		'Build/linux/vox'
	})
	record['executable'] = browser_executable
	record['executable_sha256'] = hash_file(browser_executable)!
	encoded := json.encode(record)
	atomic_write_json_text(os.join_path(receipt, 'result.json'), encoded)!
	atomic_write_json_text(os.join_path(state, 'latest.json'), encoded)!
	return 0
}

fn prune_production_receipts(state string) ! {
	root := os.join_path(state, 'receipts')
	if !os.is_dir(root) { return }
	mut names := os.ls(root)!
	names.sort()
	names = names.filter(os.is_dir(os.join_path(root, it)))
	if names.len == 0 { return }
	published := os.read_file(os.join_path(state, 'latest.json')) or { '' }
	for index, name in names {
		receipt := os.join_path(root, name)
		if index == names.len - 1 { continue }
		result := os.read_file(os.join_path(receipt, 'result.json')) or { '' }
		if published != '' && result == published { continue }
		// A reviewer may retain an unpublished completed artifact/receipt.
		mut artifact := acquire_file_lock(os.join_path(receipt, 'artifact.lock'), true)!
		if !artifact.acquired { continue }
		if index < names.len - 20 {
			remove_build_entry(receipt) or {
				artifact.release()
				return err
			}
		} else {
			for payload in ['generated', 'frozen-compiler-inputs'] {
				path := os.join_path(receipt, payload)
				if os.is_dir(path) {
					remove_build_entry(path) or {
						artifact.release()
						return err
					}
				}
			}
		}
		artifact.release()
	}
}

fn supervise(root string, args []string) !int {
	if C.vox_build_signals_begin() != 0 {
		return native_build_error('Cannot install build supervisor signal handlers')
	}
	defer { C.vox_build_signals_end() }
	mut mode := ''
	mut c_mode := 'parallel'
	mut explicit_c_mode := false
	mut v_prod := false
	mut backend := ''
	mut index := 0
	for index < args.len {
		argument := args[index]
		match argument {
			'--build', '--request', '--worker', '--upgrade-worker', '--worker-after-current',
			'--install-hook' {
				if mode != '' { return error('Select one supervisor mode') }
				mode = argument
			}
			'--no-parallel-cc', '--parallel-cc' {
				if explicit_c_mode { return error('Select one C compilation mode') }
				explicit_c_mode = true
				c_mode = if argument == '--no-parallel-cc' { 'single' } else { 'parallel' }
			}
			'--prod' { v_prod = true }
			'--backend' {
				index++
				if index >= args.len || args[index] !in ['c', 'fastc'] {
					return error('--backend requires c or fastc')
				}
				backend = args[index]
			}
			else { return error('Unknown build supervisor option: ${argument}') }
		}
		index++
	}
	if mode == '' { return error('Specify --build, --request or --worker') }
	if (explicit_c_mode || v_prod) && mode != '--build' {
		return error('Compilation options require --build')
	}
	if backend != '' && mode !in ['--build', '--request'] {
		return error('--backend requires --build or --request')
	}
	if v_prod && !explicit_c_mode { c_mode = 'single' }
	match mode {
		'--install-hook' {
			install_native_build_hooks(root)!
			return 0
		}
		'--request' {
			enqueue_build(root, true, false, '', false, '', backend)!
			return 0
		}
		'--upgrade-worker' {
			start_build_worker(root, '--worker-after-current')!
			return 0
		}
		'--worker-after-current' {
			mut upgrade := acquire_file_lock(os.join_path(production_state_dir(root), 'upgrade-${build_protocol}.lock'), true)!
			defer { upgrade.release() }
			if !upgrade.acquired { return 0 }
			mut current := acquire_file_lock(os.join_path(production_state_dir(root), 'build.lock'), false)!
			current.release()
			return build_pending(root, false)
		}
		'--build' {
			legacy := os.getenv_opt('VOX_USE_SKIA') or { '0' }
			if legacy !in ['0', '1'] { return error('VOX_USE_SKIA must be 0 or 1') }
			enqueue_build(root, false, true, c_mode, v_prod, if legacy == '1' {
				'skia'
			} else {
				'gg'
			}, backend)!
		}
		else {}
	}
	code := build_pending(root, mode == '--build')!
	prune_build_idle(root, 12 * 3600, false, false) or {
		eprintln('Build/ pruning skipped: ${err}')
	}
	return code
}

fn install_native_build_hooks(root string) ! {
	validate_build_repository(root)!
	mut path := supervisor_git(root, ['rev-parse', '--git-path', 'hooks/post-commit'])!.trim_space()
	if !os.is_abs_path(path) { path = os.join_path(root, path) }
	hooks := os.dir(path)
	if !os.real_path(hooks).starts_with(os.real_path(root) + os.path_separator) {
		return error('Shared external hooks directory retained; install the Vox request manually')
	}
	os.mkdir_all(hooks)!
	post_commit := '#!/bin/sh\n# Vox canonical production rebuild hook; managed by tools/voxbuild.\nset -eu\nrepo=$(git rev-parse --show-toplevel)\nexec sh "$repo/tools/vox-build.sh" supervise --request\n'
	pre_commit := '#!/bin/sh\n# Vox staged-file check; managed by tools/voxbuild.\nset -eu\nrepo=$(git rev-parse --show-toplevel)\nexec sh "$repo/tools/vox-build.sh" pre-commit\n'
	contents := {
		path:                              post_commit
		os.join_path(hooks, 'pre-commit'): pre_commit
	}
	for hook, content in contents {
		if os.exists(hook) {
			existing := os.read_file(hook)!
			if existing != content && existing != legacy_build_hook(os.file_name(hook)) {
				return error('Existing ${os.file_name(hook)} hook retained; install the Vox hook manually')
			}
		}
	}
	for hook, content in contents {
		os.write_file(hook, content)!
		os.chmod(hook, 0o755)!
	}
	println('Installed canonical master rebuild and staged-file hooks in ${hooks}')
}

fn legacy_build_hook(name string) string {
	return match name {
		'post-commit' {
			'#!/bin/sh\n# Vox canonical production rebuild hook; managed by tools/rebuild_browser.py.\nset -eu\nrepo=$(git rev-parse --show-toplevel)\nexec python3 "$repo/tools/rebuild_browser.py" --request\n'
		}
		'pre-commit' {
			'#!/bin/sh\n# Vox staged-file check; managed by tools/rebuild_browser.py.\nset -eu\nrepo=$(git rev-parse --show-toplevel)\n# Worktrees of older branches share these hooks but may predate the check.\n[ -f "$repo/tools/pre_commit_check.py" ] || exit 0\nexec python3 "$repo/tools/pre_commit_check.py"\n'
		}
		else { '' }
	}
}
