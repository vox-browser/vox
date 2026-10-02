module libjs

// LibRegex/Rust/src/ast.rs. Rust enum payloads become V sum variants with
// named payload records; Vec<char> becomes []rune. Literal u32 values retain
// WTF-16 surrogates. This is the complete AST model, not a parser or matcher.
pub struct RegexPatternAst {
pub mut:
	disjunction   RegexDisjunction
	flags         RegexAstFlags
	capture_count u32
	named_groups  []RegexNamedGroup
}

pub struct RegexNamedGroup {
pub mut:
	name  string
	index u32
}

pub struct RegexAstFlags {
pub mut:
	global       bool
	ignore_case  bool
	multiline    bool
	dot_all      bool
	unicode      bool
	unicode_sets bool
	sticky       bool
	has_indices  bool
}

pub struct RegexDisjunction {
pub mut:
	alternatives []RegexAlternative
}

pub struct RegexAlternative {
pub mut:
	terms []RegexTerm
}

pub struct RegexTerm {
pub mut:
	atom       RegexAtom
	quantifier ?RegexQuantifier
}

pub struct RegexQuantifier {
pub mut:
	min    u32
	max    ?u32
	greedy bool
}

pub fn RegexQuantifier.zero_or_more(greedy bool) RegexQuantifier {
	return RegexQuantifier{
		min:    0
		max:    none
		greedy: greedy
	}
}

pub fn RegexQuantifier.one_or_more(greedy bool) RegexQuantifier {
	return RegexQuantifier{
		min:    1
		max:    none
		greedy: greedy
	}
}

pub fn RegexQuantifier.zero_or_one(greedy bool) RegexQuantifier {
	return RegexQuantifier{
		min:    0
		max:    u32(1)
		greedy: greedy
	}
}

pub type RegexAtom = RegexLiteral
	| RegexDot
	| RegexCharacterClass
	| RegexBuiltinCharacterClass
	| RegexUnicodeProperty
	| RegexGroup
	| RegexNonCapturingGroup
	| RegexLookaround
	| RegexBackreferenceAtom
	| RegexAssertionKind
	| RegexModifierGroup

pub struct RegexLiteral {
pub mut:
	code_point u32
}

pub struct RegexDot {}

pub struct RegexCharacterClass {
pub mut:
	negated bool
	body    RegexCharacterClassBody
}

pub type RegexCharacterClassBody = RegexClassRanges | RegexClassSetExpression

pub struct RegexClassRanges {
pub mut:
	ranges []RegexCharacterClassRange
}

pub type RegexCharacterClassRange = RegexLiteral
	| RegexCharRange
	| RegexBuiltinCharacterClass
	| RegexUnicodeProperty

pub struct RegexCharRange {
pub mut:
	start u32
	end   u32
}

pub type RegexClassSetExpression = RegexClassSetUnion
	| RegexClassSetIntersection
	| RegexClassSetSubtraction

pub struct RegexClassSetUnion {
pub mut:
	operands []RegexClassSetOperand
}

pub struct RegexClassSetIntersection {
pub mut:
	operands []RegexClassSetOperand
}

pub struct RegexClassSetSubtraction {
pub mut:
	operands []RegexClassSetOperand
}

pub type RegexClassSetOperand = RegexLiteral
	| RegexCharRange
	| RegexCharacterClass
	| RegexBuiltinCharacterClass
	| RegexUnicodeProperty
	| RegexClassStringLiteral

pub struct RegexClassStringLiteral {
pub mut:
	code_points []rune
}

pub enum RegexBuiltinCharacterClass {
	digit
	non_digit
	word
	non_word
	whitespace
	non_whitespace
}

pub fn (class RegexBuiltinCharacterClass) negated() RegexBuiltinCharacterClass {
	return match class {
		.digit { RegexBuiltinCharacterClass.non_digit }
		.non_digit { RegexBuiltinCharacterClass.digit }
		.word { RegexBuiltinCharacterClass.non_word }
		.non_word { RegexBuiltinCharacterClass.word }
		.whitespace { RegexBuiltinCharacterClass.non_whitespace }
		.non_whitespace { RegexBuiltinCharacterClass.whitespace }
	}
}

pub struct RegexUnicodeProperty {
pub mut:
	negated bool
	name    string
	value   ?string
}

pub struct RegexGroup {
pub mut:
	index u32
	name  ?string
	body  RegexDisjunction
}

pub struct RegexNonCapturingGroup {
pub mut:
	body RegexDisjunction
}

pub struct RegexLookaround {
pub mut:
	kind RegexLookaroundKind
	body RegexDisjunction
}

pub enum RegexLookaroundKind {
	lookahead_positive
	lookahead_negative
	lookbehind_positive
	lookbehind_negative
}

pub type RegexBackreference = RegexIndexedBackreference | RegexNamedBackreference

pub struct RegexIndexedBackreference {
pub mut:
	index u32
}

