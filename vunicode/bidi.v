// Unicode 17 UAX #9 paragraph resolution. Types use the existing LibUnicode IDs.
module vunicode

struct BidiStatus {
	level         u8
	override_type int = -1
	isolate       bool
}

fn direction(level u8) u32 { return u32(level & 1) }

fn strong_direction(kind u32) u32 { return if kind in [u32(2), 5, 13] { u32(1) } else { kind } }

fn removed_bidi(kind u32) bool { return kind in [u32(11), 12, 14, 15, 16, 18] }

fn isolate_bidi(kind u32) bool { return kind in [u32(19), 20, 21] }

fn neutral_bidi(kind u32) bool { return kind in [u32(7), 8, 9, 10, 19, 20, 21, 22] }

fn first_isolate_direction(types []u32, start int) u32 {
	mut depth := 0
	for c in types[start..] {
		if isolate_bidi(c) {
			depth++
			continue
		}
		if c == 22 {
			if depth == 0 { break }
			depth--
			continue
		}
		if depth == 0 && c in [u32(0), 1, 13] { return if c == 0 { u32(0) } else { u32(1) } }
	}
	return 0
}

fn resolve_bidi_sequence(points []u32, original []u32, sequence []int, sos u32, eos u32, mut types []u32, mut levels []u8) {
	if sequence.len == 0 { return }
	// W1–W3: NSM inheritance, Arabic number context, then AL -> R.
	mut previous := sos
	mut strong := sos
	for index in sequence {
		if types[index] == 17 { types[index] = previous }
		previous = if isolate_bidi(types[index]) || types[index] == 22 {
			u32(10)
		} else {
			types[index]
		}
		if types[index] == 2 && strong == 13 { types[index] = 5 }
		if types[index] in [u32(0), 1, 13] { strong = types[index] }
		if types[index] == 13 { types[index] = 1 }
	}
	// W4–W6: number separators and terminators.
	for j in 1 .. sequence.len - 1 {
		i := sequence[j]
		a := types[sequence[j - 1]]
		b := types[sequence[j + 1]]
		if (types[i] == 3 && a == 2 && b == 2) || (types[i] == 6 && a == b && a in [
			u32(2),
			5,
		]) {
			types[i] = a
		}
	}
	mut j := 0
	for j < sequence.len {
		if types[sequence[j]] != 4 {
			j++
			continue
		}
		start := j
		for j < sequence.len && types[sequence[j]] == 4 { j++ }
		a := if start == 0 { sos } else { types[sequence[start - 1]] }
		b := if j == sequence.len { eos } else { types[sequence[j]] }
		if a == 2 || b == 2 {
			for k in start .. j { types[sequence[k]] = 2 }
		}
	}
	strong = sos
	for i in sequence {
		if types[i] in [u32(3), 4, 6] { types[i] = 10 }
		if types[i] in [u32(0), 1] { strong = types[i] }
		if types[i] == 2 && strong == 0 { types[i] = 0 }
	}
	// N0: paired brackets, including canonical bracket equivalents.
	mut opens := []int{}
	mut pairs := [][2]int{}
	for k, i in sequence {
		if types[i] != 10 { continue }
		mate, opening := bracket(points[i])
		if mate == 0 { continue }
		if opening {
			if opens.len == 63 { break }
			opens << k
		} else {
			for t := opens.len - 1; t >= 0; t-- {
				p := points[sequence[opens[t]]]
				if p == mate || (p in [u32(0x2329), 0x3008] && mate in [u32(0x2329), 0x3008]) {
					pairs << [opens[t], k]!
					opens = opens[..t].clone()
					break
				}
			}
		}
	}
	pairs.sort(a[0] < b[0])
	for pair in pairs {
		embedding := direction(levels[sequence[pair[0]]])
		mut found_embedding := false
		mut found_opposite := false
		for k in pair[0] + 1 .. pair[1] {
			c := strong_direction(types[sequence[k]])
			if c == embedding { found_embedding = true }
			if c == 1 - embedding { found_opposite = true }
		}
		mut resolved := embedding
		if !found_embedding {
			if !found_opposite { continue }
			mut before := sos
			for k := pair[0] - 1; k >= 0; k-- {
				c := strong_direction(types[sequence[k]])
				if c in [u32(0), 1] {
					before = c
					break
				}
			}
			if before == 1 - embedding { resolved = before }
		}
		for endpoint in [pair[0], pair[1]] {
			types[sequence[endpoint]] = resolved
			for k := endpoint + 1; k < sequence.len && original[sequence[k]] == 17; k++ {
				types[sequence[k]] = resolved
			}
		}
	}
	// N1–N2: neutral sequences, treating both number types as R.
	j = 0
	for j < sequence.len {
		if !neutral_bidi(types[sequence[j]]) {
			j++
			continue
		}
		start := j
		for j < sequence.len && neutral_bidi(types[sequence[j]]) { j++ }
		a := if start == 0 { sos } else { strong_direction(types[sequence[start - 1]]) }
		b := if j == sequence.len { eos } else { strong_direction(types[sequence[j]]) }
		resolved := if a == b { a } else { direction(levels[sequence[start]]) }
		for k in start .. j { types[sequence[k]] = resolved }
	}
	// I1–I2.
	for i in sequence {
		if levels[i] & 1 == 0 {
			if types[i] == 1 {
				levels[i]++
			} else if types[i] in [u32(2), 5] {
				levels[i] += 2
			}
		} else if types[i] in [u32(0), 2, 5] {
			levels[i]++
		}
	}
}

