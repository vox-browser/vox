module buildtools

import os
import json2 as json

fn test_shell_words_round_trip() ! {
	values := ['clang', '-I/path with spaces', 'quote\'and"dollar\$', '', 'a\\b', '\n']
	assert shell_split(shell_join(values))! == values
	assert shell_split("a 'unterminated") or { []string{} } == []string{}
}

fn test_backend_rejects_ambiguous_or_argument_values() ! {
	root := temporary(os.temp_dir(), 'vox-backend-test-')!
	defer { remove(root) or {} }
	for source in ["Module {\nbackend: 'c'\n}\n", "Module {\n backend: 'fastc', // accepted\n}\n"] {
		os.write_file(join(root, 'v.mod'), source)!
		assert browser_backend(root)! in ['c', 'fastc']
	}
	for source in ['Module {}', "backend: 'c'\nbackend: 'fastc'", "backend: 'c -skip-check'\n"] {
		os.write_file(join(root, 'v.mod'), source)!
		mut failed := false
		browser_backend(root) or { failed = true }
		assert failed
	}
}

fn test_fingerprints_detect_changed_and_deleted_inputs() ! {
	root := temporary(os.temp_dir(), 'vox-fingerprint-test-')!
	defer { remove(root) or {} }
	path := join(root, 'input')
	os.write_file(path, 'first')!
	inputs := fingerprint([path])!
	check_fingerprints(inputs)!
	os.write_file(path, 'second')!
	mut rejected := false
	check_fingerprints(inputs) or { rejected = true }
	assert rejected
	os.rm(path)!
	rejected = false
	check_fingerprints(inputs) or { rejected = true }
	assert rejected
}

fn test_compiler_manifest_rejects_conflicts_and_unverified_buffers() ! {
	root := temporary(os.temp_dir(), 'vox-manifest-test-')!
	defer { remove(root) or {} }
	path := join(root, 'source.v')
	os.write_file(path, 'module example\n')!
	sha := digest(path)!
	os.write_file(join(root, 'v_sources'), path)!
	os.write_file(join(root, 'v_source_digests'), sha)!
	assert component_inputs(root)! == {
		path: sha
	}
	mut rejected := false
	verified_component(root) or { rejected = true }
	assert rejected
	write_json(join(root, 'parsed-verified.json'), json.Any(map[string]json.Any{
		'protocol': 'verified-parsed-buffers-v1'
		'sources':  record_strings({
			path: sha
		})
	}))!
	assert verified_component(root)! == {
		path: sha
	}
	os.write_file(join(root, 'v_source_digests'), hash('different'))!
	rejected = false
	verified_component(root) or { rejected = true }
	assert rejected
	os.write_file(join(root, 'v_sources'), path + '\x00' + path)!
	os.write_file(join(root, 'v_source_digests'), sha + '\x00' + hash('different'))!
	rejected = false
	component_inputs(root) or { rejected = true }
	assert rejected
}

fn test_frozen_flags_reject_unsealed_inputs() ! {
	for flags in [['@unsealed.rsp'], ['-fmodules'], ['-Xlinker'], ['-Wl,-filelist,files'],
		['-Wl,-force_load,library.a'], ['-o', 'wrong'], ['-I']] {
		mut rejected := false
		parse_flags(flags, os.getwd()) or { rejected = true }
		assert rejected
	}
	parts := parse_flags(['-I', 'source.c', '-DVALUE=1', '-Wl,-rpath,@executable_path'], os.getwd())!
	assert parts.len == 3
	assert parts[0].kind == 'option'
}

