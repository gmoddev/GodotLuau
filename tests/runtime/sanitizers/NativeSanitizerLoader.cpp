// Standalone loader separates ASan initialization/unloading from Godot behavior.
#include <cstdio>
#ifdef _WIN32
#include <windows.h>
#else
#include <dlfcn.h>
#endif

int main(int Count, char **Arguments) {
    if (Count != 2) return 2;
#ifdef _WIN32
    HMODULE Library = LoadLibraryA(Arguments[1]);
    if (!Library) return 3;
    auto Touch = reinterpret_cast<int (*)()>(GetProcAddress(Library, "SanitizerProbeTouch"));
#else
    void *Library = dlopen(Arguments[1], RTLD_NOW | RTLD_LOCAL);
    if (!Library) { std::fprintf(stderr, "%s\n", dlerror()); return 3; }
    auto Touch = reinterpret_cast<int (*)()>(dlsym(Library, "SanitizerProbeTouch"));
#endif
    if (!Touch || Touch() != 73) return 4;
    std::puts("[Runtime:SanitizerLoader] Before unload");
    std::fflush(stdout);
#ifdef _WIN32
    if (!FreeLibrary(Library)) return 5;
#else
    if (dlclose(Library) != 0) return 5;
#endif
    std::puts("[Runtime:SanitizerLoader] PASS after unload");
    std::fflush(stdout);
    return 0;
}
