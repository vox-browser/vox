module domurl

import os
import platform
import url as liburl

const retain_url_input_parse = os.getenv('VOX_RETAIN_URL_INPUT_PARSE') != ''
const url_input_cache_diagnostics = os.getenv('VOX_URL_INPUT_CACHE_DIAGNOSTICS') != ''
const url_input_cache_sets = 256
const url_input_cache_max_bytes = 2048
const url_input_cache_storage_bytes = 2 * 1024 * 1024

struct URLInputCacheEntry {
	input  string
	base   ?string
	record liburl.URL
}

// Binding-local, two-way memo of successful raw input/base pairs. No JS values
// are cached: callers must finish both WebIDL conversions before asking to parse.
// Replaced entries are reclaimed together at a bounded arena threshold.
@[heap]
pub struct URLInputParser {
mut:
	base_parser       URLBaseParser
	storage_          &platform.Arena          = unsafe { nil }
	slots_            [512]&URLInputCacheEntry = unsafe { [512]&URLInputCacheEntry{} }
	next_way_         [256]u8
	seen_             [512]u64
	admission_misses_ int
	hits_             u64
	misses_           u64
	bypasses_         u64
}

fn url_input_cache_key(input string, base ?string) u64 {
	mut key := u64(14695981039346656037)
	for byte in input { key = (key ^ u64(byte)) * u64(1099511628211) }
	if value := base {
		key = (key ^ u64(255)) * u64(1099511628211)
		for byte in value { key = (key ^ u64(byte)) * u64(1099511628211) }
	}
	return key ^ (key >> 32)
}

fn url_input_cache_set(input string, base ?string) int {
	return int(url_input_cache_key(input, base) & u64(url_input_cache_sets - 1))
}

fn (mut parser URLInputParser) admit(key u64) bool {
	// A bounded membership filter avoids copying first-seen URLs into the
	// memo. False positives may admit an extra entry; exact key comparisons
	// still decide every hit. Periodic clearing bounds saturation under churn.
	if parser.admission_misses_ >= 4096 {
		parser.seen_ = [512]u64{}
		parser.admission_misses_ = 0
	}
	parser.admission_misses_++
	a := int(key & 32767)
	b := int((key >> 32) & 32767)
	a_mask := u64(1) << u32(a & 63)
	b_mask := u64(1) << u32(b & 63)
	seen := parser.seen_[a >> 6] & a_mask != 0 && parser.seen_[b >> 6] & b_mask != 0
	parser.seen_[a >> 6] |= a_mask
	parser.seen_[b >> 6] |= b_mask
	return seen
}

fn url_input_cache_base_equal(a ?string, b ?string) bool {
	if left := a {
		if right := b { return left == right }
		return false
	}
	return b == none
}

pub fn (mut parser URLInputParser) parse(input string, base ?string) ?liburl.URL {
	if retain_url_input_parse { return parser.base_parser.parse(input, base) }
	if input.len > url_input_cache_max_bytes
		|| (base or { '' }).len > url_input_cache_max_bytes {
		if url_input_cache_diagnostics { parser.bypasses_++ }
		return parser.base_parser.parse(input, base)
	}
	key := url_input_cache_key(input, base)
	set := int(key & u64(url_input_cache_sets - 1))
	for way in 0 .. 2 {
		cached := parser.slots_[set * 2 + way]
		if cached != unsafe { nil } && cached.input == input
			&& url_input_cache_base_equal(cached.base, base) {
			parser.next_way_[set] = u8(1 - way)
			if url_input_cache_diagnostics {
				parser.hits_++
				if parser.hits_ == 1 { eprintln('Vox URL input cache: reused parsed input') }
			}
			// Never lend cache-owned strings or the mutable path vector to a URL.
			return cached.record.owned_copy()
		}
	}
	if url_input_cache_diagnostics { parser.misses_++ }
	record := parser.base_parser.parse(input, base) or { return none }
	if !parser.admit(key) { return record }
	mut storage := parser.storage_
	if storage == unsafe { nil } {
		persistent := platform.enter_persistent()
		storage = platform.new_arena('URL binding inputs')
		parser.storage_ = storage
		platform.leave_persistent(persistent)
	} else if storage.usage().used >= url_input_cache_storage_bytes {
		// Drop all borrowed entry pointers before retiring their arena.
		parser.slots_ = unsafe { [512]&URLInputCacheEntry{} }
		parser.next_way_ = [256]u8{}
		storage.reset()
	}
	entry := storage.enter()
	owned_base := if value := base { ?string(value.clone()) } else { none }
	cached := &URLInputCacheEntry{ input: input.clone(), base: owned_base, record: record.owned_copy() }
	storage.leave(entry)
	way := int(parser.next_way_[set])
	parser.slots_[set * 2 + way] = cached
	parser.next_way_[set] = u8(1 - way)
	return record
}

pub fn (mut parser URLInputParser) clear() {
	if url_input_cache_diagnostics && parser.hits_ + parser.misses_ + parser.bypasses_ > 0 {
		eprintln('Vox URL input cache: hits=${parser.hits_} misses=${parser.misses_} bypasses=${parser.bypasses_}')
	}
	parser.slots_ = unsafe { [512]&URLInputCacheEntry{} }
	parser.next_way_ = [256]u8{}
	parser.seen_ = [512]u64{}
	parser.admission_misses_ = 0
	if parser.storage_ != unsafe { nil } {
		mut storage := parser.storage_
		storage.release()
		parser.storage_ = unsafe { nil }
	}
	parser.base_parser.clear()
	parser.hits_ = 0
	parser.misses_ = 0
	parser.bypasses_ = 0
}
