module streams

// A pending-read list removes the request it was given, not the first
// request with the same contents.
fn test_read_promise_list_removes_the_given_request() {
	mut first := &ReadPromise{}
	mut second := &ReadPromise{}
	mut list := ReadPromiseList{}
	list.append(first)
	list.append(second)
	assert list.remove(second)
	assert list.len == 1
	remaining := list.shift() or { panic(err) }
	assert remaining.read_request_identity() == voidptr(first)
	assert !list.remove(second)
}
