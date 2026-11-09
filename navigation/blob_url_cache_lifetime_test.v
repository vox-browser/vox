module main

import dom
import os
import page
import platform

fn test_cached_page_eviction_keeps_process_blob_stores_after_frame_retirement() {
	if os.getenv('VOX_UPSTREAM_WPT_URL') != '' { return }
	mut app := &BrowserApp{page_model: page.Page.create(1)!, viewport_width: 800, viewport_height: 600}
	defer { app.dispose_browser_tab() }
	mut documents := []&dom.Document{}
	mut storages := []&platform.RetainedArena{}
	for index in 0 .. 12 {
		loaded := LoadedPage{url: 'https://cache-blob-lifetime.test/${index}', markup: '<!doctype html><p>page ${index}</p>', content_type: 'text/html'}
		mut frame := platform.begin_thread_scratch('Blob URL cache eviction frame')
		app.install_loaded_page(loaded, true)
		frame.finish()
		documents << app.document
		// Keep the persistent arena identity for inspection after the session
		// drops the document's own storage lease; this is not a new lease.
		storages << app.document.native_storage()
		assert app.back_forward_cache.pages.len <= back_forward_cache_capacity
		if index > back_forward_cache_capacity {
			retired := documents[index-back_forward_cache_capacity-1]
			assert retired.has_been_destroyed()
			assert retired.native_storage() == unsafe { nil }
			$if prealloc {
				storage := storages[index-back_forward_cache_capacity-1]
				assert storage != unsafe { nil }
				assert storage.arena.usage().used == 0
			}
		}
	}
	assert app.history.len == 12
}
