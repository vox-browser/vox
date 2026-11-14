/* Reject error-page titles that merely mention the expected live document. */
#define wmain browser_smoke_main
#include "test_windows_browser.c"
#undef wmain
#include <assert.h>

int wmain(void) {
  wchar_t const *expected = L"V — The V Programming Language";
  assert(document_title_matches(expected, expected, 1));
  assert(document_title_matches(
      L"V — The V Programming Language — vox [prod · built today UTC]",
      expected, 1));
  assert(!document_title_matches(
      L"Could not load V — The V Programming Language", expected, 1));
  assert(!document_title_matches(
      L"V — The V Programming Language unavailable", expected, 1));
  assert(!document_title_matches(
      L"V — The V Programming Language — error", expected, 1));
  assert(!document_title_matches(L"", expected, 1));
  assert(!document_title_matches(L"V", expected, 1));
  assert(!document_title_matches(L" — vox [prod]", L"", 1));
  /* Existing local-fixture matching keeps its prior substring behavior. */
  assert(document_title_matches(L"prefix Windows startup passed suffix",
                                L"Windows startup passed", 0));
  puts("PASS: exact live document identity rejects error-page title matches");
  return 0;
}
