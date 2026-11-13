module platform

import vunicode

pub struct CodePointCategoryFacts {
pub:
	is_space_separator  bool
	is_punctuation      bool
	is_letter           bool
	is_number           bool
	is_symbol           bool
	is_open_punctuation bool
	is_dash_punctuation bool
}

pub fn code_point_category_facts(code_point u32) CodePointCategoryFacts {
	category := vunicode.category(code_point)
	mask := u32(1) << category
	bits := u32(if category == 12 { 1 } else { 0 }) |
		u32(if mask & vunicode.category_mask(35) != 0 { 2 } else { 0 }) |
		u32(if mask & vunicode.category_mask(32) != 0 { 4 } else { 0 }) |
		u32(if mask & vunicode.category_mask(34) != 0 { 8 } else { 0 }) |
		u32(if mask & vunicode.category_mask(36) != 0 { 16 } else { 0 }) |
		u32(if category == 20 { 32 } else { 0 }) |
		u32(if category == 19 { 64 } else { 0 })
	return CodePointCategoryFacts{
		is_space_separator:  bits & 1 != 0
		is_punctuation:      bits & 2 != 0
		is_letter:           bits & 4 != 0
		is_number:           bits & 8 != 0
		is_symbol:           bits & 16 != 0
		is_open_punctuation: bits & 32 != 0
		is_dash_punctuation: bits & 64 != 0
	}
}
