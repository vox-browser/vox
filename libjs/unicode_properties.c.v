module libjs

#flag darwin -licucore
#flag linux -licuuc
#include <unicode/uchar.h>

fn C.u_isIDStart(code_point int) i8
fn C.u_isIDPart(code_point int) i8

// LibUnicode/CharacterTypes.cpp uses these ICU predicates too. This avoids
// treating punctuation and combining marks as letters based on block ranges.
fn unicode_id_start(code_point u32) bool {
	return code_point <= 0x10FFFF && C.u_isIDStart(int(code_point)) != 0
}

fn unicode_id_continue(code_point u32) bool {
	return code_point <= 0x10FFFF && C.u_isIDPart(int(code_point)) != 0
}
