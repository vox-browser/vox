module main

// Opt-in benchmark of the browser's actual engine/DOM integration. The driver
// runs this source-built executable; ordinary test sweeps do no benchmark work.
import adblock
import browserjs
import crypto.sha256
import css
import dom
import html
import json2
import libjs
import libjsdom
import os
import time

#include "@VMODROOT/sites/engine_peak_rss.h"
fn C.vox_hn_self_peak_rss_bytes() u64

struct HNEngineVisit {
	self_peak_rss_bytes u64
	direct_collection_walks u64
	class_collection_hits u64
	fresh_arrays_initialized u64
	short_string_hits u64
	direct_property_reads u64
	borrowed_arguments u64
	mode              string
	cycles            int
	initialization_ms f64
	first_cycle_ms    f64
	callback_ms       f64
	compile_finish_ms f64
	total_ms          f64
	rows              int
	classes_restored  bool
	collapse_verified bool
	native_context    bool
	script_sha256     string
	page_sha256       string
	cache             libjs.NativeCacheStats
	frontend          browserjs.LibJSFrontendCacheStats
	activity          libjs.NativeCodeActivity
	lookup_activity   libjs.PropertyLookupActivity
	argument_activity libjs.ArgumentAllocationActivity
	builtin_key_activity libjs.BuiltinKeyActivity
	context_activity libjs.ContextAllocationActivity
	primitive_activity libjs.PrimitiveReadActivity
	validation_activity libjs.ValidationActivity
	empty_scope_activity libjs.EmptyScopeActivity
	index_key_activity libjs.ArrayIndexKeyActivity
	context_reuse_activity libjs.ContextReuseActivity
}

fn hn_engine_toggle(document &dom.Document, runtime &browserjs.Runtime, button &dom.Element) ! {
	if runtime.engine == .libjs {
		if !runtime.dispatch_libjs_event('click', button)! {
			return error('LibJS toggle did not cancel navigation')
		}
	} else {
		// HN deliberately gives the row and its anchor the same ID. Browser
		// input uses the registry key to retain the actual hit element.
		key := runtime.canvas_element_key_for_binding(button) or { return error('Missing toggle identity key') }
		encoded := runtime.evaluate_host('__ladybirdDispatch("click","",{key:${json2.encode(key)}})')!
		mut messages := []string{}
		commit := apply_compact_dom_task(document, encoded, runtime, mut messages)!
		if !javascript_default_prevented(encoded) || commit.navigation != none || messages.len != 0 {
			return error('V8 toggle failed cancellation, navigation or script audit: ${encoded}; ${messages}')
		}
	}
}

