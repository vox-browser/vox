module html

import dom
import fileapi
import streams

fn test_blob_text_stream_decodes_utf8_ignores_mime_and_flushes_incomplete_sequences() {
	url := dom.URL{value: 'https://blob-text-stream.test/'}
	document := &dom.Document{ url: url, origin_: url.origin() }
	window := WindowModel.create_top_level(document, none, '')!
	mut settings := window.environment_settings_.settings
	mut owner := EventLoop.create(.window)
	settings.responsible_event_loop_ = owner
	for index, bytes in [
		'hello world'.bytes(),
		[u8(0x68), 0, 0x69, 0],
		[u8(0xef), 0xbb, 0xbf, 0xc3, 0xa9],
		[u8(0xff), 0xfe, 0x61, 0],
		[u8(0xc3)],
		[]u8{},
		[u8(0xef), 0xbb, 0xbf],
		[u8(0xef), 0xbb, 0xbf, 0xef, 0xbb, 0xbf, `P`],
		[u8(`A`), 0xc3],
	] {
		blob := fileapi.Blob.create(bytes, 'text/plain; charset=utf-16le')
		mut stream := settings.blob_text_stream_in_realm(blob, settings.stream_realm())!
		mut another := settings.blob_text_stream_in_realm(blob, settings.stream_realm())!
		assert voidptr(stream) != voidptr(another)
		assert stream.realm().id == u64(voidptr(settings.realm()))
		mut reader := stream.get_default_reader()!
		first := reader.read()
		owner.perform_a_microtask_checkpoint()
		assert first.state() == .pending
		mut queue := owner.task_queue()
		for {
			task := queue.take_first_runnable() or { break }
			assert task.source() == .file_reading
			task.execute()
		}
		owner.perform_a_microtask_checkpoint()
		assert first.state() == .fulfilled
		if index in [5, 6] {
			assert first.result().done
		} else {
			mut value := first.result().value
			assert value.kind == .string_
			mut text := value.text
			for {
				next := reader.read()
				owner.perform_a_microtask_checkpoint()
				assert next.state() == .fulfilled
				if next.result().done { break }
				value = next.result().value
				assert value.kind == .string_
				text += value.text
			}
			assert text == ['hello world', 'h\0i\0', 'é', '��a\0', '�', '', '', '\ufeffP', 'A�'][index]
		}
		another.cancel(streams.undefined_value())
		owner.perform_a_microtask_checkpoint()
	}
}
