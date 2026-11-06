#ifndef GL_HTTP_POLICY_H
#define GL_HTTP_POLICY_H

#include <string>
#include <vector>
#include <algorithm>
#include <cctype>

// Policy shared by the native bridge and production-core regression tests.
namespace GLHttpPolicy {
constexpr size_t MaxUrl = 4096, MaxRequest = 1024*1024, MaxResponse = 4*1024*1024;
constexpr size_t MaxHeaders = 32, MaxHeaderBytes = 16384, MaxWire = 8*1024*1024;
constexpr size_t MaxActive = 4, MaxOwner = 2;
constexpr size_t MaxResponseHeaders = 128;
struct ResponseHeader { std::string Name,Value; };
struct Url {
    std::string Host, Target, Origin;
    int Port = 0;
    bool Tls = false;
};
inline std::string Lower(std::string Value) {
    for (char& C:Value) if (C>='A' && C<='Z') C=char(C-'A'+'a');
    return Value;
}
inline bool Parse(const std::string& Value, Url& Result) {
    if (Value.empty() || Value.size()>MaxUrl) return false;
    for (unsigned char C:Value) if (C<=32 || C>=127 || C=='\\' || C=='#') return false;
    size_t Begin=Value.rfind("https://",0)==0?8:Value.rfind("http://",0)==0?7:0;
    if (!Begin) return false;
    Url Parsed; Parsed.Tls=Begin==8;
    auto End=Value.find_first_of("/?",Begin);
    std::string Authority=Value.substr(Begin,End==std::string::npos?End:End-Begin);
    auto Colon=Authority.find(':');
    Parsed.Host=Lower(Authority.substr(0,Colon));
    if (Parsed.Host.empty() || Parsed.Host.size()>253 || Parsed.Host.back()=='.') return false;
    size_t Label=0;
    for (size_t Index=0;Index<Parsed.Host.size();++Index) {
        char C=Parsed.Host[Index];
        if (C=='.') {
            if (!Label || Label>63 || Parsed.Host[Index-1]=='-') return false;
            Label=0;
        } else {
            if (!((C>='a' && C<='z') || (C>='0' && C<='9') || (C=='-' && Label))) return false;
            ++Label;
        }
    }
    if (!Label || Label>63 || Parsed.Host.back()=='-') return false;
    Parsed.Port=Parsed.Tls?443:80;
    if (Colon!=std::string::npos) {
        std::string Port=Authority.substr(Colon+1);
        if (Port.empty() || Port.size()>5) return false;
        unsigned Number=0;
        for (char C:Port) { if (C<'0' || C>'9') return false; Number=Number*10+unsigned(C-'0'); }
        if (!Number || Number>65535) return false;
        Parsed.Port=int(Number);
    }
    Parsed.Target=End==std::string::npos?"/":Value[End]=='?'?"/"+Value.substr(End):Value.substr(End);
    for (size_t Index=0;Index<Parsed.Target.size();++Index) if (Parsed.Target[Index]=='%') {
        auto Hex=[](char C) { return (C>='0' && C<='9') || (C>='a' && C<='f') || (C>='A' && C<='F'); };
        if (Index+2>=Parsed.Target.size() || !Hex(Parsed.Target[Index+1]) || !Hex(Parsed.Target[Index+2])) return false;
        Index+=2;
    }
    Parsed.Origin=(Parsed.Tls?"https://":"http://")+Parsed.Host+":"+std::to_string(Parsed.Port);
    Result=std::move(Parsed);
    return true;
}
inline bool Method(const std::string& Value) {
    return Value=="GET" || Value=="POST" || Value=="PUT" || Value=="PATCH" || Value=="DELETE" || Value=="HEAD" || Value=="OPTIONS";
}
// Capture original checked wire values (before parser transfer-token folding).
// Preserve order/duplicates; reject obsolete folding and malformed field lines.
// Failure leaves the caller's prior collection untouched.
inline bool CaptureHeaders(const std::string& Wire,std::vector<ResponseHeader>& Result) {
    if (Wire.size()>MaxHeaderBytes) return false;
    auto End=Wire.find("\r\n");
    if (End==std::string::npos) return false;
    size_t Position=End+2;
    std::vector<ResponseHeader> Parsed;
    while (Position<Wire.size()) {
        End=Wire.find("\r\n",Position);
        if (End==std::string::npos) return false;
        if (End==Position) {
            if (End+2!=Wire.size()) return false;
            Result=std::move(Parsed); return true;
        }
        auto Colon=Wire.find(':',Position);
        if (Colon==std::string::npos || Colon>=End || Colon==Position || Colon-Position>128 || Parsed.size()>=MaxResponseHeaders) return false;
        std::string Name=Wire.substr(Position,Colon-Position);
        for (unsigned char C:Name)
            if (!((C>='A' && C<='Z') || (C>='a' && C<='z') || (C>='0' && C<='9') || std::string("!#$%&'*+-.^_`|~").find(char(C))!=std::string::npos)) return false;
        size_t Begin=Colon+1, Finish=End;
        while (Begin<Finish && (Wire[Begin]==' ' || Wire[Begin]=='\t')) ++Begin;
        while (Finish>Begin && (Wire[Finish-1]==' ' || Wire[Finish-1]=='\t')) --Finish;
        std::string Value=Wire.substr(Begin,Finish-Begin);
        for (unsigned char C:Value) if ((C<32 && C!='\t') || C>=127) return false;
        Parsed.push_back({Lower(std::move(Name)),std::move(Value)});
        Position=End+2;
    }
    return false;
}
inline bool Header(const std::string& Name,const std::string& Value) {
    if (Name.empty() || Name.size()>128 || Value.size()>4096) return false;
    for (unsigned char C:Name)
        if (!((C>='A' && C<='Z') || (C>='a' && C<='z') || (C>='0' && C<='9') || std::string("!#$%&'*+-.^_`|~").find(char(C))!=std::string::npos)) return false;
    for (unsigned char C:Value) if ((C<32 && C!='\t') || C>=127) return false;
    std::string Key=Lower(Name);
    for (const char* Reserved:{"host","connection","content-length","transfer-encoding","accept-encoding","proxy-authorization","proxy-connection","te","trailer","upgrade","expect"})
        if (Key==Reserved) return false;
    return true;
}
struct WireBudget {
    size_t Wire=0, Headers=0, Read=65536, Written=65536, HeaderTick=2048;
    bool Failed=false;
    void Tick() { Read=Written=65536; HeaderTick=2048; }
    bool ConsumeWire(size_t Bytes) {
        if (Bytes>MaxWire-Wire || Bytes>Read) { Failed=true; return false; }
        Wire+=Bytes; Read-=Bytes; return true;
    }
    bool ConsumeHeader(size_t Bytes) {
        if (Bytes>MaxHeaderBytes-Headers || Bytes>HeaderTick) { Failed=true; return false; }
        Headers+=Bytes; HeaderTick-=Bytes; return true;
    }
};
}
#endif
