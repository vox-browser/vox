@[has_globals]
module browserjs

import hash
import libjs
import os
import platform
import sync

// ParsedSource contains realm-neutral syntax/scope records. Executables, values,
// modules and environments are always constructed fresh for each new document.
struct LibJSFrontendEntry {
	parsed       &libjs.ParsedSource
	source_bytes int
mut:
	used u64
}

@[heap]
struct LibJSFrontendCache {
mut:
	lock         sync.Mutex
	entries      map[string]LibJSFrontendEntry
	source_bytes int
	clock        u64
}

const libjs_frontend_cache = &LibJSFrontendCache{}
const libjs_frontend_cache_source_limit = 6 * 1024 * 1024
const libjs_frontend_cache_max_entry_bytes = 4 * 1024 * 1024
const libjs_frontend_cache_entry_limit = 128

pub struct LibJSFrontendCacheStats {
pub:
	hits   u64
	misses u64
	// Module sources parsed on a worker thread instead of the main thread.
	background_parses u64
}

pub fn (runtime &Runtime) frontend_code_cache_stats() LibJSFrontendCacheStats {
	background := if host := runtime.module_host_ { host.libjs_background_parses } else { u64(0) }
	return LibJSFrontendCacheStats{ hits: runtime.libjs_frontend_cache_hits_, misses: runtime.libjs_frontend_cache_misses_, background_parses: background }
}

fn (runtime &Runtime) use_libjs_frontend_cache() bool {
	return match os.getenv('VOX_LIBJS_FRONTEND_CACHE') {
		'1', 'on' { true }
		'0', 'off' { false }
		else { runtime.libjs_native_cache_enabled_ }
	}
}

fn libjs_frontend_key(partition string, source string, kind libjs.SourceType, options libjs.ParseOptions) string {
	fingerprint := hash.sum64_string(source, 0)
	return '${partition}:${kind}:${options.max_recursion_depth}:${fingerprint}'
}

fn (runtime &Runtime) prepare_libjs_frontend(source string, kind libjs.SourceType, options libjs.ParseOptions) &libjs.ParsedSource {
	return runtime.prepare_libjs_frontend_with(source, kind, options, unsafe { nil })
}

// `preparsed`, when given, is the result of parsing exactly `source` with the
// same kind and options elsewhere (a background worker). It replaces the parse
// on a cache miss; cache lookup, insertion and statistics are unchanged. Only a
// clean result is reused: a worker's smaller native stack can stop a deeply
// nested source that this thread parses, so any diagnostic reparses here.
fn (runtime &Runtime) prepare_libjs_frontend_with(source string, kind libjs.SourceType, options libjs.ParseOptions, preparsed &libjs.ParsedSource) &libjs.ParsedSource {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut owner := unsafe { &Runtime(runtime) }
	usable := preparsed != unsafe { nil } && preparsed.source_text == source
		&& !preparsed.has_errors() && !preparsed.reached_recursion_limit
	if !runtime.use_libjs_frontend_cache() || source.len > libjs_frontend_cache_max_entry_bytes {
		owner.libjs_frontend_cache_misses_++
		if usable { return preparsed }
		return libjs.parse_source_with_options(source.clone(), kind, options)
	}
	key := libjs_frontend_key(runtime.libjs_native_cache_partition_, source, kind, options)
	mut cache := libjs_frontend_cache
	cache.lock.lock()
	cache.clock++
	if mut entry := cache.entries[key] {
		// The fingerprint indexes the cache. Only identical bytes can reuse syntax.
		if entry.parsed.source_text == source {
			entry.used = cache.clock
			cache.entries[key] = entry
			cache.lock.unlock()
			owner.libjs_frontend_cache_hits_++
			return entry.parsed
		}
	}
	cache.lock.unlock()
	owner.libjs_frontend_cache_misses_++
	// Own the bytes independently of a document/resource arena which can be
	// retired as soon as the first visit ends.
	parsed := if usable { preparsed } else { libjs.parse_source_with_options(source.clone(), kind, options) }
	if parsed.has_errors() || parsed.reached_recursion_limit { return parsed }
	cache.lock.lock()
	defer { cache.lock.unlock() }
	if entry := cache.entries[key] {
		// Another caller can insert while we parse, including a colliding source.
		return if entry.parsed.source_text == source { entry.parsed } else { parsed }
	}
	for cache.entries.len >= libjs_frontend_cache_entry_limit
		|| cache.source_bytes + source.len > libjs_frontend_cache_source_limit {
		mut oldest := ''
		mut used := u64(0xffffffffffffffff)
		for entry_key, entry in cache.entries {
			if entry.used < used {
				used = entry.used
				oldest = entry_key
			}
		}
		if oldest == '' { break }
		old := cache.entries[oldest] or { break }
		cache.source_bytes -= old.source_bytes
		cache.entries.delete(oldest)
	}
	cache.clock++
	cache.entries[key] = LibJSFrontendEntry{ parsed: parsed, source_bytes: source.len, used: cache.clock }
	cache.source_bytes += source.len
	return parsed
}

fn (runtime &Runtime) prepare_libjs_script(source ScriptSource) !&PreparedScript {
	if source.starting_line < 1 { return error('Script starting line must be positive') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	parsed := runtime.prepare_libjs_frontend(source.code, source.source_type, libjs.ParseOptions{ max_recursion_depth: 256 })
	owned := ScriptSource{ ...source, code: parsed.source_text, url: source.url.clone() }
	return finish_script_preparation(owned, parsed)
}
