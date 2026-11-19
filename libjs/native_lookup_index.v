module libjs

import dl
import os
import platform
import strings
import time

// A persisted lookup from an executable's source-bound identity to the cache
// record that a previous visit of the same browser build resolved for it.
//
// Resolving a record otherwise derives its key for every executable (in the
// generated-code mode, by emitting the executable's complete C source), reads
// and decodes one JSON record per executable and hashes each mapped library.
// The index is read once per VM. Entries are learned only from records the
// ordinary path loaded and verified; an entry that cannot be opened is dropped
// and that executable takes the ordinary path. The lookup key binds the
// browser executable's file identity, so a different build never reuses
// another build's bytecode-to-record mapping.
//
// A library verified by digest records its file identity (device, inode, size
// and nanosecond modification/status-change times). A later process maps it
// without rehashing only while that identity is unchanged and the record names
// the same digest; any change rehashes it before mapping.
const native_lookup_index_name = 'native-lookup-index-v1.txt'
const native_lookup_index_header = 'vox-libjs-native-lookup-v1'
const native_lookup_index_limit = 262144

@[heap]
struct NativeLookupIndex {
	path  string
	build string
mut:
	records        map[string]NativeLookupRecord
	libraries      map[string]NativeLookupLibrary
	source_digests map[voidptr]string
	dirty          bool
	stats          NativeLookupStats
}

struct NativeLookupRecord {
	key     string
	library string
	digest  string
	symbol  int
}

struct NativeLookupLibrary {
	digest   string
	identity string
}

pub struct NativeLookupStats {
pub mut:
	loaded_records      u64
	hits                u64
	misses              u64
	learned             u64
	dropped             u64
	identity_libraries  u64
	rehashed_libraries  u64
	persisted_records   u64
	last_error          string
}

$if test {
	__global native_lookup_index_disabled bool
	__global native_lookup_index_readonly_for_test bool
	pub fn set_native_lookup_index_for_testing(enabled bool) { native_lookup_index_disabled = !enabled }
	pub fn set_native_lookup_index_readonly_for_testing(readonly bool) { native_lookup_index_readonly_for_test = readonly }
}

// Same-binary control for measurements: VOX_LIBJS_NATIVE_LOOKUP_INDEX=0 uses
// only the ordinary record path and neither reads nor writes the index.
// =readonly uses a frozen index without learning or rewriting it, for timed
// visits that verify their cache inputs are unchanged.
const native_lookup_index_env_disabled = os.getenv('VOX_LIBJS_NATIVE_LOOKUP_INDEX') == '0'
const native_lookup_index_env_readonly = os.getenv('VOX_LIBJS_NATIVE_LOOKUP_INDEX') == 'readonly'

fn native_lookup_index_learns() bool {
	$if test { if native_lookup_index_readonly_for_test { return false } }
	return !native_lookup_index_env_readonly
}

fn use_native_lookup_index() bool {
	$if test { if native_lookup_index_disabled { return false } }
	return !native_lookup_index_env_disabled
}

#include "@VMODROOT/libjs/native_lookup_identity.h"

fn C.vox_libjs_native_file_identity(path &char, out &u64) int

// File identity for the verified-digest shortcut; '' when unavailable, which
// always rehashes. Windows has no implementation and always rehashes.
fn native_lookup_file_identity(path string) string {
	$if windows {
		return ''
	} $else {
		mut fields := [7]u64{}
		if C.vox_libjs_native_file_identity(&char(path.str), &fields[0]) != 0 { return '' }
		return '${fields[0]}:${fields[1]}:${fields[2]}:${fields[3]}.${fields[4]}:${fields[5]}.${fields[6]}'
	}
}

fn native_lookup_build_identity() string {
	executable := os.executable()
	identity := native_lookup_file_identity(executable)
	if identity == '' { return '' }
	return native_cache_digest_string('${executable}\n${identity}')
}

// Callers hold the persistent arena: the index lives as long as the VM, which
// is created there, whatever arena the first executing entry happens to hold.
fn (mut vm VM) native_lookup_index_for(cache &NativeCodeCache) ?&NativeLookupIndex {
	if !use_native_lookup_index() { return none }
	if index := vm.native_lookup_index {
		return index
	}
	build := native_lookup_build_identity()
	if build == '' { return none }
	mut index := &NativeLookupIndex{
		path:  os.join_path(cache.directory, native_lookup_index_name)
		build: build
	}
	index.read(cache.abi)
	vm.native_lookup_index = index
	return index
}

