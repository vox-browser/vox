module html

import dom

fn test_user_activation_construct_impl_and_window_state() {
	mut window := &dom.Window{}
	activation := UserActivation.construct_impl(window) or { panic(err) }
	assert !activation.has_been_active()
	assert !activation.is_active()
	window.set_last_activation_timestamp(0)
	assert activation.has_been_active()
	assert activation.is_active()
}
