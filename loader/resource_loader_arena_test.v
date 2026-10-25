@[has_globals]
module loader

import dom
import http
import platform

fn arena_request() &LoadRequest {
	mut request := LoadRequest.create(http.HeaderList.create())
	request.set_url(dom.URL{ value: 'https://arena.test/sprite.svg' })
	return request
}

fn clobber_retired_loader_arena(mut arena platform.Arena) {
	entry := arena.enter()
	// Small chunks overwrite the original 256 KiB scope blocks as well as
	// later blocks; one large allocation could skip the stale map backing.
	for _ in 0 .. 64 {
		junk := []u8{len: 16 * 1024, init: 0xa5}
		assert junk[0] == 0xa5 && junk[junk.len - 1] == 0xa5
	}
	arena.leave(entry)
}

fn test_shared_loader_created_during_paint_outlives_its_arena() {
	mut arena := platform.new_arena('lazy shared loader')
	defer { arena.release() }
	entry := arena.enter()
	mut resource_loader := ResourceLoader.create()
	arena.leave(entry)
	$if prealloc {
		assert !arena.contains(voidptr(resource_loader))
	}
	arena.reset()
	clobber_retired_loader_arena(mut arena)
	resource_loader.register_network_response('https://arena.test/sprite.svg', NetworkResponse{
		data: '<svg/>'.bytes()
	})
	mut request := arena_request()
	assert resource_loader.load(mut request).success
}

fn test_network_request_tracking_survives_paint_arena_retirement() {
	mut resource_loader := ResourceLoader.create()
	resource_loader.register_network_response('https://arena.test/sprite.svg', NetworkResponse{
		data: '<svg xmlns="http://www.w3.org/2000/svg"/>'.bytes()
	})
	mut arena := platform.new_arena('resource-loader paint request')
	defer { arena.release() }
	for _ in 0 .. 3 {
		entry := arena.enter()
		probe := []u8{len: 64, init: 7}
		$if prealloc {
			assert arena.contains(probe.data)
		}
		// Exercise initial allocation, growth, and deletion bookkeeping while
		// requests overlap, then retire the paint build that started them.
		mut pending := []StartedNetworkRequest{}
		for _ in 0 .. 64 {
			pending << resource_loader.start_network_request(arena_request()) or {
				panic('missing injected SVG response')
			}
		}
		for request in pending {
			resource_loader.finish_network_request(request)
		}
		assert resource_loader.pending_loads() == 0
		arena.leave(entry)
		arena.reset()
		clobber_retired_loader_arena(mut arena)
		// The next frame must reuse the loader's empty map, not the retired
		// arena's storage, even though the preceding requests all finished.
		mut request := arena_request()
		assert resource_loader.load(mut request).success
		assert resource_loader.pending_loads() == 0
	}
}

fn test_injected_svg_response_owns_bytes_after_registration_arena_retires() {
	mut resource_loader := ResourceLoader.create()
	mut arena := platform.new_arena('completed SVG publication')
	defer { arena.release() }
	entry := arena.enter()
	for i in 0 .. 32 {
		resource_loader.register_network_response('https://arena.test/${i}.svg', NetworkResponse{
			data:          '<svg id="sprite-${i}"/>'.bytes()
			headers:       [http.Header{'Content-Type'.clone(), 'image/svg+xml; marker=${i}'}]
			reason_phrase: 'Loaded ${i}'
		})
	}
	resource_loader.register_network_response('https://arena.test/failed.svg', NetworkResponse{
		error_message: 'Missing sprite ${32}'
	})
	arena.leave(entry)
	arena.reset()
	clobber_retired_loader_arena(mut arena)
	for i in 0 .. 32 {
		mut request := LoadRequest.create(http.HeaderList.create())
		request.set_url(dom.URL{ value: 'https://arena.test/${i}.svg' })
		result := resource_loader.load(mut request)
		assert result.success
		assert result.data.bytestr() == '<svg id="sprite-${i}"/>'
		assert result.headers[0].name == 'Content-Type'
		assert result.headers[0].value == 'image/svg+xml; marker=${i}'
		assert (result.reason_phrase or { panic('missing reason phrase') }) == 'Loaded ${i}'
	}
	mut failed := LoadRequest.create(http.HeaderList.create())
	failed.set_url(dom.URL{ value: 'https://arena.test/failed.svg' })
	result := resource_loader.load(mut failed)
	assert !result.success
	assert (result.error_message or { panic('missing failure message') }) == 'Request finished with error: Missing sprite 32'
}
