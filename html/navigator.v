// Copyright (c) 2022-2025, the Ladybird developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Navigator.{h,cpp} and WorkerNavigator.{h,cpp}. Objects from
// optional Web APIs are lightweight identity-bearing objects until their own
// modules are translated, preserving Navigator's required lazy singleton rules.
module html

import dom
import loader
import mediacapture

// NavigatorLanguage.h. The language preferences are the process-wide ResourceLoader's, which never holds an empty
// list.
pub struct NavigatorLanguageMixin {}

// https://html.spec.whatwg.org/multipage/system-state.html#dom-navigator-language
// FIXME: Honor WebDriver BiDi emulated language.
pub fn (mixin &NavigatorLanguageMixin) language() string {
	_ = mixin
	return loader.ResourceLoader.the().preferred_languages()[0]
}

// https://html.spec.whatwg.org/multipage/system-state.html#dom-navigator-languages
// FIXME: Honor WebDriver BiDi emulated language.
pub fn (mixin &NavigatorLanguageMixin) languages() []string {
	_ = mixin
	return loader.ResourceLoader.the().preferred_languages()
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
	// The Navigator's Window's associated Document, which answers NavigatorIDMixin::navigator_id_url().
	associated_document ?&dom.Document
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
	NavigatorConcurrentHardwareMixin
	NavigatorDeviceMemoryMixin
	NavigatorIDMixin
	NavigatorLanguageMixin
	NavigatorOnLineMixin
pub:
	configuration NavigatorHostConfiguration
pub mut:
	plugin_array_             ?&PluginArray
	media_devices_            ?&mediacapture.MediaDevices
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

pub fn (navigator &Navigator) this_navigator_storage_object() &Navigator {
	return navigator
}

pub fn Navigator.create(configuration NavigatorHostConfiguration) &Navigator {
	return &Navigator{
		NavigatorIDMixin: NavigatorIDMixin{
			navigator_id_document: configuration.associated_document
		}
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

// https://w3c.github.io/mediacapture-main/#dom-navigator-mediadevices
pub fn (mut navigator Navigator) media_devices() ?&mediacapture.MediaDevices {
	if devices := navigator.media_devices_ {
		return devices
	}
	document := navigator.configuration.associated_document or { return none }
	// NB: V has no platform audio device cache yet, so the capture environment starts without devices.
	devices := mediacapture.MediaDevices.create(document, &mediacapture.MediaCaptureEnvironment{})
	navigator.media_devices_ = devices
	return devices
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
	NavigatorConcurrentHardwareMixin
	NavigatorDeviceMemoryMixin
	NavigatorIDMixin
	NavigatorLanguageMixin
	NavigatorOnLineMixin
pub mut:
	media_capabilities_       ?&NavigatorCapability
	serial_                   ?&NavigatorCapability
	service_worker_container_ ?&NavigatorCapability
}

pub fn WorkerNavigator.create(global_scope_url dom.URL) &WorkerNavigator {
	return &WorkerNavigator{
		NavigatorIDMixin: NavigatorIDMixin{
			navigator_id_global_url: global_scope_url
		}
	}
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
