module libjs

$if test {
	__global direct_property_reads_disabled bool
	__global direct_property_reads_diagnostic bool
	__global direct_property_reads_count u64
	pub fn set_direct_property_reads_for_testing(enabled bool) { direct_property_reads_disabled = !enabled }
	pub fn diagnose_direct_property_reads_for_testing(enabled bool) u64 {
		previous := direct_property_reads_count
		direct_property_reads_count = 0
		direct_property_reads_diagnostic = enabled
		return previous
	}
}
fn use_direct_property_reads() bool {
	$if test { if direct_property_reads_disabled { return false } }
	return true
}
fn record_direct_property_read() {
	$if test { if direct_property_reads_diagnostic { direct_property_reads_count++ } }
}
