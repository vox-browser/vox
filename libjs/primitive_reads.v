module libjs

pub struct PrimitiveReadActivity {
pub:
	direct u64
	boxed  u64
}

$if test {
	__global primitive_reads_disabled_for_test bool
	__global primitive_reads_diagnostic_for_test bool
	__global primitive_reads_direct_for_test u64
	__global primitive_reads_boxed_for_test u64
	pub fn set_primitive_reads_for_testing(enabled bool) {
		primitive_reads_disabled_for_test = !enabled
	}
	pub fn diagnose_primitive_reads_for_testing(enabled bool) PrimitiveReadActivity {
		previous := PrimitiveReadActivity{primitive_reads_direct_for_test, primitive_reads_boxed_for_test}
		primitive_reads_direct_for_test = 0
		primitive_reads_boxed_for_test = 0
		primitive_reads_diagnostic_for_test = enabled
		return previous
	}
}

fn direct_primitive_read() bool {
	$if test {
		if primitive_reads_disabled_for_test {
			if primitive_reads_diagnostic_for_test { primitive_reads_boxed_for_test++ }
			return false
		}
		if primitive_reads_diagnostic_for_test { primitive_reads_direct_for_test++ }
	}
	return true
}
