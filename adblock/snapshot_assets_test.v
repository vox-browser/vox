module adblock

import os
import time

fn with_snapshot_assets_fixture() (string, string) {
	previous := os.getenv('VOX_ADBLOCK_ENGINE_ASSETS')
	directory := os.join_path(os.temp_dir(), 'vox-snapshot-assets-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory) or { panic(err) }
	root := os.dir(@FILE)
	for name in ['engine.js.gz', 'engine.snapshot.bin', 'engine.snapshot.json.gz'] {
		os.symlink(os.real_path(os.join_path(root, name)), os.join_path(directory, name)) or { panic(err) }
	}
	os.setenv('VOX_ADBLOCK_ENGINE_ASSETS', directory, true)
	return directory, previous
}

fn restore_snapshot_assets_fixture(directory string, previous string) {
	if previous == '' { os.unsetenv('VOX_ADBLOCK_ENGINE_ASSETS') } else {
		os.setenv('VOX_ADBLOCK_ENGINE_ASSETS', previous, true)
	}
	os.rmdir_all(directory) or { panic(err) }
}

fn test_diagnostic_assets_restore_full_default_filters_and_custom_suffix_parsing() {
	directory, previous := with_snapshot_assets_fixture()
	defer { restore_snapshot_assets_fixture(directory, previous) }
	context := create_context(none)!
	defer { C.JSGlobalContextRelease(context) }
	decision := evaluate_context(context, 'voxAdblockCheck({url:"https://securepubads.g.doubleclick.net/tag/js/gpt.js",source_url:"https://www.theverge.com/",request_type:"script"})')!
	assert decision.contains('"blocked":true')
	assert evaluate_context(context, 'JSON.stringify(voxDocumentFilters("https://www.theverge.com/",[".ad-banner"]))')!.contains('duet--layout--rail')
	mut custom := new_engine('||metrics.example^$third-party,script')!
	defer { custom.close() }
	assert custom.check(Request{url:'https://metrics.example/ad.js',source_url:'https://www.example.co.uk/',request_type:'script'}).blocked
}

fn test_diagnostic_missing_snapshot_does_not_use_bundled_fallback() {
	directory, previous := with_snapshot_assets_fixture()
	defer { restore_snapshot_assets_fixture(directory, previous) }
	os.rm(os.join_path(directory, 'engine.snapshot.bin'))!
	mut rejected := false
	context := create_context(none) or {
		assert err.msg().contains('Cannot restore bundled adblock snapshot')
		rejected = true
		unsafe { nil }
	}
	if context != unsafe { nil } { C.JSGlobalContextRelease(context) }
	assert rejected
}

fn test_diagnostic_missing_source_releases_context_and_does_not_use_embedded_source() {
	directory, previous := with_snapshot_assets_fixture()
	defer { restore_snapshot_assets_fixture(directory, previous) }
	os.rm(os.join_path(directory, 'engine.js.gz'))!
	mut rejected := false
	context := create_context(none) or {
		assert err.msg().contains('Cannot read diagnostic adblock source')
		rejected = true
		unsafe { nil }
	}
	if context != unsafe { nil } { C.JSGlobalContextRelease(context) }
	assert rejected
}

fn test_packaged_codec_and_metadata_follow_the_snapshot_for_browser_and_worker() {
	directory := os.join_path(os.temp_dir(), 'vox-packaged-assets-${os.getpid()}-${time.sys_mono_now()}')
	resources := os.join_path(directory, 'Vox.app', 'Contents', 'Resources')
	os.mkdir_all(resources)!
	os.mkdir_all(os.join_path(os.dir(resources), 'MacOS'))!
	defer { os.rmdir_all(directory) or { panic(err) } }
	for name in ['engine.snapshot.bin', 'engine.snapshot.json.gz', 'engine.js.gz'] {
		os.write_file(os.join_path(resources, snapshot_resource_name(name)), 'packaged ${name}')!
	}
	for binary in ['Vox', 'VoxAdblockWorker'] {
		executable := os.join_path(directory, 'Vox.app', 'Contents', 'MacOS', binary)
		for name in ['engine.snapshot.bin', 'engine.snapshot.json.gz', 'engine.js.gz'] {
			path := snapshot_asset_path_for_executable(executable, none, name) or { panic('missing packaged asset') }
			assert os.read_file(path)! == 'packaged ${name}'
			selected := snapshot_asset_path_for_executable(executable, os.join_path(directory, 'diagnostic'), name) or { panic('missing diagnostic asset') }
			assert selected == os.join_path(directory, 'diagnostic', name)
			assert !os.exists(selected)
		}
		// A partial package must fail reading its missing codec, even when an
		// embedded checkout version would be available to standalone tools.
		os.rm(os.join_path(resources, 'adblock.engine.js.gz'))!
		missing := snapshot_asset_path_for_executable(executable, none, 'engine.js.gz') or { panic('missing packaged path') }
		if _ := os.read_bytes(missing) { assert false }
		os.write_file(os.join_path(resources, 'adblock.engine.js.gz'), 'packaged engine.js.gz')!
	}
}

fn test_standalone_tools_keep_the_embedded_fallback_without_a_packaged_set() {
	executable := os.join_path(os.temp_dir(), 'vox-no-package-${os.getpid()}', 'tool')
	for name in ['engine.snapshot.bin', 'engine.snapshot.json.gz', 'engine.js.gz'] {
		assert snapshot_asset_path_for_executable(executable, none, name) == none
	}
}

fn test_a_partial_package_cannot_restore_the_checkout_snapshot() {
	directory := os.join_path(os.temp_dir(), 'vox-partial-assets-${os.getpid()}-${time.sys_mono_now()}')
	resources := os.join_path(directory, 'Contents', 'Resources')
	os.mkdir_all(resources)!
	os.mkdir_all(os.join_path(os.dir(resources), 'MacOS'))!
	defer { os.rmdir_all(directory) or { panic(err) } }
	os.write_file(os.join_path(resources, 'adblock.engine.js.gz'), 'codec')!
	path := snapshot_asset_path_for_executable(os.join_path(directory, 'Contents', 'MacOS', 'Vox'), none, 'engine.snapshot.bin') or { panic('missing packaged path') }
	if _ := os.read_bytes(path) { assert false }
}