fn test_bounded_guard_completes_and_stops_timeout_and_children() ! {
	result := bounded_run(['/bin/sh', '-c', 'exit 7'], 3 * 1073741824, 5, .01, '')!
	assert (result['reason'] or { json.Null{} }).str() == 'completed'
	assert (result['child_exit_code'] or { json.Null{} }).int() == 7
	timed := bounded_run(['/bin/sleep', '5'], 3 * 1073741824, .03, .01, '')!
	assert (timed['reason'] or { json.Null{} }).str() == 'timeout'
	limited := bounded_run(['/bin/sleep', '5'], 1, 5, .01, '')!
	assert (limited['reason'] or { json.Null{} }).str() == 'memory_limit'
	remaining := bounded_run(['/bin/sh', '-c', 'sleep 5 &'], 3 * 1073741824, 5, .01, '')!
	assert (remaining['reason'] or { json.Null{} }).str() == 'remaining_children'
}

fn test_guard_rejects_invalid_adoption_records() ! {
	root := temporary(os.temp_dir(), 'vox-adoption-test-')!
	defer { remove(root) or {} }
	path := join(root, 'registry.json')
	for value in ['{}', '[{"pid":true,"started":"identity"}]', '[{"pid":2,"started":""}]',
		'[{"pid":2.5,"started":"identity"}]'] {
		os.write_file(path, value)!
		mut rejected := false
		adopted_processes(path) or { rejected = true }
		assert rejected
	}
}

fn test_lock_is_exclusive_and_released() ! {
	root := temporary(os.temp_dir(), 'vox-lock-test-')!
	defer { remove(root) or {} }
	mut held := acquire(join(root, 'job.lock'), true)!
	mut rejected := false
	acquire(join(root, 'job.lock'), true) or { rejected = true }
	assert rejected
	held.release()
	mut next := acquire(join(root, 'job.lock'), true)!
	next.release()
}

fn test_patch_source_mismatch_fails_closed() {
	mut rejected := false
	replace_once('one one', 'one', 'two') or { rejected = true }
	assert rejected
	rejected = false
	patch_allocator('unsupported', 'unsupported') or { rejected = true }
	assert rejected
}

fn fixture_repository() !string {
	root := temporary(os.temp_dir(), 'vox-build-repository-test-')!
	git(root, 'init', '-b', 'master')!
	git(root, 'config', 'user.email', 'build-test@example.invalid')!
	git(root, 'config', 'user.name', 'Vox build tests')!
	os.write_file(join(root, '.gitignore'), 'Build/\n')!
	git(root, 'add', '.gitignore')!
	git(root, 'commit', '-m', 'Initialize build fixture')!
	return real(root)
}

fn test_queue_coalesces_explicit_backend_and_prod_requests() ! {
	root := fixture_repository()!
	defer { remove(root) or {} }
	enqueue(root, false, '', '', 'c')!
	enqueue(root, false, '', '', '')!
	state := state_dir(root)
	first := load(join(state, 'request.json'))!
	assert (first['backend'] or { json.Null{} }).str() == 'c'
	write_json(join(state, 'started.json'), json.Any(map[string]json.Any{
		'id': (first['id'] or { json.Null{} })
	}))!
	enqueue(root, false, '', '', '')!
	assert maybe_load(join(state, 'request.json'))['backend'] is json.Null
	enqueue(root, false, 'single', '1', 'c')!
	enqueue(root, false, '', '', '')!
	pending := load(join(state, 'request.json'))!
	assert (pending['v_prod'] or { json.Null{} }).bool()
	assert (pending['c_mode'] or { json.Null{} }).str() == 'single'
}

fn test_build_tool_sources_are_pinned_before_browser_parsing() ! {
	root := fixture_repository()!
	defer { remove(root) or {} }
	write_changed(join(root, 'tools/buildtools/adapter.v'), 'module buildtools\n')!
	inventory := begin_inventory(root)!
	validate_inventory(root, inventory, true)!
	write_changed(join(root, 'tools/buildtools/adapter.v'), 'module buildtools\n// changed\n')!
	mut rejected := false
	validate_inventory(root, inventory, true) or { rejected = true }
	assert rejected
	write_changed(join(root, 'tools/buildtools/adapter.v'), 'module buildtools\n')!
	write_changed(join(root, 'tools/buildtools/new_adapter.v'), 'module buildtools\n')!
	rejected = false
	validate_inventory(root, inventory, true) or { rejected = true }
	assert rejected
}

