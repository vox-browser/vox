module browserjs

$if !darwin && !linux {
	pub fn (mut host NavigatorHost) install(mut runtime Runtime) ! {
		return error('Native Navigator binding requires the Darwin JavaScript runtime')
	}
}
