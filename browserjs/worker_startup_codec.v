// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html
import math
import platform
import url as liburl

// Private WorkerProcess frame kinds. Message payloads use VXM1; startup uses
// VXS1 and the existing self-contained HTML environment serialization.
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
	url dom.URL
	options html.WorkerOptions
	outside html.SerializedEnvironmentSettingsObject
	creation_time f64
	is_shared bool
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
	length := u64(26) + u64(address.len) + u64(startup.options.name.len) + u64(settings.len)
	if length > u64(worker_message_max_bytes) { return error('Worker startup exceeds the frame limit') }
	mut bytes := []u8{cap: int(length)}
	bytes << if startup.is_shared { 'VXS2'.bytes() } else { 'VXS1'.bytes() }
	worker_message_write_u32(mut bytes, u32(address.len))
	worker_message_write_u32(mut bytes, u32(startup.options.name.len))
	worker_message_write_u32(mut bytes, u32(settings.len))
	bytes << u8(startup.options.type_)
	bytes << u8(startup.options.credentials)
	worker_message_write_u64(mut bytes, math.f64_bits(startup.creation_time))
	bytes << address.bytes()
	bytes << startup.options.name.bytes()
	bytes << settings
	return bytes
}

pub fn decode_worker_startup(bytes []u8) !WorkerStartup {
	if bytes.len > worker_message_max_bytes { return error('Worker startup exceeds the frame limit') }
	mut reader := WorkerMessageReader{bytes: bytes}
	version := reader.take(4)!.bytestr()
	if version !in ['VXS1', 'VXS2'] { return error('Invalid worker startup version') }
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
	liburl.parse(address) or { return error('Invalid worker startup URL') }
	name := reader.take(int(name_length))!.bytestr()
	settings := reader.take(int(settings_length))!
	if reader.offset != bytes.len { return error('Trailing worker startup bytes') }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	return WorkerStartup{
		url: dom.URL{value: address.clone()}
		options: html.WorkerOptions{
			type_: unsafe { html.WorkerType(type_) }
			credentials: unsafe { html.WorkerCredentials(credentials) }
			name: name.clone()
		}
		outside: html.decode_serialized_environment_settings_object(settings)!
		creation_time: creation_time
		is_shared: version == 'VXS2'
	}
}
