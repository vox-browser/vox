module fileapi

fn make_file(name string) &File {
	return File.create(name.bytes(), name, 'text/plain', i64(0))
}

fn test_empty_list() {
	list := FileList.create()
	assert list.length() == 0
	assert list.item(0) == none
}

fn test_add_and_length() {
	mut list := FileList.create()
	list.add_file(make_file('a.txt'))
	list.add_file(make_file('b.txt'))
	assert list.length() == 2
}

fn test_item_access_in_order() {
	mut list := FileList.create()
	list.add_file(make_file('a.txt'))
	list.add_file(make_file('b.txt'))
	first := list.item(0) or { panic('missing item 0') }
	second := list.item(1) or { panic('missing item 1') }
	assert first.name() == 'a.txt'
	assert second.name() == 'b.txt'
}

fn test_item_out_of_range() {
	mut list := FileList.create()
	list.add_file(make_file('a.txt'))
	// Past the end, and negative indices, return none rather than clamping.
	assert list.item(1) == none
	assert list.item(-1) == none
	assert list.item(100) == none
}

fn test_item_value_exact_entry_point() {
	mut list := FileList.create()
	file := make_file('value.txt')
	list.add_file(file)
	assert list.item_value(0) or { panic('missing item') } == file
	assert list.item_value(1) == none
}

fn test_item_returns_the_same_file() {
	f := make_file('doc.txt')
	mut list := FileList.create()
	list.add_file(f)
	got := list.item(0) or { panic('missing item 0') }
	// The stored File is returned by reference (same pointer), not a copy.
	assert voidptr(got) == voidptr(f)
	assert got.size() == u64(7)
}

fn test_file_list_structured_serialization_round_trip() {
	mut list := FileList.create()
	list.add_file(make_file('a.txt'))
	list.add_file(make_file('b.txt'))
	restored := FileList.deserialization_steps(list.serialization_steps())
	assert restored.length() == 2
	assert restored.item(0)?.name() == 'a.txt'
	assert restored.item(1)?.name() == 'b.txt'
	assert voidptr(restored.item(0)?) != voidptr(list.item(0)?)
}
