module serviceworker

import dom
import fetch
import http

fn cache_request(url string, method string, headers []http.Header) &fetch.Request {
	mut request := fetch.Request.create()
	request.set_url(dom.dom_url_parse(url, dom.url_about_blank(), 'UTF-8') or {
		panic('invalid test URL')
	})
	request.set_method(method)
	mut list := http.HeaderList.create()
	for header in headers {
		list.append(header)
	}
	request.set_header_list(list)
	return request
}

fn cache_response(status u16, body string, headers []http.Header) &fetch.Response {
	mut response := fetch.Response.create()
	response.set_status(status)
	response.set_body_bytes(body.bytes())
	mut list := http.HeaderList.create()
	for header in headers {
		list.append(header)
	}
	response.set_header_list(list)
	return response
}

fn cache_fetch_success(request &fetch.Request) !&fetch.Response {
	return cache_response(200, request.url().serialize(), [])
}

fn test_cache_storage_preserves_order_and_open_objects_share_entries() {
	mut storage := CacheStorage{}
	first_open := storage.open('first')
	mut first := first_open.cache or { panic('missing cache') }
	second_open := storage.open('second')
	_ = second_open.cache or { panic('missing cache') }
	reopened := storage.open('first').cache or { panic('missing cache') }
	assert voidptr(first) != voidptr(reopened)
	assert storage.keys().keys == ['first', 'second']
	assert storage.has('first').value or { false }

	request := cache_request('https://example.test/item', 'GET', [])
	response := cache_response(201, 'stored', [])
	assert first.put(request, response).state == .fulfilled
	matched := reopened.match_(request, CacheQueryOptions{}).response or { panic('missing response') }
	assert matched.fetch_response_status() == 201
	assert matched.fetch_response_body_bytes() or { []u8{} } == 'stored'.bytes()

	assert storage.delete_('first').value or { false }
	assert !(storage.has('first').value or { true })
	// Existing Cache objects remain functional after their name is removed.
	assert (reopened.match_(request, CacheQueryOptions{}).response or { panic('doomed cache lost data') }).fetch_response_status() == 201
}

fn test_cache_query_options_clone_results_and_replace_existing_entry() {
	mut storage := CacheStorage{}
	mut cache := storage.open('v1').cache or { panic('missing cache') }
	cached_request := cache_request('https://example.test/item?q=one#old', 'GET', [
		http.Header{name: 'Cookie', value: 'a=1'},
	])
	mut original_response := cache_response(200, 'first', [
		http.Header{name: 'Vary', value: 'Cookie'},
	])
	assert cache.put(cached_request, original_response).state == .fulfilled
	original_response.set_status(418)

	query := cache_request('https://example.test/item?q=one#new', 'GET', [
		http.Header{name: 'Cookie', value: 'a=1'},
	])
	mut first_match := cache.match_(query, CacheQueryOptions{}).response or { panic('missing match') }
	assert first_match.fetch_response_status() == 200
	first_match.set_status(202)
	assert (cache.match_(query, CacheQueryOptions{}).response or { panic('stored response was mutated') }).fetch_response_status() == 200

	wrong_query := cache_request('https://example.test/item?q=two', 'GET', [
		http.Header{name: 'Cookie', value: 'a=2'},
	])
	assert cache.match_(wrong_query, CacheQueryOptions{}).response == none
	assert cache.match_(wrong_query, CacheQueryOptions{ignore_search: true, ignore_vary: true}).response != none

	replacement := cache_response(204, '', [])
	assert cache.put(query, replacement).state == .fulfilled
	assert cache.keys(none, CacheQueryOptions{}).requests.len == 1
	assert (cache.match_(query, CacheQueryOptions{}).response or { panic('replacement missing') }).fetch_response_status() == 204
}

fn test_cache_put_delete_and_batch_validation_are_atomic() {
	mut storage := CacheStorage{}
	cache := storage.open('v1').cache or { panic('missing cache') }
	http_request := cache_request('http://example.test/a', 'GET', [])
	assert cache.put(http_request, cache_response(200, 'a', [])).state == .fulfilled
	assert cache.put(cache_request('data:text/plain,x', 'GET', []), cache_response(200, '', [])).state == .rejected
	assert cache.put(cache_request('https://example.test/post', 'POST', []), cache_response(200, '', [])).state == .rejected
	assert cache.put(cache_request('https://example.test/range', 'GET', []), cache_response(206, '', [])).state == .rejected
	assert cache.put(cache_request('https://example.test/vary', 'GET', []), cache_response(200, '', [
		http.Header{name: 'Vary', value: '*'},
	])).state == .rejected

	duplicate := cache_request('https://example.test/duplicate', 'GET', [])
	batch := [
		&CacheBatchOperation{operation_type: .put, request: duplicate, response: cache_response(200, 'one', [])},
		&CacheBatchOperation{operation_type: .put, request: duplicate.clone(), response: cache_response(200, 'two', [])},
	]
	mut batch_rejected := false
	cache.batch_cache_operations(batch) or {
		batch_rejected = true
		assert err.msg().contains('unique')
		assert cache.keys(none, CacheQueryOptions{}).requests.len == 1
		assert cache.match_(http_request, CacheQueryOptions{}).response != none
	}
	assert batch_rejected

	deleted := cache.delete_(http_request, CacheQueryOptions{})
	assert deleted.state == .fulfilled
	assert deleted.bool_value or { false }
	assert !(cache.delete_(http_request, CacheQueryOptions{}).bool_value or { true })
}

fn test_cache_add_all_uses_fetch_host_and_commits_as_one_batch() {
	mut storage := CacheStorage{}
	mut cache := storage.open('v1').cache or { panic('missing cache') }
	cache.set_fetch_hook(cache_fetch_success)
	requests := [
		cache_request('https://example.test/a', 'GET', []),
		cache_request('https://example.test/b', 'GET', []),
	]
	assert cache.add_all(requests).state == .fulfilled
	assert cache.keys(none, CacheQueryOptions{}).requests.len == 2
	assert (cache.match_(requests[1], CacheQueryOptions{}).response or { panic('missing fetched response') }).fetch_response_body_bytes() or {
		[]u8{}
	} == 'https://example.test/b'.bytes()
	assert cache.add(cache_request('https://example.test/not-get', 'POST', [])).state == .rejected
}

fn test_cache_storage_match_obeys_cache_name_and_insertion_order() {
	mut storage := CacheStorage{}
	mut first := storage.open('first').cache or { panic('missing cache') }
	mut second := storage.open('second').cache or { panic('missing cache') }
	request := cache_request('https://example.test/shared', 'GET', [])
	first.put(request, cache_response(201, '', []))
	second.put(request, cache_response(202, '', []))
	assert (storage.match_(request, MultiCacheQueryOptions{}).response or { panic('missing response') }).fetch_response_status() == 201
	assert (storage.match_(request, MultiCacheQueryOptions{cache_name: 'second'}).response or { panic('missing named response') }).fetch_response_status() == 202
	assert storage.match_(request, MultiCacheQueryOptions{cache_name: 'absent'}).response == none
}
