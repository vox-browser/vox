/* Native window lifecycle check. Run on the interactive desktop, inside
 * windows_runtime_guard, with a browser executable and a private fixture dir.
 */
#define WIN32_LEAN_AND_MEAN
#include <stdio.h>
#include <wchar.h>
#include <windows.h>
#include <tlhelp32.h>

static DWORD browser_pid;
static HWND browser_window;
static BOOL CALLBACK find_browser(HWND window, LPARAM unused) {
  (void)unused;
  DWORD pid = 0;
  GetWindowThreadProcessId(window, &pid);
  if (pid == browser_pid && IsWindowVisible(window) &&
      !GetWindow(window, GW_OWNER)) {
    browser_window = window;
    return FALSE;
  }
  return TRUE;
}

static int activate_browser(void) {
  if (GetForegroundWindow() == browser_window) return 1;
  /* A console test runner may not have an input queue yet. Join both
   * desktop queues while asking Windows to activate the browser. */
  MSG message;
  PeekMessageW(&message, NULL, 0, 0, PM_NOREMOVE);
  HWND foreground = GetForegroundWindow();
  DWORD thread = GetWindowThreadProcessId(foreground, NULL);
  DWORD target = GetWindowThreadProcessId(browser_window, NULL);
  DWORD self = GetCurrentThreadId();
  BOOL attached = thread && thread != self && AttachThreadInput(self, thread, TRUE);
  BOOL target_attached = target && target != self && target != thread &&
                        AttachThreadInput(self, target, TRUE);
  ShowWindow(browser_window, SW_RESTORE);
  BOOL raised = SetWindowPos(browser_window, HWND_TOPMOST, 0, 0, 0, 0,
                             SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
  SetForegroundWindow(browser_window);
  if (target_attached) AttachThreadInput(self, target, FALSE);
  if (attached) AttachThreadInput(self, thread, FALSE);
  if (!raised) return 0;
  if (GetForegroundWindow() == browser_window) return 1;
  /* Foreground-lock policy can reject programmatic activation from an
   * interactive scheduled task. Use real input in the address field, above
   * the document, and restore the cursor for the caller's document click. */
  POINT previous, point = {200, 44};
  if (!GetCursorPos(&previous) || !ClientToScreen(browser_window, &point) ||
      !SetCursorPos(point.x, point.y)) return 0;
  INPUT click[2] = {0};
  click[0].type = click[1].type = INPUT_MOUSE;
  click[0].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
  click[1].mi.dwFlags = MOUSEEVENTF_LEFTUP;
  UINT sent = SendInput(2, click, sizeof click[0]);
  SetCursorPos(previous.x, previous.y);
  if (sent != 2) return 0;
  ULONGLONG deadline = GetTickCount64() + 10000;
  while (GetTickCount64() < deadline) {
    if (GetForegroundWindow() == browser_window) return 1;
    Sleep(100);
  }
  return 0;
}

static int wait_title(HANDLE process, wchar_t const *expected) {
  ULONGLONG deadline = GetTickCount64() + 120000;
  while (GetTickCount64() < deadline) {
    if (WaitForSingleObject(process, 0) == WAIT_OBJECT_0)
      return 0;
    EnumWindows(find_browser, 0);
    wchar_t title[512] = {0};
    if (browser_window && GetWindowTextW(browser_window, title, 512) &&
        wcsstr(title, expected))
      return 1;
    Sleep(100);
  }
  wchar_t title[512] = {0};
  GetWindowTextW(browser_window, title, 512);
  fwprintf(stderr, L"Expected title %ls; got %ls\n", expected, title);
  return 0;
}

static int write_fixture(wchar_t const *path, char const *source,
                         DWORD length) {
  HANDLE file = CreateFileW(path, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
                            FILE_ATTRIBUTE_NORMAL, NULL);
  if (file == INVALID_HANDLE_VALUE)
    return 0;
  DWORD written = 0;
  int ok = WriteFile(file, source, length, &written, NULL) && written == length;
  CloseHandle(file);
  return ok;
}

static int wait_pixel(HANDLE process, int x, int y, COLORREF expected) {
  ULONGLONG deadline = GetTickCount64() + 30000;
  COLORREF last = CLR_INVALID;
  while (GetTickCount64() < deadline) {
    if (WaitForSingleObject(process, 0) == WAIT_OBJECT_0)
      return 0;
    POINT point = {x, y};
    ClientToScreen(browser_window, &point);
    HDC desktop = GetDC(NULL);
    COLORREF color = GetPixel(desktop, point.x, point.y);
    last = color;
    ReleaseDC(NULL, desktop);
    if (color == expected)
      return 1;
    Sleep(100);
  }
  fprintf(stderr, "Pixel %d,%d expected=%06lx actual=%06lx foreground=%p window=%p\n", x, y,
      (unsigned long)expected, (unsigned long)last, (void*)GetForegroundWindow(), (void*)browser_window);
  return 0;
}

static int key(WORD code, DWORD flags) {
  INPUT input = {0};
  input.type = INPUT_KEYBOARD;
  input.ki.wScan = (WORD)MapVirtualKeyW(code, MAPVK_VK_TO_VSC);
  input.ki.dwFlags = flags | KEYEVENTF_SCANCODE;
  return SendInput(1, &input, sizeof input) == 1;
}

static int enter_address(wchar_t const *address) {
  if (!activate_browser())
    return 0;
  if (!key(VK_CONTROL, 0) || !key('L', 0) || !key('L', KEYEVENTF_KEYUP) ||
      !key(VK_CONTROL, KEYEVENTF_KEYUP))
    return 0;
  Sleep(200);
  for (wchar_t const *p = address; *p; ++p) {
    INPUT inputs[2] = {0};
    inputs[0].type = inputs[1].type = INPUT_KEYBOARD;
    inputs[0].ki.wScan = inputs[1].ki.wScan = *p;
    inputs[0].ki.dwFlags = KEYEVENTF_UNICODE;
    inputs[1].ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
    if (SendInput(2, inputs, sizeof inputs[0]) != 2)
      return 0;
    Sleep(10);
  }
  return key(VK_RETURN, 0) && key(VK_RETURN, KEYEVENTF_KEYUP);
}

/* Locate the document below the shared chrome, then compare every canvas
 * pixel. Capturing the desktop also exercises the final D3D11 presentation. */
static int webgl_pixels(void) {
  RECT rect;
  if (!GetClientRect(browser_window, &rect) || rect.right < 128 || rect.bottom < 64)
    return 0;
  POINT origin = {0, 0};
  if (!ClientToScreen(browser_window, &origin)) return 0;
  HDC screen = GetDC(NULL), memory = CreateCompatibleDC(screen);
  BITMAPINFO info = {0};
  info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  info.bmiHeader.biWidth = rect.right;
  info.bmiHeader.biHeight = -rect.bottom;
  info.bmiHeader.biPlanes = 1;
  info.bmiHeader.biBitCount = 32;
  info.bmiHeader.biCompression = BI_RGB;
  unsigned char *pixels = NULL;
  HBITMAP bitmap = CreateDIBSection(screen, &info, DIB_RGB_COLORS,
                                  (void **)&pixels, NULL, 0);
  if (!memory || !bitmap) {
    if (memory) DeleteDC(memory);
    if (bitmap) DeleteObject(bitmap);
    ReleaseDC(NULL, screen);
    return 0;
  }
  HGDIOBJ old = SelectObject(memory, bitmap);
  int captured = BitBlt(memory, 0, 0, rect.right, rect.bottom, screen,
                       origin.x, origin.y, SRCCOPY);
  GdiFlush();
  int matched = 0;
  for (int top = 0; captured && !matched && top + 64 <= rect.bottom; ++top) {
    matched = 1;
    for (int y = 0; matched && y < 64; ++y) {
      for (int x = 0; x < 128; ++x) {
        unsigned char *p = pixels + ((size_t)(top + y) * rect.right + x) * 4;
        unsigned red = x < 64 ? (y < 32 ? 255 : 0) : (y < 32 ? 0 : 255);
        unsigned green = x < 64 ? 0 : 255;
        unsigned blue = x < 64 && y >= 32 ? 255 : 0;
        if (p[2] != red || p[1] != green || p[0] != blue) {
          matched = 0;
          break;
        }
      }
    }
  }
  SelectObject(memory, old);
  DeleteObject(bitmap);
  DeleteDC(memory);
  ReleaseDC(NULL, screen);
  return matched;
}

static int browser_uses_mesa(void) {
  HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE, browser_pid);
  if (snapshot == INVALID_HANDLE_VALUE) return 0;
  MODULEENTRY32W module = {0};
  module.dwSize = sizeof(module);
  int mesa = 0, angle = 0;
  if (Module32FirstW(snapshot, &module)) do {
    if (!lstrcmpiW(module.szModule, L"libgallium_wgl.dll")) mesa = 1;
    if (wcsstr(module.szModule, L"ANGLE") || wcsstr(module.szModule, L"angle")) angle = 1;
  } while (Module32NextW(snapshot, &module));
  CloseHandle(snapshot);
  return mesa && !angle;
}

