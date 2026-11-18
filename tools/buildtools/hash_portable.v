module buildtools

$if !macos {
	import crypto.sha256

	struct BuildDigest {
	mut:
		context &sha256.Digest
	}

	fn new_build_digest() !BuildDigest {
		return BuildDigest{context: sha256.new()}
	}

	fn (mut digest BuildDigest) add(data string) ! {
		_ = digest.context.write(data.bytes())!
	}

	fn (digest BuildDigest) hex() !string {
		return digest.context.sum([]u8{}).hex()
	}
}
