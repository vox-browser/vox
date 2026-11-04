module url

import os
import sync.stdatomic

// Keep the scanning implementation available for matched instruction controls.
const disable_url_ascii_membership = os.getenv('VOX_DISABLE_URL_ASCII_MEMBERSHIP') != ''
const url_ascii_membership_diagnostics = os.getenv('VOX_URL_ASCII_MEMBERSHIP_DIAGNOSTICS') != ''

__global url_ascii_host_reported stdatomic.AtomicVal[bool]
__global url_ascii_percent_reported stdatomic.AtomicVal[bool]

// Each bit represents an ASCII code point. The second word starts at U+0040.
// Bounds precede shifts so non-ASCII input cannot alias an ASCII character.
@[inline]
fn ascii_membership(code_point u32, lower u64, upper u64) bool {
	if code_point < 64 { return (lower >> code_point) & 1 != 0 }
	if code_point < 128 { return (upper >> (code_point - 64)) & 1 != 0 }
	return false
}

fn report_url_ascii_membership(host bool) {
	mut reported := if host { &url_ascii_host_reported } else { &url_ascii_percent_reported }
	if reported.compare_and_swap(false, true) {
		eprintln('Vox URL ASCII membership: ${if host { 'host' } else { 'percent-encode' }} masks executed')
	}
}

// WHATWG forbidden host code points: NUL, TAB, LF, CR, SP, # / : < > ? @ [ \ ] ^ |.
const host_ascii_lower = u64(0xd400800900002601)
const host_ascii_upper = u64(0x1000000078000001)

// Extra characters beyond the common C0 set. Keep each set's full membership
// here so classification does not recurse or scan dynamically sized arrays.
const fragment_ascii_lower = u64(0x5000000500000000) // SP " < >
const fragment_ascii_upper = u64(0x0000000100000000) // `
const query_ascii_lower = u64(0x5000000d00000000) // SP " # < >
const path_ascii_lower = u64(0xd000000d00000000) // query + ?
const path_ascii_upper = u64(0x2800000140000000) // ^ ` { }
const userinfo_ascii_lower = u64(0xfc00800d00000000) // path + / : ; =
const userinfo_ascii_upper = u64(0x3800000178000001) // path + @ [ \ ] |
const component_ascii_lower = u64(0xfc00987d00000000) // userinfo + $ % & + ,
const form_ascii_lower = u64(0xfc009bff00000000) // component + ! ' ( )
const form_ascii_upper = u64(0x7800000178000001) // component + ~
const encode_uri_ascii_lower = u64(0xac00ffda00000000) // ; , / ? : & = + $ - . ! ' ( ) # *
const encode_uri_ascii_upper = u64(0x4000000080000001) // @ _ ~

fn percent_encode_set_ascii_membership(code_point u32, set PercentEncodeSet) bool {
	// All nine sets encode C0 controls, DEL and non-ASCII code points.
	if code_point < 0x20 || code_point > 0x7e { return true }
	return match set {
		.c0_control { false }
		.fragment { ascii_membership(code_point, fragment_ascii_lower, fragment_ascii_upper) }
		.query { ascii_membership(code_point, query_ascii_lower, 0) }
		.special_query { code_point == `'` || ascii_membership(code_point, query_ascii_lower, 0) }
		.path { ascii_membership(code_point, path_ascii_lower, path_ascii_upper) }
		.userinfo { ascii_membership(code_point, userinfo_ascii_lower, userinfo_ascii_upper) }
		.component { ascii_membership(code_point, component_ascii_lower, userinfo_ascii_upper) }
		.application_x_www_form_urlencoded {
			ascii_membership(code_point, form_ascii_lower, form_ascii_upper)
		}
		.encode_uri {
			!is_ascii_alphanumeric(code_point) && !ascii_membership(code_point, encode_uri_ascii_lower, encode_uri_ascii_upper)
		}
	}
}
