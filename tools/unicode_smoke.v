module main

import vunicode

fn main() {
	if vunicode.category(0xf8ff) != 17 { panic('Unicode smoke check failed') }
	if !vunicode.property_named(`A`, 'Alphabetic') { panic('Unicode smoke check failed') }
	if (vunicode.map_case([u16(0xdf)], '', .uppercase).units == [u16(`S`), `S`]) == false {
		panic('Unicode smoke check failed')
	}
	if (vunicode.normalize([u32(0x65), 0x301], .nfc) == [u32(0xe9)]) == false {
		panic('Unicode smoke check failed')
	}
	if (vunicode.line_boundaries([u32(0x65e5), 0x672c], 0) == [0, 1, 2]) == false {
		panic('Unicode smoke check failed')
	}
	if (vunicode.bidi_levels([u32(0x5d0), 0x5d1], true) == [u8(1), 1]) == false {
		panic('Unicode smoke check failed')
	}
	if (vunicode.idna_map([u32(0x41)], false)? == [u32(0x61)]) == false {
		panic('Unicode smoke check failed')
	}
	println('Pure V Unicode startup passed')
}
