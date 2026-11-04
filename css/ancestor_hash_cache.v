module css

import dom
import os

const retain_ancestor_hash_recompute = os.getenv('VOX_RETAIN_ANCESTOR_HASH_RECOMPUTE') != ''
const ancestor_hash_cache_diagnostics = os.getenv('VOX_ANCESTOR_HASH_CACHE_DIAGNOSTICS') != ''
const ancestor_hash_cache_slots = 128
const ancestor_hash_cache_max_hashes = 128
const ancestor_hash_cache_min_class_bytes = 64
const ancestor_hash_cache_max_class_bytes = 8192

struct AncestorHashCacheEntry {
mut:
	identity          dom.UniqueNodeID
	document_identity dom.UniqueNodeID
	attribute_version u64
	class_address     uint
	class_length      int
	quirks            bool
	valid             bool
	hashes            []u32
}

// Only substantial class attributes enter this bounded cache. No DOM object
// or string is retained: the source address is an identity token, never read.
// Epoch and source identity changes invalidate entries before reuse, while
// tag, ID and attribute-name hashing always read their current inputs.
@[heap]
struct AncestorHashCache {
mut:
	entries  [ancestor_hash_cache_slots]AncestorHashCacheEntry
	reported bool
}

fn ancestor_hash_cache_slot(identity dom.UniqueNodeID) int {
	// UniqueNodeID is the node's aligned address, not a sequential counter.
	address := u64(identity)
	return int(((address >> 4) ^ (address >> 12)) & (ancestor_hash_cache_slots - 1))
}

fn (mut filter CountingBloomFilter) update_ancestor_class_hashes(element &dom.Element, classes string, quirks bool, adding bool) {
	cacheable := !retain_ancestor_hash_recompute && adding && filter.record_ancestor_hashes
		&& classes.len >= ancestor_hash_cache_min_class_bytes
		&& classes.len <= ancestor_hash_cache_max_class_bytes && element.document() != unsafe { nil }
		&& element.document().as_node().unique_id() == filter.ancestor_hash_cache_document_
	if cacheable && filter.replay_cached_ancestor_class_hashes(element, classes, quirks) { return }
	start := filter.ancestor_hashes.len
	mut position := 0
	for position < classes.len {
		// Preserve fields() delimiters exactly, including CR/form-feed as
		// ordinary bytes. Borrow each token only while computing its hash.
		for position < classes.len && (classes[position] == ` ` || classes[position] == `\t` || classes[position] == `\n`) {
			position++
		}
		begin := position
		for position < classes.len && classes[position] != ` ` && classes[position] != `\t` && classes[position] != `\n` {
			position++
		}
		if position == begin { break }
		name := unsafe { classes.substr_unsafe(begin, position) }
		filter.update_element_hash(if quirks {
			selector_ascii_lowercase_hash(name)
		} else {
			selector_string_hash(name)
		}, adding)
	}
	if cacheable { filter.remember_ancestor_class_hashes(element, classes, quirks, start) }
}

fn (mut filter CountingBloomFilter) replay_cached_ancestor_class_hashes(element &dom.Element, classes string, quirks bool) bool {
	mut cache := filter.ancestor_hash_cache_
	if cache == unsafe { nil } { return false }
	document := element.document()
	identity := element.as_node().unique_id()
	slot := ancestor_hash_cache_slot(identity)
	if !cache.entries[slot].valid || cache.entries[slot].identity != identity
		|| cache.entries[slot].document_identity != document.as_node().unique_id()
		|| cache.entries[slot].attribute_version != document.attribute_version()
		|| cache.entries[slot].quirks != quirks
		|| cache.entries[slot].class_address != uint(classes.str)
		|| cache.entries[slot].class_length != classes.len {
		return false
	}
	for index in 0 .. cache.entries[slot].hashes.len {
		filter.update_element_hash(cache.entries[slot].hashes[index], true)
	}
	if ancestor_hash_cache_diagnostics && !cache.reported {
		cache.reported = true
		eprintln('Vox ancestor hash cache: reused attribute-epoch class hashes; document=${document.url.serialize()}')
	}
	return true
}

fn (mut filter CountingBloomFilter) remember_ancestor_class_hashes(element &dom.Element, classes string, quirks bool, start int) {
	end := filter.ancestor_hashes.len
	if end - start > ancestor_hash_cache_max_hashes { return }
	// The saved-visit caller has entered its document's retained allocation
	// scope, including when the query arrived from temporary scratch storage.
	if filter.ancestor_hash_cache_ == unsafe { nil } {
		filter.ancestor_hash_cache_ = &AncestorHashCache{}
	}
	mut cache := filter.ancestor_hash_cache_
	identity := element.as_node().unique_id()
	slot := ancestor_hash_cache_slot(identity)
	document := element.document()
	// Keep the first admitted node in an epoch. A traversal through more
	// elements than slots must not repeatedly copy colliding cold entries.
	if cache.entries[slot].valid && cache.entries[slot].identity != identity
		&& cache.entries[slot].document_identity == document.as_node().unique_id()
		&& cache.entries[slot].attribute_version == document.attribute_version() {
		return
	}
	// Fixed-array records start zeroed; initialize each typed vector before its
	// first append, then reuse that slot's private reservation on replacement.
	if cache.entries[slot].hashes.cap == 0 { cache.entries[slot].hashes = []u32{cap: 16} }
	cache.entries[slot].hashes.clear()
	for index in start .. end { cache.entries[slot].hashes << filter.ancestor_hashes[index] }
	cache.entries[slot].identity = identity
	cache.entries[slot].document_identity = document.as_node().unique_id()
	cache.entries[slot].attribute_version = document.attribute_version()
	cache.entries[slot].class_address = uint(classes.str)
	cache.entries[slot].class_length = classes.len
	cache.entries[slot].quirks = quirks
	cache.entries[slot].valid = true
}
