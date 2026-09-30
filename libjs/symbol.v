module libjs

// Translated from LibJS/Runtime/Symbol.{h,cpp}.

pub enum SymbolKind {
	unique
	global
	private
}

@[heap]
pub struct Symbol {
pub:
	description ?Utf16String
	kind        SymbolKind
}

pub fn Symbol.create(description ?Utf16String, kind SymbolKind) &Symbol {
	return &Symbol{
		description: description
		kind:        kind
	}
}

pub fn Symbol.create_private() &Symbol {
	return Symbol.create(none, .private)
}

pub fn (symbol &Symbol) is_global() bool {
	return symbol.kind == .global
}

pub fn (symbol &Symbol) is_private() bool {
	return symbol.kind == .private
}

// 20.4.3.3.1 SymbolDescriptiveString ( sym ), https://tc39.es/ecma262/#sec-symboldescriptivestring
pub fn (symbol &Symbol) descriptive_string() Utf16String {
	// 1. Let desc be sym's [[Description]] value.
	// 2. If desc is undefined, set desc to the empty String.
	description := symbol.description or { Utf16String.new() }
	// 4. Return the string-concatenation of "Symbol(", desc, and ")".
	return utf16_concat([utf16_string('Symbol('), description, utf16_string(')')])
}

// 20.4.5.1 KeyForSymbol ( sym ), https://tc39.es/ecma262/#sec-keyforsymbol
pub fn (symbol &Symbol) key() ?Utf16String {
	// 1. For each element e of the GlobalSymbolRegistry List, do
	//    a. If SameValue(e.[[Symbol]], sym) is true, return e.[[Key]].
	if symbol.is_global() {
		// NOTE: Global symbols should always have a description string.
		return symbol.description or { panic('global symbol without a description') }
	}
	// 2. Assert: GlobalSymbolRegistry does not currently contain an entry for sym.
	// 3. Return undefined.
	return none
}

pub fn utf16_concat(parts []Utf16String) Utf16String {
	mut units := []u16{}
	for part in parts {
		units << part.as_slice()
	}
	return Utf16String.from_slice(units)
}
