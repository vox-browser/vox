module page

fn test_shared_backing_store_owns_and_consumes_transfer() {
	mut source := [u8(1), 2, 3]
	mut store := SharedBackingStore.create(source)
	source[0] = 9
	assert store.bytes() == [u8(1), 2, 3]
	bytes := store.release()!
	assert bytes == [u8(1), 2, 3]
	assert store.bytes().len == 0
	if _ := store.release() {
		assert false
	} else {
		assert err.msg().contains('already released')
	}
	decoded := decode_shared_backing_store(bytes)
	assert decoded.bytes() == bytes
}
