// Copyright (c) 2023, Luke Wilde <lukew@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of MimeType.cpp, MimeTypeArray.cpp, Plugin.cpp, and
// PluginArray.cpp. The vectors stored on Ladybird's Window are passed to the
// methods that consume them.
module html

pub const pdf_viewer_mime_types = ['application/pdf', 'text/pdf']

pub const pdf_viewer_plugin_names = ['PDF Viewer', 'Chrome PDF Viewer', 'Chromium PDF Viewer',
	'Microsoft Edge PDF Viewer', 'WebKit built-in PDF']

@[heap]
pub struct MimeType {
pub:
	type_ string
}

pub fn (mime_type &MimeType) type_name() string {
	return mime_type.type_
}

pub fn (mime_type &MimeType) type_() string {
	return mime_type.type_
}

pub fn mime_type_type(mime_type &MimeType) string {
	return mime_type.type_
}

pub fn (mime_type &MimeType) description() string {
	return 'Portable Document Format'
}

pub fn (mime_type &MimeType) suffixes() string {
	return 'pdf'
}

pub fn (mime_type &MimeType) enabled_plugin(pdf_viewer_plugin_objects []&Plugin) &Plugin {
	assert pdf_viewer_plugin_objects.len > 0
	return pdf_viewer_plugin_objects[0]
}

@[heap]
pub struct Plugin {
pub:
	name_ string
}

pub fn (plugin &Plugin) name() string {
	return plugin.name_
}

pub fn (plugin &Plugin) description() string {
	return 'Portable Document Format'
}

pub fn (plugin &Plugin) filename() string {
	return 'internal-pdf-viewer'
}

pub fn (plugin &Plugin) supported_property_names(pdf_viewer_supported bool) []string {
	return if pdf_viewer_supported { pdf_viewer_mime_types.clone() } else { []string{} }
}

pub fn (plugin &Plugin) length(pdf_viewer_mime_type_objects []&MimeType) int {
	return pdf_viewer_mime_type_objects.len
}

pub fn (plugin &Plugin) item(index u32, pdf_viewer_mime_type_objects []&MimeType) ?&MimeType {
	if index < pdf_viewer_mime_type_objects.len {
		return pdf_viewer_mime_type_objects[index]
	}
	return none
}

pub fn (plugin &Plugin) named_item(name string, pdf_viewer_mime_type_objects []&MimeType) ?&MimeType {
	for mime_type in pdf_viewer_mime_type_objects {
		if mime_type.type_ == name {
			return mime_type
		}
	}
	return none
}

pub fn (plugin &Plugin) item_value(index int, pdf_viewer_mime_type_objects []&MimeType) ?&MimeType {
	if index < 0 {
		return none
	}
	return plugin.item(u32(index), pdf_viewer_mime_type_objects)
}

pub fn (plugin &Plugin) named_item_value(name string, pdf_viewer_mime_type_objects []&MimeType) ?&MimeType {
	return plugin.named_item(name, pdf_viewer_mime_type_objects)
}

pub struct PluginArray {
pub:
	pdf_viewer_supported      bool
	pdf_viewer_plugin_objects []&Plugin
}

pub fn (array &PluginArray) refresh() {}

pub fn (array &PluginArray) supported_property_names() []string {
	return if array.pdf_viewer_supported { pdf_viewer_plugin_names.clone() } else { []string{} }
}

pub fn (array &PluginArray) length() int {
	return array.pdf_viewer_plugin_objects.len
}

pub fn (array &PluginArray) item(index u32) ?&Plugin {
	if index < array.pdf_viewer_plugin_objects.len {
		return array.pdf_viewer_plugin_objects[index]
	}
	return none
}

pub fn (array &PluginArray) named_item(name string) ?&Plugin {
	for plugin in array.pdf_viewer_plugin_objects {
		if plugin.name_ == name {
			return plugin
		}
	}
	return none
}

pub fn (array &PluginArray) item_value(index int) ?&Plugin {
	if index < 0 {
		return none
	}
	return array.item(u32(index))
}

pub fn (array &PluginArray) named_item_value(name string) ?&Plugin {
	return array.named_item(name)
}

pub struct MimeTypeArray {
pub:
	pdf_viewer_supported         bool
	pdf_viewer_mime_type_objects []&MimeType
}

pub fn (array &MimeTypeArray) supported_property_names() []string {
	return if array.pdf_viewer_supported { pdf_viewer_mime_types.clone() } else { []string{} }
}

pub fn (array &MimeTypeArray) length() int {
	return array.pdf_viewer_mime_type_objects.len
}

pub fn (array &MimeTypeArray) item(index u32) ?&MimeType {
	if index < array.pdf_viewer_mime_type_objects.len {
		return array.pdf_viewer_mime_type_objects[index]
	}
	return none
}

pub fn (array &MimeTypeArray) named_item(name string) ?&MimeType {
	for mime_type in array.pdf_viewer_mime_type_objects {
		if mime_type.type_ == name {
			return mime_type
		}
	}
	return none
}

pub fn (array &MimeTypeArray) item_value(index int) ?&MimeType {
	if index < 0 {
		return none
	}
	return array.item(u32(index))
}

pub fn (array &MimeTypeArray) named_item_value(name string) ?&MimeType {
	return array.named_item(name)
}
