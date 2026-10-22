module platform

import os
import v.embed_file

const embedded_text_startup_source = embedded_text($embed_file('../css/ua_default.css'))

fn test_embedded_text_initializes_constants_and_survives_collection() {
	expected := $embed_file('../css/ua_default.css').to_string()
	gc_collect()
	assert embedded_text_startup_source == expected
	assert embedded_text_startup_source.len > 90_000
}

fn test_embedded_text_returns_only_owned_text_to_the_calling_arena() {
	source := $embed_file('../css/ua_default.css')
	expected := $embed_file('../css/ua_default.css').to_string()
	// Warm native workspace bookkeeping before measuring the caller's arena.
	assert embedded_text(source) == expected
	mut owner := new_arena('embedded text output')
	entry := owner.enter()
	before := owner.usage().used
	text := embedded_text(source)
	growth := owner.usage().used - before
	$if prealloc {
		assert owner.contains(voidptr(text.str))
		assert growth >= u64(text.len)
		assert growth < u64(text.len + 4096)
	}
	gc_collect()
	assert text == expected
	owner.leave(entry)
	owner.release()
}

fn test_embedded_text_keeps_binary_bytes_and_uses_the_loaded_length() {
	resource := 'vox-embedded-text-${os.getpid()}.dat'
	path := os.join_path(os.dir(os.executable()), resource)
	defer { os.rm(path) or {} }
	// Deliberately stale length: the development loader must read the length
	// after loading. Reusing the descriptor also detects leaked cache mutation.
	source := embed_file.EmbedFileData{ path: resource, len: 1 }
	for bytes in [[u8(0), 0xce, 0xbb, 0, 0xf0, 0x9f, 0x8c, 0x8d], [u8(37)], []u8{}] {
		os.write_file_array(path, bytes) or { panic(err) }
		text := embedded_text(source)
		assert text.len == bytes.len
		assert text.bytes() == bytes
		assert source.len == 1
	}
}
