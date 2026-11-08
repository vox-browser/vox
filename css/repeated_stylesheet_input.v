module css

import os
import platform
import hash

const disable_repeated_stylesheet_input = os.getenv('VOX_DISABLE_REPEATED_STYLESHEET_INPUT') != ''
const repeated_stylesheet_input_diagnostics = os.getenv('VOX_REPEATED_STYLESHEET_INPUT_DIAGNOSTICS') != ''
__global repeated_stylesheet_input_reported bool

struct StylesheetConversionSeen {
	hash u64
	bytes int
}

// A first parse retires its tokenizer input as usual. A second occurrence
// admits identical bytes to the existing bounded syntax cache. Only immutable,
// context-free components are reused; every CSSOM sheet and declaration owner
// is still converted independently with its own URL and document context.
fn stylesheet_conversion_input(text string) ParserTokenStream {
	if !disable_repeated_stylesheet_input && stylesheet_syntax_cache_.admit_conversion_input(text) {
		if repeated_stylesheet_input_diagnostics && !repeated_stylesheet_input_reported {
			repeated_stylesheet_input_reported = true
			eprintln('Vox stylesheet input: repeated source admitted to bounded syntax cache')
		}
		return stylesheet_parser_input(text)
	}
	return ParserTokenStream.from_transient_source(text, 'utf-8')
}

fn (mut cache StylesheetSyntaxCache) admit_conversion_input(text string) bool {
	if text.len < stylesheet_syntax_minimum_bytes || text.len > cache.max_source_bytes
		|| cache.max_entries <= 0 { return false }
	cache.mutex.lock()
	defer { cache.mutex.unlock() }
	if _ := cache.find(text) { return true }
	fingerprint := hash.sum64_string(text, 0)
	for previous in cache.conversion_seen_ {
		if previous.bytes == text.len && previous.hash == fingerprint { return true }
	}
	// A hash collision only admits a source early: the syntax cache still
	// compares all source bytes before returning any component tree.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if !platform.arena_thread_is_current() { platform.retain_thread_allocations() }
	for cache.conversion_seen_.len > 0 && (cache.conversion_seen_.len >= cache.max_entries
		|| cache.conversion_seen_bytes_ + text.len > cache.max_source_bytes) {
		cache.conversion_seen_bytes_ -= cache.conversion_seen_[0].bytes
		cache.conversion_seen_.delete(0)
	}
	cache.conversion_seen_ << StylesheetConversionSeen{fingerprint, text.len}
	cache.conversion_seen_bytes_ += text.len
	return false
}
