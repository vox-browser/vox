module fetch

fn test_headers_normalize_combine_set_delete_and_iteration() {
	mut headers := Headers.construct([HeaderPair{ name: 'X-B', value: '  two  ' },
		HeaderPair{ name: 'x-a', value: 'one' }, HeaderPair{ name: 'X-A', value: 'three' }])!
	assert headers.get('x-b')? == 'two'
	assert headers.get('X-A')? == 'one, three'
	headers.set('X-A', ' replaced ')!
	assert headers.get('x-a')? == 'replaced'
	pairs := headers.sorted_and_combined()
	assert pairs[0] == HeaderPair{
		name:  'x-a'
		value: 'replaced'
	}
	assert pairs[1] == HeaderPair{
		name:  'x-b'
		value: 'two'
	}
	mut iterator := HeadersIterator.create(headers, .key_and_value)
	assert iterator.next().name == 'x-a'
	assert iterator.next().name == 'x-b'
	assert iterator.next().done
	headers.delete('x-a')!
	assert !headers.has('x-a')!
}

fn test_headers_guards_and_validation() {
	mut immutable := Headers.construct([])!
	immutable.set_guard(.immutable)
	mut immutable_threw := false
	immutable.append('X', 'y') or { immutable_threw = true }
	assert immutable_threw
	mut request_headers := Headers.construct([])!
	request_headers.set_guard(.request)
	request_headers.append('Cookie', 'a=b')!
	assert !request_headers.has('Cookie')!
	mut response_headers := Headers.construct([])!
	response_headers.set_guard(.response)
	response_headers.append('Set-Cookie', 'a=b')!
	assert !response_headers.has('Set-Cookie')!
	mut invalid_threw := false
	request_headers.append('bad name', 'x') or { invalid_threw = true }
	assert invalid_threw
}

fn test_headers_request_no_cors_and_set_cookie_values() {
	mut headers := Headers.construct([])!
	headers.set_guard(.request_no_cors)
	headers.append('Accept', 'text/plain')!
	headers.append('X-Unsafe', 'x')!
	assert headers.has('Accept')!
	assert !headers.has('X-Unsafe')!
	mut cookies := Headers.construct([])!
	cookies.append('Set-Cookie', 'a=1')!
	cookies.append('set-cookie', 'b=2')!
	assert cookies.get_set_cookie() == ['a=1', 'b=2']
}
