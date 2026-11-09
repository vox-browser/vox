
pub fn (h Header) keys() []string {
    mut result := []string{cap: h.data.len}
    for kv in h.data { result << kv.key }
    return arrays.uniq(result)
}