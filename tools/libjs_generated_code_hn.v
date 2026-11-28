// Manual cache-identity experiment with the original hn.js and native DOM.
// This has no browser window/layout/paint and supplies no browser-speed gate.
module main

import browserjs
import crypto.sha256
import dom
import html
import json2
import libjs
import os
import rand

const code_cache_hn_script = $embed_file('@VMODROOT/Tests/Browser/Brave/hn-home-instructions/bodies/2e38ff883bd36dc4cc26f129f19169b0357cf32059988c926a4f73e5bfaa37f0').to_string()
const code_cache_hn_page = $embed_file('@VMODROOT/Tests/Browser/Brave/input/hacker-news-item-50231722-complete.html').to_string()

struct CodeCacheHNResult {
	identity                   string
	phase                      string
	source_url                 string
	script_sha256              string
	page_sha256                string
	comment_rows               u32
	collapse_verified          bool
	classes_restored           bool
	cache                      libjs.NativeCacheStats
	activity                   libjs.NativeCodeActivity
	compiler_error             string
	native_context_initialized bool
}

fn code_cache_hn_toggle(runtime &browserjs.Runtime, button &dom.Element) ! {
	if !runtime.dispatch_libjs_event('click', button)! {
		return error('HN handler did not cancel navigation')
	}
}

fn main() {
	if os.args.len !in [5, 6] || os.args[1] !in ['source', 'generated'] || os.args[2] !in [
		'seed',
		'reopen',
	] {
		eprintln('Usage: libjs_generated_code_hn source|generated seed|reopen CACHE SOURCE_URL [SCRIPT_FILE]')
		exit(2)
	}
	if !run_code_cache_hn() { exit(1) }
}

fn run_code_cache_hn() bool {
	identity, phase, directory, url := os.args[1], os.args[2], os.args[3], os.args[4]
	profile := os.join_path(os.temp_dir(), 'vox-generated-hn-profile-' + rand.uuid_v4())
	os.setenv('VOX_PROFILE_DIR', profile, true)
	defer { os.rmdir_all(profile) or {} }
	os.setenv('VOX_LIBJS_NATIVE_CACHE', directory, true)
	os.setenv('VOX_LIBJS_NATIVE_COMPILER', if phase == 'seed' {
		'/usr/bin/clang'
	} else {
		'/usr/bin/false'
	}, true)
	os.setenv('VOX_LIBJS_NATIVE_GENERATED_CODE_CACHE', if identity == 'generated' {
		'1'
	} else {
		'0'
	}, true)
	os.setenv('VOX_LIBJS_NATIVE_DIAGNOSTICS', '1', true)
	source := if os.args.len == 6 {
		os.read_file(os.args[5]) or { panic(err) }
	} else {
		code_cache_hn_script
	}
	mut document := html.parse_document(code_cache_hn_page)
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.url = dom.URL{ value: 'https://news.ycombinator.com/item?id=50231722' }
	html.install_document_fragment_parsing_hook(document)
	mut runtime := browserjs.Runtime.create_with_engine(.libjs)
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.install_libjs_document(document) or { panic(err) }
	mut vm := runtime.libjs_vm()
	vm.diagnose_native_code(true) or { panic(err) }
	failures := runtime.run_document_scripts_collect_errors([browserjs.ScriptSource{ code: source, url: url }])
	if failures.len != 0 { panic(failures.join('\n')) }
	mut parent := unsafe { &dom.ParentNode(document) }
	rows := parent.get_elements_by_class_name('comtr')
	if rows.length() != 101 { panic('Expected all 101 archived comments') }
	mut classes := []string{}
	for i in 0 .. rows.length() {
		classes << rows.item(i) or { panic('Missing comment') }.get_attribute_value('class')
	}
	first := rows.item(0) or { panic('Missing first comment') }
	mut first_parent := unsafe { &dom.ParentNode(first.as_node()) }
	button := first_parent.get_elements_by_class_name('togg').item(0) or { panic('Missing toggle') }
	for _ in 0 .. 2 {
		code_cache_hn_toggle(runtime, button) or { panic(err) }
		if !first.get_attribute_value('class').split(' ').contains('coll')
			|| parent.get_elements_by_class_name('noshow').length() <= 1 {
			panic('Comment collapse failed')
		}
		code_cache_hn_toggle(runtime, button) or { panic(err) }
	}
	for i in 0 .. rows.length() {
		if rows.item(i) or { panic('Missing restored comment') }.get_attribute_value('class') != classes[i] {
			panic('Comment classes changed')
		}
	}
	messages := runtime.take_libjs_messages()
	if messages.len != 0 { panic(messages.join('\n')) }
	mut compiler_error := ''
	vm.flush_native_code_cache() or { compiler_error = err.msg() }
	stats := vm.native_code_cache_stats()
	activity := vm.diagnose_native_code(false) or { panic(err) }
	println(json2.encode(CodeCacheHNResult{
		identity:                   identity
		phase:                      phase
		source_url:                 url
		script_sha256:              sha256.hexhash(source)
		page_sha256:                sha256.hexhash(code_cache_hn_page)
		comment_rows:               rows.length()
		collapse_verified:          true
		classes_restored:           true
		cache:                      stats
		activity:                   activity
		compiler_error:             compiler_error
		native_context_initialized: runtime.native_context_initialized()
	}))
	return compiler_error == '' && stats.last_error == '' && !runtime.native_context_initialized()
		&& (phase != 'reopen' || (stats.cache_hits > 0 && stats.cache_misses == 0 && activity.entries > 0))
}
