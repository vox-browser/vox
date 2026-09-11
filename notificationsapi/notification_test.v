module notificationsapi

import dom

fn notification_settings() NotificationSettings {
	return NotificationSettings{
		origin: dom.URL{'https://example.test/'}.origin()
		api_base_url: dom.URL{'https://example.test/base/page'}
		current_wall_time: 1234.6
	}
}

fn test_create_notification_resolves_urls_serializes_data_and_defaults_timestamp() {
	concept := Notification.create_a_notification_with_a_settings_object('Title', NotificationOptions{
		dir: .rtl
		lang: 'ar'
		body: 'Body'
		navigate: '../next'
		tag: 'thread'
		image: '/image.png'
		icon: 'icon.png'
		badge: ':// invalid'
		renotify: true
		silent: false
		require_interaction: true
		data: dom.js_string('payload')
		actions: [
			NotificationAction{
				action: 'open'
				title: 'Open'
				navigate: '/open'
			},
		]
	}, notification_settings())!
	assert concept.title == 'Title'
	assert concept.timestamp == 1235
	assert concept.navigation_url or { panic('missing URL') }.serialize() == 'https://example.test/next'
	assert concept.image_url or { panic('missing image') }.serialize() == 'https://example.test/image.png'
	assert concept.actions[0].navigation_url or { panic('missing action URL') }.serialize() == 'https://example.test/open'
}

fn test_constructor_restrictions_getters_and_structured_data() {
	Notification.construct_impl('x', NotificationOptions{}, notification_settings(), true) or {
		assert err.msg().starts_with('TypeError:')
	}
	Notification.construct('x', NotificationOptions{
		actions: [NotificationAction{ action: 'a', title: 'A' }]
	}, notification_settings(), false) or { assert err.msg().starts_with('TypeError:') }
	notification := Notification.construct('x', NotificationOptions{
		body: 'hello'
		timestamp: u64(9)
		data: dom.js_number(42)
	}, notification_settings(), false)!
	assert notification.title() == 'x'
	assert notification.body() == 'hello'
	assert notification.timestamp() == 9
	assert notification.data().number_data == 42
	assert notification.serialized_data().data.len > 0
	assert notification.direction() == .auto
	assert notification.notification_direction() == notification.dir()
	assert Notification.max_actions() == 0
}

fn test_constructor_rejects_actions_before_serializing_data() {
	unserializable := dom.JSValue{
		kind: .object
		object_data: voidptr(1)
	}
	Notification.create_for_constructor('x', NotificationOptions{
		actions: [NotificationAction{
			action: 'open'
			title: 'Open'
		}]
		data: unserializable
	}, notification_settings(), false) or {
		assert err.msg().contains('actions is not empty')
		return
	}
	assert false
}

fn test_binding_options_are_serialized_before_global_scope_creation() {
	options := Notification.options_from_bindings(NotificationOptions{
		body: 'serialized'
		navigate: '/next'
		data: dom.js_string('payload')
	})!
	assert options.data.data.len > 0
	notification := Notification.create_with_global_scope('Title', options, notification_settings(), false)!
	assert notification.body() == 'serialized'
	assert notification.navigate() == 'https://example.test/next'
	assert Notification.serialize_url_for_bindings(none) == ''
}

fn test_renotify_requires_nonempty_tag_and_enum_conversions() {
	create_a_notification('x', NotificationOptions{ renotify: true }, dom.Origin{}, dom.URL{'https://e.test/'}, 0) or { assert err.msg().starts_with('TypeError:') }
	assert notification_permission_from_string('granted')! == .granted
	assert NotificationPermission.default_.str() == 'default'
	assert notification_direction_from_string('ltr')! == .ltr
	assert NotificationDirection.rtl.str() == 'rtl'
}
