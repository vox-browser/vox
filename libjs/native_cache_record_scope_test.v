module libjs

import json2
import platform

fn test_native_cache_record_decoding_does_not_retain_temporary_field_metadata() {
	text := json2.encode(NativeCacheRecord{key: 'k', abi: 'a', library: 'library', library_sha256: 'digest', symbol: 42})
	for _ in 0 .. 32 {
		scratch := platform.begin_thread_scratch('native record metadata lifetime')
		record := decode_native_cache_record(text)!
		assert record.key == 'k' && record.abi == 'a' && record.library == 'library'
		assert record.library_sha256 == 'digest' && record.symbol == 42
		scratch.finish()
		reuse := platform.begin_thread_scratch('overwrite native record metadata')
		_ := []u8{len: 1024 * 1024, init: 0xa5}
		reuse.finish()
	}
}

fn test_native_cache_record_rejects_invalid_types_missing_fields_and_nonintegral_symbols() {
	for invalid in ['{}', '[]', 'null',
		'{"key":1,"abi":"a","library":"l","library_sha256":"d","symbol":0}',
		'{"key":"k","abi":"a","library":"l","library_sha256":"d","symbol":"0"}',
		'{"key":"k","abi":"a","library":"l","library_sha256":"d","symbol":1.5}',
		'{"key":"k","abi":"a","library":"l","library_sha256":"d","symbol":1000001}',
		'{"key":"k","abi":"a","library":"l","library_sha256":"d","symbol":-1}'] {
		if _ := decode_native_cache_record(invalid) { assert false, invalid }
	}
}