// Read and split the file in a temporary workspace; retain only owned copies.
fn (mut index NativeLookupIndex) read(abi string) {
	$if prealloc {
		scope := unsafe { prealloc_scope_begin() }
		defer { unsafe { prealloc_scope_free_after(scope) } }
		rows := native_lookup_index_rows(index.path)
		unsafe { prealloc_scope_leave(scope) }
		index.retain_rows(rows, abi)
		return
	}
	index.retain_rows(native_lookup_index_rows(index.path), abi)
}

fn native_lookup_index_rows(path string) [][]string {
	text := os.read_file(path) or { return [][]string{} }
	return text.split_into_lines().map(it.split(' '))
}

fn (mut index NativeLookupIndex) retain_rows(rows [][]string, abi string) {
	if rows.len == 0 { return }
	header := rows[0]
	// Library identities describe files in this ABI directory and remain valid
	// for another build. Executable mappings belong to the recorded build only.
	same_build := header.len == 3 && header[0] == native_lookup_index_header
		&& header[1] == index.build && header[2] == abi
	for fields in rows[1..] {
		if fields.len == 4 && fields[0] == 'L' {
			if native_lookup_library_name(fields[1]) && valid_native_digest(fields[2]) {
				index.libraries[fields[1].clone()] = NativeLookupLibrary{digest: fields[2].clone(), identity: fields[3].clone()}
			}
		} else if same_build && fields.len == 6 && fields[0] == 'E' {
			symbol := fields[5].int()
			if valid_native_digest(fields[1]) && valid_native_digest(fields[2])
				&& native_lookup_library_name(fields[3]) && valid_native_digest(fields[4])
				&& symbol >= 0 && symbol <= 1000000 && fields[5] == symbol.str() {
				index.records[fields[1].clone()] = NativeLookupRecord{
					key: fields[2].clone()
					library: fields[3].clone()
					digest: fields[4].clone()
					symbol: symbol
				}
			}
		}
	}
	index.stats.loaded_records = u64(index.records.len)
	if !same_build && index.libraries.len > 0 { index.dirty = true }
}

fn native_lookup_library_name(name string) bool {
	return name.ends_with(dl.dl_ext) && valid_native_digest(name.all_before_last(dl.dl_ext))
}

@[direct_array_access]
fn native_lookup_put_u32(mut bytes []u8, value u32) {
	bytes << u8(value)
	bytes << u8(value >> 8)
	bytes << u8(value >> 16)
	bytes << u8(value >> 24)
}

// The source digest, filename and function role identify the executable within
// this build; the bytecode encoding and frame layout are included as well, so a
// nondeterministic compilation can only miss. The per-source digest is retained;
// the encoding is temporary workspace.
fn (mut index NativeLookupIndex) key(cache &NativeCodeCache, executable &Executable) string {
	parsed := executable.parsed_source
	if parsed == unsafe { nil } || executable.native_cache_scope == '' { return '' }
	source := index.source_digests[voidptr(parsed)] or {
		digest := native_cache_digest_string(parsed.source_text)
		index.source_digests[voidptr(parsed)] = digest
		digest
	}
	prefix := '${native_lookup_index_header}:${index.build}:${cache.abi}:${cache.generated_code_identity}:${source}:'
	$if prealloc {
		scope := unsafe { prealloc_scope_begin() }
		defer { unsafe { prealloc_scope_free_after(scope) } }
		key := native_lookup_key_in_workspace(prefix, executable)
		unsafe { prealloc_scope_leave(scope) }
		return key.clone()
	}
	return native_lookup_key_in_workspace(prefix, executable)
}

