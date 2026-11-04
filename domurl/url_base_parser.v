module domurl

import os
import platform
import url as liburl

const retain_url_base_parse = os.getenv('VOX_RETAIN_URL_BASE_PARSE') != ''
const url_base_cache_diagnostics = os.getenv('VOX_URL_BASE_CACHE_DIAGNOSTICS') != ''
const url_base_cache_max_bytes = 4096

// One immutable base per binding owner. Cache storage is independent of a
// caller's temporary arena and is recycled when the raw base string changes.
@[heap]
pub struct URLBaseParser {
mut:
	storage_ &platform.Arena = unsafe { nil }
	input_ ?string
	base_ ?liburl.URL
	hits_ u64
	misses_ u64
	bypasses_ u64
}

pub fn (mut parser URLBaseParser) parse(input string, base ?string) ?liburl.URL {
	if retain_url_base_parse { return parse_api_url(input, base) }
	base_input := base or { return parse_api_url(input, none) }
	if base_input.len > url_base_cache_max_bytes {
		if url_base_cache_diagnostics { parser.bypasses_++ }
		return parse_api_url(input, base)
	}
	mut hit := false
	if previous := parser.input_ { hit = previous == base_input }
	if hit {
		if url_base_cache_diagnostics {
			parser.hits_++
			if parser.hits_ == 1 { eprintln('Vox URL base cache: reused parsed base') }
		}
	} else {
		if url_base_cache_diagnostics { parser.misses_++ }
		parser.input_ = none
		parser.base_ = none
		mut storage := parser.storage_
		if storage == unsafe { nil } {
			persistent := platform.enter_persistent()
			storage = platform.new_arena('URL binding base')
			parser.storage_ = storage
			platform.leave_persistent(persistent)
		} else {
			storage.reset()
		}
		entry := storage.enter()
		parser.input_ = base_input.clone()
		parser.base_ = liburl.parse(base_input)
		storage.leave(entry)
	}
	parsed_base := parser.base_ or { return none }
	// Public LibURL parsing copies the complete result out of its temporary
	// workspace under preallocation. No cache-owned bytes escape to the URL.
	return liburl.parse_with_base(input, &parsed_base)
}

pub fn (mut parser URLBaseParser) clear() {
	if url_base_cache_diagnostics && parser.hits_ + parser.misses_ + parser.bypasses_ > 0 {
		eprintln('Vox URL base cache: hits=${parser.hits_} misses=${parser.misses_} bypasses=${parser.bypasses_}')
	}
	parser.input_ = none
	parser.base_ = none
	if parser.storage_ != unsafe { nil } {
		mut storage := parser.storage_
		storage.release()
		parser.storage_ = unsafe { nil }
	}
	parser.hits_ = 0
	parser.misses_ = 0
	parser.bypasses_ = 0
}
