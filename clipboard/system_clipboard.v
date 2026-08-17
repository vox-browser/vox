// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Clipboard/SystemClipboard.{h,cpp}. In Ladybird these records
// cross the WebContent/browser IPC boundary. The V port keeps that boundary as
// an injectable in-memory backend and provides the same deterministic record
// encoding used by tests and embedders.
module clipboard

pub struct SystemClipboardRepresentation {
pub:
	data      []u8
	mime_type string
}

pub struct SystemClipboardItem {
pub:
	system_clipboard_representations []SystemClipboardRepresentation
}

fn append_u32(mut output []u8, value u32) {
	output << u8(value & 0xff)
	output << u8((value >> 8) & 0xff)
	output << u8((value >> 16) & 0xff)
	output << u8((value >> 24) & 0xff)
}

fn append_bytes(mut output []u8, value []u8) {
	append_u32(mut output, u32(value.len))
	output << value
}

struct SystemClipboardDecoder {
	input []u8
mut:
	offset int
}

fn (mut decoder SystemClipboardDecoder) read_u32() !u32 {
	if decoder.offset < 0 || decoder.input.len - decoder.offset < 4 {
		return error('Invalid SystemClipboard encoding: truncated length')
	}
	value := u32(decoder.input[decoder.offset]) | (u32(decoder.input[decoder.offset + 1]) << 8) | (u32(decoder.input[
		decoder.offset + 2]) << 16) | (u32(decoder.input[decoder.offset + 3]) << 24)
	decoder.offset += 4
	return value
}

fn (mut decoder SystemClipboardDecoder) read_bytes() ![]u8 {
	length := int(decoder.read_u32()!)
	if length < 0 || decoder.offset > decoder.input.len
		|| length > decoder.input.len - decoder.offset {
		return error('Invalid SystemClipboard encoding: truncated payload')
	}
	value := decoder.input[decoder.offset..decoder.offset + length].clone()
	decoder.offset += length
	return value
}

fn encode_representation_into(mut output []u8, representation SystemClipboardRepresentation) {
	append_bytes(mut output, representation.data)
	append_bytes(mut output, representation.mime_type.bytes())
}

fn (mut decoder SystemClipboardDecoder) decode_representation() !SystemClipboardRepresentation {
	data := decoder.read_bytes()!
	mime_type := decoder.read_bytes()!.bytestr()
	return SystemClipboardRepresentation{
		data:      data
		mime_type: mime_type
	}
}

pub fn encode_system_clipboard_representation(representation SystemClipboardRepresentation) []u8 {
	mut output := []u8{}
	encode_representation_into(mut output, representation)
	return output
}

pub fn decode_system_clipboard_representation(input []u8) !SystemClipboardRepresentation {
	mut decoder := SystemClipboardDecoder{
		input: input
	}
	representation := decoder.decode_representation()!
	if decoder.offset != input.len {
		return error('Invalid SystemClipboard representation: trailing data')
	}
	return representation
}

pub fn encode_system_clipboard_item(item SystemClipboardItem) []u8 {
	mut output := []u8{}
	append_u32(mut output, u32(item.system_clipboard_representations.len))
	for representation in item.system_clipboard_representations {
		encode_representation_into(mut output, representation)
	}
	return output
}

pub fn decode_system_clipboard_item(input []u8) !SystemClipboardItem {
	mut decoder := SystemClipboardDecoder{
		input: input
	}
	count := int(decoder.read_u32()!)
	// Every representation contains at least two u32 lengths. Validate before
	// allocating so a malformed count cannot request an unbounded array.
	if count < 0 || count > (input.len - decoder.offset) / 8 {
		return error('Invalid SystemClipboard item: impossible representation count')
	}
	mut representations := []SystemClipboardRepresentation{cap: count}
	for _ in 0 .. count {
		representations << decoder.decode_representation()!
	}
	if decoder.offset != input.len {
		return error('Invalid SystemClipboard item: trailing data')
	}
	return SystemClipboardItem{
		system_clipboard_representations: representations
	}
}

fn clone_system_clipboard_items(items []SystemClipboardItem) []SystemClipboardItem {
	mut result := []SystemClipboardItem{cap: items.len}
	for item in items {
		mut representations := []SystemClipboardRepresentation{cap: item.system_clipboard_representations.len}
		for representation in item.system_clipboard_representations {
			representations << SystemClipboardRepresentation{
				data:      representation.data.clone()
				mime_type: representation.mime_type
			}
		}
		result << SystemClipboardItem{
			system_clipboard_representations: representations
		}
	}
	return result
}

// SystemClipboardBackend is the browser-process side of the translation. A
// real embedder can copy its native clipboard into this object before reads
// and consume the last written snapshot after writes.
@[heap]
pub struct SystemClipboardBackend {
mut:
	items_               []SystemClipboardItem
	presentation_styles_ []string
}

pub fn SystemClipboardBackend.create() &SystemClipboardBackend {
	return &SystemClipboardBackend{}
}

pub fn (backend &SystemClipboardBackend) items() []SystemClipboardItem {
	return clone_system_clipboard_items(backend.items_)
}

pub fn (backend &SystemClipboardBackend) presentation_styles() []string {
	return backend.presentation_styles_.clone()
}

pub fn (mut backend SystemClipboardBackend) replace_items(items []SystemClipboardItem, presentation_styles []string) {
	backend.items_ = clone_system_clipboard_items(items)
	backend.presentation_styles_ = presentation_styles.clone()
}