fn test_atomic_bundle_publication_obeys_reader_lock() ! {
	$if macos {
		root := fixture_repository()!
		defer { remove(root) or {} }
		stage := join(root, 'Build/stage')
		target := join(root, 'Build/v')
		write_changed(join(stage, 'Vox.app/Contents/MacOS/Vox'), 'candidate')!
		write_changed(join(target, 'Vox.app/Contents/MacOS/Vox'), 'previous')!
		mut held := acquire(join(state_dir(root), 'bundle.lock'), false)!
		assert !try_publish(root, stage)!
		assert read(join(target, 'Vox.app/Contents/MacOS/Vox'))! == 'previous'
		held.release()
		assert try_publish(root, stage)!
		assert read(join(target, 'Vox.app/Contents/MacOS/Vox'))! == 'candidate'
	}
}

fn test_staged_file_check_rejects_forbidden_outputs() ! {
	root := fixture_repository()!
	defer { remove(root) or {} }
	write_changed(join(root, 'docs/performance/result.json'), '{}')!
	git(root, 'add', 'docs/performance/result.json')!
	assert pre_commit(root)! == 1
	git(root, 'reset', 'HEAD', '--', 'docs/performance/result.json')!
	write_changed(join(root, 'docs/report.md'), 'Result')!
	git(root, 'add', 'docs/report.md')!
	assert pre_commit(root)! == 0
}

fn test_frozen_clang_compilation_uses_sealed_sources_and_headers() ! {
	$if macos {
		root := fixture_repository()!
		defer { remove(root) or {} }
		stage := join(root, 'Build/stage')
		receipt := join(root, 'Build/receipt')
		mkdir(receipt)!
		write_changed(join(stage, 'Vox.app/Contents/Resources/resource'), 'resource')!
		write_changed(join(root, 'packaging/Vox.entitlements.plist'), 'entitlements')!
		write_changed(join(root, 'tools/localize_bundle_rpaths.vsh'), '// packaging helper')!
		header := join(root, 'header.h')
		write_changed(header, '#define FROZEN_VALUE 7\n')!
		extra := join(root, 'extra.c')
		write_changed(extra, 'int extra_value(void) { return 3; }\n')!
		source := join(receipt, 'main.c')
		write_changed(source, '#include <stdio.h>\nint extra_value(void);\nint main(void) { printf("%d\\n", FROZEN_VALUE + extra_value()); }\n')!
		flags := join(receipt, 'flags')
		write_changed(flags, shell_join(['-O1', '-include', header, '-x', 'c', extra, '-x', 'none']))!
		inventory := begin_inventory(root)!
		inventory_path := join(receipt, 'inventory.json')
		manifest_path := join(receipt, 'manifest.json')
		write_json(inventory_path, json.Any(inventory))!
		write_json(manifest_path, (inventory['early_inputs'] or { json.Null{} }))!
		before := repository_state(root)!
		write_json(join(receipt, 'inputs-before.json'), json.Any(before))!
		output := join(stage, 'probe')
		a := arguments(['--root', root, '--stage', stage, '--receipt', receipt, '--source', source,
			'--flags', flags, '--output', output, '--source-manifest', manifest_path,
			'--source-inventory', inventory_path], []string{})!
		mut data := prepare_frozen(a)!
		write_changed(header, '#error must not reread this live header\n')!
		write_changed(extra, '#error must not reread this live source\n')!
		validate_frozen(receipt, before, false)!
		checked(strings((data['compiler_command'] or { json.Null{} })))!
		assert trimmed_eq(capture([output])!, '10')
		data['compiler_exit'] = 0
		data['complete'] = true
		write_json(join(receipt, 'frozen-compile.json'), json.Any(data))!
		validate_frozen(receipt, before, true)!
		write_changed(join(stage, 'Vox.app/Contents/Resources/resource'), 'changed')!
		mut rejected := false
		validate_frozen(receipt, before, true) or { rejected = true }
		assert rejected
	}
}

