module libjs

import crypto.sha256
import dl
import json2
import os
import rand
import time

// Per-source, per-executable disk lookup. Unlike the manual warmup experiment,
// a new VM can attach code before an executable's first instruction runs.
@[heap]
struct NativeCodeCache {
	directory string
	compiler  string
	abi       string
mut:
	checked       []&Executable
	keys          map[voidptr]string
	source_hashes map[voidptr]string
	pending       map[string]&Executable
	entries       map[string]NativeEntry
	libraries     map[string]NativeCachedLibrary
	stats         NativeCacheStats
}

struct NativeCachedLibrary {
	handle voidptr
	digest string
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

fn native_cache_abi() string {
	// Invalidate machine code when the ABI or generated fast-path semantics
	// change, without invalidating it for unrelated browser/docs commits.
	return sha256.hexhash('native-disk-v1:${os.user_os()}:${os.uname().machine}:' +
		$embed_file('@VMODROOT/libjs/native_tier.v').to_string() +
		$embed_file('@VMODROOT/libjs/native_dynamic_dispatch.v').to_string() +
		$embed_file('@VMODROOT/libjs/native_code_cache.v').to_string() +
		$embed_file('@VMODROOT/libjs/instruction.v').to_string() +
		$embed_file('@VMODROOT/libjs/value.v').to_string() +
		$embed_file('@VMODROOT/libjs/utf16_utils.v').to_string() +
		$embed_file('@VMODROOT/libjs/utf16_ascii_storage.v').to_string() +
		$embed_file('@VMODROOT/libjs/operand.v').to_string())
}

// The caller supplies a private executable cache, not the HTTP resource cache.
// Enabling lookup never starts a compiler. Compilation is an explicit idle
// checkpoint, and the next VM needs no warmup or profile to use that result.
pub fn (mut vm VM) enable_native_code_cache(directory string, compiler string) ! {
	if vm.run_executable_depth != 0 || vm.external_budget_depth != 0 {
		return error('Cannot enable the native disk cache during JavaScript execution')
	}
	if vm.native_tier != none { return error('Native tier already initialized') }
	abi := native_cache_abi()
	path := os.join_path(directory, abi)
	os.mkdir_all(path)!
	vm.native_tier = &NativeTier{
		enabled:    true
		profiling:  false
		persistent: &NativeCodeCache{ directory: os.real_path(path), compiler: compiler, abi: abi }
	}
}

pub fn (vm &VM) native_code_cache_stats() NativeCacheStats {
	if tier := vm.native_tier {
		if cache := tier.persistent {
			return NativeCacheStats{ ...cache.stats, pending_executables: cache.pending.len }
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
			u32(instruction.strict), u32(instruction.arguments.len)] {
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
	path := os.join_path(cache.directory, key + '.json')
	// A missing record is an ordinary first-visit miss. Corrupt records are
	// diagnostics and get replaced only after a successful compilation.
	text := os.read_file(path)!
	if text.len > 16384 { return error('Native cache record is too large') }
	record := json2.decode[NativeCacheRecord](text)!
	if record.key != key || record.abi != cache.abi || record.symbol < 0
		|| record.symbol > 1000000 || !valid_native_digest(record.library_sha256)
		|| !record.library.ends_with(dl.dl_ext)
		|| !valid_native_digest(record.library.all_before_last(dl.dl_ext)) {
		return error('Invalid native cache identity')
	}
	mut handle := unsafe { nil }
	if loaded := cache.libraries[record.library] {
		if loaded.digest != record.library_sha256 {
			return error('Native cache library identity changed')
		}
		handle = loaded.handle
	} else {
		library := os.join_path(cache.directory, record.library)
		if sha256.hexhash(os.read_file(library)!) != record.library_sha256 {
			return error('Native cache library digest mismatch')
		}
		handle = dl.open_opt(library, dl.rtld_now | dl.rtld_local)!
		cache.libraries[record.library] = NativeCachedLibrary{ handle: handle, digest: record.library_sha256 }
	}
	return unsafe { NativeEntry(dl.sym_opt(handle, 'vox_native_${record.symbol}')!) }
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
		tier.entries[address] = entry
		return
	}
	if os.is_file(os.join_path(cache.directory, key + '.json')) {
		started := time.sys_mono_now()
		if entry := cache.load(key) {
			cache.stats.load_ms += f64(time.sys_mono_now() - started) / 1e6
			cache.entries[key] = entry
			tier.entries[address] = entry
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
	if vm.run_executable_depth != 0 || vm.external_budget_depth != 0 {
		return error('Native disk cache compilation requires an idle VM')
	}
	mut tier := vm.native_tier or { return NativeCacheStats{} }
	mut cache := tier.persistent or { return NativeCacheStats{} }
	if cache.pending.len == 0 { return cache.stats }
	keys := cache.pending.keys().sorted()
	mut selected := []&Executable{cap: keys.len}
	for key in keys {
		executable := cache.pending[key] or { return error('Missing pending native executable') }
		executable.validate(0)!
		selected << executable
	}
	compiled := native_compile_library(selected, cache.directory, cache.compiler) or {
		cache.stats.last_error = err.msg()
		return err
	}
	library := os.file_name(compiled.stats.library)
	if loaded := cache.libraries[library] {
		// dlopen increments the reference even when the code is already mapped.
		// Keep the existing owner and release this redundant reference.
		dl.close(compiled.handle)
		if loaded.digest != compiled.stats.library_sha256 {
			return error('Compiled native library identity changed')
		}
	} else {
		cache.libraries[library] = NativeCachedLibrary{ handle: compiled.handle, digest: compiled.stats.library_sha256 }
	}
	cache.stats.compiled_executables += u64(selected.len)
	if !compiled.stats.cache_hit { cache.stats.compiler_invocations++ }
	cache.stats.compile_ms += compiled.stats.compile_ms
	cache.stats.load_ms += compiled.stats.load_ms
	for index, key in keys {
		record := NativeCacheRecord{
			key:            key
			abi:            cache.abi
			library:        library
			library_sha256: compiled.stats.library_sha256
			symbol:         index
		}
		path := os.join_path(cache.directory, key + '.json')
		temporary := path + '.' + rand.uuid_v4() + '.tmp'
		os.write_file(temporary, json2.encode(record))!
		os.mv(temporary, path) or {
			os.rm(temporary) or {}
			return err
		}
		cache.entries[key] = compiled.entries[index]
		cache.pending.delete(key)
	}
	for executable in cache.checked {
		if entry := cache.entries[cache.keys[voidptr(executable)]] {
			tier.entries[voidptr(executable)] = entry
		}
	}
	return cache.stats
}
