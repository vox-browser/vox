// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of NotificationsAPI/Notification.{h,cpp,idl}.
module notificationsapi

import dom
import html
import math

pub enum NotificationPermission {
	default_
	denied
	granted
}

pub enum NotificationDirection {
	auto
	ltr
	rtl
}

pub fn notification_permission_from_string(value string) !NotificationPermission {
	return match value {
		'default' { .default_ }
		'denied' { .denied }
		'granted' { .granted }
		else { error('Invalid NotificationPermission: ${value}') }
	}
}

pub fn (permission NotificationPermission) str() string {
	return match permission {
		.default_ { 'default' }
		.denied { 'denied' }
		.granted { 'granted' }
	}
}

pub fn notification_direction_from_string(value string) !NotificationDirection {
	return match value {
		'auto' { .auto }
		'ltr' { .ltr }
		'rtl' { .rtl }
		else { error('Invalid NotificationDirection: ${value}') }
	}
}

pub fn (direction NotificationDirection) str() string {
	return match direction {
		.auto { 'auto' }
		.ltr { 'ltr' }
		.rtl { 'rtl' }
	}
}

pub struct NotificationAction {
pub:
	action   string
	title    string
	navigate ?string
	icon     ?string
}

pub struct NotificationOptions {
pub:
	dir                 NotificationDirection = .auto
	lang                string
	body                string
	navigate            ?string
	tag                 string
	image               ?string
	icon                ?string
	badge               ?string
	timestamp           ?u64
	renotify            bool
	silent              ?bool
	require_interaction bool
	data                dom.JSValue = dom.JSValue{
		kind: .null_
	}
	actions             []NotificationAction
}

pub struct ConceptNotificationAction {
pub:
	name           string
	title          string
	navigation_url ?dom.URL
	icon_url       ?dom.URL
}

pub struct ConceptNotification {
pub:
	title                          string
	direction                      NotificationDirection
	language                       string
	body                           string
	navigation_url                 ?dom.URL
	tag                            string
	data                           html.SerializationRecord
	timestamp                      u64
	origin                         dom.Origin
	renotify_preference            bool
	silent_preference              ?bool
	require_interaction_preference bool
	image_url                      ?dom.URL
	icon_url                       ?dom.URL
	badge_url                      ?dom.URL
	actions                        []ConceptNotificationAction
}

fn complete_url(value string, base_url dom.URL) ?dom.URL {
	return dom.dom_url_parse(value, base_url, 'utf-8')
}

pub fn create_a_notification(title string, options NotificationOptions, origin dom.Origin, base_url dom.URL, fallback_timestamp u64) !ConceptNotification {
	if options.renotify && options.tag == '' {
		return error('TypeError: options["tag"] cannot be empty when renotify is true')
	}
	serialized_data := html.structured_serialize_for_storage(options.data)!
	mut actions := []ConceptNotificationAction{}
	for action in options.actions {
		actions << ConceptNotificationAction{
			name:           action.action
			title:          action.title
			navigation_url: if value := action.navigate {
				complete_url(value, base_url)
			} else {
				none
			}
			icon_url:       if value := action.icon { complete_url(value, base_url) } else { none }
		}
	}
	return ConceptNotification{
		title:                          title
		direction:                      options.dir
		language:                       options.lang
		body:                           options.body
		navigation_url:                 if value := options.navigate {
			complete_url(value, base_url)
		} else {
			none
		}
		tag:                            options.tag
		data:                           html.SerializationRecord{
			data: serialized_data.data.clone()
		}
		timestamp:                      options.timestamp or { fallback_timestamp }
		origin:                         origin
		renotify_preference:            options.renotify
		silent_preference:              options.silent
		require_interaction_preference: options.require_interaction
		image_url:                      if value := options.image {
			complete_url(value, base_url)
		} else {
			none
		}
		icon_url:                       if value := options.icon {
			complete_url(value, base_url)
		} else {
			none
		}
		badge_url:                      if value := options.badge {
			complete_url(value, base_url)
		} else {
			none
		}
		actions:                        actions
	}
}

pub struct NotificationSettings {
pub:
	origin            dom.Origin
	api_base_url      dom.URL
	current_wall_time f64
}

pub fn create_a_notification_with_a_settings_object(title string, options NotificationOptions, settings NotificationSettings) !ConceptNotification {
	return create_a_notification(title, options, settings.origin, settings.api_base_url,
		u64(math.round(settings.current_wall_time)))
}

@[heap]
pub struct Notification {
	dom.EventTarget
mut:
	notification_ ConceptNotification
}

pub fn Notification.construct(title string, options NotificationOptions, settings NotificationSettings, relevant_global_is_service_worker bool) !&Notification {
	if relevant_global_is_service_worker {
		return error('TypeError: relevant global object is a ServiceWorkerGlobalScope')
	}
	if options.actions.len != 0 {
		return error('TypeError: options actions is not empty')
	}
	concept := create_a_notification_with_a_settings_object(title, options, settings)!
	return &Notification{
		EventTarget:   dom.EventTarget{}
		notification_: concept
	}
}

pub fn Notification.max_actions() u32 {
	return 0
}

pub fn (notification &Notification) title() string {
	return notification.notification_.title
}

pub fn (notification &Notification) dir() NotificationDirection {
	return notification.notification_.direction
}

pub fn (notification &Notification) lang() string {
	return notification.notification_.language
}

pub fn (notification &Notification) body() string {
	return notification.notification_.body
}

pub fn (notification &Notification) tag() string {
	return notification.notification_.tag
}

pub fn (notification &Notification) timestamp() u64 {
	return notification.notification_.timestamp
}

pub fn (notification &Notification) renotify() bool {
	return notification.notification_.renotify_preference
}

pub fn (notification &Notification) silent() ?bool {
	return notification.notification_.silent_preference
}

pub fn (notification &Notification) require_interaction() bool {
	return notification.notification_.require_interaction_preference
}

pub fn (notification &Notification) navigate() string {
	return if url := notification.notification_.navigation_url { url.serialize() } else { '' }
}

pub fn (notification &Notification) image() string {
	return if url := notification.notification_.image_url { url.serialize() } else { '' }
}

pub fn (notification &Notification) icon() string {
	return if url := notification.notification_.icon_url { url.serialize() } else { '' }
}

pub fn (notification &Notification) badge() string {
	return if url := notification.notification_.badge_url { url.serialize() } else { '' }
}

pub fn (notification &Notification) actions() []NotificationAction {
	mut actions := []NotificationAction{}
	for entry in notification.notification_.actions {
		actions << NotificationAction{
			action:   entry.name
			title:    entry.title
			navigate: if url := entry.navigation_url { url.serialize() } else { none }
			icon:     if url := entry.icon_url { url.serialize() } else { none }
		}
	}
	return actions
}

pub fn (notification &Notification) data() dom.JSValue {
	return html.structured_deserialize(notification.notification_.data) or { dom.js_null() }
}
