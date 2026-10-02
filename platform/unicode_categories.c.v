module platform

#flag darwin -licucore
#flag linux -licuuc
#include "unicode_categories_bridge.h"

fn C.libweb_v_code_point_category_facts(code_point u32) u32

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
	bits := C.libweb_v_code_point_category_facts(code_point)
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
