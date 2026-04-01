#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., not attached to pty)
  if (!::AttachConsole(ATTACH_PARENT_PROCESS)) {
    // If the command line includes /help or -h, create a console window so
    // that the help text is visible.
    if (::wcsstr(command_line, L"--help") != nullptr ||
        ::wcsstr(command_line, L"-h") != nullptr) {
      ::AllocConsole();
      ::SetConsoleOutputCP(CP_UTF8);
    }
  }
  if (::IsDebuggerPresent()) {
    ::AllocConsole();
    ::SetConsoleOutputCP(CP_UTF8);
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 800);
  if (!window.CreateAndShow(L"Move Item Sorter", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  return EXIT_SUCCESS;
}
