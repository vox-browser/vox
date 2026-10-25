module browserhistory

import url

pub struct MostVisitedSite {
pub:
	url          string
	title        string
	favicon_url  string
	host         string
	visits       int
	last_visited i64
}

// Combine pages on the same host, including its www alias and HTTP/HTTPS
// variants. Keep distinct non-default ports separate. The latest visit supplies
// the destination and label; ties in frequency prefer the most recent site.
pub fn (store &Store) most_visited(limit int, now i64) []MostVisitedSite {
	if limit <= 0 { return []MostVisitedSite{} }
	mut sites := []MostVisitedSite{}
	mut indices := map[string]int{}
	for visit in store.visits {
		if visit.visited_at <= now - retention_seconds { continue }
		parsed := url.parse(visit.url) or { continue }
		if parsed.scheme !in ['http', 'https'] || parsed.includes_credentials() { continue }
		host := parsed.host or { continue }
		mut key := host.serialize().trim_string_left('www.')
		if key == '' { continue }
		if port := parsed.port { key += ':${port}' }
		if index := indices[key] {
			previous := sites[index]
			latest := visit.visited_at > previous.last_visited
			sites[index] = MostVisitedSite{
				...previous
				url: if latest { visit.url } else { previous.url }
				title: if latest { visit.title } else { previous.title }
				favicon_url: if latest { visit.favicon_url } else { previous.favicon_url }
				visits: previous.visits + 1
				last_visited: if latest { visit.visited_at } else { previous.last_visited }
			}
		} else {
			indices[key] = sites.len
			sites << MostVisitedSite{
				url: visit.url
				title: visit.title
				favicon_url: visit.favicon_url
				host: key
				visits: 1
				last_visited: visit.visited_at
			}
		}
	}
	sites.sort_with_compare(fn (a &MostVisitedSite, b &MostVisitedSite) int {
		if a.visits != b.visits { return if a.visits > b.visits { -1 } else { 1 } }
		if a.last_visited != b.last_visited { return if a.last_visited > b.last_visited { -1 } else { 1 } }
		return compare_strings(a.host, b.host)
	})
	return if sites.len > limit { sites[..limit].clone() } else { sites }
}
