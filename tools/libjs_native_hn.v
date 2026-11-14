module main

// Standalone native-tier experiment against the real archived HN script and
// translated DOM. This deliberately excludes browser layout, paint and network.
import crypto.sha256
import dom
import html
import json2
import libjs
import libjsdom
import os
import time

const hn_script = $embed_file('@VMODROOT/Tests/Browser/Brave/hn-home-instructions/bodies/2e38ff883bd36dc4cc26f129f19169b0357cf32059988c926a4f73e5bfaa37f0').to_string()
const hn_page = $embed_file('@VMODROOT/Tests/Browser/Brave/input/hacker-news-item-50231722-complete.html').to_string()

struct HackerNewsNativeResult {
	mode              string
	scope             string = 'unmodified archived hn.js; native DOM; collapse/expand callbacks only; no layout, paint, network or browser startup'
	script_sha256     string
	page_sha256       string
	comment_rows      u32
	toggle_id         string
	warmup_cycles     int
	cycles            int
	setup_ms          f64
	warmup_ms         f64
	prepare_native_ms f64
	elapsed_ns        i64
	collapse_verified bool
	classes_restored  bool
	native            libjs.NativeCodeStats
	activity          libjs.NativeCodeActivity
}

fn toggle(target &dom.EventTarget) ! {
	event := dom.Event.create('click', dom.EventInit{ bubbles: true, cancelable: true })
	target.dispatch_event(event)
	if !event.default_prevented() {
		return error('HN click handler did not cancel the toggle navigation')
	}
}

fn main() {
	if os.args.len != 5 || os.args[1] !in ['control', 'native', 'diagnostic'] {
		eprintln('Usage: libjs_native_hn control|native|diagnostic CACHE_DIRECTORY CYCLES WARMUP_CYCLES')
		exit(2)
	}
	mode, cache := os.args[1], os.args[2]
	cycles, warmup := os.args[3].int(), os.args[4].int()
	if cycles <= 0 || warmup <= 0 { panic('Cycle counts must be positive') }
	started := time.sys_mono_now()
	mut document := html.parse_document(hn_page)
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.url = dom.URL{ value: 'https://news.ycombinator.com/item?id=50231722' }
	html.install_document_fragment_parsing_hook(document)
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	vm.profile_native_code() or { panic(err) }
	defer { vm.close_native_code() or { panic(err) } }
	mut failures := []string{}
	mut host := libjsdom.Host.create(vm, vm.realm(), document, libjsdom.Hooks{
		exception: fn [mut failures] (message string) { failures << message }
	}) or { panic(err) }
	defer { host.close() }
	mut script := libjs.Script.parse(hn_script, vm.realm(), 'https://news.ycombinator.com/hn.js', unsafe { nil }) or { panic(err) }
	vm.run_with_limits(mut script, libjs.ExecutionLimits{ max_instructions: 1000000 }) or { panic(err) }
	mut parent := unsafe { &dom.ParentNode(document) }
	rows := parent.get_elements_by_class_name('comtr')
	if rows.length() != 101 { panic('Expected the complete archived 101-comment discussion') }
	mut classes := []string{}
	for index in 0 .. rows.length() {
		classes << rows.item(index) or { panic('Missing comment') }.get_attribute_value('class')
	}
	first := rows.item(0) or { panic('Missing first comment') }
	mut first_parent := unsafe { &dom.ParentNode(first.as_node()) }
	button := first_parent.get_elements_by_class_name('togg').item(0) or { panic('Missing HN toggle') }
	target := unsafe { &dom.EventTarget(button) }
	setup_ms := f64(time.sys_mono_now() - started) / 1e6
	warmup_started := time.sys_mono_now()
	for _ in 0 .. warmup {
		toggle(target) or { panic(err) }
		if !first.get_attribute_value('class').split(' ').contains('coll') {
			panic('Warmup did not collapse comments')
		}
		toggle(target) or { panic(err) }
	}
	warmup_ms := f64(time.sys_mono_now() - warmup_started) / 1e6
	compile_started := time.sys_mono_now()
	native := vm.compile_native_code(cache, '/usr/bin/clang', 2) or { panic(err) }
	prepare_native_ms := f64(time.sys_mono_now() - compile_started) / 1e6
	vm.use_native_code(mode != 'control') or { panic(err) }
	// End-state restoration alone could miss a handler that became a no-op.
	// Verify actual collapse in the selected tier, outside the timed region.
	toggle(target) or { panic(err) }
	if !first.get_attribute_value('class').split(' ').contains('coll')
		|| parent.get_elements_by_class_name('noshow').length() <= 1 {
		panic('Selected tier did not collapse the archived comment subtree')
	}
	toggle(target) or { panic(err) }
	if mode == 'diagnostic' { vm.diagnose_native_code(true) or { panic(err) } }
	measure_started := time.sys_mono_now()
	for _ in 0 .. cycles {
		toggle(target) or { panic(err) }
		toggle(target) or { panic(err) }
	}
	elapsed_ns := time.sys_mono_now() - measure_started
	activity := vm.diagnose_native_code(false) or { panic(err) }
	// Correctness checks and diagnostic reads are outside the timed region.
	for index in 0 .. rows.length() {
		if rows.item(index) or { panic('Missing restored comment') }.get_attribute_value('class') != classes[index] {
			panic('Comment classes did not restore after collapse/expand')
		}
	}
	if failures.len != 0 { panic(failures.join('\n')) }
	if vm.execution_context_stack().len != 1 || vm.interpreter_stack().depth() != 0 {
		panic('Leaked JS frame')
	}
	println(json2.encode(HackerNewsNativeResult{
		mode:              mode
		script_sha256:     sha256.hexhash(hn_script)
		page_sha256:       sha256.hexhash(hn_page)
		comment_rows:      rows.length()
		toggle_id:         first.get_attribute_value('id')
		warmup_cycles:     warmup
		cycles:            cycles
		setup_ms:          setup_ms
		warmup_ms:         warmup_ms
		prepare_native_ms: prepare_native_ms
		elapsed_ns:        elapsed_ns
		collapse_verified: true
		classes_restored:  true
		native:            native
		activity:          activity
	}))
}
