module devtools

import strings

pub enum Panel {
	elements
	console
}

pub enum ConsoleKind {
	log
	error
	input
	result
}

pub struct ConsoleEntry {
pub:
	kind ConsoleKind
	text string
}

const max_console_entries = 1000
const max_console_history = 100

// Host diagnostics for failed scripts start with these prefixes; everything
// else the page logged came through console.*.
pub fn console_kind_for_message(message string) ConsoleKind {
	return if message.starts_with('JavaScript') || message.starts_with('Uncaught') {
		.error
	} else {
		.log
	}
}

pub fn (mut tools DevTools) add_console(kind ConsoleKind, text string) {
	tools.console << ConsoleEntry{
		kind: kind
		text: text
	}
	if tools.console.len > max_console_entries {
		tools.console.delete(0)
	}
	tools.console_reveal = true
	tools.version++
}

// import_console appends what the page logged since the last import. The
// host's message list starts over with each document.
pub fn (mut tools DevTools) import_console(messages []string) bool {
	if messages.len < tools.console_seen {
		tools.console_seen = 0
	}
	if messages.len == tools.console_seen {
		return false
	}
	for message in messages[tools.console_seen..] {
		tools.add_console(console_kind_for_message(message), message.clone())
	}
	tools.console_seen = messages.len
	return true
}

pub fn (mut tools DevTools) clear_console() {
	tools.console = []ConsoleEntry{}
	tools.version++
}

pub fn (mut tools DevTools) remember_input(text string) {
	if text != '' && (tools.console_history.len == 0 || tools.console_history.last() != text) {
		tools.console_history << text
		if tools.console_history.len > max_console_history {
			tools.console_history.delete(0)
		}
	}
	tools.console_history_index = tools.console_history.len
}

// history_step walks earlier (`up`) or later inputs; past the newest input
// it returns an empty prompt.
pub fn (mut tools DevTools) history_step(up bool) ?string {
	if tools.console_history.len == 0 {
		return none
	}
	if up {
		if tools.console_history_index > 0 {
			tools.console_history_index--
		}
	} else if tools.console_history_index < tools.console_history.len {
		tools.console_history_index++
	}
	if tools.console_history_index >= tools.console_history.len {
		return ''
	}
	return tools.console_history[tools.console_history_index]
}

// js_string quotes text as a JavaScript string literal.
pub fn js_string(text string) string {
	mut builder := strings.new_builder(text.len + 2)
	builder.write_u8(`"`)
	for r in text.runes() {
		match r {
			`"` { builder.write_string('\\"') }
			`\\` { builder.write_string('\\\\') }
			`\n` { builder.write_string('\\n') }
			`\r` { builder.write_string('\\r') }
			`\t` { builder.write_string('\\t') }
			` ` { builder.write_string('\\u2028') }
			` ` { builder.write_string('\\u2029') }
			else {
				if r < 0x20 {
					builder.write_string('\\u00')
					builder.write_string('${int(r):02x}')
				} else {
					builder.write_rune(r)
				}
			}
		}
	}
	builder.write_u8(`"`)
	return builder.str()
}

// Formats a console result roughly as Chrome prints it: strings quoted,
// arrays and objects summarized two levels deep, nodes by tag.
const console_formatter = '(function (value) {' +
	' function format(v, depth) {' +
	'  var t = typeof v;' +
	'  if (v === null) return "null";' +
	'  if (t === "undefined") return "undefined";' +
	'  if (t === "string") return JSON.stringify(v);' +
	'  if (t === "number" || t === "boolean") return String(v);' +
	'  if (t === "bigint") return String(v) + "n";' +
	'  if (t === "symbol") return v.toString();' +
	'  if (t === "function") return "ƒ " + (v.name || "") + "()";' +
	'  try {' +
	'   if (v.nodeType === 1 && typeof v.localName === "string") {' +
	'    var tag = "<" + v.localName;' +
	'    if (v.id) tag += " id=\\"" + v.id + "\\"";' +
	'    if (typeof v.className === "string" && v.className) tag += " class=\\"" + v.className + "\\"";' +
	'    return tag + ">";' +
	'   }' +
	'   if (v.nodeType === 3) return "#text " + JSON.stringify(v.data);' +
	'   if (v.nodeType === 9) return "#document";' +
	'  } catch (e) {}' +
	'  if (v instanceof Error) return v.name + ": " + v.message;' +
	'  if (depth > 1) return Array.isArray(v) ? "Array(" + v.length + ")" : "{…}";' +
	'  if (Array.isArray(v)) {' +
	'   var items = [];' +
	'   for (var i = 0; i < v.length && i < 100; i++) items.push(format(v[i], depth + 1));' +
	'   if (v.length > 100) items.push("…");' +
	'   return (depth === 0 ? "(" + v.length + ") " : "") + "[" + items.join(", ") + "]";' +
	'  }' +
	'  var keys = [];' +
	'  try { keys = Object.keys(v); } catch (e) {}' +
	'  var parts = [];' +
	'  for (var j = 0; j < keys.length && j < 50; j++) {' +
	'   var shown;' +
	'   try { shown = format(v[keys[j]], depth + 1); } catch (e) { shown = "?"; }' +
	'   parts.push(keys[j] + ": " + shown);' +
	'  }' +
	'  if (keys.length > 50) parts.push("…");' +
	'  var name = "";' +
	'  try { if (v.constructor && v.constructor.name && v.constructor.name !== "Object") name = v.constructor.name + " "; } catch (e) {}' +
	'  return name + "{" + parts.join(", ") + "}";' +
	' }' +
	' return format(value, 0);' +
	'})'

// console_expression evaluates console input as global code (so `var` and
// function declarations persist) and returns its formatted completion value.
pub fn console_expression(source string) string {
	return '${console_formatter}((0, eval)(${js_string(source)}))'
}

// clean_console_error drops the frames JavaScriptCore reports for the
// console's own evaluation wrapper, keeping the message and page frames.
pub fn clean_console_error(message string) string {
	lines := message.split('\n').filter(it.trim_space() !in ['eval code@', 'eval@[native code]',
		'global code@', 'eval code', 'global code'])
	return lines.join('\n')
}

// console_line_count estimates wrapped lines for a monospaced message.
pub fn console_line_count(text string, columns int) int {
	mut count := 0
	for line in text.split('\n') {
		length := line.runes().len
		count += if length == 0 { 1 } else { (length + columns - 1) / columns }
	}
	return if count < 1 {
		1
	} else if count > 40 {
		40
	} else {
		count
	}
}
