// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Platform/FontPlugin.{h,cpp}. Actual font loading remains the
// host provider boundary represented by installed_font_names.
module platform

pub enum GenericFont {
	cursive
	fantasy
	monospace
	sans_serif
	serif
	ui_monospace
	ui_rounded
	ui_sans_serif
	ui_serif
}

const cursive_fallbacks = ['Comic Sans MS', 'Comic Sans', 'Apple Chancery', 'Bradley Hand',
	'Brush Script MT', 'Snell Roundhand', 'URW Chancery L', 'Dancing Script']
const fantasy_fallbacks = ['Impact', 'Luminari', 'Chalkduster', 'Jazz LET', 'Blippo', 'Stencil Std',
	'Marker Felt', 'Trattatello', 'Coming Soon']
const monospace_fallbacks = ['Andale Mono', 'Courier New', 'Courier', 'FreeMono', 'OCR A Std',
	'Noto Sans Mono', 'DejaVu Sans Mono', 'Droid Sans Mono', 'Liberation Mono']
const sans_serif_fallbacks = ['Arial', 'Helvetica', 'Verdana', 'Trebuchet MS', 'Gill Sans',
	'Noto Sans', 'Avantgarde', 'Optima', 'Arial Narrow', 'Liberation Sans', 'Roboto']
const serif_fallbacks = ['Times', 'Times New Roman', 'Didot', 'Georgia', 'Palatino', 'Bookman',
	'New Century Schoolbook', 'American Typewriter', 'Liberation Serif', 'Roman', 'Noto Serif']

pub struct Font {
pub:
	family     string
	point_size f32
	weight     int = 400
}

@[heap]
pub struct FontPlugin {
pub:
	is_layout_test_mode bool
mut:
	installed_font_names []string
	generic_font_names   map[GenericFont]string
	symbol_font_names_   []string
	default_font_name_   string
}

pub fn FontPlugin.new(is_layout_test_mode bool, installed_font_names []string, is_macos bool) &FontPlugin {
	mut plugin := &FontPlugin{
		is_layout_test_mode:  is_layout_test_mode
		installed_font_names: installed_font_names.clone()
	}
	plugin.update_generic_fonts()
	plugin.default_font_name_ = plugin.generic_font_name(.ui_sans_serif)
	plugin.symbol_font_names_ = if is_layout_test_mode {
		['Noto Emoji']
	} else if is_macos {
		['Apple Color Emoji', 'Apple Symbols']
	} else {
		['Noto Color Emoji', 'Noto Sans Symbols']
	}
	return plugin
}

fn (plugin &FontPlugin) select_font(fallbacks []string) string {
	if plugin.is_layout_test_mode {
		return 'SerenitySans'
	}
	for fallback in fallbacks {
		if fallback in plugin.installed_font_names {
			return fallback
		}
	}
	return ''
}

pub fn (mut plugin FontPlugin) update_generic_fonts() {
	plugin.generic_font_names[.cursive] = plugin.select_font(cursive_fallbacks)
	plugin.generic_font_names[.fantasy] = plugin.select_font(fantasy_fallbacks)
	plugin.generic_font_names[.monospace] = plugin.select_font(monospace_fallbacks)
	plugin.generic_font_names[.sans_serif] = plugin.select_font(sans_serif_fallbacks)
	plugin.generic_font_names[.serif] = plugin.select_font(serif_fallbacks)
	plugin.generic_font_names[.ui_monospace] = plugin.select_font(monospace_fallbacks)
	plugin.generic_font_names[.ui_rounded] = plugin.select_font(sans_serif_fallbacks)
	plugin.generic_font_names[.ui_sans_serif] = plugin.select_font(sans_serif_fallbacks)
	plugin.generic_font_names[.ui_serif] = plugin.select_font(serif_fallbacks)
}

pub fn (plugin &FontPlugin) generic_font_name(generic GenericFont) string {
	return plugin.generic_font_names[generic]
}

pub fn (plugin &FontPlugin) default_font(point_size f32) ?Font {
	if plugin.default_font_name_ == '' {
		return none
	}
	return Font{
		family:     plugin.default_font_name_
		point_size: point_size
	}
}

pub fn (plugin &FontPlugin) default_fixed_width_font() ?Font {
	family := plugin.generic_font_name(.ui_monospace)
	if family == '' {
		return none
	}
	return Font{
		family:     family
		point_size: 12
	}
}

pub fn (plugin &FontPlugin) symbol_font_names() []string {
	return plugin.symbol_font_names_.clone()
}

pub struct FontPluginRegistry {
mut:
	plugin ?&FontPlugin
}

pub fn (mut registry FontPluginRegistry) install(plugin &FontPlugin) {
	if registry.plugin != none { panic('FontPlugin already installed') }
	registry.plugin = plugin
}

pub fn (registry &FontPluginRegistry) get() &FontPlugin {
	return registry.plugin or { panic('FontPlugin is not installed') }
}
