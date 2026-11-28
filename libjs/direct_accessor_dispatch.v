module libjs

$if test {
	__global direct_accessor_dispatch_disabled bool
	pub fn set_direct_accessor_dispatch_for_testing(enabled bool) {
		direct_accessor_dispatch_disabled = !enabled
	}
}

fn use_direct_accessor_dispatch() bool {
	$if test { if direct_accessor_dispatch_disabled { return false } }
	return true
}

fn (mut vm VM) record_direct_accessor_dispatch(setter bool) {
	if mut tier := vm.native_tier {
		if tier.diagnostics {
			if setter { tier.activity.direct_accessor_sets++ }
			else { tier.activity.direct_accessor_gets++ }
		}
	}
}
