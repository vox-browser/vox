
pub fn (h Header) custom_values(key string, flags HeaderQueryConfig) []string {
    mut result := []string{}
    for kv in h.data {
        matched := if flags.exact { kv.key == key } else { header_key_eq(kv.key, key) }
        if matched { result << kv.value }
    }
    return result
}