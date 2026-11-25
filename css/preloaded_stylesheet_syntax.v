module css

import os
import platform
import sync

const serial_preloaded_stylesheet_syntax = os.getenv('VOX_SERIAL_PRELOADED_STYLESHEET_SYNTAX') == '1'
const preloaded_stylesheet_syntax_diagnostics = os.getenv('VOX_PRELOADED_STYLESHEET_SYNTAX_DIAGNOSTICS') == '1'
const prepare_preloaded_stylesheet_selectors = os.getenv('VOX_PREPARE_PRELOADED_STYLESHEET_SELECTORS') == '1'
const preloaded_stylesheet_syntax_max_source_bytes = 32 * 1024
const preloaded_stylesheet_syntax_max_arena_bytes = 4 * 1024 * 1024
const preloaded_stylesheet_syntax_slots = 4
const preloaded_stylesheet_syntax_label = 'preloaded stylesheet syntax'

struct PreloadedStylesheetSyntax {
	input string
	rules []Rule
	selectors &PreparedStyleRuleSelectors = unsafe { nil }
	thread_id u64
mut:
	storage platform.DetachedThreadScratch
}

struct PreloadedStylesheetSyntaxCache {
mut:
	mutex &sync.Mutex = sync.new_mutex()
	entries [preloaded_stylesheet_syntax_slots]PreloadedStylesheetSyntax
	next int
}

__global preloaded_stylesheet_syntax_ = PreloadedStylesheetSyntaxCache{}

fn preloaded_stylesheet_syntax_eligible(text string) bool {
	$if macos && prealloc && !vox_css_diagnostics ? {
		return !serial_preloaded_stylesheet_syntax && !bulk_css_input_probe_diagnostics
			&& !exact_component_source_copy_diagnostics && !flat_component_source_diagnostics
			&& text.len >= stylesheet_syntax_minimum_bytes
			&& text.len <= preloaded_stylesheet_syntax_max_source_bytes
	}
	return false
}

// Fetch workers can parse top-level grammar without a document. Its source
// and borrowed token ranges belong to a detachable, bounded staging arena.
// The ordinary CSSOM parser still controls decoding, validation and cascade.
pub fn prepare_preloaded_stylesheet_syntax(text string) {
	if !preloaded_stylesheet_syntax_eligible(text) || platform.is_main_thread() { return }
	scratch := platform.begin_thread_scratch(preloaded_stylesheet_syntax_label)
	input := text.clone()
	mut parser := RuleSelectorParser{
		token_stream: ParserTokenStream.from_transient_source(input, 'utf-8')
	}
	rules := parser.parse_a_stylesheet(none).rules
	selectors := if prepare_preloaded_stylesheet_selectors && !rule_selector_reuse_diagnostics
		&& !borrowed_selector_span_diagnostics && !retained_selector_construction_diagnostics {
		prepare_stylesheet_selector_lists(rules, stylesheet_leading_namespaces(rules), .no)
	} else {
		unsafe { &PreparedStyleRuleSelectors(nil) }
	}
	mut storage := scratch.detach()
	if storage.capacity() > preloaded_stylesheet_syntax_max_arena_bytes {
		storage.discard(preloaded_stylesheet_syntax_label)
		return
	}
	preloaded_stylesheet_syntax_.insert(PreloadedStylesheetSyntax{
		input: input
		rules: rules
		selectors: selectors
		storage: storage
		thread_id: if preloaded_stylesheet_syntax_diagnostics { platform.native_thread_identity() } else { u64(0) }
	})
}

fn (mut cache PreloadedStylesheetSyntaxCache) insert(entry PreloadedStylesheetSyntax) {
	cache.mutex.lock()
	mut discarded := cache.entries[cache.next]
	cache.entries[cache.next] = entry
	cache.next = (cache.next + 1) % cache.entries.len
	cache.mutex.unlock()
	discarded.storage.discard(preloaded_stylesheet_syntax_label)
}

// Exactly one consumer claims the staging lease. Later consumers use the
// ordinary syntax caches or parse their own inputs.
fn (mut cache PreloadedStylesheetSyntaxCache) take(text string) ?PreloadedStylesheetSyntax {
	if !preloaded_stylesheet_syntax_eligible(text) { return none }
	cache.mutex.lock()
	defer { cache.mutex.unlock() }
	for index, entry in cache.entries {
		if entry.input != text { continue }
		cache.entries[index] = PreloadedStylesheetSyntax{}
		return entry
	}
	return none
}

fn (mut cache PreloadedStylesheetSyntaxCache) release_unused() {
	cache.mutex.lock()
	mut entries := cache.entries
	cache.entries = [preloaded_stylesheet_syntax_slots]PreloadedStylesheetSyntax{}
	cache.next = 0
	cache.mutex.unlock()
	for mut entry in entries { entry.storage.discard(preloaded_stylesheet_syntax_label) }
}
