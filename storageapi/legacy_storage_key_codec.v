// SPDX-License-Identifier: BSD-2-Clause

// Existing standalone byte-codec compatibility. These flags do not represent
// a Source URL Origin and must never be recovered as a typed StorageKey owner.
module storageapi

pub struct LegacyStorageOrigin {
pub:
	serialized  string
	opaque      bool
	opaque_file bool
}

pub struct LegacyStorageKeyRecord {
pub:
	origin LegacyStorageOrigin
}

pub fn encode_legacy_storage_key(key LegacyStorageKeyRecord) []u8 {
	serialized := key.origin.serialized.bytes()
	mut output := []u8{cap: 6 + serialized.len}
	length := u32(serialized.len)
	for shift in 0 .. 4 {
		output << u8(length >> (shift * 8))
	}
	output << serialized
	output << u8(key.origin.opaque)
	output << u8(key.origin.opaque_file)
	return output
}

pub fn decode_legacy_storage_key(data []u8) !LegacyStorageKeyRecord {
	if data.len < 6 {
		return error('truncated storage key IPC data')
	}
	mut length := u32(0)
	for shift in 0 .. 4 {
		length |= u32(data[shift]) << (shift * 8)
	}
	end := 4 + int(length)
	if end < 4 || end + 2 != data.len {
		return error('invalid storage key IPC data')
	}
	if data[end] > 1 || data[end + 1] > 1 {
		return error('invalid storage key IPC boolean')
	}
	return LegacyStorageKeyRecord{
		origin: LegacyStorageOrigin{
			serialized:  data[4..end].bytestr()
			opaque:      data[end] == 1
			opaque_file: data[end + 1] == 1
		}
	}
}
