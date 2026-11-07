module url

import platform

fn test_url_workspace_preserves_parser_results_after_temporary_storage_reuse() {
	base := basic_parse_in_workspace('https://user:pass@[2001:db8::1]:8443/a/b?old#before', none, none)?
	for input in ['../c?q=hello world#end', '//faß.de:443/a/../b', '?next', '#fragment',
		'https://name:pass@example.test:8443/測試/😀?q=日本語#é', 'http://0x7f.1/',
		'file:///C|/a/../b', 'mailto:user@example.test?a=b c', 'data:text/plain,hello world',
		'http://[2001:db8::2]/', 'http://[not-an-address]/', 'http://example.test:65536/'] {
		expected := basic_parse_in_workspace(input, &base, none)
		actual := basic_parse(input, &base)
		mut reuse := platform.begin_thread_scratch('reuse URL parser workspace')
		_ = []u8{len: 64 * 1024, init: 0xa5}
		reuse.finish()
		if reference := expected {
			owned := actual or { panic('lost parsed URL') }
			assert owned.serialize(false) == reference.serialize(false)
			assert owned.scheme == reference.scheme
			assert owned.username == reference.username
			assert owned.password == reference.password
			assert owned.paths == reference.paths
			assert owned.query == reference.query
			assert owned.fragment == reference.fragment
		} else {
			assert actual == none
		}
	}
}

fn test_url_parser_retains_components_without_growing_input_workspaces() {
	source := 'https://memory.test/' + 'a'.repeat(2048) + '?q=' + 'x'.repeat(512) + '#fragment'
	before := platform.thread_arena_usage().used
	record := parse(source)?
	after := platform.thread_arena_usage().used
	$if prealloc {
		assert after - before < source.len + 4096
	}
	assert record.serialize(false) == source
	assert record.paths[0] == 'a'.repeat(2048)
}

fn test_url_owned_snapshot_detaches_blob_bytes_and_origin() {
	for opaque in [false, true] {
		mut storage := platform.new_arena('URL base owner')
		entry := storage.enter()
		mut base := parse('blob:https://blob.test/identifier')?
		origin := if opaque {
			Origin.opaque([16]u8{}, .file)
		} else {
			Origin.tuple('https'.clone(), Host.from_string('blob.test'.clone()), none, 'domain.test'.clone())
		}
		base.set_blob_url_entry(BlobURLEntry{
			object:      BlobURLBlob{ type_: 'text/'.clone() + 'plain', data: [u8(1), 2, 3] }
			environment: BlobURLEnvironment{ origin: origin }
		})
		storage.leave(entry)
		owned := base.owned_copy()
		storage.release()
		resolved := owned.with_fragment('owned')
		assert resolved.serialize(false) == 'blob:https://blob.test/identifier#owned'
		blob := resolved.blob_url_entry()?
		assert blob.environment.origin.serialize() == if opaque {
			'null'
		} else {
			'https://blob.test'
		}
		if opaque {
			assert blob.environment.origin.is_same_origin(Origin.opaque([16]u8{}, .file))
		}
		object := blob.object
		assert object is BlobURLBlob
		assert object.type_ == 'text/plain'
		assert object.data == [u8(1), 2, 3]
	}
}
