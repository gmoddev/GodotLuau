#pragma once

#include <cstdint>
#include <map>
#include <memory>
#include <string>
#include <vector>

// Editor-only copied-data service. No Godot or VM objects on its worker.
class GLProjectIndexer {
public:
    struct Entry {
        std::string Path, Name, Kind, Target, Type;
        int Line=0, Column=0, DefinitionLine=0, DefinitionColumn=0;
        uint64_t Revision=0;
    };
    struct Request {
        std::string Root, Active, Module, Member, Query="Symbols", Replacement, Definitions;
        std::map<std::string,std::string> Buffers;
        int Line=1, Column=1;
        size_t Offset=0;
        bool Refresh=false;
    };
    struct Result {
        uint64_t Generation=0, Microseconds=0;
        size_t Files=0, Parsed=0, Cached=0, Bytes=0, Invalidated=0, Matches=0;
        bool Incomplete=false, More=false;
        std::string Error;
        std::vector<Entry> Entries, Diagnostics;
        std::map<std::string,std::vector<std::string>> Dependencies;
        // Exact source revisions used by rename previews. No writes are made.
        std::map<std::string,std::string> Revisions;
    };
    GLProjectIndexer();
    ~GLProjectIndexer();
    uint64_t Submit(Request Value);
    std::shared_ptr<const Result> Poll(uint64_t Generation) const;
    void Cancel();
    GLProjectIndexer(const GLProjectIndexer&)=delete;
    GLProjectIndexer& operator=(const GLProjectIndexer&)=delete;
private:
    struct State;
    std::unique_ptr<State> Data;
};
