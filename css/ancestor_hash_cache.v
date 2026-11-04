module css

import dom
import os

const retain_ancestor_hash_recompute = os.getenv('VOX_RETAIN_ANCESTOR_HASH_RECOMPUTE') != ''
const ancestor_hash_cache_diagnostics = os.getenv('VOX_ANCESTOR_HASH_CACHE_DIAGNOSTICS') != ''
const ancestor_hash_cache_slots = 128
const ancestor_hash_cache_max_hashes = 128

struct AncestorHashCacheEntry {
mut:
	identity          dom.UniqueNodeID
	document_identity dom.UniqueNodeID
	attribute_version u64
	tag_hash          u32
	id_key            u64
	quirks            bool
	html_attributes   bool
	valid             bool
	hashes            []u32
}

// No DOM objects or strings are retained. Each slot owns at most 128 scalar
// hashes, and replacement reuses its buffer. The document-wide attribute epoch
// invalidates all entries conservatively before attribute-change callbacks.
@[heap]
struct AncestorHashCache {
mut:
	entries  [ancestor_hash_cache_slots]AncestorHashCacheEntry
	reported bool
}

fn ancestor_hash_cache_slot(identity dom.UniqueNodeID) int {
	return int(u64(identity) & (ancestor_hash_cache_slots - 1))
}

fn (mut filter CountingBloomFilter) update_element_hashes_with_cache(element &dom.Element, adding bool) {
	// Saved ancestor visits supply the hash span to publish on a miss. Keep
	// standalone filter updates and fallback removals on their original path.
	document := element.document()
	if retain_ancestor_hash_recompute || !adding || !filter.record_ancestor_hashes
		|| document == unsafe { nil } {
		filter.update_element_hashes_uncached(element, adding)
		return
	}
	identity := element.as_node().unique_id()
	document_identity := document.as_node().unique_id()
	version := document.attribute_version()
	quirks := document.in_quirks_mode()
	tag_hash := selector_ascii_lowercase_hash(element.local_name())
	// Attribute-change callbacks can query style after the epoch advances but
	// before Element publishes its derived ID. Check the live derived ID too;
	// equal hashes are equivalent inputs to the filter, including collisions.
	id_key := if id := element.id() {
		u64(if quirks { selector_ascii_lowercase_hash(id) } else { selector_string_hash(id) }) * 2 + 1
	} else {
		u64(0)
	}
	html_attributes := element.is_html_element() && document.is_html_document()
	slot := ancestor_hash_cache_slot(identity)
	if filter.ancestor_hash_cache_ == unsafe { nil } {
		// The saved-visit caller has already entered its document's retained
		// allocation scope, including when a query arrived from scratch storage.
		filter.ancestor_hash_cache_ = &AncestorHashCache{}
	}
	mut cache := filter.ancestor_hash_cache_
	if cache.entries[slot].valid && cache.entries[slot].identity == identity
		&& cache.entries[slot].document_identity == document_identity
		&& cache.entries[slot].attribute_version == version
		&& cache.entries[slot].quirks == quirks && cache.entries[slot].tag_hash == tag_hash
		&& cache.entries[slot].id_key == id_key && cache.entries[slot].html_attributes == html_attributes {
		for index in 0 .. cache.entries[slot].hashes.len {
			filter.update_element_hash(cache.entries[slot].hashes[index], true)
		}
		if ancestor_hash_cache_diagnostics && !cache.reported {
			cache.reported = true
			eprintln('Vox ancestor hash cache: reused attribute-epoch hashes; document=${document.url.serialize()}')
		}
		return
	}
	start := filter.ancestor_hashes.len
	filter.update_element_hashes_uncached(element, true)
	end := filter.ancestor_hashes.len
	if end - start > ancestor_hash_cache_max_hashes { return }
	// V zero-initializes records nested in a fixed array. Give this vector a
	// complete typed descriptor before its first append, then reuse it.
	if cache.entries[slot].hashes.cap == 0 {
		cache.entries[slot].hashes = []u32{cap: 16}
	}
	cache.entries[slot].hashes.clear()
	for index in start .. end {
		cache.entries[slot].hashes << filter.ancestor_hashes[index]
	}
	cache.entries[slot].identity = identity
	cache.entries[slot].document_identity = document_identity
	cache.entries[slot].attribute_version = version
	cache.entries[slot].tag_hash = tag_hash
	cache.entries[slot].id_key = id_key
	cache.entries[slot].quirks = quirks
	cache.entries[slot].html_attributes = html_attributes
	cache.entries[slot].valid = true
}
