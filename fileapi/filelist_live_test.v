module fileapi

@[heap]
struct LiveFileListFixture {
mut:
	files []&File
}

fn live_file_list_contents(target voidptr) []&File {
	return unsafe { &LiveFileListFixture(target) }.files
}

fn test_live_file_list_reads_current_native_files_and_serializes_a_snapshot() {
	first := File.create('one'.bytes(), 'one.txt', 'text/plain', 1)
	second := File.create('two'.bytes(), 'two.txt', 'text/plain', 2)
	mut source := &LiveFileListFixture{files: [first]}
	list := FileList.create_live(voidptr(source), live_file_list_contents)
	assert list.length() == 1
	assert voidptr(list.item(0)?) == voidptr(first)
	assert list.item(-1) == none && list.item(1) == none
	saved_files := list.files()
	serialized := list.serialization_steps()
	source.files = [second, first]
	assert list.length() == 2
	assert voidptr(list.item(0)?) == voidptr(second)
	assert voidptr(list.item(1)?) == voidptr(first)
	assert saved_files.len == 1 && voidptr(saved_files[0]) == voidptr(first)
	restored := FileList.deserialization_steps(serialized)
	assert restored.length() == 1
	assert restored.item(0)?.name() == 'one.txt'
	source.files = []
	assert list.length() == 0 && list.item(0) == none
	assert restored.item(0)?.raw_bytes() == 'one'.bytes()
}
