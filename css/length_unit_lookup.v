module css

import os
import sync.stdatomic

const retain_length_unit_iteration = os.getenv('VOX_RETAIN_LENGTH_UNIT_ITERATION') != ''
const length_unit_lookup_diagnostics = os.getenv('VOX_LENGTH_UNIT_LOOKUP_DIAGNOSTICS') != ''

__global packed_length_unit_reported stdatomic.AtomicVal[bool]

fn report_packed_length_unit_lookup() {
	if packed_length_unit_reported.compare_and_swap(false, true) {
		eprintln('Vox length unit lookup: packed ASCII comparison')
	}
}

// Every supported spelling contains only ASCII letters and at most five bytes.
// OR-ing bit 5 folds its uppercase letters; no other byte can become one of
// those lowercase letters. Explicit shifts keep the key independent of native
// byte order. No lowercase string, lookup table or borrowed input is retained.
fn packed_length_unit(unit string) ?LengthUnit {
	if unit.len == 0 || unit.len > 5 { return none }
	mut key := u64(0)
	for index, byte in unit {
		key |= u64(byte | u8(0x20)) << u32(index * 8)
	}
	return match key {
		u64(0x706163) { LengthUnit.cap } // cap
		u64(0x6863) { LengthUnit.ch } // ch
		u64(0x6d63) { LengthUnit.cm } // cm
		u64(0x627163) { LengthUnit.cqb } // cqb
		u64(0x687163) { LengthUnit.cqh } // cqh
		u64(0x697163) { LengthUnit.cqi } // cqi
		u64(0x78616d7163) { LengthUnit.cqmax } // cqmax
		u64(0x6e696d7163) { LengthUnit.cqmin } // cqmin
		u64(0x777163) { LengthUnit.cqw } // cqw
		u64(0x627664) { LengthUnit.dvb } // dvb
		u64(0x687664) { LengthUnit.dvh } // dvh
		u64(0x697664) { LengthUnit.dvi } // dvi
		u64(0x78616d7664) { LengthUnit.dvmax } // dvmax
		u64(0x6e696d7664) { LengthUnit.dvmin } // dvmin
		u64(0x777664) { LengthUnit.dvw } // dvw
		u64(0x6d65) { LengthUnit.em } // em
		u64(0x7865) { LengthUnit.ex } // ex
		u64(0x6369) { LengthUnit.ic } // ic
		u64(0x6e69) { LengthUnit.in_ } // in
		u64(0x686c) { LengthUnit.lh } // lh
		u64(0x62766c) { LengthUnit.lvb } // lvb
		u64(0x68766c) { LengthUnit.lvh } // lvh
		u64(0x69766c) { LengthUnit.lvi } // lvi
		u64(0x78616d766c) { LengthUnit.lvmax } // lvmax
		u64(0x6e696d766c) { LengthUnit.lvmin } // lvmin
		u64(0x77766c) { LengthUnit.lvw } // lvw
		u64(0x6d6d) { LengthUnit.mm } // mm
		u64(0x6370) { LengthUnit.pc } // pc
		u64(0x7470) { LengthUnit.pt } // pt
		u64(0x7870) { LengthUnit.px } // px
		u64(0x71) { LengthUnit.q } // q
		u64(0x70616372) { LengthUnit.rcap } // rcap
		u64(0x686372) { LengthUnit.rch } // rch
		u64(0x6d6572) { LengthUnit.rem } // rem
		u64(0x786572) { LengthUnit.rex } // rex
		u64(0x636972) { LengthUnit.ric } // ric
		u64(0x686c72) { LengthUnit.rlh } // rlh
		u64(0x627673) { LengthUnit.svb } // svb
		u64(0x687673) { LengthUnit.svh } // svh
		u64(0x697673) { LengthUnit.svi } // svi
		u64(0x78616d7673) { LengthUnit.svmax } // svmax
		u64(0x6e696d7673) { LengthUnit.svmin } // svmin
		u64(0x777673) { LengthUnit.svw } // svw
		u64(0x6276) { LengthUnit.vb } // vb
		u64(0x6876) { LengthUnit.vh } // vh
		u64(0x6976) { LengthUnit.vi } // vi
		u64(0x78616d76) { LengthUnit.vmax } // vmax
		u64(0x6e696d76) { LengthUnit.vmin } // vmin
		u64(0x7776) { LengthUnit.vw } // vw
		else { none }
	}
}
