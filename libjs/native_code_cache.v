module libjs

import crypto.rand
import crypto.sha256
import dl
import json2
import math
import os
import time

// Per-source, per-executable disk lookup. Unlike the manual warmup experiment,
// a new VM can attach code before an executable's first instruction runs.
@[heap]
struct NativeCodeCache {
	directory string
	compiler  string
	abi       string
	generated_code_identity bool
mut:
	checked       []&Executable
	keys          map[voidptr]string
	source_hashes map[voidptr]string
	pending       map[string]&Executable
	entries       map[string]NativeEntry
	libraries     map[string]NativeCachedLibrary
	stats         NativeCacheStats
	background_batch ?&NativeCacheBackgroundBatch
}

struct NativeCachedLibrary {
	handle voidptr
	digest string
}

struct NativeLoadedEntry {
	entry   NativeEntry
	handle  voidptr
	library string
	digest  string
	opened  bool
}

struct NativeCacheRecord {
	key            string
	abi            string
	library        string
	library_sha256 string
	symbol         int
}

pub struct NativeCacheStats {
pub mut:
	abi                  string
	identity_kind        string
	pending_executables  int
	cache_hits           u64
	cache_misses         u64
	invalid_entries      u64
	compiled_executables u64
	compiler_invocations u64
	compile_ms           f64
	load_ms              f64
	last_error           string
}

fn native_cache_binary_abi(executable string) !string {
	return sha256.hexhash('native-disk-binary-v1:${os.user_os()}:${os.uname().machine}:' +
		os.read_file(executable)!)
}

fn native_cache_abi() !string {
	$if !prod {
		// Development builds reload $embed_file inputs from the working tree.
		// Those files can change without changing this executable's generator or
		// Value layout. Bind their cache to the executable instead, and fail
		// closed if its identity cannot be read. Production embeds the sources
		// below, so unrelated browser rebuilds can still share native code.
		return native_cache_binary_abi(native_cache_executable()!)
	} $else {
		// Invalidate machine code when the ABI or generated fast-path semantics
		// change, without invalidating it for unrelated browser/docs commits.
		return sha256.hexhash('native-disk-v2:${os.user_os()}:${os.uname().machine}:${native_primitive_layout_identity()}:' +
			$embed_file('@VMODROOT/libjs/native_tier.v').to_string() +
			$embed_file('@VMODROOT/libjs/native_dynamic_dispatch.v').to_string() +
			$embed_file('@VMODROOT/libjs/native_property_read.v').to_string() +
			$embed_file('@VMODROOT/libjs/native_property_length.v').to_string() +
			$embed_file('@VMODROOT/libjs/native_property_index.v').to_string() +
			$embed_file('@VMODROOT/libjs/native_code_cache.v').to_string() +
			$embed_file('@VMODROOT/libjs/native_generated_code_cache.v').to_string() +
			$embed_file('@VMODROOT/libjs/instruction.v').to_string() +
			$embed_file('@VMODROOT/libjs/value.v').to_string() +
			$embed_file('@VMODROOT/libjs/object.v').to_string() +
			$embed_file('@VMODROOT/libjs/primitive_string.v').to_string() +
			$embed_file('@VMODROOT/libjs/native_primitive_ops.v').to_string() +
			$embed_file('@VMODROOT/libjs/utf16_utils.v').to_string() +
			$embed_file('@VMODROOT/libjs/utf16_ascii_storage.v').to_string() +
			$embed_file('@VMODROOT/libjs/operand.v').to_string())
	}
}

// The caller supplies a private executable cache, not the HTTP resource cache.
// Enabling lookup never starts a compiler. Compilation is an explicit idle
// checkpoint, and the next VM needs no warmup or profile to use that result.
pub fn (mut vm VM) enable_native_code_cache(directory string, compiler string) ! {
	vm.enable_native_code_cache_with_options(directory, compiler, NativeCodeCacheOptions{})!
}

pub struct NativeCodeCacheOptions {
pub:
	// Experimental reuse of exactly matching generated function code, across
	// source URLs and edits. The ordinary source-bound cache remains default.
	generated_code_identity bool
}

