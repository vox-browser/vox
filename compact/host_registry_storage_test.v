module main

import browserjs

fn test_websocket_registry_outlives_registration_arena() {
	browserjs.check_websocket_registry_storage()
}

fn test_timer_registries_outlive_registration_arena() {
	browserjs.check_timer_registry_storage()
}
