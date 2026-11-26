module libjs

$if test {
	__global direct_declarative_reads_disabled bool
	pub fn set_direct_declarative_reads_for_testing(enabled bool) {
		direct_declarative_reads_disabled = !enabled
	}
}

fn use_direct_declarative_reads() bool {
	$if test {
		if direct_declarative_reads_disabled { return false }
	}
	return true
}

fn (mut vm VM) record_direct_declarative_binding_read() {
	if mut tier := vm.native_tier {
		if tier.diagnostics { tier.activity.direct_declarative_binding_reads++ }
	}
}
