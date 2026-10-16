module css

import platform

fn (computer &FontComputer) font_rendering_policy() platform.FontRenderingPolicy {
	if document := computer.document_ {
		if document.font_rendering_policy() == .chromium { return .chromium }
	}
	return .libweb
}

fn (mut list FontCascadeList) set_font_rendering_policy(policy platform.FontRenderingPolicy) {
	for index, entry in list.fonts {
		list.fonts[index] = FontCascadeEntry{
			font: PlatformFont{ ...entry.font, font_rendering_policy: policy }
			unicode_ranges: entry.unicode_ranges
		}
	}
	if list.last_resort_font != unsafe { nil } {
		list.last_resort_font = &PlatformFont{ ...list.last_resort_font, font_rendering_policy: policy }
	}
}
