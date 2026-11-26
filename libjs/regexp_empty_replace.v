module libjs

$if test {
	__global empty_regexp_replacements_disabled bool
	__global empty_regexp_replacements_diagnostics bool
	__global empty_regexp_replacements u64
	pub fn set_empty_regexp_replacements_for_testing(enabled bool) {
		empty_regexp_replacements_disabled = !enabled
	}
	pub fn diagnose_empty_regexp_replacements_for_testing(enabled bool) u64 {
		previous := empty_regexp_replacements
		empty_regexp_replacements = 0
		empty_regexp_replacements_diagnostics = enabled
		return previous
	}
}

fn use_empty_regexp_replacements() bool {
	$if test {
		if empty_regexp_replacements_disabled { return false }
	}
	return true
}