pub fn (mut vm VM) enable_native_code_cache_with_options(directory string, compiler string, options NativeCodeCacheOptions) ! {
	if vm.run_executable_depth != 0 || vm.external_budget_depth != 0 {
		return error('Cannot enable the native disk cache during JavaScript execution')
	}
	if vm.native_tier != none { return error('Native tier already initialized') }
	base_abi := native_cache_abi()!
	abi := if options.generated_code_identity {
		sha256.hexhash('native-generated-code-v1:' + base_abi)
	} else {
		base_abi
	}
	path := os.join_path(directory, abi)
	os.mkdir_all(path)!
	vm.ensure_native_type_names()
	vm.native_tier = &NativeTier{
		enabled:    true
		profiling:  false
		persistent: &NativeCodeCache{
			directory: os.real_path(path)
			compiler: compiler
			abi: abi
			generated_code_identity: options.generated_code_identity
		}
	}
}

pub fn (vm &VM) native_code_cache_stats() NativeCacheStats {
	if tier := vm.native_tier {
		if cache := tier.persistent {
			return NativeCacheStats{
				...cache.stats
				abi: cache.abi
				identity_kind: if cache.generated_code_identity { 'generated-code' } else { 'source' }
				pending_executables: cache.pending.len
			}
		}
	}
	return NativeCacheStats{}
}

pub fn (vm &VM) native_code_cache_is_idle() bool {
	return vm.run_executable_depth == 0 && vm.external_budget_depth == 0 && !vm.running_promise_jobs
}

fn native_key_u32(mut bytes []u8, value u32) {
	bytes << [u8(value), u8(value >> 8), u8(value >> 16), u8(value >> 24)]
}

fn (mut cache NativeCodeCache) key(executable &Executable) string {
	parsed := executable.parsed_source
	if parsed == unsafe { nil } || executable.native_cache_scope == '' { return '' }
	if cache.generated_code_identity {
		code := native_generated_code_identity(executable) or {
			cache.stats.last_error = err.msg()
			return ''
		}
		return sha256.hexhash(cache.abi + ':' + code)
	}
	source_hash := cache.source_hashes[voidptr(parsed)] or {
		hash := sha256.hexhash(parsed.source_text)
		cache.source_hashes[voidptr(parsed)] = hash
		hash
	}
	mut bytes := []u8{cap: executable.instructions.len * 40}
	for value in [executable.registers_and_locals_count, executable.local_index_base,
		u32(executable.constants.len), u32(executable.local_variable_names.len),
		executable.bytecode_length] {
		native_key_u32(mut bytes, value)
	}
	for instruction in executable.instructions {
		for value in [u32(instruction.op), instruction.dst.raw, instruction.lhs.raw,
			instruction.rhs.raw, instruction.src.raw, instruction.identifier, instruction.target,
			u32(instruction.strict), u32(instruction.annex_b), u32(instruction.arguments.len)] {
			native_key_u32(mut bytes, value)
		}
		for argument in instruction.arguments { native_key_u32(mut bytes, argument.raw) }
	}
	filename := if source := executable.source_code {
		source.filename.str().all_before('#vox-libjs-inline-')
	} else {
		''
	}
	return sha256.hexhash(cache.abi + ':' + source_hash + ':' +
		sha256.hexhash(filename) + ':' + executable.native_cache_scope + ':' +
		sha256.sum(bytes).hex())
}

fn valid_native_digest(value string) bool {
	return value.len == 64 && value.bytes().all((it >= `0` && it <= `9`) || (it >= `a` && it <= `f`))
}

fn (mut cache NativeCodeCache) load(key string) !NativeEntry {
	// The typed JSON decoder lazily retains per-type metadata. Keep decoding
	// outside the temporary file-hashing workspace so that cache stays alive.
	return cache.retain_entry(cache.read_entry(key)!)
}

fn native_library_digest(path string) !string {
	$if prealloc {
		scope := unsafe { prealloc_scope_begin() }
		defer { unsafe { prealloc_scope_free_after(scope) } }
		digest := native_library_digest_in_workspace(path) or {
			unsafe { prealloc_scope_leave(scope) }
			return error_with_code(err.msg().clone(), err.code())
		}
		unsafe { prealloc_scope_leave(scope) }
		return digest.clone()
	}
	return native_library_digest_in_workspace(path)
}

