module layout

import os

// VOX_PAINT_PHASE_REFRESH_DIAGNOSTICS: list the entries each viewport phase
// cache refresh re-records, with the commands each one produced. Animation
// frames that change no box should refresh nothing.
const paint_phase_refresh_diagnostics = os.getenv('VOX_PAINT_PHASE_REFRESH_DIAGNOSTICS') != ''
const paint_phase_refresh_diagnostic_limit = 12

fn report_paint_phase_refresh(entries []PaintOrderEntry, selected []bool, phase_commands [][]PaintCommand) {
	mut count := 0
	mut commands := 0
	mut listed := []string{}
	for index in 0 .. entries.len {
		if index >= selected.len || !selected[index] { continue }
		count++
		mut produced := 0
		for phase in 0 .. compatibility_paint_phase_count {
			bucket := index * compatibility_paint_phase_count + phase
			if bucket < phase_commands.len { produced += phase_commands[bucket].len }
		}
		commands += produced
		if listed.len < paint_phase_refresh_diagnostic_limit {
			listed << '${paint_phase_refresh_entry_name(entries[index].box)}:${produced}'
		}
	}
	eprintln('VOX_PAINT_PHASE_REFRESH entries=${count}/${entries.len} commands=${commands} ${listed.join(' ')}')
}

fn paint_phase_refresh_entry_name(box &BlockBox) string {
	if box.layout_handle == unsafe { nil } { return 'anonymous' }
	node := unsafe { &Node(box.layout_handle) }
	dom_node := node.dom_node() or { return 'anonymous' }
	if element := dom_node.as_element() {
		class_name := element.get_attribute('class') or { '' }
		return '${element.local_name()}.${class_name.all_before(' ')}'
	}
	return if dom_node.is_text() { 'text' } else { 'node' }
}
