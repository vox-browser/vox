// Copyright (c) 2022-2023, the SerenityOS developers.
// SPDX-License-Identifier: BSD-2-Clause

// FileAPI/Blob.cpp::get_stream/read_all_blob_bytes cross the actual HTML
// relevant-realm and FileReading-task boundary here to avoid an import cycle.
module html

import fileapi
import streams
import webidl

pub fn (settings &EnvironmentSettingsObject) get_blob_stream(blob &fileapi.Blob) &streams.ReadableStream {
	return settings.get_blob_stream_in_realm(blob, settings.stream_realm())
}

// Native bindings pass the actual relevant JS Realm's allocation/data hooks.
// Its Promise jobs still belong to these real Window/Worker settings.
pub fn (settings &EnvironmentSettingsObject) get_blob_stream_in_realm(blob &fileapi.Blob, realm streams.StreamRealm) &streams.ReadableStream {
	assert realm.id == u64(voidptr(settings.realm())), 'Source Blob relevant Realm must belong to its settings'
	mut stream := streams.ReadableStream.create_for_internal()
	stream.set_up_with_byte_reading_support_in_realm(realm, none, none, 0)
	// Source currently queues one copied whole-buffer chunk, including empty
	// blobs. The copy belongs to the task before any read or callback runs.
	bytes := blob.raw_bytes()
	queue_a_task(.file_reading, settings.responsible_event_loop(), settings.responsible_document(), fn [settings, mut stream, bytes] () {
		mut realm := unsafe { &ScriptingRealm(settings.realm()) }
		mut context := TemporaryExecutionContext.create(mut realm, .yes)
		defer { context.close() }
		// This is the internal ReadableStream enqueue operation. The public
		// byte-controller enqueue rejects the empty chunk which Source uses.
		stream.enqueue(streams.bytes_value(bytes)) or {
			stream.error_value(blob_operation_exception_value(err))
			return
		}
		stream.close()
	})
	return stream
}

pub fn (settings &EnvironmentSettingsObject) read_all_blob_bytes(blob &fileapi.Blob) &webidl.Promise {
	return settings.read_all_blob_bytes_in_realm(blob, settings.stream_realm())
}

pub fn (settings &EnvironmentSettingsObject) read_all_blob_bytes_in_realm(blob &fileapi.Blob, realm streams.StreamRealm) &webidl.Promise {
	mut stream := settings.get_blob_stream_in_realm(blob, realm)
	mut reader := stream.get_default_reader() or {
		return webidl.create_rejected_promise_for(realm.promise_context(), blob_operation_exception_value(err))
	}
	return reader.read_all_bytes_deprecated()
}

// The typed Streams ExceptionOr adapter still uses IError for built-in
// SimpleException failures. Convert those descriptors at the same Source
// throw_dom_exception_if_needed boundary; thrown JS values retain identity.
fn blob_operation_exception_value(exception IError) webidl.Value {
	if exception is webidl.ValueException { return exception.value }
	message := exception.msg()
	if message.starts_with('TypeError: ') {
		return webidl.simple_exception_value(webidl.SimpleException{ type_: .type_error, message: message['TypeError: '.len..] })
	}
	if message.starts_with('RangeError: ') {
		return webidl.simple_exception_value(webidl.SimpleException{ type_: .range_error, message: message['RangeError: '.len..] })
	}
	panic('Source Blob ExceptionOr: unsupported typed exception ${message}')
}
