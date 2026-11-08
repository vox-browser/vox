module browserjs

$if !darwin && !linux && !windows {
	pub fn (mut host ElementWheelHost) install(mut runtime Runtime) ! {
		_ = host
		_ = runtime
		return error('Native Element wheel binding requires the Darwin JavaScript runtime')
	}
}
