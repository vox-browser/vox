module url

// Convert only a file URL's decoded path to the host filesystem representation.
// URL serialization retains the leading slash before a Windows drive letter;
// Win32 file APIs need the drive path without it. Queries/fragments are metadata.
pub fn (record &URL) to_file_path() ?string {
	return record.file_path_for_platform($if windows { true } $else { false })
}

fn (record &URL) file_path_for_platform(windows bool) ?string {
	if record.scheme != 'file' { return none }
	mut path := percent_decode(record.serialize_path()).bytestr()
	if path.contains('\x00') { return none }
	if host := record.host {
		if !host.is_empty_host() {
			if !windows { return none }
			return '//${host.serialize()}${path}'
		}
	}
	if windows && path.len >= 3 && path[0] == `/`
		&& ((path[1] >= `a` && path[1] <= `z`) || (path[1] >= `A` && path[1] <= `Z`))
		&& path[2] == `:` && (path.len == 3 || path[3] == `/`) {
		path = path[1..]
	}
	return path
}
