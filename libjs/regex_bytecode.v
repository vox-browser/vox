module libjs

// LibRegex/Rust/src/bytecode.rs and the PropertyKind/ResolvedProperty records
// it re-exports from LibUnicode/Rust/src/character_types.rs. Opcode payloads
// are sum variants, not executable JS bytecode or a substitute regex matcher.
pub enum RegexPropertyKind as u8 {
	script
	script_extension
	general_category
	binary_property
}

pub fn regex_property_kind_from_u8(value u8) ?RegexPropertyKind {
	return match value {
		0 { RegexPropertyKind.script }
		1 { RegexPropertyKind.script_extension }
		2 { RegexPropertyKind.general_category }
		3 { RegexPropertyKind.binary_property }
		else { none }
	}
}

pub struct RegexResolvedProperty {
pub mut:
	kind RegexPropertyKind
	id   u32
}

pub struct RegexNamedGroupEntry {
pub mut:
	name  string
	index u32
}

@[heap]
pub struct RegexProgram {
pub mut:
	instructions   []RegexInstruction
	capture_count  u32
	register_count u32 = 2
	unicode        bool
	unicode_sets   bool
	ignore_case    bool
	multiline      bool
	dot_all        bool
	named_groups   []RegexNamedGroupEntry
}

pub type RegexInstruction = RegexLiteral
	| RegexCharNoCase
	| RegexAnyChar
	| RegexBytecodeCharClass
	| RegexBuiltinCharacterClass
	| RegexUnicodePropertyData
	| RegexJump
	| RegexSplit
	| RegexSave
	| RegexClearRegister
	| RegexAssertStart
	| RegexAssertEnd
	| RegexAssertWordBoundary
	| RegexAssertNonWordBoundary
	| RegexMatch
	| RegexFail
	| RegexIndexedBackreference
	| RegexNamedBackreference
	| RegexRepeatStart
	| RegexRepeatCheck
	| RegexLookStart
	| RegexLookEnd
	| RegexPushModifiers
	| RegexPopModifiers
	| RegexNop
	| RegexStringPropertyMatch
	| RegexProgressCheck
	| RegexGreedyLoop
	| RegexLazyLoop

pub struct RegexCharNoCase {
pub mut:
	first  u32
	second u32
}

pub struct RegexAnyChar {
pub mut:
	dot_all bool
}

pub struct RegexBytecodeCharClass {
pub mut:
	ranges  []RegexCharRange
	negated bool
}

pub struct RegexUnicodePropertyData {
pub mut:
	negated  bool
	name     string
	value    ?string
	resolved ?RegexResolvedProperty
}

pub struct RegexJump {
pub mut:
	target u32
}

pub struct RegexSplit {
pub mut:
	prefer u32
	other  u32
}

pub struct RegexSave {
pub mut:
	reg u32
}

pub struct RegexClearRegister {
pub mut:
	reg u32
}

pub struct RegexAssertStart {
pub mut:
	multiline bool
}

pub struct RegexAssertEnd {
pub mut:
	multiline bool
}

pub struct RegexAssertWordBoundary {}

pub struct RegexAssertNonWordBoundary {}

pub struct RegexMatch {}

pub struct RegexFail {}

pub struct RegexRepeatStart {
pub mut:
	counter_reg u32
}

pub struct RegexRepeatCheck {
pub mut:
	counter_reg u32
	min         u32
	max         ?u32
	body        u32
	greedy      bool
}

pub struct RegexLookStart {
pub mut:
	positive bool
	forward  bool
	end      u32
}

pub struct RegexLookEnd {}

pub struct RegexPushModifiers {
pub mut:
	ignore_case ?bool
	multiline   ?bool
	dot_all     ?bool
}

pub struct RegexPopModifiers {}

pub struct RegexNop {}

pub struct RegexStringPropertyMatch {
pub mut:
	strings  []u32 // Packed [length, code points..., length, code points...].
	property RegexUnicodePropertyData
}

pub struct RegexProgressCheck {
pub mut:
	reg            u32
	clear_captures []u32
}

pub struct RegexGreedyLoop {
pub mut:
	matcher RegexSimpleMatch
	min     u32
	max     ?u32
}

pub struct RegexLazyLoop {
pub mut:
	matcher RegexSimpleMatch
	min     u32
	max     ?u32
}

pub type RegexSimpleMatch = RegexAnyChar
	| RegexLiteral
	| RegexCharNoCase
	| RegexBytecodeCharClass
	| RegexBuiltinCharacterClass
	| RegexUnicodePropertyData
	| RegexSimpleUnion

