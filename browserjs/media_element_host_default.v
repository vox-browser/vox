module browserjs

$if !darwin && !linux && !windows {
	pub fn (mut host MediaElementHost) install(mut runtime Runtime) ! {
		_ = host
		_ = runtime
		return error('Native media element binding requires the Darwin JavaScript runtime')
	}
}
