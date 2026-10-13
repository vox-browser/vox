module entriesapi

import libjs

fn test_file_system_entry_native_name_retains_raw_units_and_owned_snapshot() {
	mut units := [u16(`n`), 0xd800, 0, 0xdc00, 0x6587, 0xd83d, 0xde00, 0xdfff]
	name := libjs.utf16_string_from_code_units(units)
	entry := FileSystemEntry.create_utf16(.file, name)
	units[0] = u16(`x`)
	mut returned := entry.name_utf16().code_units()
	returned[0] = u16(`y`)
	assert entry.is_file() && !entry.is_directory()
	assert entry.name_utf16().code_units() == name.code_units()
	assert entry.name() == name.str()
	assert FileSystemEntry.create_utf16(.directory, name).is_directory()
}

fn test_file_system_entry_compatibility_name_keeps_bytes_and_exposes_source_units() {
	raw := libjs.utf16_string_from_code_units([u16(0xdc00), 0, 0xd800]).str()
	entry := FileSystemEntry.create(.file, raw)
	assert entry.name() == raw
	assert entry.name_utf16().code_units() == [u16(0xdc00), 0, 0xd800]
	assert FileSystemEntry.create_utf16(.file, libjs.utf16_string('')).name_utf16().code_units().len == 0
	// The compatibility producer does not reinterpret its input byte string.
	bytes := [u8(0xc0), 0x80, 0xff]
	assert FileSystemEntry.create(.file, bytes.bytestr()).name().bytes() == bytes
}
