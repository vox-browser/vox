module css

import platform

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
	return &ListStyleType{ ...value }
}
