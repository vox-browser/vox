module css

import platform

struct AdditionalBuiltinListStyles {
mut:
	circle            &ListStyleType = unsafe { nil }
	square            &ListStyleType = unsafe { nil }
	disclosure_open   &ListStyleType = unsafe { nil }
	disclosure_closed &ListStyleType = unsafe { nil }
}

__global css_additional_builtin_list_styles_ = AdditionalBuiltinListStyles{}

fn stored_list_style_type(value ListStyleType) &ListStyleType {
	if value.kind == .none_ && value.name == '' && value.counter_style == none {
		return unsafe { nil }
	}
	if value.kind == .counter_style && (value.name == 'disc' || value.name == 'decimal') {
		if counter := value.counter_style {
			mut builtins := builtin_counter_styles()
			if (value.name == 'disc' && counter == builtins.disc)
				|| (value.name == 'decimal' && counter == builtins.decimal) {
				persistent := platform.enter_persistent()
				defer { platform.leave_persistent(persistent) }
				if value.name == 'disc' {
					if voidptr(builtins.disc_list_style) == unsafe { nil } {
						builtins.disc_list_style = &ListStyleType{
							kind:          .counter_style
							name:          'disc'
							counter_style: builtins.disc
						}
					}
					return builtins.disc_list_style
				}
				if voidptr(builtins.decimal_list_style) == unsafe { nil } {
					builtins.decimal_list_style = &ListStyleType{
						kind:          .counter_style
						name:          'decimal'
						counter_style: builtins.decimal
					}
				}
				return builtins.decimal_list_style
			}
		}
	}
	if value.kind == .counter_style && (value.name == 'circle' || value.name == 'square'
		|| value.name == 'disclosure-open' || value.name == 'disclosure-closed') {
		if counter := value.counter_style {
			builtins := builtin_counter_styles()
			mut builtin := builtins.circle
			match value.name {
				'square' { builtin = builtins.square }
				'disclosure-open' { builtin = builtins.disclosure_open }
				'disclosure-closed' { builtin = builtins.disclosure_closed }
				else {}
			}
			// A matching name alone must not discard a caller's custom counter.
			if counter == builtin {
				mut marker := match value.name {
					'circle' { css_additional_builtin_list_styles_.circle }
					'square' { css_additional_builtin_list_styles_.square }
					'disclosure-open' { css_additional_builtin_list_styles_.disclosure_open }
					else { css_additional_builtin_list_styles_.disclosure_closed }
				}
				if voidptr(marker) != unsafe { nil } {
					return marker
				}
				persistent := platform.enter_persistent()
				defer { platform.leave_persistent(persistent) }
				// Publish canonical persistent storage, never the equal caller payload.
				name := match value.name {
					'circle' { 'circle' }
					'square' { 'square' }
					'disclosure-open' { 'disclosure-open' }
					else { 'disclosure-closed' }
				}
				marker = &ListStyleType{ kind: .counter_style, name: name, counter_style: builtin }
				match name {
					'circle' { css_additional_builtin_list_styles_.circle = marker }
					'square' { css_additional_builtin_list_styles_.square = marker }
					'disclosure-open' {
						css_additional_builtin_list_styles_.disclosure_open = marker
					}
					else { css_additional_builtin_list_styles_.disclosure_closed = marker }
				}
				return marker
			}
		}
	}
	return &ListStyleType{ ...value }
}