fn hn_engine_visit(mode string, cycles int, diagnostic bool) !HNEngineVisit {
	markup := $embed_file('@VMODROOT/Tests/Browser/Brave/input/hacker-news-item-50231722-complete.html').to_string()
	script := $embed_file('@VMODROOT/Tests/Browser/Brave/hn-home-instructions/bodies/2e38ff883bd36dc4cc26f129f19169b0357cf32059988c926a4f73e5bfaa37f0').to_string()
	measure_memory := os.getenv('VOX_HN_ENGINE_MEMORY') == '1'
	engine := if mode in ['v8', 'jsc'] { browserjs.Engine.javascriptcore } else { browserjs.Engine.libjs }
	libjs.diagnose_property_lookup_hints_for_testing(diagnostic)
	libjs.diagnose_argument_allocation_for_testing(diagnostic)
	libjs.diagnose_builtin_keys_for_testing(diagnostic)
	started := time.sys_mono_now()
	address := dom.URL{ value: 'https://news.ycombinator.com/item?id=50231722' }
	mut document := html.parse_navigation_document(markup, address, address.origin(), none)!
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	mut runtime := browserjs.Runtime.create_with_engine(engine)
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_script_sources(document, document.url.serialize(), [browserjs.ScriptSource{
		code: script
		url:  'https://news.ycombinator.com/hn.js'
	}], runtime, mut messages)
	if messages.len != 0 { return error(messages.join('\n')) }
	initialization_ms := f64(time.sys_mono_now() - started) / 1e6
	// Fixture/correctness queries are excluded from the reported intervals.
	rows := css.query_selector_all(document.as_node(), '.comtr')
	if rows.len != 101 { return error('Expected 101 archived comments') }
	classes := rows.map(it.get_attribute_value('class'))
	button := css.query_selector(rows[0].as_node(), '.togg') or { return error('Missing toggle') }
	mut vm := runtime.libjs_vm()
	libjs.diagnose_builtin_keys_for_testing(diagnostic)
	libjs.diagnose_context_allocation_for_testing(diagnostic)
	libjs.diagnose_primitive_reads_for_testing(diagnostic)
	libjs.diagnose_validation_cache_for_testing(diagnostic)
	libjs.diagnose_empty_scopes_for_testing(diagnostic)
	libjs.diagnose_array_index_keys_for_testing(diagnostic)
	libjs.diagnose_context_reuse_for_testing(diagnostic)
	if diagnostic && engine == .libjs { vm.diagnose_native_code(true)! }
	libjs.diagnose_borrowed_call_arguments_for_testing(diagnostic)
	libjs.diagnose_short_string_cache_for_testing(diagnostic)
	libjs.diagnose_direct_property_reads_for_testing(diagnostic)
	libjs.diagnose_fresh_array_storage_for_testing(diagnostic)
	libjsdom.diagnose_class_query_cache_for_testing(diagnostic)
	dom.diagnose_direct_collection_walk_for_testing(diagnostic)
	first_started := time.sys_mono_now()
	hn_engine_toggle(document, runtime, button)!
	first_collapse_ms := f64(time.sys_mono_now() - first_started) / 1e6
	if !rows[0].class_names().contains('coll') || css.query_selector_all(document.as_node(), '.noshow').len <= 1 {
		return error('First toggle did not collapse descendants')
	}
	second_started := time.sys_mono_now()
	hn_engine_toggle(document, runtime, button)!
	first_cycle_ms := first_collapse_ms + f64(time.sys_mono_now() - second_started) / 1e6
	callback_started := time.sys_mono_now()
	for _ in 0 .. cycles {
		hn_engine_toggle(document, runtime, button)!
		hn_engine_toggle(document, runtime, button)!
	}
	callback_ms := f64(time.sys_mono_now() - callback_started) / 1e6
	direct_collection_walks := dom.diagnose_direct_collection_walk_for_testing(false)
	class_collection_hits := libjsdom.diagnose_class_query_cache_for_testing(false)
	fresh_arrays_initialized := libjs.diagnose_fresh_array_storage_for_testing(false)
	short_string_hits := libjs.diagnose_short_string_cache_for_testing(false)
	direct_property_reads := libjs.diagnose_direct_property_reads_for_testing(false)
	borrowed_arguments := libjs.diagnose_borrowed_call_arguments_for_testing(false)
	lookup_activity := libjs.diagnose_property_lookup_hints_for_testing(false)
	argument_activity := libjs.diagnose_argument_allocation_for_testing(false)
	builtin_key_activity := libjs.diagnose_builtin_keys_for_testing(false)
	context_activity := libjs.diagnose_context_allocation_for_testing(false)
	primitive_activity := libjs.diagnose_primitive_reads_for_testing(false)
	validation_activity := libjs.diagnose_validation_cache_for_testing(false)
	empty_scope_activity := libjs.diagnose_empty_scopes_for_testing(false)
	index_key_activity := libjs.diagnose_array_index_keys_for_testing(false)
	context_reuse_activity := libjs.diagnose_context_reuse_for_testing(false)
	activity := if engine == .libjs {
		vm.diagnose_native_code(false)!
	} else {
		libjs.NativeCodeActivity{}
	}
	finish_started := time.sys_mono_now()
	cache := if engine == .libjs { vm.flush_native_code_cache()! } else { libjs.NativeCacheStats{} }
	compile_finish_ms := f64(time.sys_mono_now() - finish_started) / 1e6
	self_peak_rss_bytes := if measure_memory { C.vox_hn_self_peak_rss_bytes() } else { u64(0) }
	for index, row in rows {
		if row.get_attribute_value('class') != classes[index] {
			return error('Comment classes not restored')
		}
	}
	if runtime.take_libjs_messages().len != 0 || vm.interpreter_stack().depth() != 0 {
		return error('Script errors or retained frames')
	}
	if engine == .libjs && runtime.native_context_initialized() {
		return error('Unexpected native engine fallback')
	}
	return HNEngineVisit{
		self_peak_rss_bytes: self_peak_rss_bytes
		direct_collection_walks: direct_collection_walks
		class_collection_hits: class_collection_hits
		fresh_arrays_initialized: fresh_arrays_initialized
		short_string_hits: short_string_hits
		direct_property_reads: direct_property_reads
		borrowed_arguments: borrowed_arguments
		mode:              mode
		cycles:            cycles
		initialization_ms: initialization_ms
		first_cycle_ms:    first_cycle_ms
		callback_ms:       callback_ms
		compile_finish_ms: compile_finish_ms
		total_ms:          initialization_ms + first_cycle_ms + callback_ms + compile_finish_ms
		rows:              rows.len
		classes_restored:  true
		collapse_verified: true
		native_context:    runtime.native_context_initialized()
		script_sha256:     sha256.hexhash(script)
		page_sha256:       sha256.hexhash(markup)
		cache:             cache
		frontend:          runtime.frontend_code_cache_stats()
		activity:          activity
		lookup_activity:   lookup_activity
		argument_activity: argument_activity
		builtin_key_activity: builtin_key_activity
		context_activity: context_activity
		primitive_activity: primitive_activity
		validation_activity: validation_activity
		empty_scope_activity: empty_scope_activity
		index_key_activity: index_key_activity
		context_reuse_activity: context_reuse_activity
	}
}

