// Copyright (c) 2023-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibUnicode/IDNA.cpp. Ladybird delegates UTS #46
// processing to ICU; this port uses the equivalent stable ICU C API.
module url

#flag darwin -licucore
#flag linux -licuuc
#include "idna_bridge.h"

fn C.libweb_v_idna_to_ascii(input &char, input_length int, strict int, output_length &int) &char
fn C.free(pointer voidptr)

// https://url.spec.whatwg.org/#concept-domain-to-ascii
pub fn domain_to_ascii(domain string, be_strict bool) ?string {
	// Preserve LibURL's ASCII fast path. xn-- labels still take the ICU path
	// so invalid Punycode is rejected.
	if !be_strict && domain.is_ascii() {
		if domain == '' {
			return none
		}
		mut needs_idna := false
		for part in domain.split('.') {
			if part.to_lower().starts_with('xn--') {
				needs_idna = true
				break
			}
		}
		if !needs_idna {
			return domain.to_lower()
		}
	}
	mut output_length := 0
	output := C.libweb_v_idna_to_ascii(domain.str, domain.len, int(be_strict), &output_length)
	if output == unsafe { nil } {
		return none
	}
	result := unsafe { tos(&u8(output), output_length).clone() }
	C.free(output)
	return result
}
