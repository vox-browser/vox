module clipboard

import fileapi
import dom
import html

fn test_system_clipboard_records_round_trip_and_reject_malformed_input() {
	representation := SystemClipboardRepresentation{
		data:      [u8(0), 1, 2, 255]
		mime_type: 'image/png'
	}
	encoded_representation := encode_system_clipboard_representation(representation)
	decoded_representation := decode_system_clipboard_representation(encoded_representation) or {
		panic(err)
	}
	assert decoded_representation == representation

	item := SystemClipboardItem{
		system_clipboard_representations: [representation, SystemClipboardRepresentation{
			data:      'hello'.bytes()
			mime_type: 'text/plain'
		}]
	}
	encoded_item := encode_system_clipboard_item(item)
	assert decode_system_clipboard_item(encoded_item) or { panic(err) } == item
	if _ := decode_system_clipboard_item(encoded_item[..encoded_item.len - 1]) {
		assert false
	}
	mut representation_with_trailing_data := encoded_representation.clone()
	representation_with_trailing_data << u8(0)
	if _ := decode_system_clipboard_representation(representation_with_trailing_data) {
		assert false
	}
}

fn test_system_clipboard_backend_owns_snapshots() {
	mut backend := SystemClipboardBackend.create()
	mut source_data := 'before'.bytes()
	backend.replace_items([
		SystemClipboardItem{
			system_clipboard_representations: [
				SystemClipboardRepresentation{
					data:      source_data
					mime_type: 'text/plain'
				},
			]
		},
	], ['inline'])
	source_data[0] = `X`
	assert backend.items()[0].system_clipboard_representations[0].data.bytestr() == 'before'
	assert backend.presentation_styles() == ['inline']
}

fn test_clipboard_item_normalizes_types_and_get_type_converts_strings() {
	item := ClipboardItem.construct_impl([
		ClipboardItemInput{
			type_: 'TEXT/PLAIN;Charset=UTF-8'
			data:  ClipboardItemDataPromise.resolved_string('hello')
		},
		ClipboardItemInput{
			type_: 'web Application/X-Test'
			data:  ClipboardItemDataPromise.resolved_string('custom')
		},
	], ClipboardItemOptions{
		presentation_style: .inline
	}) or { panic(err) }
	assert item.types() == ['text/plain;charset=UTF-8', 'web application/x-test']
	assert item.presentation_style() == .inline
	promise := item.get_type('text/plain;charset=UTF-8') or { panic(err) }
	assert promise.state() == .fulfilled
	blob := promise.blob() or { panic('missing Blob') }
	assert blob.type_() == 'text/plain;charset=UTF-8'
	assert blob.raw_bytes().bytestr() == 'hello'
	assert item.get_type('web application/x-test') or { panic(err) }.state() == .fulfilled
	assert item.get_type('application/x-test') or { panic(err) }.state() == .rejected
}

fn test_clipboard_item_get_type_tracks_pending_and_rejected_data() {
	mut data := ClipboardItemDataPromise.pending()
	item := ClipboardItem.construct_impl([
		ClipboardItemInput{
			type_: 'image/png'
			data:  data
		},
	], ClipboardItemOptions{}) or { panic(err) }
	result := item.get_type('image/png') or { panic(err) }
	assert result.state() == .pending
	blob := fileapi.Blob.create([u8(137), 80, 78, 71], 'image/png')
	data.resolve(ClipboardItemData.from_blob(blob))
	assert result.state() == .fulfilled
	assert result.blob() or { panic('missing Blob') } == blob

	rejected_item := ClipboardItem.construct_impl([
		ClipboardItemInput{
			type_: 'text/plain'
			data:  ClipboardItemDataPromise.rejected('source failed')
		},
	], ClipboardItemOptions{}) or { panic(err) }
	rejected := rejected_item.get_type('text/plain') or { panic(err) }
	assert rejected.state() == .rejected
	assert rejected.reason().starts_with('NotFoundError:')
}

fn test_clipboard_item_rejects_empty_invalid_and_normalized_duplicate_types() {
	if _ := ClipboardItem.construct_impl([], ClipboardItemOptions{}) {
		assert false
	}
	if _ := ClipboardItem.construct_impl([
		ClipboardItemInput{
			type_: 'not a mime type'
			data:  ClipboardItemDataPromise.resolved_string('x')
		},
	], ClipboardItemOptions{})
	{
		assert false
	}
	if _ := ClipboardItem.construct_impl([
		ClipboardItemInput{
			type_: 'TEXT/PLAIN'
			data:  ClipboardItemDataPromise.resolved_string('a')
		},
		ClipboardItemInput{
			type_: 'text/plain'
			data:  ClipboardItemDataPromise.resolved_string('b')
		},
	], ClipboardItemOptions{})
	{
		assert false
	}
	assert ClipboardItem.supports('text/plain')
	assert ClipboardItem.supports('text/html')
	assert ClipboardItem.supports('image/png')
	assert !ClipboardItem.supports('application/json')
}

fn test_clipboard_event_exposes_initialization_and_data_transfer() {
	transfer := html.DataTransfer.construct()
	event := ClipboardEvent.construct_impl('paste', ClipboardEventInit{
		EventInit:      dom.EventInit{
			bubbles:    true
			cancelable: true
		}
		clipboard_data: transfer
	}) or { panic(err) }
	assert event.type_name() == 'paste'
	assert event.bubbles()
	assert event.cancelable()
	assert event.clipboard_data() or { panic('missing transfer') } == transfer
}
