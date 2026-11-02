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
