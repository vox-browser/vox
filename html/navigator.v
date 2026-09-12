// Copyright (c) 2022-2025, the Ladybird developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Navigator.{h,cpp} and WorkerNavigator.{h,cpp}. Objects from
// optional Web APIs are lightweight identity-bearing objects until their own
// modules are translated, preserving Navigator's required lazy singleton rules.
module html

pub struct NavigatorLanguageMixin {
pub:
	preferred_languages []string = ['en-US']
}

pub fn (mixin &NavigatorLanguageMixin) language() string {
	return if mixin.preferred_languages.len > 0 { mixin.preferred_languages[0] } else { '' }
}

pub fn (mixin &NavigatorLanguageMixin) languages() []string {
	return mixin.preferred_languages.clone()
}

pub struct NavigatorOnLineMixin {}

pub fn (mixin &NavigatorOnLineMixin) on_line() bool {
	_ = mixin
	return true
}

pub struct NavigatorHostConfiguration {
pub:
	pdf_viewer_supported bool
	webdriver_active     bool
}

@[heap]
pub struct NavigatorCapability {
pub:
	name string
}

@[heap]
pub struct NavigatorBatteryPromise {
pub:
	rejected       bool = true
	exception_name string = 'NotAllowedError'
	reason         string = 'Battery Status API is not yet implemented'
}

@[heap]
pub struct Navigator {
pub:
	configuration NavigatorHostConfiguration
pub mut:
	plugin_array_             ?&PluginArray
	mime_type_array_          ?&MimeTypeArray
	clipboard_                ?&NavigatorCapability
	geolocation_              ?&NavigatorCapability
	serial_                   ?&NavigatorCapability
	user_activation_          ?&NavigatorCapability
	credentials_              ?&NavigatorCapability
	service_worker_container_ ?&NavigatorCapability
	media_capabilities_       ?&NavigatorCapability
	battery_promise_          ?&NavigatorBatteryPromise
	xr_                       ?&NavigatorCapability
	beacon_context_           ?&NavigatorBeaconContext
}

pub fn (navigator &Navigator) language() string {
	_ = navigator
	return NavigatorLanguageMixin{}.language()
}

pub fn (navigator &Navigator) languages() []string {
	_ = navigator
	return NavigatorLanguageMixin{}.languages()
}

pub fn (navigator &Navigator) on_line() bool {
	_ = navigator
	return true
}

pub fn (navigator &Navigator) this_navigator_storage_object() &Navigator {
	return navigator
}

pub fn Navigator.create(configuration NavigatorHostConfiguration) &Navigator {
	return &Navigator{
		configuration: configuration
	}
}

pub fn (navigator &Navigator) cookie_enabled() bool {
	return true
}

pub fn (navigator &Navigator) java_enabled() bool {
	return false
}

pub fn (navigator &Navigator) pdf_viewer_enabled() bool {
	return navigator.configuration.pdf_viewer_supported
}

pub fn (navigator &Navigator) webdriver() bool {
	return navigator.configuration.webdriver_active
}

fn navigator_plugins(pdf_viewer_supported bool) []&Plugin {
	if !pdf_viewer_supported {
		return []&Plugin{}
	}
	mut result := []&Plugin{}
	for name in pdf_viewer_plugin_names {
		result << &Plugin{
			name_: name
		}
	}
	return result
}

fn navigator_mime_types(pdf_viewer_supported bool) []&MimeType {
	if !pdf_viewer_supported {
		return []&MimeType{}
	}
	mut result := []&MimeType{}
	for type_ in pdf_viewer_mime_types {
		result << &MimeType{
			type_: type_
		}
	}
	return result
}

pub fn (mut navigator Navigator) mime_types() &MimeTypeArray {
	if value := navigator.mime_type_array_ {
		return value
	}
	value := &MimeTypeArray{
		pdf_viewer_supported:         navigator.configuration.pdf_viewer_supported
		pdf_viewer_mime_type_objects: navigator_mime_types(navigator.configuration.pdf_viewer_supported)
	}
	navigator.mime_type_array_ = value
	return value
}

pub fn (mut navigator Navigator) plugins() &PluginArray {
	if value := navigator.plugin_array_ {
		return value
	}
	value := &PluginArray{
		pdf_viewer_supported:      navigator.configuration.pdf_viewer_supported
		pdf_viewer_plugin_objects: navigator_plugins(navigator.configuration.pdf_viewer_supported)
	}
	navigator.plugin_array_ = value
	return value
}

fn (mut navigator Navigator) capability(mut slot ?&NavigatorCapability, name string) &NavigatorCapability {
	if value := slot {
		return value
	}
	value := &NavigatorCapability{
		name: name
	}
	slot = value
	return value
}

pub fn (mut navigator Navigator) clipboard() &NavigatorCapability {
	return navigator.capability(mut navigator.clipboard_, 'clipboard')
}

pub fn (mut navigator Navigator) geolocation() &NavigatorCapability {
	return navigator.capability(mut navigator.geolocation_, 'geolocation')
}

pub fn (mut navigator Navigator) serial() &NavigatorCapability {
	return navigator.capability(mut navigator.serial_, 'serial')
}

pub fn (mut navigator Navigator) user_activation() &NavigatorCapability {
	return navigator.capability(mut navigator.user_activation_, 'userActivation')
}

pub fn (mut navigator Navigator) credentials() &NavigatorCapability {
	return navigator.capability(mut navigator.credentials_, 'credentials')
}

pub fn (mut navigator Navigator) service_worker() &NavigatorCapability {
	return navigator.capability(mut navigator.service_worker_container_, 'serviceWorker')
}

pub fn (mut navigator Navigator) media_capabilities() &NavigatorCapability {
	return navigator.capability(mut navigator.media_capabilities_, 'mediaCapabilities')
}

pub fn (mut navigator Navigator) xr() &NavigatorCapability {
	return navigator.capability(mut navigator.xr_, 'xr')
}

pub fn (mut navigator Navigator) get_battery() &NavigatorBatteryPromise {
	if value := navigator.battery_promise_ {
		return value
	}
	value := &NavigatorBatteryPromise{}
	navigator.battery_promise_ = value
	return value
}

pub fn Navigator.max_touch_points() int {
	return 0
}

@[heap]
pub struct WorkerNavigator {
pub mut:
	media_capabilities_       ?&NavigatorCapability
	serial_                   ?&NavigatorCapability
	service_worker_container_ ?&NavigatorCapability
}

pub fn WorkerNavigator.create() &WorkerNavigator {
	return &WorkerNavigator{}
}

pub fn (navigator &WorkerNavigator) this_navigator_storage_object() &WorkerNavigator {
	return navigator
}

pub fn (mut navigator WorkerNavigator) media_capabilities() &NavigatorCapability {
	if value := navigator.media_capabilities_ {
		return value
	}
	value := &NavigatorCapability{
		name: 'mediaCapabilities'
	}
	navigator.media_capabilities_ = value
	return value
}

pub fn (mut navigator WorkerNavigator) serial() &NavigatorCapability {
	if value := navigator.serial_ {
		return value
	}
	value := &NavigatorCapability{
		name: 'serial'
	}
	navigator.serial_ = value
	return value
}

pub fn (mut navigator WorkerNavigator) service_worker() &NavigatorCapability {
	if value := navigator.service_worker_container_ {
		return value
	}
	value := &NavigatorCapability{
		name: 'serviceWorker'
	}
	navigator.service_worker_container_ = value
	return value
}
