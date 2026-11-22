module browserui

import time
import ui2

// Pin the label and cached chrome snapshots to the executable's compilation.
pub const build_timestamp = @BUILD_TIMESTAMP
const build_time_label = format_build_time(build_timestamp.i64())

fn format_build_time(timestamp i64) string {
	built := time.unix(timestamp)
	return '${built.smonth()} ${built.day} ${built.hour:02}:${built.minute:02} UTC'
}

@[params]
pub struct StatusBarOptions {
pub:
	javascript_compilation ?int
}

pub fn status_bar(frame ui2.Rect, footer string, memory string, options StatusBarOptions) ui2.Element {
	footer_width := if frame.width > 304 { frame.width - 304 } else { 0.0 }
	compilation_label_width := if options.javascript_compilation != none && footer_width >= 140 {
		140.0
	} else {
		0.0
	}
	mut children := [
		ui2.label('footer', footer, ui2.rect(12, 0, footer_width - compilation_label_width, frame.height),
			ui2.TextStyle{ color: 0x555555, size: 12 }),
		ui2.Element{
			...ui2.label('build-time', build_time_label,
				ui2.rect(frame.width - 280, 0, 128, frame.height),
				ui2.TextStyle{ color: 0x555555, size: 12, align: .right })
			tooltip: 'Build time (UTC)'
			accessibility_label: 'Build time (UTC)'
		},
		ui2.label('memory', memory, ui2.rect(frame.width - 140, 0, 128, frame.height),
			ui2.TextStyle{ color: 0x555555, size: 12, align: .right }),
	]
	if percent := options.javascript_compilation {
		progress := ui2.linear_progress(ui2.LinearProgressConfig{
			id: 'js-compilation-progress'
			frame: ui2.rect(0, 0, frame.width, 3)
			value: f64(percent)
			loading: percent == 0
			reduce_motion: true
			color: 0x2563ab
			track_color: 0xcbd5e1
			radius: 0
			accessibility_label: 'Compiling JavaScript'
		}) or { ui2.Element{} }
		children << ui2.Element{ ...progress, tooltip: 'Compiling JavaScript' }
		if compilation_label_width > 0 {
			children << ui2.label('js-compilation-label', 'Compiling JavaScript',
				ui2.rect(12 + footer_width - compilation_label_width, 0, compilation_label_width,
					frame.height), ui2.TextStyle{color: 0x555555, size: 12, align: .right})
		}
	}
	return ui2.view('status-bar', frame, ui2.BoxStyle{ bg: 0xececec }, children)
}
