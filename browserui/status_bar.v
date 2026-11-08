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

pub fn status_bar(frame ui2.Rect, footer string, memory string) ui2.Element {
	footer_width := if frame.width > 304 { frame.width - 304 } else { 0.0 }
	return ui2.view('status-bar', frame, ui2.BoxStyle{ bg: 0xececec }, [
		ui2.label('footer', footer, ui2.rect(12, 0, footer_width, frame.height),
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
	])
}