fn bidi_paragraph(points []u32, rtl bool) []u8 {
	base := if rtl { u8(1) } else { u8(0) }
	original := points.map(bidi_class(it))
	mut types := original.clone()
	mut levels := []u8{len: points.len, init: base}
	mut stack := [BidiStatus{ level: base }]
	mut overflow_isolates := 0
	mut overflow_embeddings := 0
	mut valid_isolates := 0
	mut matching := []int{len: points.len, init: -1}
	mut isolates := []int{}
	for i, c in original {
		if isolate_bidi(c) {
			isolates << i
		} else if c == 22 && isolates.len > 0 {
			matching[isolates.pop()] = i
		}
		current := stack.last()
		levels[i] = current.level
		if c in [u32(11), 12, 14, 15, 19, 20, 21] {
			is_isolate := isolate_bidi(c)
			right := c in [u32(14), 15, 21] || (c == 19 && first_isolate_direction(original, i + 1) == 1)
			new_level := if right {
				(int(current.level) + 1) | 1
			} else {
				(int(current.level) + 2) & ~1
			}
			if is_isolate && current.override_type >= 0 { types[i] = u32(current.override_type) }
			if new_level <= 125 && overflow_isolates == 0 && overflow_embeddings == 0 {
				stack << BidiStatus{u8(new_level), if c == 12 {
					0
				} else if c == 15 {
					1
				} else {
					-1
				}, is_isolate}
				if is_isolate { valid_isolates++ }
			} else if is_isolate {
				overflow_isolates++
			} else if overflow_isolates == 0 {
				overflow_embeddings++
			}
		} else if c == 22 {
			if overflow_isolates > 0 {
				overflow_isolates--
			} else if valid_isolates > 0 {
				overflow_embeddings = 0
				for stack.len > 1 && !stack.last().isolate { stack.pop() }
				stack.pop()
				valid_isolates--
			}
			levels[i] = stack.last().level
			if stack.last().override_type >= 0 { types[i] = u32(stack.last().override_type) }
		} else if c == 16 {
			if overflow_isolates == 0 {
				if overflow_embeddings > 0 {
					overflow_embeddings--
				} else if stack.len > 1 && !stack.last().isolate {
					stack.pop()
				}
			}
		} else if c == 7 {
			levels[i] = base
			stack = [BidiStatus{ level: base }]
			overflow_isolates = 0
			overflow_embeddings = 0
			valid_isolates = 0
		} else if c != 18 && current.override_type >= 0 {
			types[i] = u32(current.override_type)
		}
	}
	// X9–X10: level runs linked through matching isolates form sequences.
	embeddings := levels.clone()
	mut runs := [][]int{}
	mut run_for := []int{len: points.len, init: -1}
	mut active := []int{}
	for i, c in original {
		if removed_bidi(c) { continue }
		if active.len == 0 || embeddings[i] != embeddings[active.last()] { runs << []int{} }
		runs[runs.len - 1] << i
		run_for[i] = runs.len - 1
		active << i
	}
	mut links := []int{len: runs.len, init: -1}
	mut linked := []bool{len: runs.len}
	for r, run in runs {
		last := run.last()
		if isolate_bidi(original[last]) && matching[last] >= 0 {
			next := run_for[matching[last]]
			if next >= 0 {
				links[r] = next
				linked[next] = true
			}
		}
	}
	for r, run in runs {
		if linked[r] { continue }
		mut sequence := run.clone()
		mut next := links[r]
		for next >= 0 {
			sequence << runs[next]
			next = links[next]
		}
		first := sequence[0]
		last := sequence.last()
		mut before := base
		mut after := base
		for k := first - 1; k >= 0; k-- {
			if !removed_bidi(original[k]) {
				before = embeddings[k]
				break
			}
		}
		if !isolate_bidi(original[last]) {
			for k := last + 1; k < points.len; k++ {
				if !removed_bidi(original[k]) {
					after = embeddings[k]
					break
				}
			}
		}
		sos := direction(if embeddings[first] > before { embeddings[first] } else { before })
		eos := direction(if embeddings[last] > after { embeddings[last] } else { after })
		resolve_bidi_sequence(points, original, sequence, sos, eos, mut types, mut levels)
	}
	// X9 characters are absent during reordering. Give their retained UTF-16
	// slots the preceding resolved level so they cannot split a visual run.
	mut preceding := base
	for i, c in original {
		if removed_bidi(c) { levels[i] = preceding } else { preceding = levels[i] }
	}
	// L1 paragraph/segment separators and trailing whitespace/format controls.
	for i, c in original {
		if c in [u32(7), 8] {
			levels[i] = base
			for k := i - 1; k >= 0 && (original[k] == 9 || removed_bidi(original[k]) || isolate_bidi(original[k]) || original[k] == 22); k-- {
				levels[k] = base
			}
		}
	}
	for k := points.len - 1; k >= 0 && (original[k] == 9 || removed_bidi(original[k]) || isolate_bidi(original[k]) || original[k] == 22); k-- {
		levels[k] = base
	}
	mut result := []u8{}
	for i, p in points {
		result << levels[i]
		if p > 0xffff { result << levels[i] }
	}
	return result
}

pub fn visual_order(levels []u8) []int {
	mut order := []int{len: levels.len, init: index}
	mut maximum := u8(0)
	mut minimum_odd := u8(255)
	for level in levels {
		if level > maximum { maximum = level }
		if level & 1 != 0 && level < minimum_odd { minimum_odd = level }
	}
	for level := int(maximum); level >= int(minimum_odd); level-- {
		mut i := 0
		for i < levels.len {
			if int(levels[i]) < level {
				i++
				continue
			}
			start := i
			for i < levels.len && int(levels[i]) >= level { i++ }
			mut a := start
			mut b := i - 1
			for a < b {
				order[a], order[b] = order[b], order[a]
				a++
				b--
			}
		}
	}
	return order
}

// Paragraph separators terminate both explicit and weak-type context (P1).
pub fn bidi_levels(points []u32, rtl bool) []u8 {
	mut result := []u8{}
	mut start := 0
	for i, p in points {
		if bidi_class(p) == 7 {
			result << bidi_paragraph(points[start..i + 1], rtl)
			start = i + 1
		}
	}
	if start < points.len { result << bidi_paragraph(points[start..], rtl) }
	return result
}
