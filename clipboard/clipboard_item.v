// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Clipboard/ClipboardItem.{h,cpp,idl}.
module clipboard

import fileapi
import mimesniff

pub const web_custom_format_prefix = 'web '

pub enum PresentationStyle {
	unspecified
	inline
	attachment
}

pub enum ClipboardPromiseState {
	pending
	fulfilled
	rejected
}

pub enum ClipboardItemDataKind {
	string_
	blob
}

pub struct ClipboardItemData {
pub:
	kind ClipboardItemDataKind
	text string
	blob ?&fileapi.Blob
}

pub fn ClipboardItemData.from_string(value string) ClipboardItemData {
	return ClipboardItemData{
		kind: .string_
		text: value
	}
}

pub fn ClipboardItemData.from_blob(value &fileapi.Blob) ClipboardItemData {
	return ClipboardItemData{
		kind: .blob
		blob: value
	}
}

pub type ClipboardItemDataFulfilled = fn (ClipboardItemData)

pub type ClipboardItemDataRejected = fn (string)

// WebIDL::Promise<DOMString or Blob>, represented without erasing the value's
// type. Reactions run when the promise settles; the Clipboard write algorithm
// uses them to resume work instead of assuming already-settled input.
@[heap]
pub struct ClipboardItemDataPromise {
mut:
	state_               ClipboardPromiseState
	result_              ClipboardItemData
	reason_              string
	fulfillment_handlers []ClipboardItemDataFulfilled
	rejection_handlers   []ClipboardItemDataRejected
}

pub fn ClipboardItemDataPromise.pending() &ClipboardItemDataPromise {
	return &ClipboardItemDataPromise{}
}

pub fn ClipboardItemDataPromise.resolved_string(value string) &ClipboardItemDataPromise {
	return &ClipboardItemDataPromise{
		state_: .fulfilled
		result_: ClipboardItemData.from_string(value)
	}
}

pub fn ClipboardItemDataPromise.resolved_blob(value &fileapi.Blob) &ClipboardItemDataPromise {
	return &ClipboardItemDataPromise{
		state_: .fulfilled
		result_: ClipboardItemData.from_blob(value)
	}
}

pub fn ClipboardItemDataPromise.rejected(reason string) &ClipboardItemDataPromise {
	return &ClipboardItemDataPromise{
		state_: .rejected
		reason_: reason
	}
}

pub fn (promise &ClipboardItemDataPromise) state() ClipboardPromiseState {
	return promise.state_
}

pub fn (promise &ClipboardItemDataPromise) result() ?ClipboardItemData {
	if promise.state_ != .fulfilled {
		return none
	}
	return promise.result_
}

pub fn (promise &ClipboardItemDataPromise) reason() string {
	return promise.reason_
}

pub fn (mut promise ClipboardItemDataPromise) resolve(value ClipboardItemData) {
	if promise.state_ != .pending {
		return
	}
	promise.state_ = .fulfilled
	promise.result_ = value
	handlers := promise.fulfillment_handlers.clone()
	promise.fulfillment_handlers.clear()
	promise.rejection_handlers.clear()
	for handler in handlers {
		handler(value)
	}
}

pub fn (mut promise ClipboardItemDataPromise) reject(reason string) {
	if promise.state_ != .pending {
		return
	}
	promise.state_ = .rejected
	promise.reason_ = reason
	handlers := promise.rejection_handlers.clone()
	promise.fulfillment_handlers.clear()
	promise.rejection_handlers.clear()
	for handler in handlers {
		handler(reason)
	}
}

pub fn (promise &ClipboardItemDataPromise) react(on_fulfilled ClipboardItemDataFulfilled, on_rejected ClipboardItemDataRejected) {
	match promise.state_ {
		.fulfilled {
			on_fulfilled(promise.result_)
		}
		.rejected {
			on_rejected(promise.reason_)
		}
		.pending {
			mut mutable_promise := unsafe { &ClipboardItemDataPromise(promise) }
			mutable_promise.fulfillment_handlers << on_fulfilled
			mutable_promise.rejection_handlers << on_rejected
		}
	}
}

