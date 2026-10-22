module platform

import v.embed_file

// Return owned text while retiring the runtime loader's byte buffer and path
// work. Copy the descriptor so its lazy cache never points into the workspace
// after release. Production embeds already contain their bytes; development
// embeds may reload a file whose length differs from its compile-time length.
pub fn embedded_text(source embed_file.EmbedFileData) string {
	$if prealloc {
		workspace := begin_thread_scratch('embedded text input')
		local := source
		text := local.to_string()
		workspace.leave()
		owned := text.clone()
		workspace.finish()
		return owned
	} $else {
		return source.to_string()
	}
}