fn native_lookup_key_in_workspace(prefix string, executable &Executable) string {
	mut bytes := []u8{cap: 32 + executable.instructions.len * 44}
	for value in [executable.registers_and_locals_count, executable.local_index_base,
		u32(executable.constants.len), u32(executable.local_variable_names.len),
		u32(executable.identifier_table.len), executable.bytecode_length, u32(executable.instructions.len)] {
		native_lookup_put_u32(mut bytes, value)
	}
	for instruction in executable.instructions {
		for value in [u32(instruction.op), instruction.dst.raw, instruction.lhs.raw,
			instruction.rhs.raw, instruction.src.raw, instruction.identifier, instruction.target,
			u32(instruction.strict), u32(instruction.annex_b), u32(instruction.arguments.len)] {
			native_lookup_put_u32(mut bytes, value)
		}
		for argument in instruction.arguments { native_lookup_put_u32(mut bytes, argument.raw) }
	}
	filename := if code := executable.source_code {
		code.filename.str().all_before('#vox-libjs-inline-')
	} else {
		''
	}
	mut builder := strings.new_builder(bytes.len + prefix.len + executable.native_cache_scope.len + 96)
	builder.write_string(prefix)
	builder.write_string(native_cache_digest_string(filename))
	builder.write_string(':${executable.native_cache_scope}:')
	builder.write(bytes) or {}
	return native_cache_digest_string(builder.str())
}

// Open a learned record. A failure drops it; the caller then uses the
// ordinary path, which verifies and (when valid) relearns the record.
fn (mut index NativeLookupIndex) open(mut cache NativeCodeCache, record NativeLookupRecord) !NativeEntry {
	mut handle := unsafe { nil }
	if loaded := cache.libraries[record.library] {
		if loaded.digest != record.digest { return error('Native lookup library identity changed') }
		handle = loaded.handle
	} else {
		path := os.join_path(cache.directory, record.library)
		identity := native_lookup_file_identity(path)
		known := index.libraries[record.library] or { NativeLookupLibrary{} }
		if identity == '' || known.digest != record.digest || known.identity != identity {
			if native_library_digest(path)! != record.digest {
				return error('Native lookup library digest mismatch')
			}
			index.stats.rehashed_libraries++
			if identity != '' {
				index.libraries[record.library] = NativeLookupLibrary{digest: record.digest, identity: identity}
				index.dirty = true
			}
		} else {
			index.stats.identity_libraries++
		}
		handle = dl.open_opt(path, dl.rtld_now | dl.rtld_local)!
		cache.libraries[record.library] = NativeCachedLibrary{ handle: handle, digest: record.digest }
	}
	symbol := dl.sym_opt(handle, 'vox_native_${record.symbol}')!
	return unsafe { NativeEntry(symbol) }
}

enum NativeLookupOutcome {
	skipped // resolved earlier, or no index: the ordinary path applies
	missed  // consulted and absent: the ordinary path applies, then learn it
	hit     // installed in the tier from the index
}

// Consult the index for an executable that has never been resolved in this
// cache. The caller has already missed the tier's entry-cache slot.
fn (mut vm VM) native_lookup_entry(mut tier NativeTier, mut cache NativeCodeCache, executable &Executable) NativeLookupOutcome {
	address := voidptr(executable)
	if address in cache.keys { return .skipped }
	if !tier.enabled { return .skipped }
	if _ := tier.entries[address] { return .skipped }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut index := vm.native_lookup_index_for(cache) or { return .skipped }
	key := index.key(cache, executable)
	if key == '' { return .skipped }
	record := index.records[key] or {
		index.stats.misses++
		return .missed
	}
	started := time.sys_mono_now()
	entry := index.open(mut cache, record) or {
		index.records.delete(key)
		index.dirty = true
		index.stats.dropped++
		index.stats.last_error = err.msg()
		return .missed
	}
	cache.stats.load_ms += f64(time.sys_mono_now() - started) / 1e6
	// Like the record path, count each record once, not each executable that
	// shares its generated code.
	if record.key !in cache.entries { cache.stats.cache_hits++ }
	// Keep the executable and its ParsedSource alive while their addresses are
	// used as keys, exactly as the ordinary record path does.
	cache.checked << executable
	cache.keys[address] = record.key
	cache.entries[record.key] = entry
	tier.set_native_entry(executable, entry)
	index.stats.hits++
	return .hit
}

