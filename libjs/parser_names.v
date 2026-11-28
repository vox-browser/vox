module libjs

// Identifier names interned per parse. Every occurrence of a name shares one
// copy of its code units and its UTF-8 key for the scope collector's maps, so
// an identifier no longer copies its name and converts it to UTF-8 again.
// Names are never modified after parsing.
struct InternedName {
	text Utf16String
	key  string
}

struct ParserNames {
mut:
	entries []InternedName
	// Open addressing: entry index + 1, 0 when empty; a power-of-two length.
	slots []u32
}

@[direct_array_access]
fn parser_name_hash(units []u16) u64 {
	mut hash := u64(14695981039346656037)
	for unit in units {
		hash = (hash ^ u64(unit)) * 1099511628211
	}
	return hash
}

// The entry by value: a later intern() may reallocate the entry list.
@[direct_array_access]
fn (mut names ParserNames) intern(units []u16) InternedName {
	if names.slots.len == 0 {
		names.slots = []u32{len: 256}
	}
	mask := u64(names.slots.len - 1)
	mut slot := int(parser_name_hash(units) & mask)
	for {
		entry := names.slots[slot]
		if entry == 0 {
			break
		}
		if utf16_key_units_equal(names.entries[int(entry) - 1].text.data, units) {
			return names.entries[int(entry) - 1]
		}
		slot = int((u64(slot) + 1) & mask)
	}
	names.entries << InternedName{
		text: Utf16String.from_slice(units)
		key:  string_from_utf16_lossy(units)
	}
	index := names.entries.len - 1
	names.slots[slot] = u32(index + 1)
	if names.entries.len * 2 > names.slots.len {
		names.grow()
	}
	return names.entries[index]
}

@[direct_array_access]
fn (mut names ParserNames) grow() {
	mut slots := []u32{len: names.slots.len * 2}
	mask := u64(slots.len - 1)
	for index, entry in names.entries {
		mut slot := int(parser_name_hash(entry.text.data) & mask)
		for slots[slot] != 0 {
			slot = int((u64(slot) + 1) & mask)
		}
		slots[slot] = u32(index + 1)
	}
	names.slots = slots
}
