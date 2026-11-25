module css

import os
import platform
import sync

const stylesheet_rule_cache_minimum_bytes = 16_384
const disable_stylesheet_rule_cache = os.getenv('VOX_DISABLE_STYLESHEET_RULE_CACHE') != ''
const stylesheet_rule_cache_diagnostics = os.getenv('VOX_STYLESHEET_RULE_CACHE_DIAGNOSTICS') != ''

// Cache syntax, not CSSOM or a snapshot of matching rules. A rule that is
// unused during the first render can become necessary after a DOM change,
// hover, a media-query change, or script access to cssRules. Reusing the raw
// rule tree skips its tokenizer and declaration-syntax work while conversion
// still creates fresh selectors, owners and lazily parsed property values.
@[heap]
struct StylesheetRuleEntry {
	input   string
	rules   []Rule
	nodes   int
	retained_bytes i64
	storage &platform.RetainedArena = unsafe { nil }
	// Never reused: sheets converted from entries with equal ids have equal
	// source bytes (duplicate_style_sheets.v).
	id u64
mut:
	last_used u64
}

// A lookup owns a lease until conversion has exported every retained value.
// Cooperative parsing/conversion may reenter and evict or clear the cache.
fn (entry &StylesheetRuleEntry) release() {
	$if prealloc {
		mut storage := entry.storage
		storage.release()
	}
}

@[heap]
struct StylesheetRuleCache {
	max_entries      int = 24
	max_source_bytes int = 4 * 1_048_576
	max_nodes        int = 262_144
	max_retained_bytes i64 = 16 * 1_048_576
mut:
	mutex        &sync.Mutex = sync.new_mutex()
	entries      []&StylesheetRuleEntry
	source_bytes int
	nodes        int
	retained_bytes i64
	serial       u64
	reported_hit bool
	next_id      u64
}

__global stylesheet_rule_cache_ = StylesheetRuleCache{}

fn (cache &StylesheetRuleCache) eligible(input string) bool {
	$if prealloc {
		// RetainedArena leases belong to the UI/origin thread. Worker parses
		// use the ordinary parser and never retain an origin-thread payload.
		if !platform.arena_thread_is_current() { return false }
	}
	return cache.max_entries > 0 && input.len >= stylesheet_rule_cache_minimum_bytes
		&& input.len <= cache.max_source_bytes
}

// Diagnostics only: whether `input` already has cached rule syntax.
fn (mut cache StylesheetRuleCache) contains(input string) bool {
	if !cache.eligible(input) { return false }
	cache.mutex.lock()
	defer { cache.mutex.unlock() }
	return cache.entries.any(it.input == input)
}

fn (mut cache StylesheetRuleCache) lookup(input string) ?&StylesheetRuleEntry {
	if !cache.eligible(input) { return none }
	cache.mutex.lock()
	defer { cache.mutex.unlock() }
	for mut entry in cache.entries {
		// A URL or validator alone cannot identify a representation. Exact
		// decoded response bytes also cover changed bodies at the same URL.
		if entry.input != input { continue }
		cache.serial++
		entry.last_used = cache.serial
		$if prealloc {
			mut storage := entry.storage
			storage.retain()
		}
		if stylesheet_rule_cache_diagnostics && !cache.reported_hit {
			cache.reported_hit = true
			eprintln('Vox stylesheet rules: reused exact-source rule syntax (${cache.entries.len} entries, ${cache.source_bytes} source bytes, ${cache.nodes} nodes)')
		}
		return entry
	}
	return none
}

fn stylesheet_rule_nodes(rule Rule) int {
	match rule {
		AtRule {
			return 1 + stylesheet_syntax_node_count(rule.prelude) +
				stylesheet_rule_child_nodes(rule.child_rules_and_lists_of_declarations)
		}
		QualifiedRule {
			return 1 + stylesheet_syntax_node_count(rule.prelude) +
				stylesheet_declaration_nodes(rule.declarations) +
				stylesheet_rule_child_nodes(rule.child_rules)
		}
	}
}

fn stylesheet_rule_child_nodes(children []RuleOrListOfDeclarations) int {
	mut nodes := children.len
	for child in children {
		match child {
			RuleNode { nodes += stylesheet_rule_nodes(child.rule) }
			DeclarationList { nodes += stylesheet_declaration_nodes(child.declarations) }
		}
	}
	return nodes
}

fn stylesheet_declaration_nodes(declarations []Declaration) int {
	mut nodes := declarations.len
	for declaration in declarations { nodes += stylesheet_syntax_node_count(declaration.value) }
	return nodes
}

struct StylesheetRulePayload {
	input string
	rules []Rule
	nodes int
}

fn stylesheet_rule_tree_nodes(rules []Rule) int {
	mut nodes := rules.len
	for rule in rules { nodes += stylesheet_rule_nodes(rule) }
	return nodes
}

