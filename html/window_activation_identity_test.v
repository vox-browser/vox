module html

import dom
import highresolutiontime
import math
import page

fn activation_identity_window() !(&dom.Document, &WindowModel) {
	owner := page.Page.create(1)!
	url := dom.URL{value: 'https://activation-identity.example/'}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	native := document.get_window() or { return error('missing actual Window') }
	return document, unsafe { &WindowModel(native) }
}

fn activation_identity_now(document &dom.Document) f64 {
	return highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
		time_origin: document.load_timing_info.navigation_start_time
	})
}

fn test_window_activation_native_and_typed_setters_share_source_record_and_gates() {
	mut document, mut window := activation_identity_window()!
	defer { document.finalize() }
	mut native := document.get_window()?
	activation := UserActivation.construct_impl(native)!
	settings := window.environment_settings_.settings
	assert math.is_inf(native.last_activation_timestamp, 1)
	assert math.is_inf(window.last_activation_timestamp(), 1)
	assert !window.has_sticky_activation() && !window.has_transient_activation()
	assert !activation.has_been_active() && !activation.is_active()
	assert !settings.has_transient_activation()
	assert !snapshot_source_snapshot_params(document).has_transient_activation

	now := activation_identity_now(document)
	native.set_last_activation_timestamp(now)
	assert window.last_activation_timestamp() == now
	assert window.has_sticky_activation() && window.has_transient_activation()
	assert activation.has_been_active() && activation.is_active()
	assert settings.has_transient_activation()
	assert snapshot_source_snapshot_params(document).has_transient_activation
	assert window.has_history_action_activation()
	window.set_last_history_action_activation_timestamp(now)
	assert !window.has_history_action_activation()

	window.set_last_activation_timestamp(activation_identity_now(document) - 5001)
	assert native.last_activation_timestamp == window.last_activation_timestamp()
	assert native.has_sticky_activation() && !native.has_transient_activation()
	assert window.has_sticky_activation() && !window.has_transient_activation()
	assert activation.has_been_active() && !activation.is_active()
	assert !settings.has_transient_activation()
	assert !snapshot_source_snapshot_params(document).has_transient_activation
}

fn test_window_activation_consumption_preserves_source_infinity_and_native_sticky_state() {
	mut document, mut window := activation_identity_window()!
	defer { document.finalize() }
	native := document.get_window()?
	activation := UserActivation.construct_impl(native)!
	assert math.is_inf(window.last_history_action_activation_timestamp(), 1)
	assert !window.has_history_action_activation()
	window.consume_user_activation()
	assert math.is_inf(native.last_activation_timestamp, 1)
	assert !window.has_sticky_activation() && !activation.has_been_active()
	assert !window.has_history_action_activation()

	window.set_last_activation_timestamp(activation_identity_now(document))
	assert native.has_transient_activation() && activation.is_active()
	window.consume_user_activation()
	assert math.is_inf(native.last_activation_timestamp, -1)
	assert math.is_inf(window.last_activation_timestamp(), -1)
	assert native.has_sticky_activation() && !native.has_transient_activation()
	assert window.has_sticky_activation() && !window.has_transient_activation()
	assert activation.has_been_active() && !activation.is_active()
}

fn test_window_activation_history_consumption_reads_current_native_timestamp() {
	mut document, mut window := activation_identity_window()!
	defer { document.finalize() }
	mut native := document.get_window()?
	assert !window.has_history_action_activation()
	native.set_last_activation_timestamp(42)
	assert window.has_history_action_activation()
	window.consume_history_action_user_activation()
	assert window.last_history_action_activation_timestamp() == 42
	assert !window.has_history_action_activation()
	native.set_last_activation_timestamp(84)
	assert window.has_history_action_activation()
	window.consume_history_action_user_activation()
	assert window.last_history_action_activation_timestamp() == 84
	assert !window.has_history_action_activation()
}
