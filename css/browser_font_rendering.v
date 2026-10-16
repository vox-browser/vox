module css

import platform
import math

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

fn (mut list FontCascadeList) set_font_rendering_policy(policy platform.FontRenderingPolicy, font_size f64) {
	pixel_size := if policy == .chromium { ?f32(browser_font_size_for_rendering(font_size)) } else { none }
	for index, entry in list.fonts {
		list.fonts[index] = FontCascadeEntry{
			font: PlatformFont{ ...entry.font, font_rendering_policy: policy, pixel_size_override_: pixel_size }
			unicode_ranges: entry.unicode_ranges
		}
	}
	if list.last_resort_font != unsafe { nil } {
		list.last_resort_font = &PlatformFont{ ...list.last_resort_font, font_rendering_policy: policy, pixel_size_override_: pixel_size }
	}
}
