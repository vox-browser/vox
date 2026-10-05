// SPDX-License-Identifier: BSD-2-Clause

// LibURL/URL.h:45–64: the URL record's copied blob entry, distinct from the
// FileAPI store entry that retains the live Blob/MediaSource and settings.
module url

pub struct BlobURLBlob {
pub mut:
	type_ string
	data  []u8
}

pub struct BlobURLMediaSource {}

pub type BlobURLObject = BlobURLBlob | BlobURLMediaSource

pub struct BlobURLEnvironment {
pub:
	origin Origin
}

pub struct BlobURLEntry {
pub:
	object      BlobURLObject
	environment BlobURLEnvironment
}

// Source value copies retain the Origin and copy the ByteBuffer's bytes
// (URL.h:158–173 and AK/ByteBuffer.h:30–35,52–61).
fn copy_blob_url_entry(entry BlobURLEntry) BlobURLEntry {
	object := entry.object
	if object is BlobURLBlob {
		return BlobURLEntry{
			object:      BlobURLBlob{ type_: object.type_, data: object.data.clone() }
			environment: entry.environment
		}
	}
	return BlobURLEntry{
		object:      BlobURLMediaSource{}
		environment: entry.environment
	}
}

pub fn (record &URL) blob_url_entry() ?BlobURLEntry {
	entry := record.blob_url_entry_ or { return none }
	return copy_blob_url_entry(entry)
}

pub fn (mut record URL) set_blob_url_entry(entry ?BlobURLEntry) {
	if value := entry {
		record.blob_url_entry_ = copy_blob_url_entry(value)
	} else {
		record.blob_url_entry_ = none
	}
}

// The DOM adapter's owned value and const-style getter use the same existing
// Source record copy as the parser's component setters.
pub fn (record &URL) copy() URL {
	return parser_copy_url(record)
}