fn test_hacker_news_engine_benchmark() {
	choice := os.getenv('VOX_HN_ENGINE_BENCHMARK')
	if choice == '' { return }
	libjs.set_property_lookup_hints_for_testing(os.getenv('VOX_LIBJS_LOOKUP_HINTS') != '0')
	libjs.set_argument_elision_for_testing(os.getenv('VOX_LIBJS_ARGUMENT_ELISION') != '0')
	libjs.set_register_bindings_for_testing(os.getenv('VOX_LIBJS_REGISTER_BINDINGS') != '0')
	libjs.set_builtin_key_cache_for_testing(os.getenv('VOX_LIBJS_BUILTIN_KEYS') != '0')
	libjs.set_exact_context_capacity_for_testing(os.getenv('VOX_LIBJS_EXACT_CONTEXT') != '0')
	libjs.set_primitive_reads_for_testing(os.getenv('VOX_LIBJS_PRIMITIVE_READS') != '0')
	libjs.set_validation_cache_for_testing(os.getenv('VOX_LIBJS_VALIDATION_CACHE') != '0')
	libjs.set_empty_scope_elision_for_testing(os.getenv('VOX_LIBJS_EMPTY_SCOPES') != '0')
	libjs.set_numeric_array_keys_for_testing(os.getenv('VOX_LIBJS_NUMERIC_KEYS') != '0')
	libjs.set_context_reuse_for_testing(os.getenv('VOX_LIBJS_CONTEXT_REUSE') != '0')
	libjs.set_borrowed_call_arguments_for_testing(os.getenv('VOX_LIBJS_BORROW_ARGUMENTS') != '0')
	libjs.set_short_string_cache_for_testing(os.getenv('VOX_LIBJS_SHORT_STRINGS') != '0')
	libjs.set_fast_binding_reads_for_testing(os.getenv('VOX_LIBJS_FAST_BINDINGS') != '0')
	libjs.set_function_environment_reuse_for_testing(os.getenv('VOX_LIBJS_REUSE_FUNCTION_ENVIRONMENTS') != '0')
	libjs.set_call_argument_forwarding_for_testing(os.getenv('VOX_LIBJS_FORWARD_CALL_ARGUMENTS') != '0')
	libjs.set_array_search_reads_for_testing(os.getenv('VOX_LIBJS_ARRAY_SEARCH_READS') != '0')
	libjs.set_direct_accessor_dispatch_for_testing(os.getenv('VOX_LIBJS_DIRECT_ACCESSORS') != '0')
	libjs.set_compact_reference_reads_for_testing(os.getenv('VOX_LIBJS_COMPACT_REFERENCES') != '0')
	libjs.set_native_dynamic_dispatch_for_testing(os.getenv('VOX_LIBJS_NATIVE_DYNAMIC') != '0')
	libjs.set_direct_property_reads_for_testing(os.getenv('VOX_LIBJS_DIRECT_READS') != '0')
	libjs.set_fresh_array_storage_for_testing(os.getenv('VOX_LIBJS_FRESH_ARRAYS') != '0')
	libjsdom.set_class_query_cache_for_testing(os.getenv('VOX_LIBJS_CLASS_QUERY_CACHE') != '0')
	dom.set_direct_collection_walk_for_testing(os.getenv('VOX_LIBJS_DIRECT_COLLECTION_WALK') != '0')
	// Keep this author-script/DOM workload independent of filter-list startup.
	adblock.set_enabled(false)
	$if vox_v8 ? {
		if choice == 'jsc' { panic('JSC requires a build without vox_v8') }
	} $else {
		if choice == 'v8' { panic('V8 requires -d vox_v8') }
	}
	if choice !in ['v8', 'jsc', 'libjs', 'libjs-warm'] { panic('Expected v8, jsc, libjs or libjs-warm') }
	cycles := os.getenv('VOX_HN_ENGINE_CYCLES').int()
	if cycles < 1 { panic('Set positive VOX_HN_ENGINE_CYCLES') }
	diagnostic := os.getenv('VOX_HN_ENGINE_DIAGNOSTIC') == '1'
	if choice in ['v8', 'jsc'] {
		println(json2.encode(hn_engine_visit(choice, cycles, diagnostic)!))
	} else if choice == 'libjs-warm' {
		os.setenv('VOX_LIBJS_NATIVE_COMPILER', '/usr/bin/false', true)
		println(json2.encode(hn_engine_visit('libjs-warm', cycles, diagnostic)!))
	} else {
		println(json2.encode(hn_engine_visit('libjs-cold', cycles, diagnostic)!))
		os.setenv('VOX_LIBJS_NATIVE_COMPILER', '/usr/bin/false', true)
		println(json2.encode(hn_engine_visit('libjs-process-warm', cycles, diagnostic)!))
	}
}
