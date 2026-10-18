module css

import platform
import math

// Blink's -webkit-small-control system font resolves to 13 1/3px Arial.
// Keep this at UA origin so explicit author fonts, including `inherit`, win.
// Blink's html.css also gives check boxes and radio buttons asymmetric margins.
__global chromium_control_font_stylesheet &CSSStyleSheet

fn chromium_control_font_style_sheet() &CSSStyleSheet {
	if chromium_control_font_stylesheet == unsafe { nil } {
		chromium_control_font_stylesheet = parse_css_stylesheet_with_params(ParsingParams{
			is_ua_style_sheet: .yes
		}, 'input, select, button, textarea { font: 13.3333333333333px Arial; }
textarea { font-family: monospace; }
input::placeholder, textarea::placeholder { color:#757575; }
input[type=checkbox i] { margin: 3px 3px 3px 4px; }
input[type=radio i] { margin: 3px 3px 0px 5px; }', none)
	}
	return chromium_control_font_stylesheet
}

fn (computer &FontComputer) font_rendering_policy() platform.FontRenderingPolicy {
	if document := computer.document_ {
		if document.font_rendering_policy() == .chromium { return .chromium }
	}
	return .libweb
}

fn browser_font_size_for_rendering(font_size f64) f32 {
	// FontDescription::EffectiveFontSize() floors the computed float size to
	// hundredths of a pixel, matching FontCacheKey's precision.
	return f32(math.floor(f64(f32(font_size) * f32(100)))) / 100
}

fn (mut list FontCascadeList) set_font_rendering_policy(policy platform.FontRenderingPolicy, font_size f64, slope int) {
	pixel_size := if policy == .chromium { ?f32(browser_font_size_for_rendering(font_size)) } else { none }
	italic := policy == .chromium && slope != 0
	for index, entry in list.fonts {
		list.fonts[index] = FontCascadeEntry{
			font: PlatformFont{ ...entry.font, font_rendering_policy: policy, pixel_size_override_: pixel_size, italic: italic }
			unicode_ranges: entry.unicode_ranges
		}
	}
	if list.last_resort_font != unsafe { nil } {
		list.last_resort_font = &PlatformFont{ ...list.last_resort_font, font_rendering_policy: policy, pixel_size_override_: pixel_size, italic: italic }
	}
}
