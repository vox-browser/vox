// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Clipboard/SystemClipboard.{h,cpp}. In Ladybird these records
// cross the WebContent/browser IPC boundary. The V port keeps that boundary as
// an injectable in-memory backend and provides the same deterministic record
// encoding used by tests and embedders.
module clipboard

import dom
import html

pub type SystemClipboardData = []u8 | html.SelectedFile

pub struct SystemClipboardRepresentation {
pub:
	data      SystemClipboardData
	mime_type string
}

pub fn SystemClipboardRepresentation.from_file(mime_type string, file html.SelectedFile) SystemClipboardRepresentation {
	return SystemClipboardRepresentation{
		data: file
		mime_type: mime_type
	}
}

pub fn (representation &SystemClipboardRepresentation) byte_data() ?[]u8 {
	if representation.data is []u8 {
		return representation.data.clone()
	}
	return none
}

pub fn (representation &SystemClipboardRepresentation) selected_file() ?html.SelectedFile {
	if representation.data is html.SelectedFile {
		return representation.data.clone_for_transfer()
	}
	return none
}

pub fn (representation &SystemClipboardRepresentation) is_file_backed() bool {
	return representation.data is html.SelectedFile
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
	value := u32(decoder.input[decoder.offset]) | (u32(decoder.input[decoder.offset + 1]) << 8) | (u32(decoder.input[decoder.offset + 2]) << 16) | (u32(decoder.input[decoder.offset + 3]) << 24)
	decoder.offset += 4
	return value
}

fn (mut decoder SystemClipboardDecoder) read_u8() !u8 {
	if decoder.offset < 0 || decoder.offset >= decoder.input.len {
		return error('Invalid SystemClipboard encoding: truncated variant tag')
	}
	value := decoder.input[decoder.offset]
	decoder.offset++
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

fn encode_representation_into(mut output []u8, representation SystemClipboardRepresentation) ! {
	append_bytes(mut output, representation.mime_type.bytes())
	if representation.data is []u8 {
		output << u8(0)
		append_bytes(mut output, representation.data)
		return
	}
	output << u8(1)
	file := representation.data as html.SelectedFile
	append_bytes(mut output, html.encode_selected_file(&file)!)
}

fn (mut decoder SystemClipboardDecoder) decode_representation() !SystemClipboardRepresentation {
	mime_type := decoder.read_bytes()!.bytestr()
	tag := decoder.read_u8()!
	payload := decoder.read_bytes()!
	data := match tag {
		0 { SystemClipboardData(payload) }
		1 { SystemClipboardData(html.decode_selected_file(payload)!) }
		else { return error('Invalid SystemClipboard representation variant tag') }
	}
	return SystemClipboardRepresentation{
		data: data
		mime_type: mime_type
	}
}

pub fn encode_system_clipboard_representation(representation SystemClipboardRepresentation) ![]u8 {
	mut output := []u8{}
	encode_representation_into(mut output, representation)!
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

pub fn encode_system_clipboard_item(item SystemClipboardItem) ![]u8 {
	mut output := []u8{}
	append_u32(mut output, u32(item.system_clipboard_representations.len))
	for representation in item.system_clipboard_representations {
		encode_representation_into(mut output, representation)!
	}
	return output
}

pub fn decode_system_clipboard_item(input []u8) !SystemClipboardItem {
	mut decoder := SystemClipboardDecoder{
		input: input
	}
	count := int(decoder.read_u32()!)
	// Every representation contains at least two u32 lengths and a tag. Validate before
	// allocating so a malformed count cannot request an unbounded array.
	if count < 0 || count > (input.len - decoder.offset) / 9 {
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
			data := if representation.data is []u8 {
				SystemClipboardData(representation.data.clone())
			} else {
				file := representation.data as html.SelectedFile
				SystemClipboardData(file.clone_for_transfer())
			}
			representations << SystemClipboardRepresentation{
				data: data
				mime_type: representation.mime_type
			}
		}
		result << SystemClipboardItem{
			system_clipboard_representations: representations
		}
	}
	return result
}

struct ClipboardOriginWrite {
	origin dom.Origin
	traversable &dom.Navigable = unsafe { nil }
	items []SystemClipboardItem
}

// SystemClipboardBackend is the browser-process side of the translation, with
// one instance per tab. The embedder copies the current native clipboard into
// it before reads and consumes the last written snapshot after writes. It
// retains the tab's last page write separately from the current native data.
@[heap]
pub struct SystemClipboardBackend {
mut:
	items_               []SystemClipboardItem
	presentation_styles_ []string
	change_count_        uint
	last_write_by_page_   ?ClipboardOriginWrite
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

pub fn (backend &SystemClipboardBackend) change_count() uint {
	return backend.change_count_
}

pub fn (mut backend SystemClipboardBackend) replace_items(items []SystemClipboardItem, presentation_styles []string) {
	backend.items_ = clone_system_clipboard_items(items)
	backend.presentation_styles_ = presentation_styles.clone()
	backend.change_count_++
}

// The writing document's native identity supplies the origin and tab; neither
// is supplied by the calling script. External clipboard changes do not erase
// this record, since identical data still tells its author nothing new.
pub fn (mut backend SystemClipboardBackend) replace_items_written_by(items []SystemClipboardItem, presentation_styles []string, document &dom.Document) {
	backend.replace_items(items, presentation_styles)
	navigable := document.navigable() or { return }
	traversable := navigable.traversable_navigable() or { return }
	backend.last_write_by_page_ = ClipboardOriginWrite{
		origin: document.origin()
		traversable: traversable
		items: clone_system_clipboard_items(items)
	}
}

// A native clipboard may omit representations or reorder them. Every current
// representation must nevertheless be byte data, with the exact MIME name and
// bytes previously written by this origin in this tab. File-backed entries
// and additional/changed representations reject the entire read.
pub fn (backend &SystemClipboardBackend) items_written_by(document &dom.Document) []SystemClipboardItem {
	written := backend.last_write_by_page_ or { return []SystemClipboardItem{} }
	navigable := document.navigable() or { return []SystemClipboardItem{} }
	traversable := navigable.traversable_navigable() or { return []SystemClipboardItem{} }
	if voidptr(traversable) != voidptr(written.traversable)
		|| !document.origin().is_same_origin(written.origin)
		|| backend.items_.len == 0 {
		return []SystemClipboardItem{}
	}
	for item in backend.items_ {
		if item.system_clipboard_representations.len == 0 {
			return []SystemClipboardItem{}
		}
		for representation in item.system_clipboard_representations {
			data := representation.byte_data() or { return []SystemClipboardItem{} }
			mut found := false
			for written_item in written.items {
				for original in written_item.system_clipboard_representations {
					original_data := original.byte_data() or { continue }
					if original.mime_type == representation.mime_type && original_data == data {
						found = true
						break
					}
				}
				if found { break }
			}
			if !found { return []SystemClipboardItem{} }
		}
	}
	return backend.items()
}
