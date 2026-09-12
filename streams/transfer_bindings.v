// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Stream-specific structured-transfer glue. A MessagePort pointer represents
// the entangled pair used by LibWeb; its readable and writable targets are the
// two endpoints of the V cross-realm transform.
module streams

pub enum StreamObjectKind {
	readable
	writable
}

pub struct StreamObject {
mut:
	kind_     StreamObjectKind
	readable_ &ReadableStream = unsafe { nil }
	writable_ &WritableStream = unsafe { nil }
}

pub fn StreamObject.from_readable(stream &ReadableStream) StreamObject {
	return StreamObject{
		kind_: .readable
		readable_: stream
	}
}

pub fn StreamObject.from_writable(stream &WritableStream) StreamObject {
	return StreamObject{
		kind_: .writable
		writable_: stream
	}
}

pub fn readable_stream_from_object(object StreamObject) !&ReadableStream {
	if object.kind_ != .readable || isnil(object.readable_) {
		return error('TypeError: Object does not wrap a ReadableStream')
	}
	return object.readable_
}

pub fn writable_stream_from_object(object StreamObject) !&WritableStream {
	if object.kind_ != .writable || isnil(object.writable_) {
		return error('TypeError: Object does not wrap a WritableStream')
	}
	return object.writable_
}

enum StreamTransferKind {
	readable
	writable
}

struct StreamTransferRecord {
	kind StreamTransferKind
	port &MessagePort
}

pub struct TransferDataEncoder {
mut:
	records_ []StreamTransferRecord
}

pub struct TransferDataDecoder {
mut:
	records_ []StreamTransferRecord
	index_   int
}

pub fn (encoder &TransferDataEncoder) record_count() int {
	return encoder.records_.len
}

pub fn (encoder &TransferDataEncoder) decoder() TransferDataDecoder {
	return TransferDataDecoder{
		records_: encoder.records_.clone()
	}
}

fn (mut decoder TransferDataDecoder) take(kind StreamTransferKind) !&MessagePort {
	if decoder.index_ >= decoder.records_.len {
		return error('DataCloneError: Missing transferred stream data')
	}
	record := decoder.records_[decoder.index_]
	decoder.index_++
	if record.kind != kind {
		return error('DataCloneError: Transferred stream type does not match')
	}
	return record.port
}

pub fn serialize_readable_stream_with_transfer(realm StreamRealm, mut encoder TransferDataEncoder, mut stream ReadableStream) ! {
	if stream.locked() {
		return error('DataCloneError: Cannot transfer locked ReadableStream')
	}
	mut port := MessagePort.create()
	mut writable_endpoint := &WritableStream{
		realm_: realm
	}
	set_up_cross_realm_transform_writable(mut writable_endpoint, mut port)
	_ = stream.pipe_to(mut writable_endpoint, StreamPipeOptions{})
	encoder.records_ << StreamTransferRecord{
		kind: .readable
		port: port
	}
}

pub fn serialize_writable_stream_with_transfer(realm StreamRealm, mut encoder TransferDataEncoder, mut stream WritableStream) ! {
	if stream.locked() {
		return error('DataCloneError: Cannot transfer locked WritableStream')
	}
	mut port := MessagePort.create()
	mut readable_endpoint := &ReadableStream{
		realm_: realm
	}
	set_up_cross_realm_transform_readable(mut readable_endpoint, mut port)
	_ = readable_endpoint.pipe_to(mut stream, StreamPipeOptions{})
	encoder.records_ << StreamTransferRecord{
		kind: .writable
		port: port
	}
}

pub fn (mut stream ReadableStream) transfer_receiving_steps_from(realm StreamRealm, mut decoder TransferDataDecoder) ! {
	mut port := decoder.take(.readable)!
	stream.realm_ = realm
	set_up_cross_realm_transform_readable(mut stream, mut port)
}

pub fn (mut stream WritableStream) transfer_receiving_steps_from(realm StreamRealm, mut decoder TransferDataDecoder) ! {
	mut port := decoder.take(.writable)!
	stream.realm_ = realm
	set_up_cross_realm_transform_writable(mut stream, mut port)
}

pub fn (mut source ReadableStream) transfer_in_realm(realm StreamRealm) !&ReadableStream {
	mut encoder := TransferDataEncoder{}
	serialize_readable_stream_with_transfer(source.realm_, mut encoder, mut source)!
	mut decoder := encoder.decoder()
	mut proxy := &ReadableStream{}
	proxy.transfer_receiving_steps_from(realm, mut decoder)!
	return proxy
}

pub fn (mut source WritableStream) transfer_in_realm(realm StreamRealm) !&WritableStream {
	mut encoder := TransferDataEncoder{}
	serialize_writable_stream_with_transfer(source.realm_, mut encoder, mut source)!
	mut decoder := encoder.decoder()
	mut proxy := &WritableStream{}
	proxy.transfer_receiving_steps_from(realm, mut decoder)!
	return proxy
}
