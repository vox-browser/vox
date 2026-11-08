module browserjs

import html as _

$if !darwin && !linux && !windows {
	pub fn (mut runtime Runtime) install_time_ranges_binding() ! {
		return error('Native TimeRanges bindings are currently available on macOS only')
	}

	pub fn (mut runtime Runtime) javascript_time_ranges(_ &html.TimeRanges) !voidptr {
		return error('Native TimeRanges bindings are currently available on macOS only')
	}

	pub fn (runtime &Runtime) native_time_ranges(_ voidptr) !&html.TimeRanges {
		return error('Native TimeRanges bindings are currently available on macOS only')
	}
}
