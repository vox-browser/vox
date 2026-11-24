// SPDX-License-Identifier: BSD-2-Clause
module libjs

struct BytecodeLabel {
	name Utf16String
	scope_depth int
	loop_depth int
	loop_index ?int
mut:
	breaks []u32
}

struct LoopAbruptExit {
	jump u32
	scope_depth int
	target_loop ?int
	target_label ?int
	is_continue bool
}

// Labels around nested labels all designate the same final iteration statement.
// Block labels only accept break. Parser checks remain authoritative for early
// errors; Annex B labelled function initialization is a separate runtime slice.
fn (mut generator BytecodeGenerator) labelled_statement(mut vm VM, statement &Statement) ! {
	iteration := generator.labelled_item_is_iteration(statement.kind.labelled_item or { return error('Missing labelled statement') })
	generator.labels << BytecodeLabel{name: statement.kind.label_text().clone(), scope_depth: generator.scope_depth, loop_depth: generator.loops.len, loop_index: if iteration { ?int(generator.loops.len) } else { none }}
	generator.statement(mut vm, statement.kind.labelled_item or { return error('Missing labelled statement') })!
	label := generator.labels.pop()
	for jump in label.breaks { generator.patch(jump) }
}

fn (generator &BytecodeGenerator) labelled_item_is_iteration(item &Statement) bool {
	if item.kind.tag == .labelled {
		return generator.labelled_item_is_iteration(item.kind.labelled_item or { return false })
	}
	if item.kind.tag == .block {
		if scope := item.kind.scope {
			if scope.children.len == 1 {
				child := scope.children[0]
				// The synthetic scope starts at `for`; an author block starts
				// at `{`. For-in/of child ranges instead start at `in`/`of`.
				source := generator.executable.source_code or { return false }
				offset := int(item.range.start.offset)
				return child.kind.tag in [.for_stmt, .for_in_of] && offset < source.code.data.len && source.code.data[offset] == u16(`f`)
			}
		}
	}
	return item.kind.tag in [.while_stmt, .do_while, .for_stmt, .for_in_of]
}

fn (mut generator BytecodeGenerator) loop_control_statement(statement &Statement) ! {
	is_continue := statement.kind.tag == .continue_stmt
	if target := statement.kind.target_label {
		name := *target
		for index := generator.labels.len - 1; index >= 0; index-- {
			label := generator.labels[index]
			if label.name != name { continue }
			if loop := label.loop_index { return generator.emit_loop_control(loop, none, is_continue) }
			if is_continue { return error('Continue target ${name.str()} is not an iteration statement') }
			return generator.emit_loop_control(none, index, false)
		}
		return error('Unknown loop-control label')
	}
	if generator.loops.len == 0 { return error('Loop control outside loop') }
	if is_continue {
		for index := generator.loops.len - 1; index >= 0; index-- {
			if generator.loops[index].is_iteration { return generator.emit_loop_control(index, none, true) }
		}
		return error('Continue outside iteration statement')
	}
	generator.emit_loop_control(generator.loops.len - 1, none, is_continue)!
}

fn (mut generator BytecodeGenerator) emit_loop_control(target_loop ?int, target_label ?int, is_continue bool) ! {
	boundary := if loop := target_loop { loop } else {
		label := generator.labels[target_label or { return error('Missing abrupt target') }]
		// Only loops inside the labelled block are crossed. A surrounding
		// for-of remains live when break leaves a label inside its body.
		label.loop_depth - 1
	}
	mut finalizer := -1
	if generator.finalizers.len > 0 {
		last := generator.finalizers.len - 1
		context := generator.finalizers[last]
		exits := if loop := target_loop { loop < context.loop_depth } else {
			(target_label or { return error('Missing abrupt target') }) < context.label_depth
		}
		if exits { finalizer = last }
	}
	for index := generator.loops.len - 1; index > boundary; index-- {
		if generator.loops[index].iterator == none { continue }
		if finalizer >= 0 && index < generator.finalizers[finalizer].loop_depth { break }
		jump := generator.emit(Instruction{op: .jump})
		generator.loops[index].abrupts << LoopAbruptExit{jump: jump, scope_depth: generator.scope_depth, target_loop: target_loop, target_label: target_label, is_continue: is_continue}
		return
	}
	if finalizer >= 0 {
		jump := generator.emit(Instruction{op: .jump})
		generator.finalizers[finalizer].abrupts << LoopAbruptExit{jump: jump, scope_depth: generator.scope_depth, target_loop: target_loop, target_label: target_label, is_continue: is_continue}
		return
	}
	depth := if loop := target_loop { generator.loops[loop].scope_depth } else { generator.labels[target_label or { return error('Missing label target') }].scope_depth }
	for _ in depth .. generator.scope_depth { generator.emit(Instruction{op: .leave_scope}) }
	jump := generator.emit(Instruction{op: .jump})
	if loop := target_loop {
		if is_continue { generator.loops[loop].continues << jump }
		else { generator.loops[loop].breaks << jump }
	} else { generator.labels[target_label or { return error('Missing label target') }].breaks << jump }
}
