module adblock

import os
import json2
import time

struct ConcurrentFilterResult {
 error string
}

fn concurrent_filter_worker(index int, ready chan bool, start chan bool, results chan ConcurrentFilterResult) {
 ready <- true
 _ := <-start
 for _ in 0 .. 8 {
  request := Request{url: if index % 2 == 0 { 'https://securepubads.g.doubleclick.net/tag/js/gpt.js' } else { 'https://edition.cnn.com/story?title=%22quoted%22&lang=日本語' }, source_url:'https://edition.cnn.com/',request_type:'script'}
  decision := check(request)
  if decision.error != '' || decision.blocked != (index % 2 == 0) { results <- ConcurrentFilterResult{'request ${index}: ${decision}'}; return }
  response := check_response(Request{url:'https://pikabu.ru/ajax/transport',source_url:'https://pikabu.ru/',request_type:'xmlhttprequest'},[ResponseHeader{name:'llasalbbubrrl',value:'1'}])
  if response.error != '' || !response.blocked { results <- ConcurrentFilterResult{'response ${index}: ${response}'}; return }
 }
 results <- ConcurrentFilterResult{}
}

fn test_cold_parallel_filter_transport_preserves_requests_responses_and_log_records() {
 // Initialize JSC, but leave Request/Decision/header/log JSON metadata cold.
 assert evaluate_engine('1')! == '1'
 log_path := os.join_path(os.temp_dir(),'vox-cold-filter-${os.getpid()}-${time.sys_mono_now()}.jsonl')
 previous := os.getenv('VOX_ADBLOCK_LOG')
 os.setenv('VOX_ADBLOCK_LOG',log_path,true)
 defer {os.setenv('VOX_ADBLOCK_LOG',previous,true);os.rm(log_path) or {}}
 ready := chan bool{cap:24};start := chan bool{cap:24};results := chan ConcurrentFilterResult{cap:24}
 for index in 0 .. 24 {spawn concurrent_filter_worker(index,ready,start,results)}
 for _ in 0 .. 24 {_ := <-ready}
 for _ in 0 .. 24 {start <- true}
 for _ in 0 .. 24 {assert (<-results).error == ''}
 lines := os.read_lines(log_path)!
 assert lines.len == 24 * 8 * 2
 for line in lines {
  assert line.starts_with('{') && line.ends_with('}')
  record := json2.decode[map[string]json2.Any](line)!
  assert record['method'] or { json2.Any('') } == json2.Any('GET')
  assert record['error'] or { json2.Any('missing') } == json2.Any('')
  phase := (record['phase'] or { json2.Any('') }).str()
  assert phase in ['request','response']
  if phase == 'response' {assert record['blocked'] or { json2.Any(false) } == json2.Any(true)}
 }
}