fn copy_stylesheet_rule_payload(input string, rules []Rule, nodes int) StylesheetRulePayload {
	owned_input := input.clone()
	mut owned_rules := []Rule{cap: rules.len}
	for rule in rules { owned_rules << own_transient_rule_tree(rule) }
	return StylesheetRulePayload{input: owned_input, rules: owned_rules, nodes: nodes}
}

// A startup worker can build the same independent payload as store() without
// touching cache state. The owner adopts its storage after the handoff.
fn prepare_stylesheet_rule_payload(input string, rules []Rule, max_nodes int) (StylesheetRulePayload, platform.DetachedThreadScratch) {
	nodes := stylesheet_rule_tree_nodes(rules)
	if nodes > max_nodes { return StylesheetRulePayload{}, platform.DetachedThreadScratch{} }
	scratch := platform.begin_thread_scratch('stylesheet rule cache')
	payload := copy_stylesheet_rule_payload(input, rules, nodes)
	return payload, scratch.detach()
}

// Called after ordinary syntax parsing, so an oversized candidate never
// causes a second parse. No parser or author callback runs under the lock.
// Returns the stored (or already published) entry's id, or 0 when the source
// is not cached.
fn (mut cache StylesheetRuleCache) store(input string, rules []Rule) u64 {
	if !cache.eligible(input) { return 0 }
	nodes := stylesheet_rule_tree_nodes(rules)
	if nodes > cache.max_nodes { return 0 }
	cache.mutex.lock()
	defer { cache.mutex.unlock() }
	// Another parser or a cooperative checkpoint may already have published.
	for entry in cache.entries {
		if entry.input == input { return entry.id }
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut storage := unsafe { &platform.RetainedArena(nil) }
	mut allocation_scope := platform.RetainedArenaScope{}
	$if prealloc {
		storage = platform.new_retained_arena('stylesheet rule cache')
		allocation_scope = storage.enter_nested()
	}
	payload := copy_stylesheet_rule_payload(input, rules, nodes)
	allocation_scope.finish()
	return cache.publish(payload, storage)
}

fn (mut cache StylesheetRuleCache) store_prepared(payload StylesheetRulePayload, mut detached platform.DetachedThreadScratch) u64 {
	mut storage := detached.adopt('stylesheet rule cache')
	if storage == unsafe { nil } { return 0 }
	if !cache.eligible(payload.input) || payload.nodes > cache.max_nodes {
		storage.release()
		return 0
	}
	cache.mutex.lock()
	defer { cache.mutex.unlock() }
	for entry in cache.entries {
		if entry.input == payload.input {
			storage.release()
			return entry.id
		}
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	return cache.publish(payload, storage)
}

// Caller holds the cache mutex and owns the payload's initial arena lease.
fn (mut cache StylesheetRuleCache) publish(payload StylesheetRulePayload, storage &platform.RetainedArena) u64 {
	mut retained_bytes := i64(0)
	$if prealloc {
		// Decoded strings, immutable token payloads and allocator overhead
		// can make a short source occupy many times its text size.
		retained_bytes = storage.arena.usage().capacity
		if retained_bytes > cache.max_retained_bytes {
			mut rejected := storage
			rejected.release()
			return 0
		}
	}
	for cache.entries.len > 0 && (cache.entries.len >= cache.max_entries
		|| cache.source_bytes + payload.input.len > cache.max_source_bytes
		|| cache.nodes + payload.nodes > cache.max_nodes
		|| cache.retained_bytes + retained_bytes > cache.max_retained_bytes) {
		cache.evict_oldest()
	}
	cache.serial++
	cache.next_id++
	cache.entries << &StylesheetRuleEntry{
		input:     payload.input
		rules:     payload.rules
		nodes:     payload.nodes
		retained_bytes: retained_bytes
		storage:   storage
		id:        cache.next_id
		last_used: cache.serial
	}
	cache.source_bytes += payload.input.len
	cache.nodes += payload.nodes
	cache.retained_bytes += retained_bytes
	return cache.next_id
}

// Caller holds the mutex. The cache drops only its lease; an active
// conversion keeps the immutable payload alive through its own lease.
fn (mut cache StylesheetRuleCache) evict_oldest() {
	mut oldest := 0
	for index, entry in cache.entries {
		if entry.last_used < cache.entries[oldest].last_used { oldest = index }
	}
	entry := cache.entries[oldest]
	cache.source_bytes -= entry.input.len
	cache.nodes -= entry.nodes
	cache.retained_bytes -= entry.retained_bytes
	last := cache.entries.len - 1
	cache.entries[oldest] = cache.entries[last]
	cache.entries[last] = unsafe { nil }
	cache.entries = cache.entries[..last]
	entry.release()
}

fn (mut cache StylesheetRuleCache) release_unused() {
	$if prealloc {
		if !platform.arena_thread_is_current() { return }
	}
	cache.mutex.lock()
	defer { cache.mutex.unlock() }
	for entry in cache.entries { entry.release() }
	cache.entries = []&StylesheetRuleEntry{}
	cache.source_bytes = 0
	cache.nodes = 0
	cache.retained_bytes = 0
}
