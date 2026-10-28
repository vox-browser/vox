module browserjs

import dom
import html
import math
import platform

fn worker_startup_test_record() WorkerStartup {
	address := dom.URL{value: 'https://worker-startup.test/maps/entry.js?lang=ru'}
	return WorkerStartup{
		url: address
		options: html.WorkerOptions{name: 'Санкт-Петербург 😀\x00', credentials: .include}
		creation_time: 123456.75
		outside: html.SerializedEnvironmentSettingsObject{
			creation_url: dom.URL{value: 'https://worker-startup.test/original'}
			api_base_url: dom.URL{value: 'https://worker-startup.test/assets/'}
			origin: address.origin()
			policy_container: html.SerializedPolicyContainer{referrer_policy: .no_referrer}
			global: html.SerializedWindow{associated_document: html.SerializedDocument{
				url: dom.URL{value: 'https://worker-startup.test/current#maps'}
				relevant_settings_object_is_secure_context: true
			}}
		}
	}
}

fn test_worker_startup_round_trips_options_and_the_original_parent_settings() {
	for type_ in [html.WorkerType.classic, .module_] {
		for credentials in [html.WorkerCredentials.omit, .same_origin, .include] {
			original := worker_startup_test_record()
			startup := WorkerStartup{...original, options: html.WorkerOptions{...original.options, type_: type_, credentials: credentials}}
			actual := decode_worker_startup(encode_worker_startup(startup)!)!
			assert actual.url == startup.url
			assert actual.options == startup.options
			assert actual.creation_time == startup.creation_time
			assert actual.outside.creation_url == startup.outside.creation_url
			assert actual.outside.api_base_url == startup.outside.api_base_url
			assert actual.outside.origin.is_same_origin(startup.outside.origin)
			assert actual.outside.policy_container.referrer_policy == .no_referrer
			assert actual.outside.global is html.SerializedWindow
			assert actual.outside.global.associated_document.url.serialize() == 'https://worker-startup.test/current#maps'
		}
	}
}

fn test_worker_startup_rejects_every_truncation_and_invalid_wire_metadata() {
	bytes := encode_worker_startup(worker_startup_test_record())!
	for end in 0 .. bytes.len {
		if _ := decode_worker_startup(bytes[..end]) { assert false, '${end}' }
	}
	for offset in [0, 4, 8, 12, 16, 17, 18, 26] {
		mut invalid := bytes.clone()
		invalid[offset] = 255
		if _ := decode_worker_startup(invalid) { assert false, '${offset}' }
	}
	mut trailing := bytes.clone()
	trailing << 0
	if _ := decode_worker_startup(trailing) { assert false }
}

fn test_worker_startup_rejects_nonfinite_time_invalid_url_and_oversized_frames() {
	original := worker_startup_test_record()
	for value in [-1.0, math.inf(1), math.inf(-1), math.nan()] {
		if _ := encode_worker_startup(WorkerStartup{...original, creation_time: value}) { assert false }
		mut bytes := encode_worker_startup(original)!
		mut bits := []u8{}
		worker_message_write_u64(mut bits, math.f64_bits(value))
		for i, byte in bits { bytes[18 + i] = byte }
		if _ := decode_worker_startup(bytes) { assert false }
	}
	if _ := encode_worker_startup(WorkerStartup{...original, url: dom.URL{value: 'relative.js'}}) { assert false }
	oversized := []u8{len: worker_message_max_bytes + 1}
	if _ := decode_worker_startup(oversized) { assert false }
	if _ := encode_worker_startup(WorkerStartup{...original, options: html.WorkerOptions{name: oversized.bytestr()}}) { assert false }
}

fn test_worker_startup_owns_nested_settings_after_encode_and_decode_scratch_resets() {
	mut caller := platform.begin_thread_scratch('worker startup caller')
	encoded := encode_worker_startup(worker_startup_test_record())!
	caller.finish()
	mut receiver := platform.begin_thread_scratch('worker startup receiver')
	actual := decode_worker_startup(encoded)!
	receiver.finish()
	assert actual.options.name == 'Санкт-Петербург 😀\x00'
	assert actual.url.serialize() == 'https://worker-startup.test/maps/entry.js?lang=ru'
	assert actual.outside.api_base_url.serialize() == 'https://worker-startup.test/assets/'
	assert actual.outside.global is html.SerializedWindow
	assert actual.outside.global.associated_document.url.serialize() == 'https://worker-startup.test/current#maps'
}