// Promise returned by ClipboardItem.getType().
@[heap]
pub struct ClipboardBlobPromise {
mut:
	state_  ClipboardPromiseState
	blob_   ?&fileapi.Blob
	reason_ string
}

pub fn ClipboardBlobPromise.pending() &ClipboardBlobPromise {
	return &ClipboardBlobPromise{}
}

pub fn (promise &ClipboardBlobPromise) state() ClipboardPromiseState {
	return promise.state_
}

pub fn (promise &ClipboardBlobPromise) blob() ?&fileapi.Blob {
	return promise.blob_
}

pub fn (promise &ClipboardBlobPromise) reason() string {
	return promise.reason_
}

fn (mut promise ClipboardBlobPromise) resolve(blob &fileapi.Blob) {
	if promise.state_ == .pending {
		promise.state_ = .fulfilled
		promise.blob_ = blob
	}
}

pub fn resolve_clipboard_item_blob_promise(mut promise ClipboardBlobPromise, blob &fileapi.Blob) {
	promise.resolve(blob)
}

fn (mut promise ClipboardBlobPromise) reject(reason string) {
	if promise.state_ == .pending {
		promise.state_ = .rejected
		promise.reason_ = reason
	}
}

pub struct ClipboardItemOptions {
pub:
	presentation_style PresentationStyle = .unspecified
}

pub struct ClipboardItemInput {
pub:
	type_ string
	data  &ClipboardItemDataPromise = unsafe { nil }
}

pub struct ClipboardItemRepresentation {
pub:
	mime_type string
	is_custom bool
	data      &ClipboardItemDataPromise = unsafe { nil }
}

struct NormalizedClipboardType {
	mime_type string
	is_custom bool
}

fn normalize_clipboard_type(type_ string) !NormalizedClipboardType {
	mut value := type_
	mut is_custom := false
	if value.starts_with(web_custom_format_prefix) {
		value = value[web_custom_format_prefix.len..]
		is_custom = true
	}
	mime_type := mimesniff.MimeType.parse(value) or {
		return error('TypeError: Invalid MIME type: ${type_}')
	}
	return NormalizedClipboardType{
		mime_type: mime_type.serialized()
		is_custom: is_custom
	}
}

@[heap]
pub struct ClipboardItem {
mut:
	types_                         []string
	representations_               []ClipboardItemRepresentation
	presentation_style_            PresentationStyle
	clipboard_change_count_at_read ?uint
	originating_system_item_       ?SystemClipboardItem
	unsanitized_mime_types_        []string
	representations_with_resolvers map[string]&ClipboardBlobPromise
}

pub fn ClipboardItem.construct_impl(items []ClipboardItemInput, options ClipboardItemOptions) !&ClipboardItem {
	if items.len == 0 {
		return error('TypeError: Items cannot be empty')
	}
	mut item := &ClipboardItem{
		presentation_style_: options.presentation_style
		representations_with_resolvers: map[string]&ClipboardBlobPromise{}
	}
	for input in items {
		if input.data == unsafe { nil } {
			return error('TypeError: Clipboard item data promise cannot be null')
		}
		normalized := normalize_clipboard_type(input.type_)!
		for representation in item.representations_ {
			if representation.mime_type == normalized.mime_type
				&& representation.is_custom == normalized.is_custom {
				return error('TypeError: Duplicate MIME type: ${input.type_}')
			}
		}
		item.append_representation(ClipboardItemRepresentation{
			mime_type: normalized.mime_type
			is_custom: normalized.is_custom
			data: input.data
		})
	}
	return item
}

pub fn ClipboardItem.create(items []ClipboardItemInput, presentation_style PresentationStyle) !&ClipboardItem {
	return ClipboardItem.construct_impl(items, ClipboardItemOptions{
		presentation_style: presentation_style
	})
}

