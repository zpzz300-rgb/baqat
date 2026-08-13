#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

// ─── 💾 حفظ حجم ومكان النافذة ─────────────────────────────────────
// من غير ده، كل ما تفتح البرنامج بيرجع 1280x720 في نفس المكان حتى لو
// كنت مكبّره على الشاشة كلها. بنخزّن الحجم والمكان في الريجستري ونرجّعهم.
namespace {

constexpr wchar_t kRegPath[] = L"Software\\TelecomApp\\Window";

void SaveWindowPlacement(HWND hwnd) {
  WINDOWPLACEMENT wp{};
  wp.length = sizeof(wp);
  if (!::GetWindowPlacement(hwnd, &wp)) return;
  HKEY key = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, kRegPath, 0, nullptr, 0,
                        KEY_WRITE, nullptr, &key, nullptr) != ERROR_SUCCESS) {
    return;
  }
  ::RegSetValueExW(key, L"Placement", 0, REG_BINARY,
                   reinterpret_cast<const BYTE*>(&wp), sizeof(wp));
  ::RegCloseKey(key);
}

bool LoadWindowPlacement(WINDOWPLACEMENT* wp) {
  HKEY key = nullptr;
  if (::RegOpenKeyExW(HKEY_CURRENT_USER, kRegPath, 0, KEY_READ, &key) !=
      ERROR_SUCCESS) {
    return false;
  }
  DWORD size = sizeof(WINDOWPLACEMENT);
  DWORD type = 0;
  const bool ok = ::RegQueryValueExW(key, L"Placement", nullptr, &type,
                                     reinterpret_cast<BYTE*>(wp),
                                     &size) == ERROR_SUCCESS &&
                  type == REG_BINARY && size == sizeof(WINDOWPLACEMENT);
  ::RegCloseKey(key);
  return ok && wp->length == sizeof(WINDOWPLACEMENT);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"telecom_app", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  // رجّع آخر حجم ومكان للنافذة (بما فيهم لو كانت مكبّرة)
  WINDOWPLACEMENT saved{};
  if (LoadWindowPlacement(&saved)) {
    saved.showCmd = (saved.showCmd == SW_SHOWMINIMIZED) ? SW_SHOWNORMAL
                                                        : saved.showCmd;
    ::SetWindowPlacement(window.GetHandle(), &saved);
  }

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    // ⚠️ لازم نحفظ **قبل** ما الرسالة تتنفّذ: لما WM_CLOSE توصل للنافذة
    // بتتدمّر على طول والـ HWND بيبقى مش صالح، فالحفظ بعد اللوب مابيشتغلش.
    // بنحفظ كمان بعد أي تحريك/تحجيم عشان لو البرنامج اتقفل فجأة.
    if (msg.message == WM_CLOSE || msg.message == WM_EXITSIZEMOVE) {
      if (msg.hwnd) SaveWindowPlacement(msg.hwnd);
    }
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
