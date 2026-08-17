module entriesapi

fn test_file_entry_exposes_file_kind_and_name() {
	entry := FileSystemEntry.create(.file, 'photo.jpg')

	assert entry.is_file()
	assert !entry.is_directory()
	assert entry.name() == 'photo.jpg'
}

fn test_directory_entry_exposes_directory_kind_and_name() {
	entry := FileSystemEntry.create(.directory, 'Documents')

	assert !entry.is_file()
	assert entry.is_directory()
	assert entry.name() == 'Documents'
}

fn test_name_preserves_empty_and_unicode_values() {
	empty := FileSystemEntry.create(.file, '')
	unicode := FileSystemEntry.create(.directory, '文件/🦉')

	assert empty.name() == ''
	assert unicode.name() == '文件/🦉'
}

fn test_each_entry_has_exactly_one_kind() {
	for kind in [EntryType.file, .directory] {
		entry := FileSystemEntry.create(kind, 'entry')
		assert entry.is_file() != entry.is_directory()
	}
}