// create_empty is used by Clipboard.read while constructing the underlying
// clipboard item described by the specification.
pub fn ClipboardItem.create_empty() &ClipboardItem {
	return &ClipboardItem{
		representations_with_resolvers: map[string]&ClipboardBlobPromise{}
	}
}

pub fn (mut item ClipboardItem) append_representation(representation ClipboardItemRepresentation) {
	public_type := if representation.is_custom {
		'${web_custom_format_prefix}${representation.mime_type}'
	} else {
		representation.mime_type
	}
	item.types_ << public_type
	item.representations_ << representation
}

pub fn (item &ClipboardItem) types() []string {
	return item.types_.clone()
}

pub fn (item &ClipboardItem) representations() []ClipboardItemRepresentation {
	return item.representations_.clone()
}

pub fn (item &ClipboardItem) presentation_style() PresentationStyle {
	return item.presentation_style_
}

pub fn (mut item ClipboardItem) set_clipboard_change_count_at_read(count uint) {
	item.clipboard_change_count_at_read = count
}

pub fn (mut item ClipboardItem) set_originating_system_clipboard_item(originating ?SystemClipboardItem) {
	item.originating_system_item_ = originating
}

pub fn (mut item ClipboardItem) set_unsanitized_mime_types(types []string) {
	item.unsanitized_mime_types_ = types.clone()
}

pub fn (item &ClipboardItem) get_type(type_ string) !&ClipboardBlobPromise {
	normalized := normalize_clipboard_type(type_)!
	mut result := ClipboardBlobPromise.pending()
	for representation in item.representations_ {
		if representation.mime_type != normalized.mime_type
			|| representation.is_custom != normalized.is_custom {
			continue
		}
		mime_type := normalized.mime_type
		if item.clipboard_change_count_at_read != none {
			key := if normalized.is_custom {
				'${web_custom_format_prefix}${normalized.mime_type}'
			} else {
				normalized.mime_type
			}
			if cached := item.representations_with_resolvers[key] {
				return cached
			}
			mut mutable_item := unsafe { &ClipboardItem(item) }
			mutable_item.representations_with_resolvers[key] = result
			originating := item.originating_system_item_ or {
				result.reject('InvalidStateError: This clipboard item is missing an originating system clipboard entry')
				return result
			}
			if normalized.is_custom {
				result.reject('NotFoundError: No data found for MIME type: ${type_}')
				return result
			}
			os_format_name := os_specific_well_known_format(normalized.mime_type)
			for system_representation in originating.system_clipboard_representations {
				if os_specific_well_known_format(system_representation.mime_type) == os_format_name {
					data := system_representation.byte_data() or { continue }
					blob := fileapi.Blob.create(data, normalized.mime_type)
					resolve_clipboard_item_blob_promise(mut result, blob)
					return result
				}
			}
			result.reject('NotFoundError: No data found for MIME type: ${os_format_name}')
			return result
		}
		requested_type := type_
		representation.data.react(fn [mut result, mime_type] (value ClipboardItemData) {
			match value.kind {
				.string_ {
					result.resolve(fileapi.Blob.create(value.text.bytes(), mime_type))
				}
				.blob {
					if blob := value.blob {
						result.resolve(blob)
					} else {
						result.reject('NotFoundError: Clipboard Blob value is missing')
					}
				}
			}
		}, fn [mut result, requested_type] (_ string) {
			result.reject('NotFoundError: No data found for MIME type: ${requested_type}')
		})
		return result
	}
	result.reject('NotFoundError: No data found for MIME type: ${type_}')
	return result
}

pub fn ClipboardItem.supports(type_ string) bool {
	return type_ == 'text/plain' || type_ == 'text/html' || type_ == 'image/png'
}

pub fn presentation_style_to_string(style PresentationStyle) string {
	return match style {
		.unspecified { 'unspecified' }
		.inline { 'inline' }
		.attachment { 'attachment' }
	}
}

pub fn presentation_style_string(style PresentationStyle) string {
	return presentation_style_to_string(style)
}
