module adblock

import os
import time

#include <sys/wait.h>
#include "@DIR/default_engine_release_test.h"
fn C.vox_adblock_test_exchange_error(&char) &char
fn C.kill(int, int) int
fn C.waitpid(int, &int, int) int

__global worker_test_owned_directory = ''

fn worker_test_build_helpers_if_needed() ! {
	if os.getenv('VOX_ADBLOCK_WORKER_HELPER') != '' && os.getenv('VOX_ADBLOCK_WORKER_FAKE') != '' { return }
	root := os.real_path(os.join_path(os.dir(@FILE), '..'))
	directory := os.join_path(os.temp_dir(), 'vox-adblock-worker-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(directory)!
	worker_test_owned_directory = directory
	for name in ['tmp', 'cache'] { os.mkdir_all(os.join_path(directory, name))! }
	mut compiler := os.getenv('V_BIN')
	if compiler == '' { compiler = os.getenv('VEXE') }
	if compiler == '' { compiler = os.find_abs_path_of_executable('v') or { os.expand_tilde_to_home('~/code/v/v') } }
	gc := $if gcboehm ? { 'boehm' } $else { 'none' }
	if os.getenv('VOX_ADBLOCK_WORKER_HELPER') == '' {
		helper := os.join_path(directory, 'worker')
		command := ['/usr/bin/env', 'VTMP=' + os.join_path(directory, 'tmp'),
			'TMPDIR=' + os.join_path(directory, 'tmp'), 'VCACHE=' + os.join_path(directory, 'cache'),
			compiler, '-bug-report-url', 'http://127.0.0.1:9', '-enable-globals',
			'-exclude', '@vlib/time/zoneinfo.native.v', '-gc', gc, '-path', root + '|@vlib',
			'-o', helper, os.join_path(root, 'tools/adblock-worker-mini/main.v')]
		result := os.execute(command.map(os.quoted_path(it)).join(' '))
		os.write_file(os.join_path(directory, 'helper-build.log'), result.output)!
		assert result.exit_code == 0, result.output
		os.setenv('VOX_ADBLOCK_WORKER_HELPER', helper, true)
	}
	if os.getenv('VOX_ADBLOCK_WORKER_FAKE') == '' {
		fake := os.join_path(directory, 'fake-worker')
		command := ['cc', '-std=c11', '-O2', os.join_path(root, 'tools/adblock_worker_fake_test.c'), '-o', fake]
		result := os.execute(command.map(os.quoted_path(it)).join(' '))
		os.write_file(os.join_path(directory, 'fake-build.log'), result.output)!
		assert result.exit_code == 0, result.output
		os.setenv('VOX_ADBLOCK_WORKER_FAKE', fake, true)
	}
}

fn testsuite_begin() {
	worker_test_build_helpers_if_needed()!
	assert C.vox_adblock_worker_is_configured() == 0
	assert default_worker_pid() == 0
	assert C.vox_adblock_get_context() == unsafe { nil }
	configure_default_worker_with_deadline(os.getenv('VOX_ADBLOCK_WORKER_HELPER'), 15000)!
}

fn testsuite_end() {
	_ = release_unused_engine()
	assert default_worker_pid() == 0
	configure_default_worker('')!
	assert C.vox_adblock_worker_is_configured() == 0
	if worker_test_owned_directory != '' {
		os.rmdir_all(worker_test_owned_directory)!
	}
}

fn test_worker_explicit_opt_in_context_isolation_and_lazy_restore() {
	_ = release_unused_engine()
	assert !release_unused_engine()
	assert run_default_worker_role(['ordinary invocation']) == none
	assert C.vox_adblock_get_context() == unsafe { nil }
	assert evaluate_engine('globalThis.workerFixture=17; workerFixture')! == '17'
	pid := default_worker_pid()
	assert pid > 0
	assert C.vox_adblock_get_context() == unsafe { nil }
	assert evaluate_engine('++workerFixture')! == '18'
	assert default_worker_pid() == pid
	mut configuration_error := ''
	configure_default_worker('') or { configuration_error = err.msg() }
	assert configuration_error == 'Release the default adblock engine before changing its backend'
	assert release_unused_engine()
	assert default_worker_pid() == 0
	mut status := 0
	assert C.waitpid(pid, &status, 1) == -1
	assert evaluate_engine('typeof workerFixture')! == 'undefined'
	assert C.vox_adblock_get_context() == unsafe { nil }
}

fn test_worker_source_and_result_exact_bytes_match_direct_javascriptcore() {
	context := create_context(none)!
	defer { C.JSGlobalContextRelease(context) }
	sources := [
		'', '1+2', '"Unicode λ 日本語 🌍 é"', '\uFEFF"BOM λ"',
		'"NUL result: \\u0000 tail"', '"large λ🌍".repeat(200000)',
		'"prefix"\x00+"tail"', [u8(0x80), `+`, `1`].bytestr(),
		[u8(0xed),0xa0,0x80].bytestr(), [u8(0xf4),0x90,0x80,0x80].bytestr(),
		'throw new Error("fixture λ 🌍")', '({toString(){throw new Error("conversion")}})',
	]
	for source in sources {
		mut direct_failed := false
		direct := evaluate_context(context, source) or { direct_failed = true; err.msg() }
		mut worker_failed := false
		worker := evaluate_engine(source) or { worker_failed = true; err.msg() }
		assert worker_failed == direct_failed
		assert worker.len == direct.len
		assert worker == direct
	}
	assert C.vox_adblock_get_context() == unsafe { nil }
}

fn test_prepared_worker_retains_filtering_and_release_lifecycle() {
	_ = release_unused_engine()
	set_enabled(false)
	assert !prepare_default_worker()!
	assert default_worker_pid() == 0
	set_enabled(true)
	defer { _ = release_unused_engine() }
	assert prepare_default_worker()!
	pid := default_worker_pid()
	assert pid > 0
	assert C.vox_adblock_get_context() == unsafe { nil }
	assert prepare_default_worker()!
	assert default_worker_pid() == pid
	request := Request{url: 'https://securepubads.g.doubleclick.net/tag/js/gpt.js?startup-preparation', source_url: 'https://www.theverge.com/', request_type: 'script'}
	assert check(request).blocked
	assert default_worker_pid() == pid
	assert !release_default_engine_if_idle(5000)
	assert release_unused_engine()
	assert default_worker_pid() == 0
	assert prepare_default_worker()!
	assert default_worker_pid() > 0
	assert default_worker_pid() != pid
	assert check(request).blocked
}

fn prepare_worker_during_filter_test() string {
	prepare_default_worker() or { return err.msg() }
	return ''
}

fn test_worker_preparation_can_race_the_first_filter_request() {
	_ = release_unused_engine()
	set_enabled(true)
	defer { _ = release_unused_engine() }
	preparation := spawn prepare_worker_during_filter_test()
	// A distinct URL prevents an earlier test's memoized result bypassing the helper.
	decision := check(Request{url: 'https://securepubads.g.doubleclick.net/tag/js/gpt.js?startup-concurrent',
		source_url: 'https://www.theverge.com/', request_type: 'script'})
	assert preparation.wait() == ''
	assert decision.error == ''
	assert decision.blocked
	assert default_worker_pid() > 0
	assert C.vox_adblock_get_context() == unsafe { nil }
}

fn test_worker_evaluation_exception_retains_state_and_does_not_restart() {
	assert evaluate_engine('globalThis.errorCounter=1; errorCounter')! == '1'
	pid := default_worker_pid()
	message := evaluate_engine('++errorCounter; throw new Error("expected λ")') or { err.msg() }
	assert message == 'Adblock JavaScriptCore: Error: expected λ'
	assert default_worker_pid() == pid
	assert evaluate_engine('errorCounter')! == '2'
}

fn test_worker_killed_process_fails_one_request_then_lazily_restores() {
	_ = evaluate_engine('42')!
	pid := default_worker_pid()
	assert C.kill(pid, 9) == 0
	message := evaluate_engine('globalThis.neverRetried=1') or { err.msg() }
	assert message.starts_with('Adblock worker ')
	assert default_worker_pid() == 0
	assert evaluate_engine('typeof neverRetried')! == 'undefined'
	assert default_worker_pid() != pid
}

fn restore_actual_worker() {
	_ = release_unused_engine()
	os.unsetenv('VOX_AB_FAKE_MODE')
	configure_default_worker_with_deadline(os.getenv('VOX_ADBLOCK_WORKER_HELPER'), 15000) or { panic(err) }
}

fn test_worker_transport_failure_has_no_inline_retry_and_next_request_is_independent() {
	_ = release_unused_engine()
	defer { restore_actual_worker() }
	fake := os.getenv('VOX_ADBLOCK_WORKER_FAKE')
	configure_default_worker_with_deadline(fake, 1000)!
	for mode in ['startup-eof','startup-hang','wrong-id','truncate','oversize','exit','hang'] {
		os.setenv('VOX_AB_FAKE_MODE', mode, true)
		message := evaluate_engine('side-effect') or { err.msg() }
		assert message.starts_with('Adblock worker ')
		assert default_worker_pid() == 0
		assert C.vox_adblock_get_error() == unsafe { nil }
	}
	os.setenv('VOX_AB_FAKE_MODE', 'echo', true)
	assert evaluate_engine('one independent request')! == 'one independent request'
}

fn test_worker_initialization_error_is_sticky_across_release_and_configuration() {
	_ = release_unused_engine()
	C.vox_adblock_lock()
	previous := C.vox_adblock_test_exchange_error(unsafe { nil })
	C.vox_adblock_unlock()
	defer {
		C.vox_adblock_lock()
		_ = C.vox_adblock_test_exchange_error(previous)
		C.vox_adblock_unlock()
		restore_actual_worker()
	}
	configure_default_worker_with_deadline(os.getenv('VOX_ADBLOCK_WORKER_FAKE'), 1000)!
	os.setenv('VOX_AB_FAKE_MODE', 'init-error', true)
	first := evaluate_engine('1') or { err.msg() }
	assert first == 'fixture init failure'
	assert default_worker_pid() == 0
	assert !release_unused_engine()
	os.setenv('VOX_AB_FAKE_MODE', 'echo', true)
	mut preparation_error := ''
	_ = prepare_default_worker() or { preparation_error = err.msg(); false }
	assert preparation_error == first
	assert evaluate_engine('2') or { err.msg() } == first
	assert default_worker_pid() == 0
	assert C.vox_adblock_get_context() == unsafe { nil }
}

fn test_worker_opt_in_can_be_cleared_without_changing_ordinary_direct_backend() {
	_ = release_unused_engine()
	configure_default_worker('')!
	defer { restore_actual_worker() }
	assert C.vox_adblock_worker_is_configured() == 0
	assert !prepare_default_worker()!
	assert C.vox_adblock_get_context() == unsafe { nil }
	assert evaluate_engine('42')! == '42'
	assert C.vox_adblock_get_context() != unsafe { nil }
	assert default_worker_pid() == 0
	assert release_unused_engine()
	assert C.vox_adblock_get_context() == unsafe { nil }
}

fn test_worker_footprint_accounts_live_child_and_clears_after_exact_release() {
	_ = release_unused_engine()
	assert default_worker_memory_bytes()! == 0
	assert evaluate_engine('42')! == '42'
	assert default_worker_memory_bytes()! > 0
	assert C.vox_adblock_get_context() == unsafe { nil }
	assert release_unused_engine()
	assert default_worker_memory_bytes()! == 0
}

fn test_worker_restores_full_bundled_request_header_cosmetic_and_scriptlet_rules() {
	set_enabled(true)
	request := Request{url: 'https://pikabu.ru/ajax/stories', source_url: 'https://pikabu.ru/', request_type: 'xmlhttprequest'}
	for _ in 0 .. 2 {
		assert check(Request{url: 'https://securepubads.g.doubleclick.net/tag/js/gpt.js', source_url: 'https://www.theverge.com/', request_type: 'script'}).blocked
		assert !check(request).blocked
		header := check_response(request, [ResponseHeader{name: 'LLaSalBBubRRl', value: '1'}])
		assert header.error == '' && header.blocked
		assert header.rule.contains('responseheader=llasalbbubrrl')
		filters := document_filters('https://www.theverge.com/', ['.ad-banner'])!
		assert filters.css.contains('div[data-concert]')
		assert filters.filters.any(it.contains('abort-current-script'))
		assert filters.scriptlets.contains('const scriptletGlobals =')
		assert release_unused_engine()
		assert filters.css.contains('div[data-concert]')
		assert filters.scriptlets.contains('const scriptletGlobals =')
	}
}

fn test_worker_self_path_and_bundle_lookup_ignore_injected_dyld_image_order() {
	expected := os.real_path(os.args[0])
	assert os.real_path(current_executable_path()!) == expected
	assert bundled_snapshot_path() == os.join_path(os.dir(expected), '..', 'Resources', 'adblock.snapshot.bin')
}
