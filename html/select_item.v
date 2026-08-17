// Copyright (c) 2023, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/SelectItem.{h,cpp}.
module html

import dom

pub struct SelectItemOption {
pub:
	id             u32
	selected       bool
	disabled       bool
	option_element ?&dom.HTMLOptionElement
	label          string
	value          string
}

pub struct SelectItemOptionGroup {
pub:
	label string
	items []SelectItemOption
}

pub struct SelectItemSeparator {}

pub type SelectItem = SelectItemOption | SelectItemOptionGroup | SelectItemSeparator

fn select_item_append_u32(mut output []u8, value u32) {
	output << u8(value)
	output << u8(value >> 8)
	output << u8(value >> 16)
	output << u8(value >> 24)
}

fn select_item_append_string(mut output []u8, value string) {
	select_item_append_u32(mut output, u32(value.len))
	output << value.bytes()
}

fn select_item_append_option(mut output []u8, item SelectItemOption) {
	// Match SelectItem.cpp's IPC field order. option_element is intentionally
	// not serialized: it is process-local GC state.
	select_item_append_u32(mut output, item.id)
	select_item_append_string(mut output, item.label)
	select_item_append_string(mut output, item.value)
	output << u8(item.selected)
	output << u8(item.disabled)
}

pub fn encode_select_item_option(item SelectItemOption) []u8 {
	mut output := []u8{}
	select_item_append_option(mut output, item)
	return output
}

pub fn encode_select_item_option_group(item SelectItemOptionGroup) []u8 {
	mut output := []u8{}
	select_item_append_string(mut output, item.label)
	select_item_append_u32(mut output, u32(item.items.len))
	for option in item.items {
		select_item_append_option(mut output, option)
	}
	return output
}

pub fn encode_select_item_separator(_ SelectItemSeparator) []u8 {
	return []
}

struct SelectItemDecoder {
	data []u8
mut:
	offset int
}

fn (mut decoder SelectItemDecoder) read_u8() !u8 {
	if decoder.offset >= decoder.data.len {
		return error('truncated SelectItem IPC data')
	}
	value := decoder.data[decoder.offset]
	decoder.offset++
	return value
}

fn (mut decoder SelectItemDecoder) read_u32() !u32 {
	if decoder.offset + 4 > decoder.data.len {
		return error('truncated SelectItem IPC data')
	}
	value := u32(decoder.data[decoder.offset]) | (u32(decoder.data[decoder.offset + 1]) << 8) | (u32(decoder.data[
		decoder.offset + 2]) << 16) | (u32(decoder.data[decoder.offset + 3]) << 24)
	decoder.offset += 4
	return value
}

fn (mut decoder SelectItemDecoder) read_string() !string {
	length := int(decoder.read_u32()!)
	if length < 0 || decoder.offset + length > decoder.data.len {
		return error('truncated SelectItem IPC string')
	}
	value := decoder.data[decoder.offset..decoder.offset + length].bytestr()
	decoder.offset += length
	return value
}

fn (mut decoder SelectItemDecoder) read_bool() !bool {
	value := decoder.read_u8()!
	if value > 1 {
		return error('invalid SelectItem IPC boolean')
	}
	return value == 1
}

fn (mut decoder SelectItemDecoder) read_option() !SelectItemOption {
	id := decoder.read_u32()!
	label := decoder.read_string()!
	value := decoder.read_string()!
	selected := decoder.read_bool()!
	disabled := decoder.read_bool()!
	return SelectItemOption{
		id:       id
		label:    label
		value:    value
		selected: selected
		disabled: disabled
	}
}

pub fn decode_select_item_option(data []u8) !SelectItemOption {
	mut decoder := SelectItemDecoder{
		data: data
	}
	item := decoder.read_option()!
	if decoder.offset != data.len {
		return error('trailing SelectItem IPC data')
	}
	return item
}

pub fn decode_select_item_option_group(data []u8) !SelectItemOptionGroup {
	mut decoder := SelectItemDecoder{
		data: data
	}
	label := decoder.read_string()!
	item_count := int(decoder.read_u32()!)
	mut items := []SelectItemOption{cap: item_count}
	for _ in 0 .. item_count {
		items << decoder.read_option()!
	}
	if decoder.offset != data.len {
		return error('trailing SelectItem IPC data')
	}
	return SelectItemOptionGroup{
		label: label
		items: items
	}
}

pub fn decode_select_item_separator(data []u8) !SelectItemSeparator {
	if data.len != 0 {
		return error('SelectItemSeparator IPC data must be empty')
	}
	return SelectItemSeparator{}
}
