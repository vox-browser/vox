module libjs

// Literal programs live with the executable that compiled and validated them.
// Pattern operands are assigned increasing constant indices during generation.
struct RegExpLiteralProgram {
	constant_index u32
	engine         &RegexEngine
}

fn (executable &Executable) regexp_literal_engine(constant_index u32) ?&RegexEngine {
	mut low := 0
	mut high := executable.regexp_literal_programs.len
	for low < high {
		middle := low + (high - low) / 2
		entry := executable.regexp_literal_programs[middle]
		if constant_index < entry.constant_index {
			high = middle
		} else if constant_index > entry.constant_index {
			low = middle + 1
		} else {
			return entry.engine
		}
	}
	return none
}
