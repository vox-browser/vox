module dom

import platform
import url as liburl

fn test_url_snapshot_serialization_retains_one_owned_result_per_call() {
	source := 'https://serialization-budget.test/' + 'a'.repeat(2048) + '?query#fragment'
	parsed := liburl.parse(source)?
	for value in [URL{ value: source }, url_from_record(parsed)] {
		assert value.serialize() == source
		before := platform.thread_arena_usage().used
		for _ in 0 .. 8 {
			assert value.serialize() == source
		}
		$if prealloc {
			assert platform.thread_arena_usage().used - before < 8 * (source.len + 16) + 1024
		}
	}
}

fn test_url_snapshot_serialized_result_outlives_its_source_arena() {
	mut storage := platform.new_arena('URL snapshot source')
	entry := storage.enter()
	value := url_from_record(liburl.parse('https://owned-snapshot.test/path?query#fragment')?)
	storage.leave(entry)
	serialized := value.serialize()
	storage.release()
	assert serialized == 'https://owned-snapshot.test/path?query#fragment'
}

fn test_url_snapshot_value_edits_cannot_reuse_blob_entry_metadata() {
	mut record := liburl.parse('blob:https://snapshot-blob.test/id')?
	owner := liburl.Origin.create_opaque(.standard)
	record.set_blob_url_entry(liburl.BlobURLEntry{
		object:      liburl.BlobURLBlob{ type_: 'text/plain', data: [u8(1), 2, 3] }
		environment: liburl.BlobURLEnvironment{ origin: owner }
	})
	mut value := url_from_record(record)
	assert value.parsed()?.origin().is_same_origin(owner)
	assert URL{ value: value.value }.parsed()?.blob_url_entry() == none
	mut supplied := value.parsed()?
	supplied.set_blob_url_entry(none)
	assert value.parsed()?.blob_url_entry() != none
	value.value = 'HTTP://replacement-snapshot.test:80/new'
	assert value.serialize() == 'http://replacement-snapshot.test/new'
	assert value.parsed()?.blob_url_entry() == none
	assert value.serialized_host() == 'replacement-snapshot.test'
}

fn test_url_snapshot_read_only_components_do_not_copy_the_parsed_path() {
	value := url_from_record(liburl.parse('https://reader:password@url-read-only.test:8443/' + 'path/'.repeat(40) + '?query')?)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 32 {
		assert !value.has_an_opaque_path()
		assert !value.cannot_have_a_username_or_password_or_port()
		assert value.scheme() == 'https'
		assert value.username() == 'reader'
		assert value.password() == 'password'
		assert value.port()? == 8443
		assert value.query()? == 'query'
	}
	$if prealloc {
		assert platform.thread_arena_usage().used == before
	}
	assert sizeof(URL) <= 64
}