pub struct RegexSimpleUnion {
pub mut:
	left  &RegexSimpleMatch @[required]
	right &RegexSimpleMatch @[required]
}

// Rust Box equality is value equality, independent of pointer identity.
pub fn (a RegexSimpleUnion) == (b RegexSimpleUnion) bool {
	return *a.left == *b.left && *a.right == *b.right
}

pub fn RegexProgram.new() RegexProgram {
	return RegexProgram{
		register_count: 2
	}
}

pub fn (mut program RegexProgram) emit(instruction RegexInstruction) u32 {
	index := u32(program.instructions.len)
	program.instructions << instruction
	return index
}

pub fn (program RegexProgram) current_offset() u32 {
	return u32(program.instructions.len)
}

pub fn (mut program RegexProgram) patch_jump(at u32, target u32) {
	instruction := program.instructions[int(at)]
	match instruction {
		RegexJump {
			program.instructions[int(at)] = RegexJump{
				target: target
			}
			return
		}
		RegexSplit {
			if instruction.prefer == 0xffffffff {
				program.instructions[int(at)] = RegexSplit{
					...instruction
					prefer: target
				}
				return
			}
			if instruction.other == 0xffffffff {
				program.instructions[int(at)] = RegexSplit{
					...instruction
					other: target
				}
				return
			}
		}
		else {}
	}

	// Keep the source panic boundary; V's record dump replaces Rust Debug text.
	panic('cannot patch non-jump instruction: ${instruction}')
}

pub fn (program RegexProgram) clone() RegexProgram {
	return RegexProgram{
		...program
		instructions: program.instructions.map(it.clone())
		named_groups: program.named_groups.clone()
	}
}

pub fn (instruction RegexInstruction) clone() RegexInstruction {
	return match instruction {
		RegexBytecodeCharClass {
			instruction.clone()
		}
		RegexStringPropertyMatch {
			instruction.clone()
		}
		RegexProgressCheck {
			instruction.clone()
		}
		RegexGreedyLoop {
			RegexGreedyLoop{
				...instruction
				matcher: instruction.matcher.clone()
			}
		}
		RegexLazyLoop {
			RegexLazyLoop{
				...instruction
				matcher: instruction.matcher.clone()
			}
		}
		else {
			instruction
		}
	}
}

pub fn (class RegexBytecodeCharClass) clone() RegexBytecodeCharClass {
	return RegexBytecodeCharClass{
		...class
		ranges: class.ranges.clone()
	}
}

pub fn (instruction RegexStringPropertyMatch) clone() RegexStringPropertyMatch {
	return RegexStringPropertyMatch{
		...instruction
		strings: instruction.strings.clone()
	}
}

pub fn (instruction RegexProgressCheck) clone() RegexProgressCheck {
	return RegexProgressCheck{
		...instruction
		clear_captures: instruction.clear_captures.clone()
	}
}

pub fn (matcher RegexSimpleMatch) clone() RegexSimpleMatch {
	return match matcher {
		RegexBytecodeCharClass { matcher.clone() }
		RegexSimpleUnion { matcher.clone() }
		else { matcher }
	}
}

pub fn (matcher RegexSimpleUnion) clone() RegexSimpleUnion {
	return RegexSimpleUnion{
		left:  box_regex_simple_match(matcher.left.clone())
		right: box_regex_simple_match(matcher.right.clone())
	}
}

// Box::new on a sum value must allocate the tag and its value payload. Taking
// a local sum's address would leave a dangling tag after this frame returns.
fn box_regex_simple_match(matcher RegexSimpleMatch) &RegexSimpleMatch {
	return match matcher {
		RegexAnyChar { &RegexSimpleMatch(matcher) }
		RegexLiteral { &RegexSimpleMatch(matcher) }
		RegexCharNoCase { &RegexSimpleMatch(matcher) }
		RegexBytecodeCharClass { &RegexSimpleMatch(matcher) }
		RegexBuiltinCharacterClass { &RegexSimpleMatch(matcher) }
		RegexUnicodePropertyData { &RegexSimpleMatch(matcher) }
		RegexSimpleUnion { &RegexSimpleMatch(matcher) }
	}
}

// The complete bytecode.rs WTF-16 append helper: reject out-of-range values
// without changing the output, while retaining surrogate code points verbatim.
pub fn regex_append_code_point_wtf16(mut output []u16, code_point u32) ? {
	if code_point <= 0xffff {
		output << u16(code_point)
		return
	}
	if code_point > 0x10ffff { return none }
	value := code_point - 0x10000
	output << u16(0xd800) | u16(value >> 10)
	output << u16(0xdc00) | u16(value & 0x3ff)
}