// After the ordinary path resolved a stored record for this executable, learn
// it. Pending (not yet compiled) and failed lookups are not learned.
fn (mut vm VM) learn_native_lookup_entry(tier &NativeTier, executable &Executable) {
	if !native_lookup_index_learns() { return }
	cache := tier.persistent or { return }
	mut index := vm.native_lookup_index or { return }
	key := cache.keys[voidptr(executable)] or { return }
	if key !in cache.entries { return }
	if index.records.len >= native_lookup_index_limit { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	lookup := index.key(cache, executable)
	if lookup == '' || lookup in index.records { return }
	stored := native_lookup_stored_record(os.join_path(cache.directory, key + '.json')) or { return }
	if stored.key != key || stored.abi != cache.abi || !native_lookup_library_name(stored.library)
		|| !valid_native_digest(stored.library_sha256) || stored.symbol < 0 || stored.symbol > 1000000 {
		return
	}
	loaded := cache.libraries[stored.library] or { return }
	if loaded.digest != stored.library_sha256 { return }
	if stored.library !in index.libraries {
		identity := native_lookup_file_identity(os.join_path(cache.directory, stored.library))
		if identity != '' {
			index.libraries[stored.library] = NativeLookupLibrary{digest: stored.library_sha256, identity: identity}
		}
	}
	index.records[lookup] = NativeLookupRecord{
		key: key
		library: stored.library
		digest: stored.library_sha256
		symbol: stored.symbol
	}
	index.dirty = true
	index.stats.learned++
}

// Decode a record in a temporary workspace and return owned fields.
fn native_lookup_stored_record(path string) ?NativeCacheRecord {
	$if prealloc {
		scope := unsafe { prealloc_scope_begin() }
		defer { unsafe { prealloc_scope_free_after(scope) } }
		record := native_lookup_decode_record(path) or {
			unsafe { prealloc_scope_leave(scope) }
			return none
		}
		unsafe { prealloc_scope_leave(scope) }
		return NativeCacheRecord{
			key: record.key.clone()
			abi: record.abi.clone()
			library: record.library.clone()
			library_sha256: record.library_sha256.clone()
			symbol: record.symbol
		}
	}
	return native_lookup_decode_record(path)
}

fn native_lookup_decode_record(path string) ?NativeCacheRecord {
	text := os.read_file(path) or { return none }
	if text.len > 16384 { return none }
	return decode_native_cache_record(text) or { return none }
}

pub fn (vm &VM) native_lookup_stats() NativeLookupStats {
	if index := vm.native_lookup_index { return index.stats }
	return NativeLookupStats{}
}

// Write learned mappings atomically. Idle callers persist at checkpoints and
// shutdown; an unchanged index is never rewritten.
pub fn (mut vm VM) persist_native_lookup_index() ! {
	mut index := vm.native_lookup_index or { return }
	if !index.dirty || !native_lookup_index_learns() { return }
	mut tier := vm.native_tier or { return }
	cache := tier.persistent or { return }
	$if prealloc {
		scope := unsafe { prealloc_scope_begin() }
		defer { unsafe { prealloc_scope_free_after(scope) } }
		index.write(cache.abi) or {
			unsafe { prealloc_scope_leave(scope) }
			return error_with_code(err.msg().clone(), err.code())
		}
		unsafe { prealloc_scope_leave(scope) }
	} $else {
		index.write(cache.abi)!
	}
	index.dirty = false
	index.stats.persisted_records = u64(index.records.len)
}

fn (index &NativeLookupIndex) write(abi string) ! {
	mut output := strings.new_builder(128 + index.records.len * 280)
	output.writeln('${native_lookup_index_header} ${index.build} ${abi}')
	for name in index.libraries.keys().sorted() {
		library := index.libraries[name] or { continue }
		if library.identity == '' || library.identity.contains(' ') { continue }
		output.writeln('L ${name} ${library.digest} ${library.identity}')
	}
	for lookup in index.records.keys().sorted() {
		record := index.records[lookup] or { continue }
		output.writeln('E ${lookup} ${record.key} ${record.library} ${record.digest} ${record.symbol}')
	}
	temporary := '${index.path}.${os.getpid()}.${time.sys_mono_now()}.tmp'
	os.write_file(temporary, output.str())!
	os.mv(temporary, index.path) or {
		os.rm(temporary) or {}
		return err
	}
}
