module fileapi

import platform
import url as liburl

@[heap]
struct BlobStoreLifetimeSettings {
	origin liburl.Origin
}

fn (settings &BlobStoreLifetimeSettings) blob_url_settings_origin() liburl.Origin { return settings.origin }
fn (settings &BlobStoreLifetimeSettings) blob_url_settings_identity() voidptr { return voidptr(settings) }

@[noinline]
fn blob_store_lifetime_string(value string) string { return value.clone() }

fn test_process_blob_url_stores_are_not_owned_by_the_first_document_arena() {
	mut owner := platform.new_retained_arena('first Blob URL store caller')
	mut scope := owner.enter()
	defer { scope.finish(); owner.release() }
	modern := blob_url_store()
	legacy := legacy_blob_url_store()
	$if prealloc {
		assert !owner.arena.contains(modern), 'process Blob URL store belongs to a document arena'
		assert !owner.arena.contains(legacy), 'process legacy Blob URL store belongs to a document arena'
	}
	assert modern.length() == 0
	assert legacy.length() == 0
}

fn test_process_blob_url_store_entries_survive_a_retired_mutation_arena() {
	settings := &BlobStoreLifetimeSettings{origin: liburl.parse('https://blob-store-lifetime.test/')?.origin()}
	blob := Blob.create('durable URL payload'.bytes(), 'text/plain')
	mut modern := blob_url_store()
	mut legacy := legacy_blob_url_store()
	mut urls := []string{}
	mut legacy_urls := []string{}
	for round in 0 .. 3 {
		mut owner := platform.new_retained_arena('Blob URL store mutation')
		mut scope := owner.enter()
		for _ in 0 .. 40 {
			value := modern.add_entry(BlobURLObject.from_blob(blob), settings)!
			old_value := legacy.add_entry(BlobURLObject.from_blob(blob), LegacyBlobURLEnvironment{
				id: blob_store_lifetime_string('persistent-legacy-owner'), origin: blob_store_lifetime_string('https://blob-store-lifetime.test'), storage_key: blob_store_lifetime_string('persistent-partition')
			})!
			$if prealloc { assert !owner.arena.contains(value.str) && !owner.arena.contains(old_value.str) }
			persistent := platform.enter_persistent()
			urls << value
			legacy_urls << old_value
			platform.leave_persistent(persistent)
		}
		scope.finish()
		owner.release()
		assert modern.length() == (round+1)*40
		assert legacy.length() == (round+1)*40
		for value in urls {
			entry := modern.resolve(liburl.parse(value)?) or { panic('lost modern Blob URL entry') }
			assert voidptr(entry.object.blob or { panic('lost modern Blob') }) == voidptr(blob)
		}
		for value in legacy_urls {
			entry := legacy.resolve(value) or { panic('lost legacy Blob URL entry') }
			assert voidptr(entry.object.blob or { panic('lost legacy Blob') }) == voidptr(blob)
			assert entry.environment.id == 'persistent-legacy-owner' && entry.environment.storage_key == 'persistent-partition'
		}
	}
	modern.run_unloading_cleanup_steps(settings)
	legacy.run_unloading_cleanup_steps('persistent-legacy-owner')
	assert modern.length() == 0 && legacy.length() == 0
}