fn native_library_digest_in_workspace(path string) !string {
	return sha256.hexhash(os.read_file(path)!)
}

fn (mut cache NativeCodeCache) retain_entry(loaded NativeLoadedEntry) NativeEntry {
	if loaded.opened {
		cache.libraries[loaded.library.clone()] = NativeCachedLibrary{
			handle: loaded.handle
			digest: loaded.digest.clone()
		}
	}
	return loaded.entry
}

fn (cache &NativeCodeCache) read_entry(key string) !NativeLoadedEntry {
	path := os.join_path(cache.directory, key + '.json')
	// A missing record is an ordinary first-visit miss. Corrupt records are
	// diagnostics and get replaced only after a successful compilation.
	text := os.read_file(path)!
	if text.len > 16384 { return error('Native cache record is too large') }
	record := decode_native_cache_record(text)!
	if record.key != key || record.abi != cache.abi || record.symbol < 0
		|| record.symbol > 1000000 || !valid_native_digest(record.library_sha256)
		|| !record.library.ends_with(dl.dl_ext)
		|| !valid_native_digest(record.library.all_before_last(dl.dl_ext)) {
		return error('Invalid native cache identity')
	}
	mut handle := unsafe { nil }
	mut opened := false
	if loaded := cache.libraries[record.library] {
		if loaded.digest != record.library_sha256 {
			return error('Native cache library identity changed')
		}
		handle = loaded.handle
	} else {
		library := os.join_path(cache.directory, record.library)
		if native_library_digest(library)! != record.library_sha256 {
			return error('Native cache library digest mismatch')
		}
		handle = dl.open_opt(library, dl.rtld_now | dl.rtld_local)!
		opened = true
	}
	symbol := dl.sym_opt(handle, 'vox_native_${record.symbol}') or {
		if opened { dl.close(handle) }
		return err
	}
	return NativeLoadedEntry{
		entry: unsafe { NativeEntry(symbol) }
		handle: handle
		library: record.library
		digest: record.library_sha256
		opened: opened
	}
}

fn native_record_string(fields map[string]json2.Any, name string) !string {
	value := fields[name] or { return error('Missing native cache field: ${name}') }
	if value is string { return value }
	return error('Invalid native cache string: ${name}')
}

// Typed struct decoding caches process-wide reflection metadata in the current
// allocator. A first decode inside load's temporary arena would leave that
// cache dangling. Map/Any decoding has no retained struct metadata. Require the
// canonical record field types and keep all decoded values inside this lookup.
fn decode_native_cache_record(text string) !NativeCacheRecord {
	fields := json2.decode[map[string]json2.Any](text)!
	key := native_record_string(fields, 'key')!
	abi := native_record_string(fields, 'abi')!
	library := native_record_string(fields, 'library')!
	digest := native_record_string(fields, 'library_sha256')!
	symbol := fields['symbol'] or { return error('Missing native cache field: symbol') }
	if symbol !is int && symbol !is i64 && symbol !is u64 && symbol !is f64 {
		return error('Invalid native cache symbol type')
	}
	number := symbol.f64()
	if math.is_nan(number) || number < 0 || number > 1000000 || math.trunc(number) != number {
		return error('Invalid native cache symbol')
	}
	return NativeCacheRecord{key: key, abi: abi, library: library, library_sha256: digest, symbol: int(number)}
}

fn (mut tier NativeTier) prepare_cached_entry(executable &Executable) {
	mut cache := tier.persistent or { return }
	address := voidptr(executable)
	if _ := tier.entries[address] { return }
	if _ := cache.keys[address] { return }
	key := cache.key(executable)
	if key == '' { return }
	// Keep the executable and its ParsedSource alive while their addresses are
	// used as VM-local keys, including otherwise transient closure instances.
	cache.checked << executable
	cache.keys[address] = key
	if entry := cache.entries[key] {
		tier.set_native_entry(executable, entry)
		return
	}
	if os.is_file(os.join_path(cache.directory, key + '.json')) {
		started := time.sys_mono_now()
		if entry := cache.load(key) {
			cache.stats.load_ms += f64(time.sys_mono_now() - started) / 1e6
			cache.entries[key] = entry
			tier.set_native_entry(executable, entry)
			cache.stats.cache_hits++
			return
		} else {
			cache.stats.invalid_entries++
			cache.stats.last_error = err.msg()
		}
	}
	cache.stats.cache_misses++
	cache.pending[key] = executable
}

