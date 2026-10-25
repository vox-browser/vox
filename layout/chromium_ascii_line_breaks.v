module layout

// Blink's printable-ASCII compatibility table precedes Unicode line breaking.
// In particular, slash-separated identifiers stay together rather than taking
// ICU's default break after a solidus.
// third_party/blink/renderer/platform/text/character_property_data_generator.cc
fn apply_chromium_ascii_line_breaks(units []u16, mut boundaries []bool) {
	for i := 1; i < boundaries.len - 1; i++ {
		previous := units[i - 1]
		next := units[i]
		if previous < 0x21 || previous > 0x7f || next < 0x21 || next > 0x7f {
			continue
		}
		mut allowed := next in [u16(`(`), `<`, `[`, `{`] || previous in [u16(`-`), `?`]
		if next in [u16(`!`), `)`, `,`, `.`, `/`, `:`, `;`, `?`, `]`, `}`]
			|| (previous == `-` && next == `$`)
			|| (previous == `?` && next in [u16(`"`), `'`]) {
			allowed = false
		}
		if previous in [u16(`$`), `'`, `(`, `/`, `<`, `@`, `[`, `{`, 0x7f]
			|| (previous >= `0` && previous <= `9`)
			|| (previous >= `A` && previous <= `Z`)
			|| (previous >= `^` && previous <= `z`) {
			allowed = false
		}
		if previous == `-` && next >= `0` && next <= `9` {
			before := if i > 1 { units[i - 2] } else { u16(0) }
			allowed = (before >= `0` && before <= `9`)
				|| (before >= `A` && before <= `Z`) || (before >= `a` && before <= `z`)
		}
		boundaries[i] = allowed
	}
}
