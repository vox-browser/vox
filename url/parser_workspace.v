module url

import platform

// A parsed URL keeps its component strings and path vector. Input runes,
// normalization buffers, host probes and growing component strings are local
// to parsing, including when a DOM URL cache asks for a persistent result.
fn parse_url_in_workspace(input string, base ?&URL) ?URL {
	mut scratch := platform.begin_thread_scratch('URL parser')
	parsed := basic_parse_in_workspace(input, base) or {
		scratch.finish()
		return none
	}
	scratch.leave()
	owned := own_parsed_url(parsed)
	scratch.finish()
	return owned
}

fn own_url_optional_string(value ?string) ?string {
	if text := value { return text.clone() }
	return none
}

fn own_url_host(host Host) Host {
	match host {
		string { return Host(host.clone()) }
		Ipv6Host { return Host.ipv6(host.pieces.clone()) }
		Ipv4Host { return Host.ipv4(host.address) }
	}
}

fn own_url_origin(origin Origin) Origin {
	match origin {
		OriginTuple {
			return Origin.tuple(own_url_optional_string(origin.scheme), own_url_host(origin.host),
				origin.port, own_url_optional_string(origin.domain))
		}
		OpaqueOriginData { return Origin.opaque(origin.nonce, origin.type_) }
	}
}

fn own_url_blob_entry(entry ?BlobURLEntry) ?BlobURLEntry {
	value := entry or { return none }
	object := value.object
	environment := BlobURLEnvironment{ origin: own_url_origin(value.environment.origin) }
	if object is BlobURLBlob {
		return BlobURLEntry{
			object:      BlobURLBlob{ type_: object.type_.clone(), data: object.data.clone() }
			environment: environment
		}
	}
	return BlobURLEntry{ object: BlobURLMediaSource{}, environment: environment }
}

fn own_parsed_url(record &URL) URL {
	mut paths := []string{cap: record.paths.len}
	for path in record.paths { paths << path.clone() }
	return URL{
		scheme:             record.scheme.clone()
		username:           record.username.clone()
		password:           record.password.clone()
		host:               if host := record.host { ?Host(own_url_host(host)) } else { none }
		port:               record.port
		paths:              paths
		query:              own_url_optional_string(record.query)
		fragment:           own_url_optional_string(record.fragment)
		has_an_opaque_path: record.has_an_opaque_path
		blob_url_entry_:    own_url_blob_entry(record.blob_url_entry_)
	}
}
