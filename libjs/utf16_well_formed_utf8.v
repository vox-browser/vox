module libjs

import os

const retain_usv_utf16_repair = os.getenv('VOX_RETAIN_USV_UTF16_REPAIR') != ''
const usv_utf16_diagnostics = os.getenv('VOX_USV_UTF16_DIAGNOSTICS') != ''

__global usv_utf16_reported bool

// Equivalent to to_well_formed().str(), without a validation pass or a
// repaired UTF-16 allocation. Keep the unchecked ASCII byte-view contract.
pub fn (text Utf16String) to_well_formed_utf8() string {
	if retain_usv_utf16_repair { return text.to_well_formed().str() }
	if bytes := text.retained_ascii_bytes() { return bytes.bytestr() }
	if usv_utf16_diagnostics && !usv_utf16_reported && text.data.len >= 32 {
		usv_utf16_reported = true
		eprintln('Vox USV UTF16: encoded directly with surrogate replacement')
	}
	return encode_utf16(text.data, true)
}