pub struct RegexNamedBackreference {
pub mut:
	name string
}

pub struct RegexBackreferenceAtom {
pub mut:
	reference RegexBackreference
}

pub enum RegexAssertionKind {
	start_of_input
	end_of_input
	word_boundary
	non_word_boundary
}

pub struct RegexModifierGroup {
pub mut:
	add_flags    RegexModifierFlags
	remove_flags RegexModifierFlags
	body         RegexDisjunction
}

pub struct RegexModifierFlags {
pub mut:
	ignore_case bool
	multiline   bool
	dot_all     bool
}

pub fn (ranges RegexClassRanges) clone() RegexClassRanges {
	return RegexClassRanges{
		ranges: ranges.ranges.clone()
	}
}

pub fn (expression RegexClassSetUnion) clone() RegexClassSetUnion {
	return RegexClassSetUnion{
		operands: expression.operands.map(it.clone())
	}
}

pub fn (expression RegexClassSetIntersection) clone() RegexClassSetIntersection {
	return RegexClassSetIntersection{
		operands: expression.operands.map(it.clone())
	}
}

pub fn (expression RegexClassSetSubtraction) clone() RegexClassSetSubtraction {
	return RegexClassSetSubtraction{
		operands: expression.operands.map(it.clone())
	}
}

pub fn (literal RegexClassStringLiteral) clone() RegexClassStringLiteral {
	return RegexClassStringLiteral{
		code_points: literal.code_points.clone()
	}
}

pub fn (group RegexGroup) clone() RegexGroup {
	return RegexGroup{
		...group
		body: group.body.clone()
	}
}

pub fn (group RegexNonCapturingGroup) clone() RegexNonCapturingGroup {
	return RegexNonCapturingGroup{
		body: group.body.clone()
	}
}

pub fn (lookaround RegexLookaround) clone() RegexLookaround {
	return RegexLookaround{
		...lookaround
		body: lookaround.body.clone()
	}
}

pub fn (group RegexModifierGroup) clone() RegexModifierGroup {
	return RegexModifierGroup{
		...group
		body: group.body.clone()
	}
}

// Rust's derived Clone recursively owns all Vec/Box payloads. V struct copies
// share array headers, so reproduce the deep copy explicitly. Immutable UTF-8
// strings can share their storage without exposing mutable Rust String aliases.
pub fn (pattern RegexPatternAst) clone() RegexPatternAst {
	return RegexPatternAst{
		...pattern
		disjunction:  pattern.disjunction.clone()
		named_groups: pattern.named_groups.clone()
	}
}

pub fn (disjunction RegexDisjunction) clone() RegexDisjunction {
	return RegexDisjunction{
		alternatives: disjunction.alternatives.map(it.clone())
	}
}

pub fn (alternative RegexAlternative) clone() RegexAlternative {
	return RegexAlternative{
		terms: alternative.terms.map(it.clone())
	}
}

pub fn (term RegexTerm) clone() RegexTerm {
	return RegexTerm{
		...term
		atom: term.atom.clone()
	}
}

pub fn (atom RegexAtom) clone() RegexAtom {
	return match atom {
		RegexCharacterClass {
			atom.clone()
		}
		RegexGroup {
			RegexGroup{
				...atom
				body: atom.body.clone()
			}
		}
		RegexNonCapturingGroup {
			RegexNonCapturingGroup{
				body: atom.body.clone()
			}
		}
		RegexLookaround {
			RegexLookaround{
				...atom
				body: atom.body.clone()
			}
		}
		RegexModifierGroup {
			RegexModifierGroup{
				...atom
				body: atom.body.clone()
			}
		}
		else {
			atom
		}
	}
}

pub fn (class RegexCharacterClass) clone() RegexCharacterClass {
	return RegexCharacterClass{
		...class
		body: class.body.clone()
	}
}

pub fn (body RegexCharacterClassBody) clone() RegexCharacterClassBody {
	return match body {
		RegexClassRanges {
			RegexClassRanges{
				ranges: body.ranges.clone()
			}
		}
		RegexClassSetExpression {
			body.clone()
		}
	}
}

pub fn (expression RegexClassSetExpression) clone() RegexClassSetExpression {
	return match expression {
		RegexClassSetUnion {
			RegexClassSetUnion{
				operands: expression.operands.map(it.clone())
			}
		}
		RegexClassSetIntersection {
			RegexClassSetIntersection{
				operands: expression.operands.map(it.clone())
			}
		}
		RegexClassSetSubtraction {
			RegexClassSetSubtraction{
				operands: expression.operands.map(it.clone())
			}
		}
	}
}

pub fn (operand RegexClassSetOperand) clone() RegexClassSetOperand {
	return match operand {
		RegexCharacterClass {
			operand.clone()
		}
		RegexClassStringLiteral {
			RegexClassStringLiteral{
				code_points: operand.code_points.clone()
			}
		}
		else {
			operand
		}
	}
}
