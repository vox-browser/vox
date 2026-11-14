/* Exercise real external-process stack capture and preservation of old dumps. */
#define wmain browser_smoke_main
#include "test_windows_browser.c"
#undef wmain
#include <assert.h>

int wmain(int argc, wchar_t **argv) {
  if (argc == 3 && !wcscmp(argv[1], L"--dump-child")) {
    HANDLE ready = OpenEventW(EVENT_MODIFY_STATE, FALSE, argv[2]);
    if (!ready || !SetEvent(ready)) return 2;
    CloseHandle(ready);
    Sleep(INFINITE);
    return 1;
  }
  if (argc != 2 || GetFileAttributesW(argv[1]) != INVALID_FILE_ATTRIBUTES)
    return 2;
  wchar_t event_name[128], self[32768], command[32768];
  assert(swprintf(event_name, 128, L"Local\\VoxCloseDump-%lu-%llu",
                  GetCurrentProcessId(), GetTickCount64()) > 0);
  HANDLE ready = CreateEventW(NULL, TRUE, FALSE, event_name);
  assert(ready);
  DWORD length = GetModuleFileNameW(NULL, self, 32768);
  assert(length && length < 32768);
  assert(swprintf(command, 32768, L"\"%ls\" --dump-child %ls", self, event_name) > 0);
  STARTUPINFOW startup = {0};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION child = {0};
  assert(CreateProcessW(self, command, NULL, NULL, FALSE, CREATE_NO_WINDOW,
                        NULL, NULL, &startup, &child));
  CloseHandle(child.hThread);
  assert(WaitForSingleObject(ready, 120000) == WAIT_OBJECT_0);
  CloseHandle(ready);
  browser_pid = child.dwProcessId;
  assert(SetEnvironmentVariableW(L"VOX_WINDOWS_CLOSE_DUMP", argv[1]));
  capture_close_timeout(child.hProcess);

  HANDLE file = CreateFileW(argv[1], GENERIC_READ | GENERIC_WRITE, 0, NULL,
                            OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
  assert(file != INVALID_HANDLE_VALUE);
  MINIDUMP_HEADER header = {0};
  DWORD transferred = 0;
  assert(ReadFile(file, &header, sizeof(header), &transferred, NULL));
  assert(transferred == sizeof(header));
  assert(header.Signature == 0x504d444dUL && header.NumberOfStreams > 0); /* MDMP */
  assert(header.Flags & MiniDumpWithThreadInfo);
  LARGE_INTEGER zero = {0}, expected_size, actual_size;
  zero.QuadPart = header.StreamDirectoryRva;
  assert(SetFilePointerEx(file, zero, NULL, FILE_BEGIN));
  BOOL threads = FALSE, thread_info = FALSE;
  for (DWORD i = 0; i < header.NumberOfStreams; ++i) {
    MINIDUMP_DIRECTORY entry = {0};
    assert(ReadFile(file, &entry, sizeof(entry), &transferred, NULL));
    assert(transferred == sizeof(entry));
    threads |= entry.StreamType == ThreadListStream;
    thread_info |= entry.StreamType == ThreadInfoListStream;
  }
  assert(threads && thread_info);
  char const marker[] = "preserve-existing-close-dump";
  zero.QuadPart = 0;
  assert(SetFilePointerEx(file, zero, NULL, FILE_END));
  assert(WriteFile(file, marker, sizeof(marker), &transferred, NULL));
  assert(transferred == sizeof(marker));
  assert(GetFileSizeEx(file, &expected_size));
  CloseHandle(file);
  capture_close_timeout(child.hProcess);
  file = CreateFileW(argv[1], GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING,
                      FILE_ATTRIBUTE_NORMAL, NULL);
  assert(file != INVALID_HANDLE_VALUE);
  assert(GetFileSizeEx(file, &actual_size));
  assert(actual_size.QuadPart == expected_size.QuadPart);
  zero.QuadPart = -(LONGLONG)sizeof(marker);
  assert(SetFilePointerEx(file, zero, NULL, FILE_END));
  char actual_marker[sizeof(marker)] = {0};
  assert(ReadFile(file, actual_marker, sizeof(actual_marker), &transferred, NULL));
  assert(transferred == sizeof(marker) && !memcmp(marker, actual_marker, sizeof(marker)));
  CloseHandle(file);
  assert(DeleteFileW(argv[1]));
  assert(TerminateProcess(child.hProcess, 0));
  assert(WaitForSingleObject(child.hProcess, 10000) == WAIT_OBJECT_0);
  CloseHandle(child.hProcess);
  puts("PASS: external-process close dump and no-overwrite protection");
  return 0;
}
