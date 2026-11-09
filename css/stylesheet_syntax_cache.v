module css

import sync
import platform

const stylesheet_syntax_minimum_bytes = 4096

// Only context-free tokenizer input is shared. CSSRule, declarations, sheet
// owners, namespace state, URL resolution and media evaluation remain fresh.
@[heap]
struct StylesheetSyntaxEntry {
	input string
	values []ComponentValue
	nodes int
mut:
	last_used u64
}

@[heap]
struct StylesheetSyntaxCache {
	max_entries int = 16
	max_source_bytes int = 1_048_576
	max_nodes int = 131_072
mut:
	mutex &sync.Mutex = sync.new_mutex()
	entries []&StylesheetSyntaxEntry
	source_bytes int
	nodes int
	serial u64
	conversion_seen_ []StylesheetConversionSeen
	conversion_seen_bytes_ int
}

__global stylesheet_syntax_cache_ = StylesheetSyntaxCache{}

// Completed stylesheets own their rules and any deferred component input.
// Keeping a second root to every token tree only benefits a future parse. An
// idle static document can discard that cache without changing live CSSOM or
// parser borrowers; a later parse repopulates it normally.
fn (mut cache StylesheetSyntaxCache) release_unused() {
	cache.mutex.lock()
	defer { cache.mutex.unlock() }
	// clear() would leave pointers in the scanned array's backing allocation.
	cache.entries = []&StylesheetSyntaxEntry{}
	cache.source_bytes = 0
	cache.nodes = 0
	cache.conversion_seen_ = []StylesheetConversionSeen{}
	cache.conversion_seen_bytes_ = 0
}

pub fn release_unused_stylesheet_syntax() {
	stylesheet_syntax_cache_.release_unused()
	stylesheet_rule_cache_.release_unused()
}

fn stylesheet_syntax_node_count(values []ComponentValue) int {
	mut count := values.len
	for value in values {
		if value.is_block() { count += stylesheet_syntax_node_count(value.block().value) }
		else if value.is_function() { count += stylesheet_syntax_node_count(value.function().value) }
	}
	return count
}

// Caller holds mutex; the returned component arrays are immutable parser input.
fn (mut cache StylesheetSyntaxCache) find(input string) ?[]ComponentValue {
	for mut entry in cache.entries {
		if entry.input == input {
			cache.serial++
			entry.last_used = cache.serial
			return entry.values
		}
	}
	return none
}

fn (mut cache StylesheetSyntaxCache) evict_oldest() {
	mut oldest := 0
	for index, entry in cache.entries {
		if entry.last_used < cache.entries[oldest].last_used { oldest = index }
	}
	cache.source_bytes -= cache.entries[oldest].input.len
	cache.nodes -= cache.entries[oldest].nodes
	last := cache.entries.len - 1
	cache.entries[oldest] = cache.entries[last]
	// A shortened V array still scans its backing allocation. Clear the old
	// slot so eviction really releases the tree when no sheet still uses it.
	cache.entries[last] = unsafe { nil }
	cache.entries = cache.entries[..last]
}

fn (mut cache StylesheetSyntaxCache) parse(input string) []ComponentValue {
	if input.len < stylesheet_syntax_minimum_bytes || input.len > cache.max_source_bytes {
		return stylesheet_components_from_source(input)
	}
	cache.mutex.lock()
	if values := cache.find(input) {
		cache.mutex.unlock()
		return values
	}
	cache.mutex.unlock()
	$if prealloc { return cache.parse_candidate(input) }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	// Tokenization can service a cooperative UI checkpoint. Never hold the
	// cache lock across parsing or author/native reentry, or wait for another
	// thread's parse to finish while holding it.
	// Cached token ranges can borrow the source. Own both in persistent
	// storage even when the caller's stylesheet text belongs to a document.
	owned_input := input.clone()
	values := stylesheet_components_from_source(owned_input)
	nodes := stylesheet_syntax_node_count(values)
	if nodes > cache.max_nodes || cache.max_entries <= 0 { return values }
	cache.mutex.lock()
	defer { cache.mutex.unlock() }
	if existing := cache.find(input) { return existing }
	for cache.entries.len > 0 && (cache.entries.len >= cache.max_entries
		|| cache.source_bytes + input.len > cache.max_source_bytes
		|| cache.nodes + nodes > cache.max_nodes) {
		cache.evict_oldest()
	}
	cache.serial++
	cache.entries << &StylesheetSyntaxEntry{
		input: owned_input
		values: values
		nodes: nodes
		last_used: cache.serial
	}
	cache.source_bytes += input.len
	cache.nodes += nodes
	return values
}

// A source-byte limit cannot predict its token count. Decide whether this tree
// can enter the process cache before choosing the owner of its immutable copy.
// Rejected candidates belong to the caller, including a retiring native document.
fn (mut cache StylesheetSyntaxCache) parse_candidate(input string) []ComponentValue {
	mut scratch := platform.begin_thread_scratch('stylesheet syntax cache candidate')
	values := ParserTokenStream.from_source(input, 'utf-8').values
	nodes := stylesheet_syntax_node_count(values)
	scratch.leave()
	defer { scratch.finish() }
	if nodes > cache.max_nodes || cache.max_entries <= 0 {
		return own_stylesheet_components(values)
	}
	cache.mutex.lock()
	defer { cache.mutex.unlock() }
	// Parsing can yield or race another parser. Recheck before publishing or
	// allocating another process-owned copy. Copying immutable values cannot
	// invoke author code or a cooperative checkpoint while the lock is held.
	if existing := cache.find(input) { return existing }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if !platform.arena_thread_is_current() {
		// Worker persistent sections use that worker's base scope, which must
		// survive its exit when it publishes a process-wide cache payload.
		platform.retain_thread_allocations()
	}
	owned_input := input.clone()
	owned_values := own_stylesheet_components(values)
	for cache.entries.len > 0 && (cache.entries.len >= cache.max_entries
		|| cache.source_bytes + input.len > cache.max_source_bytes
		|| cache.nodes + nodes > cache.max_nodes) {
		cache.evict_oldest()
	}
	cache.serial++
	cache.entries << &StylesheetSyntaxEntry{
		input: owned_input
		values: owned_values
		nodes: nodes
		last_used: cache.serial
	}
	cache.source_bytes += input.len
	cache.nodes += nodes
	return owned_values
}

fn stylesheet_parser_input(input string) ParserTokenStream {
	return ParserTokenStream{values: stylesheet_syntax_cache_.parse(input)}
}
