module platform

import os
import time

fn restore_layout_font_policy_environment(previous ?string) {
	if value := previous {
		os.setenv('LADYBIRD_LAYOUT_TEST_FONT', value, true)
	} else {
		os.unsetenv('LADYBIRD_LAYOUT_TEST_FONT')
	}
}

fn test_layout_font_policy_scope_observes_each_outer_pass_and_live_unscoped_queries() {
	previous := os.getenv_opt('LADYBIRD_LAYOUT_TEST_FONT')
	defer { restore_layout_font_policy_environment(previous) }
	path := os.join_path(os.temp_dir(), 'vox-font-policy-${os.getpid()}-${time.sys_mono_now()}')
	defer { os.rm(path) or {} }
	os.setenv('LADYBIRD_LAYOUT_TEST_FONT', path, true)
	assert !layout_test_font_is_configured()
	mut first := begin_layout_font_policy_scope()
	os.write_file(path, 'configured font file')!
	for _ in 0 .. 128 { assert !layout_test_font_is_configured() }
	first.finish()
	assert layout_test_font_is_configured()
	mut second := begin_layout_font_policy_scope()
	os.rm(path)!
	for _ in 0 .. 128 { assert layout_test_font_is_configured() }
	second.finish()
	assert !layout_test_font_is_configured()
}

fn test_nested_layout_font_policy_scopes_preserve_the_outer_snapshot() {
	previous := os.getenv_opt('LADYBIRD_LAYOUT_TEST_FONT')
	defer { restore_layout_font_policy_environment(previous) }
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	os.unsetenv('LADYBIRD_LAYOUT_TEST_FONT')
	mut outer := begin_layout_font_policy_scope()
	os.setenv('LADYBIRD_LAYOUT_TEST_FONT', source, true)
	mut inner := begin_layout_font_policy_scope()
	assert !layout_test_font_is_configured()
	inner.finish()
	inner.finish()
	assert !layout_test_font_is_configured()
	outer.finish()
	assert layout_test_font_is_configured()
	outer.finish()
	os.unsetenv('LADYBIRD_LAYOUT_TEST_FONT')
	assert !layout_test_font_is_configured()
}

fn font_policy_scope_early_return() bool {
	mut scope := begin_layout_font_policy_scope()
	defer { scope.finish() }
	return layout_test_font_is_configured()
}

fn test_layout_font_policy_scope_unwinds_on_early_return() {
	previous := os.getenv_opt('LADYBIRD_LAYOUT_TEST_FONT')
	defer { restore_layout_font_policy_environment(previous) }
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	os.unsetenv('LADYBIRD_LAYOUT_TEST_FONT')
	assert !font_policy_scope_early_return()
	os.setenv('LADYBIRD_LAYOUT_TEST_FONT', source, true)
	assert font_policy_scope_early_return()
	assert layout_test_font_is_configured()
	os.unsetenv('LADYBIRD_LAYOUT_TEST_FONT')
	assert !layout_test_font_is_configured()
}

fn layout_font_policy_on_worker() bool {
	return layout_test_font_is_configured()
}

fn test_layout_font_policy_snapshot_is_local_to_the_layout_thread() {
	previous := os.getenv_opt('LADYBIRD_LAYOUT_TEST_FONT')
	defer { restore_layout_font_policy_environment(previous) }
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	os.unsetenv('LADYBIRD_LAYOUT_TEST_FONT')
	mut scope := begin_layout_font_policy_scope()
	defer { scope.finish() }
	os.setenv('LADYBIRD_LAYOUT_TEST_FONT', source, true)
	worker := spawn layout_font_policy_on_worker()
	assert worker.wait()
	assert !layout_test_font_is_configured()
}

fn test_resolved_font_policy_remains_live_after_the_layout_scope() {
	if !system_font_matching_supported() { return }
	previous := os.getenv_opt('LADYBIRD_LAYOUT_TEST_FONT')
	defer { restore_layout_font_policy_environment(previous) }
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	font := &Font{
		family: 'Verdana'
		point_size: 16
		font_rendering_policy: .chromium
		resolved_system_face_: SystemFontFace{family_name: 'Verdana'}
		system_face_resolved_: true
	}
	os.unsetenv('LADYBIRD_LAYOUT_TEST_FONT')
	mut scope := begin_layout_font_policy_scope()
	os.setenv('LADYBIRD_LAYOUT_TEST_FONT', source, true)
	assert font.system_face() != none
	scope.finish()
	assert font.system_face() == none
	os.unsetenv('LADYBIRD_LAYOUT_TEST_FONT')
	assert font.system_face() != none
}
