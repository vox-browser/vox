module html

import dom
import platform

// Web Storage bottles are process-wide and keyed by origin, while pages write
// them with their document's native storage entered. Their contents must not
// live in that arena, and a retired document's Storage leaves the shared hub.
fn test_storage_bottles_and_hub_outlive_the_writing_documents_arena() {
	url := dom.URL{
		value: 'https://storage-lifetime.example/'
	}
	mut first := dom.Document.create(url)
	first.enable_native_storage()
	mut window := WindowModel.create_top_level(first, none, '')!
	mut scope := first.enter_native_storage()
	mut storage := window.local_storage()!
	for index in 0 .. 64 {
		storage.set_item('key-${index}', 'value-${index}')!
	}
	scope.finish()
	bottle := storage.storage_bottle
	hub := window_storage_hub()
	assert hub.storages_.any(voidptr(it) == voidptr(storage))
	$if prealloc {
		arena := first.native_storage().arena
		assert !arena.contains(bottle.keys.data)
		assert !arena.contains(bottle.keys[0].str)
		assert !arena.contains((bottle.entries['key-0'] or { '' }).str)
	}
	first.release_native_storage()
	assert !hub.storages_.any(voidptr(it) == voidptr(storage))
	for _ in 0 .. 4 {
		work := platform.begin_thread_scratch('storage registry overwrite')
		_ = []u8{len: 256 * 1024, init: u8(0xa5)}
		work.finish()
	}
	mut second := dom.Document.create(url)
	mut next_window := WindowModel.create_top_level(second, none, '')!
	mut next := next_window.local_storage()!
	assert voidptr(next.storage_bottle) == voidptr(bottle)
	assert next.get_item('key-63') or { '' } == 'value-63'
	assert next.length() == 64
	next.set_item('after', 'retirement')!
	assert next.key(64) or { '' } == 'after'
}