int wmain(int argc, wchar_t **argv) {
  if (argc != 3 && argc != 4) {
    fwprintf(stderr,
             L"usage: test_windows_browser.exe BROWSER PRIVATE_FIXTURE_DIR [WEBGL_FIXTURE]\n");
    return 2;
  }
  SetProcessDPIAware();
  CreateDirectoryW(argv[2], NULL);
  wchar_t initial[32768], destination[32768], command[32768], address[32768];
  if (swprintf(initial, 32768, L"%ls\\startup.html", argv[2]) < 0 ||
      swprintf(destination, 32768, L"%ls\\keyboard space.html", argv[2]) < 0)
    return 2;
  char const first[] = "<!doctype html><title>Windows startup passed</title>"
      "<body id=\"click-target\" style=\"margin:0;background:#2ca05a;color:white;height:100vh\" "
      "onclick=\"this.style.backgroundColor='#ad394c'\"><h1>Windows startup passed</h1></body><script>globalThis.nativeInputReady=true;</script>";
  char const second[] = "<!doctype html><title>Windows address entry "
                        "passed</title><h1>Navigation passed</h1>";
  if (!write_fixture(initial, first, sizeof first - 1) ||
      !write_fixture(destination, second, sizeof second - 1))
    return 2;
  int n = swprintf(command, 32768,
                   L"\"%ls\" --enable-javascript --window-width=800 --window-height=600 \"%ls\"",
                   argv[1], initial);
  if (n < 0 || n >= 32768)
    return 2;
  STARTUPINFOW startup = {0};
  startup.cb = sizeof startup;
  startup.dwFlags = STARTF_USESTDHANDLES;
  startup.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
  startup.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
  startup.hStdError = GetStdHandle(STD_ERROR_HANDLE);
  PROCESS_INFORMATION browser = {0};
  if (!CreateProcessW(argv[1], command, NULL, NULL, TRUE, CREATE_NO_WINDOW,
                      NULL, NULL, &startup, &browser))
    return 2;
  CloseHandle(browser.hThread);
  browser_pid = browser.dwProcessId;
  int result = 1;
  char const *phase = "startup-title";
  if (!wait_title(browser.hProcess, L"Windows startup passed"))
    goto finished;
  phase = "startup-activate";
  if (!activate_browser()) goto finished;
  phase = "startup-pixels";
  if (!wait_pixel(browser.hProcess, 400, 300, RGB(44, 160, 90)))
    goto finished;
  puts("PASS: native startup and rendered pixels");
  fflush(stdout);

  phase = "click";
  POINT point = {400, 300};
  if (!ClientToScreen(browser_window, &point) ||
      !SetCursorPos(point.x, point.y) || !activate_browser())
    goto finished;
  INPUT click[2] = {0};
  click[0].type = click[1].type = INPUT_MOUSE;
  click[0].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
  click[1].mi.dwFlags = MOUSEEVENTF_LEFTUP;
  if (SendInput(1, &click[0], sizeof click[0]) != 1) goto finished;
  Sleep(150);
  if (SendInput(1, &click[1], sizeof click[1]) != 1 ||
      !wait_pixel(browser.hProcess, 400, 300, RGB(173, 57, 76)))
    goto finished;
  puts("PASS: native click and JavaScript mutation");
  fflush(stdout);

  phase = "resize";
  RECT target = {0, 0, 960, 720};
  if (!AdjustWindowRectEx(
          &target, (DWORD)GetWindowLongPtrW(browser_window, GWL_STYLE), FALSE,
          (DWORD)GetWindowLongPtrW(browser_window, GWL_EXSTYLE)) ||
      !SetWindowPos(browser_window, HWND_TOPMOST, 20, 20,
                    target.right - target.left, target.bottom - target.top,
                    0) ||
      !wait_pixel(browser.hProcess, 900, 620, RGB(173, 57, 76)))
    goto finished;
  RECT actual;
  if (!GetClientRect(browser_window, &actual) || actual.right != 960 ||
      actual.bottom != 720)
    goto finished;
  puts("PASS: native resize and redraw at 960x720");
  fflush(stdout);

  phase = "address";
  n = swprintf(address, 32768, L"file:///");
  for (wchar_t const *p = destination; *p && n < 32760; ++p) {
    if (*p == L' ') {
      address[n++] = L'%';
      address[n++] = L'2';
      address[n++] = L'0';
    } else
      address[n++] = *p == L'\\' ? L'/' : *p;
  }
  address[n] = 0;
  if (n >= 32760 || wcscat_s(address, 32768, L"?check=1#ready") != 0 ||
      !enter_address(address) ||
      !wait_title(browser.hProcess, L"Windows address entry passed"))
    goto finished;
  puts("PASS: Ctrl+L / Enter file URL with an escaped space, query and "
       "fragment");
  fflush(stdout);

  if (argc == 4) {
    phase = "WebGL";
    /* Navigate the unchanged shared fixture only after startup/input checks. */
    wchar_t fixture[32768];
    if (!GetFullPathNameW(argv[3], 32768, fixture, NULL)) goto finished;
    n = swprintf(address, 32768, L"file:///");
    for (wchar_t const *p = fixture; *p && n < 32760; ++p) {
      if (*p == L' ') {
        address[n++] = L'%'; address[n++] = L'2'; address[n++] = L'0';
      } else address[n++] = *p == L'\\' ? L'/' : *p;
    }
    address[n] = 0;
    if (n >= 32760 || !enter_address(address) ||
        !wait_title(browser.hProcess, L"WebGL GPU smoke PASS") ||
        !activate_browser()) goto finished;
    ULONGLONG deadline = GetTickCount64() + 30000;
    int pixels = 0;
    while (GetTickCount64() < deadline && !(pixels = webgl_pixels())) Sleep(100);
    if (!pixels || !browser_uses_mesa()) goto finished;
    puts("PASS: Mesa WebGL1/WebGL2 shader readback and 8192 displayed canvas pixels");
    fflush(stdout);
  }

  phase = "close";
  if (!PostMessageW(browser_window, WM_CLOSE, 0, 0) ||
      WaitForSingleObject(browser.hProcess, 120000) != WAIT_OBJECT_0)
    goto finished;
  DWORD exit_code;
  if (!GetExitCodeProcess(browser.hProcess, &exit_code) || exit_code != 0)
    goto finished;
  puts("PASS: native close (browser exit 0)");
  fflush(stdout);
  result = 0;
finished:
  if (result) {
    DWORD error = GetLastError(), code = STILL_ACTIVE;
    GetExitCodeProcess(browser.hProcess, &code);
    wchar_t title[512] = {0};
    GetWindowTextW(browser_window, title, 512);
    fprintf(stderr, "FAIL: phase=%s pid=%lu error=%lu child_exit=%lu window=%p foreground=%p title=%ls\n", phase,
            (unsigned long)browser_pid, (unsigned long)error, (unsigned long)code,
            (void*)browser_window, (void*)GetForegroundWindow(), title);
    TerminateProcess(browser.hProcess, 125);
    WaitForSingleObject(browser.hProcess, 10000);
  }
  CloseHandle(browser.hProcess);
  return result;
}
