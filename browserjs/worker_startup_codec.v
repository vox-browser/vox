// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html
import math
import platform
import url as liburl

// Private WorkerProcess frame kinds. Message payloads use VXM1; startup uses
// VXS1/VXS2 retain the original string-only layout. VXS3/VXS4 additionally
// carry the entry URL's Blob snapshot across the independent process boundary.
pub enum WorkerAgentFrameKind as u32 {
	start = 1
	ready
	message
	load_failure
	shutdown
	port_message
}

pub struct WorkerStartup {
pub:
	url           dom.URL
	options       html.WorkerOptions
	outside       html.SerializedEnvironmentSettingsObject
	creation_time f64
	is_shared     bool
}

struct WorkerStartupBlob {
	entry ?liburl.BlobURLEntry
}

fn validate_worker_startup_time(value f64) ! {
	if math.is_nan(value) || math.is_inf(value, 0) || value < 0 {
		return error('Invalid worker creation time')
	}
}

pub fn encode_worker_startup(startup WorkerStartup) ![]u8 {
	validate_worker_startup_time(startup.creation_time)!
	address := startup.url.serialize()
	liburl.parse(address) or { return error('Invalid worker startup URL') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	settings := html.encode_serialized_environment_settings_object(startup.outside)
	entry := (worker_startup_blob_entry(startup.url)!).entry
	mut blob_bytes := []u8{}
	mut blob_type := ''
	mut blob_origin := ''
	if snapshot := entry {
		object := snapshot.object
		if object is liburl.BlobURLBlob {
			blob_bytes = object.data
			blob_type = object.type_
			blob_origin = dom.origin_from_liburl(snapshot.environment.origin).serialize_for_ipc()
		}
	}
	mut length := u64(26) + u64(address.len) + u64(startup.options.name.len) + u64(settings.len)
	if entry != none {
		length += 12 + u64(blob_bytes.len) + u64(blob_type.len) + u64(blob_origin.len)
	}
	if length > u64(worker_message_max_bytes) {
		return error('Worker startup exceeds the frame limit')
	}
	mut bytes := []u8{cap: int(length)}
	bytes << if entry != none {
		if startup.is_shared { 'VXS4'.bytes() } else { 'VXS3'.bytes() }
	} else if startup.is_shared {
		'VXS2'.bytes()
	} else {
		'VXS1'.bytes()
	}
	worker_message_write_u32(mut bytes, u32(address.len))
	worker_message_write_u32(mut bytes, u32(startup.options.name.len))
	worker_message_write_u32(mut bytes, u32(settings.len))
	bytes << u8(startup.options.type_)
	bytes << u8(startup.options.credentials)
	worker_message_write_u64(mut bytes, math.f64_bits(startup.creation_time))
	bytes << address.bytes()
	bytes << startup.options.name.bytes()
	bytes << settings
	if entry != none {
		worker_message_write_u32(mut bytes, u32(blob_type.len))
		worker_message_write_u32(mut bytes, u32(blob_origin.len))
		worker_message_write_u32(mut bytes, u32(blob_bytes.len))
		bytes << blob_type.bytes()
		bytes << blob_origin.bytes()
		bytes << blob_bytes
	}
	return bytes
}

pub fn decode_worker_startup(bytes []u8) !WorkerStartup {
	if bytes.len > worker_message_max_bytes {
		return error('Worker startup exceeds the frame limit')
	}
	mut reader := WorkerMessageReader{ bytes: bytes }
	version := reader.take(4)!.bytestr()
	if version !in ['VXS1', 'VXS2', 'VXS3', 'VXS4'] {
		return error('Invalid worker startup version')
	}
	address_length := reader.read_u32()!
	name_length := reader.read_u32()!
	settings_length := reader.read_u32()!
	type_ := reader.take(1)![0]
	credentials := reader.take(1)![0]
	if type_ > u8(html.WorkerType.module_) || credentials > u8(html.WorkerCredentials.include) {
		return error('Invalid worker startup options')
	}
	creation_time := math.f64_from_bits(reader.read_u64()!)
	validate_worker_startup_time(creation_time)!
	address := reader.take(int(address_length))!.bytestr()
	mut parsed := liburl.parse(address) or { return error('Invalid worker startup URL') }
	name := reader.take(int(name_length))!.bytestr()
	settings := reader.take(int(settings_length))!
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	// Parse again in persistent storage: the caller may reset its receive arena.
	parsed = liburl.parse(address) or { return error('Invalid worker startup URL') }
	if version in ['VXS3', 'VXS4'] {
		if parsed.scheme != 'blob' { return error('Worker Blob entry requires a blob URL') }
		type_length := reader.read_u32()!
		origin_length := reader.read_u32()!
		data_length := reader.read_u32()!
		type_name := reader.take(int(type_length))!.bytestr()
		origin_name := reader.take(int(origin_length))!.bytestr()
		origin := dom.origin_from_ipc(origin_name).liburl_origin() or { return error('Invalid worker Blob origin') }
		data := reader.take(int(data_length))!
		parsed.set_blob_url_entry(liburl.BlobURLEntry{
			object:      liburl.BlobURLBlob{ type_: type_name, data: data.clone() }
			environment: liburl.BlobURLEnvironment{ origin: origin }
		})
	}
	if reader.offset != bytes.len { return error('Trailing worker startup bytes') }
	return WorkerStartup{
		url:           dom.url_from_record(parsed)
		options:       html.WorkerOptions{
			type_:       unsafe { html.WorkerType(type_) }
			credentials: unsafe { html.WorkerCredentials(credentials) }
			name:        name.clone()
		}
		outside:       html.decode_serialized_environment_settings_object(settings)!
		creation_time: creation_time
		is_shared:     version in ['VXS2', 'VXS4']
	}
}

fn worker_startup_blob_entry(address dom.URL) !WorkerStartupBlob {
	parsed := address.parsed() or { return error('Invalid worker startup URL') }
	entry := parsed.blob_url_entry() or { return WorkerStartupBlob{} }
	if parsed.scheme != 'blob' || entry.object !is liburl.BlobURLBlob {
		return error('Worker startup requires a Blob entry')
	}
	return WorkerStartupBlob{ entry: entry }
}

fn own_worker_entry_url(address dom.URL) !dom.URL {
	// The basic parser owns component strings independently of the caller.
	mut parsed := liburl.parse(address.serialize()) or { return error('Invalid worker startup URL') }
	if entry := (worker_startup_blob_entry(address)!).entry {
		object := entry.object
		if object is liburl.BlobURLBlob {
			origin_name := dom.origin_from_liburl(entry.environment.origin).serialize_for_ipc().clone()
			origin := dom.origin_from_ipc(origin_name).liburl_origin() or { return error('Invalid worker Blob origin') }
			parsed.set_blob_url_entry(liburl.BlobURLEntry{
				object:      liburl.BlobURLBlob{ type_: object.type_.clone(), data: object.data.clone() }
				environment: liburl.BlobURLEnvironment{ origin: origin }
			})
		}
	}
	return dom.url_from_record(parsed)
}
