module libjs

import os
import rand

fn test_development_native_cache_identity_tracks_binary_bytes_and_rejects_missing_identity() {
	directory := os.join_path(os.temp_dir(), 'vox-native-identity-' + rand.uuid_v4())
	os.mkdir_all(directory)!
	defer { os.rmdir_all(directory) or {} }
	path := os.join_path(directory, 'executable')
	os.write_file(path, 'first generator and value layout')!
	first := native_cache_binary_abi(path)!
	assert native_cache_binary_abi(path)! == first
	os.write_file(path, 'second generator and value layout')!
	assert native_cache_binary_abi(path)! != first
	os.rm(path)!
	if _ := native_cache_binary_abi(path) {
		assert false, 'An unreadable executable must not share a native cache identity'
	}
}
