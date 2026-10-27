module libjs

// LibRegex/Rust/src/vm.rs::{execute_simple_scan_into,
// execute_simple_greedy_scan_into,find_all_simple_scan}. These source fast paths
// operate on a supplied SimpleScan; they do not parse or compile a pattern.
// As in Rust, single-match callers provide at least two output slots, and
// greedy bounds satisfy the compiler's min <= max precondition.
pub fn regex_execute_simple_scan_into(program RegexProgram, input RegexInput, start uint, scan RegexSimpleScan, mut output []i32) bool {
	if scan is RegexGreedyLoop {
		return regex_execute_simple_greedy_scan_into(program, input, start, scan.matcher, scan.min,
			scan.max, mut output)
	}
	mut pos := start
	for pos < input.len() {
		point := regex_decode_code_point(program.unicode, input, pos)
		if regex_match_simple_scan(scan, point) {
			end := regex_code_point_len(program.unicode, input, pos) + pos
			output[0] = i32(pos)
			output[1] = i32(end)
			return true
		}
		pos += regex_code_point_len(program.unicode, input, pos)
	}
	return false
}

pub fn regex_execute_simple_greedy_scan_into(program RegexProgram, input RegexInput, start uint, matcher RegexSimpleMatch, minimum u32, maximum ?u32, mut output []i32) bool {
	mut pos := start
	for pos < input.len() {
		point := regex_decode_code_point(program.unicode, input, pos)
		if regex_match_simple_match(matcher, point) {
			match_start := pos
			mut count := u32(0)
			mut end := pos
			for end < input.len() {
				if limit := maximum {
					if count >= limit { break
					 }
				}
				candidate := regex_decode_code_point(program.unicode, input, end)
				if !regex_match_simple_match(matcher, candidate) { break
				 }
				end += regex_code_point_len(program.unicode, input, end)
				count++
			}
			if count >= minimum {
				output[0] = i32(match_start)
				output[1] = i32(end)
				return true
			}
			pos = end
		} else {
			pos += regex_code_point_len(program.unicode, input, pos)
		}
	}
	return false
}

pub fn regex_find_all_simple_scan(program RegexProgram, input RegexInput, start uint, scan RegexSimpleScan, mut output []i32) i32 {
	capacity := uint(output.len)
	mut count := i32(0)
	mut pos := start
	for {
		if pos > input.len() { break
		 }
		mut pair := [i32(-1), -1]
		if !regex_execute_simple_scan_into(program, input, pos, scan, mut pair) { break
		 }
		match_start := pair[0]
		match_end := pair[1]
		index := uint(count) * 2
		if index + 1 >= capacity { return -1 }
		output[int(index)] = match_start
		output[int(index + 1)] = match_end
		count++
		pos = if match_end == match_start { uint(match_end) + 1 } else { uint(match_end) }
	}
	return count
}
