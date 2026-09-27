// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module platform

#flag darwin -licucore
#flag linux -licuuc
#include "unicode_case_bridge.h"

fn C.libweb_v_transform_utf8_case(input &char, input_length int, locale &char, transform int, output_length &int) &char
fn C.free(pointer voidptr)

pub enum TextCaseTransform {
	uppercase
	lowercase
	titlecase
}

// Apply Unicode Default Case Conversion with the language inherited by the
// rendered text. ICU accepts BCP 47 language tags here, matching LibUnicode's
// locale-sensitive casing used by Layout::TextNode.
pub fn transform_text_case(text string, locale string, transform TextCaseTransform) string {
	mut output_length := 0
	output := C.libweb_v_transform_utf8_case(text.str, text.len, locale.str, int(transform),
		&output_length)
	if output == unsafe { nil } {
		return match transform {
			.uppercase { text.to_upper() }
			.lowercase { text.to_lower() }
			.titlecase { text }
		}
	}
	result := unsafe { tos(&u8(output), output_length).clone() }
	C.free(output)
	return result
}
