// Baseline-only fault injection: pause after the production call really truncates.
// Never linked into the extension or enabled in normal core/native qualification.
#include <filesystem>
#include <fstream>
#include <thread>
#include <chrono>
#include <string>
#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#else
#include <unistd.h>
#endif
static bool Inject=false;
static std::filesystem::path Marker;
static void AfterTruncate() {
    if (!Inject) return;
    { std::ofstream Signal(Marker); Signal << "native truncation complete"; }
    std::this_thread::sleep_for(std::chrono::seconds(5));
}
#ifdef _WIN32
static BOOL BaselineTruncate(HANDLE File) {
    BOOL Result=SetEndOfFile(File);
    if (Result) AfterTruncate();
    return Result;
}
#define SetEndOfFile BaselineTruncate
#else
static int BaselineTruncate(int File,off_t Size) {
    int Result=ftruncate(File,Size);
    if (!Result) AfterTruncate();
    return Result;
}
#define ftruncate BaselineTruncate
#endif
#include "gl_storage.h"
int main(int Count,char** Arguments) {
#ifdef _WIN32
    SetErrorMode(0x8003);
#endif
    if (Count!=2) return 2;
    auto Root=std::filesystem::absolute(Arguments[1]);
    std::filesystem::create_directories(Root);
    Marker=Root/"truncated.marker";
    GLStorage Storage(Root.u8string(),GLStorage::Read|GLStorage::Write);
    if (Storage.WriteFile("ds_GL009_interrupted.json","{\"Sentinel\":12345}")!=GLStorage::Error::None) return 3;
    std::string Prior;
    if (Storage.ReadFile("ds_GL009_interrupted.json",Prior)!=GLStorage::Error::None || Prior!="{\"Sentinel\":12345}") return 6;
    { std::ofstream Saved(Root/"previous-sentinel.json"); Saved << Prior; }
    Inject=true;
    if (Storage.WriteFile("ds_GL009_interrupted.json","{\"Replacement\":999}")!=GLStorage::Error::None) return 4;
    return 5; // Controller must terminate during the pause, not count this as proof.
}