// Run after the outer script/callback/module entry has finished, or before
// disposing its runtime. Never run a compiler from the interpreter hot loop.
pub fn (mut vm VM) flush_native_code_cache() !NativeCacheStats {
	mut stats := vm.flush_native_code_cache_batch()!
	for stats.pending_executables>0 { stats=vm.flush_native_code_cache_batch()! }
	return stats
}

// Bound each compiler invocation by function count and bytecode size. HTML
// embedders can return to their event loop between batches; a full flush still
// completes every pending entry before shutdown or an explicit checkpoint.
pub fn (mut vm VM) flush_native_code_cache_batch() !NativeCacheStats {
	if vm.run_executable_depth != 0 || vm.external_budget_depth != 0 {
		return error('Native disk cache compilation requires an idle VM')
	}
	mut tier := vm.native_tier or { return NativeCacheStats{} }
	mut cache := tier.persistent or { return NativeCacheStats{} }
	if cache.background_batch != none {
		return error('Native disk cache compilation already running in the background')
	}
	if cache.pending.len == 0 { return vm.native_code_cache_stats() }
	keys, selected := cache.select_batch()!
	compiled := native_compile_library(selected, cache.directory, cache.compiler) or {
		cache.stats.last_error = err.msg()
		return err
	}
	publish_native_cache_batch(cache.directory, cache.abi, keys, compiled.stats) or {
		dl.close(compiled.handle)
		cache.stats.last_error = err.msg()
		return err
	}
	cache.install_batch(mut tier, keys, compiled)!
	return vm.native_code_cache_stats()
}

fn (cache &NativeCodeCache) select_batch() !([]string, []&Executable) {
	mut keys := []string{}
	mut selected := []&Executable{}
	mut instructions := u64(0)
	for key in cache.pending.keys().sorted() {
		executable := cache.pending[key] or { return error('Missing pending native executable') }
		if selected.len > 0 && (selected.len >= 128 || instructions + u64(executable.instructions.len) > 32768) { break }
		executable.validate(0)!
		keys << key
		selected << executable
		instructions += u64(executable.instructions.len)
	}
	return keys, selected
}

fn (mut cache NativeCodeCache) install_batch(mut tier NativeTier, keys []string, compiled NativeCompiledLibrary) ! {
	library := os.file_name(compiled.stats.library)
	if loaded := cache.libraries[library] {
		// dlopen increments the reference even when the code is already mapped.
		// Keep the existing owner and release this redundant reference.
		dl.close(compiled.handle)
		if loaded.digest != compiled.stats.library_sha256 {
			return error('Compiled native library identity changed')
		}
	} else {
		cache.libraries[library.clone()] = NativeCachedLibrary{ handle: compiled.handle, digest: compiled.stats.library_sha256.clone() }
	}
	cache.stats.compiled_executables += u64(keys.len)
	if !compiled.stats.cache_hit { cache.stats.compiler_invocations++ }
	cache.stats.compile_ms += compiled.stats.compile_ms
	cache.stats.load_ms += compiled.stats.load_ms
	for index, key in keys {
		cache.entries[key.clone()] = compiled.entries[index]
		cache.pending.delete(key)
	}
	for executable in cache.checked {
		if entry := cache.entries[cache.keys[voidptr(executable)]] {
			tier.set_native_entry(executable, entry)
		}
	}
}

fn publish_native_cache_batch(directory string, abi string, keys []string, stats NativeCodeStats) ! {
	library := os.file_name(stats.library)
	suffix := rand.bytes(16)!.hex()
	for index, key in keys {
		record := NativeCacheRecord{
			key:            key
			abi:            abi
			library:        library
			library_sha256: stats.library_sha256
			symbol:         index
		}
		path := os.join_path(directory, key + '.json')
		temporary := path + '.' + suffix + '.tmp'
		os.write_file(temporary, json2.encode(record)) or {
			os.rm(temporary) or {}
			return err
		}
		os.mv(temporary, path) or {
			os.rm(temporary) or {}
			return err
		}
	}
}
