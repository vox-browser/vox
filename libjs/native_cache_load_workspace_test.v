module libjs

import dl
import json2
import os
import platform
import rand

fn test_native_cache_lookup_reclaims_record_and_library_hash_work() {
	directory := os.join_path(os.temp_dir(), 'vox-native-load-workspace-' + rand.uuid_v4())
	os.mkdir_all(directory)!
	defer { os.rmdir_all(directory) or {} }
	mut instructions := []Instruction{}
	for _ in 0 .. 2048 { instructions << Instruction{ op: .nop } }
	instructions << Instruction{ op: .end, lhs: Operand.constant(0) }
	executable := &Executable{
		registers_and_locals_count: 5
		constants:                  [Value.from_i32(42)]
		instructions:               instructions
		bytecode_length:            u32(instructions.len)
	}
	executable.validate(0)!
	compiled := native_compile_library([executable], directory, '/usr/bin/clang')!
	dl.close(compiled.handle)
	key := '0'.repeat(64)
	abi := 'a'.repeat(64)
	record := NativeCacheRecord{
		key:            key
		abi:            abi
		library:        os.file_name(compiled.stats.library)
		library_sha256: compiled.stats.library_sha256
		symbol:         0
	}
	os.write_file(os.join_path(directory, key + '.json'), json2.encode(record))!
	before := platform.thread_arena_usage().used
	for _ in 0 .. 32 {
		mut cache := NativeCodeCache{ directory: directory, abi: abi, compiler: '/usr/bin/false' }
		first := cache.load(key)!
		scratch := platform.begin_thread_scratch('native lookup owner lifetime')
		_ := []u8{len: 1024 * 1024, init: 0xa5}
		scratch.finish()
		assert voidptr(cache.load(key)!) == voidptr(first)
		assert cache.libraries.len == 1
		library := cache.libraries[record.library] or { panic('missing loaded library') }
		assert library.digest == record.library_sha256
		dl.close(library.handle)
	}
	$if prealloc {
		growth := platform.thread_arena_usage().used - before
		assert growth < 512 * 1024, 'native lookup retained ${growth} bytes'
	}
	// A library that cannot provide the requested entry must not be retained.
	os.write_file(os.join_path(directory, key + '.json'), json2.encode(NativeCacheRecord{ ...record, symbol: 99 }))!
	mut invalid := NativeCodeCache{ directory: directory, abi: abi, compiler: '/usr/bin/false' }
	if _ := invalid.load(key) {
		assert false, 'Expected missing native symbol'
	} else {
		scratch := platform.begin_thread_scratch('native lookup error lifetime')
		_ := []u8{len: 1024 * 1024, init: 0xa5}
		scratch.finish()
		assert err.msg() != ''
	}
	assert invalid.libraries.len == 0
}
