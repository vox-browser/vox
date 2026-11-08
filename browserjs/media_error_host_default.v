module browserjs

import html as _

$if !darwin && !linux && !windows {
	pub fn (mut runtime Runtime) install_media_error_binding() ! {
		return error('Native MediaError bindings are currently available on macOS only')
	}

	pub fn (mut runtime Runtime) javascript_media_error(_ &html.MediaError) !voidptr {
		return error('Native MediaError bindings are currently available on macOS only')
	}

	pub fn (runtime &Runtime) native_media_error(_ voidptr) !&html.MediaError {
		return error('Native MediaError bindings are currently available on macOS only')
	}
}
