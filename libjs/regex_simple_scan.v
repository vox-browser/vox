module libjs

// LibRegex/Rust/src/vm.rs::match_simple_scan. Greedy scans are recognized by
// the separate execution caller; this predicate returns false for that variant
// exactly as upstream. Scan execution is not supplied by this helper.
pub fn regex_match_simple_scan(scan RegexSimpleScan, code_point u32) bool {
	return match scan {
		RegexBytecodeCharClass { regex_char_in_ranges(code_point, scan.ranges) != scan.negated }
		RegexBuiltinCharacterClass { regex_match_builtin_class(code_point, scan, false) }
		RegexLiteral { code_point == scan.code_point }
		RegexGreedyLoop { false }
	}
}
