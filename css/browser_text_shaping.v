module css

import platform

fn (computer &FontComputer) text_shaping_policy() platform.TextShapingPolicy {
	if document := computer.document_ {
		if document.text_shaping_policy() == .chromium { return .chromium }
	}
	return .libweb
}

fn (mut list FontCascadeList) set_text_shaping_policy(policy platform.TextShapingPolicy) {
	for index, entry in list.fonts {
		list.fonts[index] = FontCascadeEntry{
			font: PlatformFont{ ...entry.font, text_shaping_policy: policy }
			unicode_ranges: entry.unicode_ranges
		}
	}
	if list.last_resort_font != unsafe { nil } {
		list.last_resort_font = &PlatformFont{ ...list.last_resort_font, text_shaping_policy: policy }
	}
}