fn test_process_identity_preserves_ps_date_spacing() {
	assert process_start_identity('  31  20  31  1024 S  Thu Nov  5 12:34:56 2026') == 'Thu Nov  5 12:34:56 2026'
}

fn test_managed_hooks_upgrade_without_replacing_custom_hooks() ! {
	root := fixture_repository()!
	defer { remove(root) or {} }
	install_hook(root)!
	install_hook(root)!
	assert read(join(root, '.git/hooks/post-commit'))!.contains('rebuild_browser --request --backend c --prod')
	assert !read(join(root, '.git/hooks/pre-commit'))!.contains('python')
	os.write_file(join(root, '.git/hooks/post-commit'), '#!/bin/sh\necho custom\n')!
	mut rejected := false
	install_hook(root) or { rejected = true }
	assert rejected
	assert read(join(root, '.git/hooks/post-commit'))! == '#!/bin/sh\necho custom\n'
}

fn test_pruning_preserves_published_and_newest_payloads_and_retention() ! {
	root := temporary(os.temp_dir(), 'vox-prune-test-')!
	defer { remove(root) or {} }
	build := join(root, 'Build')
	state := join(build, 'production-build')
	for i in 100 .. 123 {
		receipt := join(state, 'receipts', i.str())
		write_changed(join(receipt, 'result.json'), i.str())!
		write_changed(join(receipt, 'generated/source.c'), 'generated fixture')!
	}
	write_changed(join(state, 'latest.json'), '101')!
	prune_receipts(build, false)!
	assert !exists(join(state, 'receipts/100'))
	assert exists(join(state, 'receipts/101/generated/source.c'))
	assert !exists(join(state, 'receipts/102'))
	assert exists(join(state, 'receipts/103/result.json'))
	assert !exists(join(state, 'receipts/103/generated'))
	assert exists(join(state, 'receipts/122/generated/source.c'))
}

fn test_pruning_does_not_follow_symlinks() ! {
	root := temporary(os.temp_dir(), 'vox-prune-link-test-')!
	defer { remove(root) or {} }
	write_changed(join(root, 'keep/input'), 'preserved')!
	link_to(join(root, 'discard'), join(root, 'keep'))!
	retire(join(root, 'discard'), false)!
	assert read(join(root, 'keep/input'))! == 'preserved'
	assert !exists(join(root, 'discard'))
}

fn test_build_lock_is_not_inherited_by_executed_children() ! {
	$if !windows {
		root := temporary(os.temp_dir(), 'vox-lock-inheritance-test-')!
		defer { remove(root) or {} }
		path := join(root, 'build.lock')
		mut held := acquire(path, true)!
		mut child := os.new_process('/bin/sh')
		child.set_args(['-c', 'echo ready >"$1"; exec sleep 5', 'sh', join(root, 'ready')])
		child.run()
		defer {
			child.signal_kill()
			child.wait()
			child.close()
		}
		for !exists(join(root, 'ready')) { if !child.is_alive() { panic('Child did not start') } }
		// Model abrupt parent exit: close without explicitly unlocking the OFD.
		held.file.close()
		held.held = false
		mut next := acquire(path, true)!
		next.release()
	}
}

fn test_windows_mesa_rejects_corrupt_cached_archives() ! {
    root := temporary(os.temp_dir(), 'vox-mesa-checksum-')!
    defer { remove(root) or {} }
    mkdir(join(root, 'mesa'))!
    mesa_version := load(join(root_dir(), 'tools/windows_mesa.json'))!['version']!.str()
    for kind in ['devel-mingw', 'release-mingw'] {
        os.write_file(join(root, 'mesa', 'mesa3d-${mesa_version}-${kind}.7z'), 'corrupt dependency')!
    }
    mut failure := ''
    prepare_windows_mesa(root) or { failure = err.msg() }
    assert failure.starts_with('Mesa archive checksum mismatch:')
    assert !os.exists(join(root, 'mesa/lib/pkgconfig/vox-mesa-egl.pc'))
}
