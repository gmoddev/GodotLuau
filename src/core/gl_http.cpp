#include "gl_http.h"
#include "gl_http_policy.h"
#include "gl_domain_host.h"
#include "gl_execution_domain.h"
#include "gl_net_bridge.h"
#include "lua.h"
#include "lualib.h"
#include <godot_cpp/classes/http_client.hpp>
#include <godot_cpp/classes/stream_peer_extension.hpp>
#include <godot_cpp/classes/stream_peer_tls.hpp>
#include <godot_cpp/classes/tls_options.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <array>
#include <cstring>
#include <cmath>
#include <set>

using namespace godot;

// HTTPClient remains the parser. Meter its stream before its unbounded header
// loop or chunk/trailer parsing sees data. No worker thread, sleeps or joins.
class GLHttpStream : public StreamPeerExtension {
    GDCLASS(GLHttpStream,StreamPeerExtension);
    Ref<StreamPeer> Source;
    std::array<uint8_t,2048> Cache{};
    size_t Position=0, Available=0;
    size_t HeaderLineStart=0;
    bool TransferEncodingLine=false;
protected:
    static void _bind_methods() {}
public:
    GLHttpPolicy::WireBudget Budget;
    bool Headers=true;
    bool Invalid=false;
    std::string HeaderText;
    void SetSource(const Ref<StreamPeer>& Selected) { Source=Selected; }
    int32_t _get_available_bytes() const override { return int32_t(Available-Position); }
    Error _get_partial_data(uint8_t* Buffer,int32_t Bytes,int32_t* Received) override {
        *Received=0;
        if (Bytes<0 || Source.is_null()) return ERR_UNAVAILABLE;
        size_t Count=std::min(size_t(Bytes),Budget.Read);
        if (Headers) Count=std::min({Count,Budget.HeaderTick,GLHttpPolicy::MaxHeaderBytes-Budget.Headers});
        if (!Count) {
            if (Headers && Budget.Headers==GLHttpPolicy::MaxHeaderBytes) Budget.Failed=true;
            if (Budget.Wire==GLHttpPolicy::MaxWire) Budget.Failed=true;
            return Budget.Failed?ERR_OUT_OF_MEMORY:OK;
        }
        Error Status=OK;
        if (Position==Available) {
            size_t Fetch=std::min({Budget.Read,GLHttpPolicy::MaxWire-Budget.Wire,(Headers || Count<2048)?size_t(2048):Count});
            // StreamPeer's Array API discards partial data on error. TLS can
            // otherwise consume a valid short response and then encounter EOF
            // in the same oversized read. Probe one byte, then drain only the
            // currently decrypted bytes; never read past a TLS record boundary.
            if (auto Tls=Object::cast_to<StreamPeerTLS>(Source.ptr()))
                Fetch=std::min(Fetch,size_t(std::max(1,Tls->get_available_bytes())));
            if (!Fetch) { Budget.Failed=true; return ERR_OUT_OF_MEMORY; }
            Array Result=Source->get_partial_data(int32_t(Fetch));
            Status=Error(int64_t(Result[0]));
            PackedByteArray BytesRead=Result[1];
            if (BytesRead.size()>int64_t(Fetch) || !Budget.ConsumeWire(size_t(BytesRead.size()))) return ERR_OUT_OF_MEMORY;
            // The header cache amortizes the engine's one-byte parser calls.
            // Body reads can go straight to the caller's bounded buffer.
            if (!Headers && Fetch<=Count) {
                size_t Copy=std::min(Count,size_t(BytesRead.size()));
                if (Copy) std::memcpy(Buffer,BytesRead.ptr(),Copy);
                *Received=int32_t(Copy);
                return Status;
            }
            Available=size_t(BytesRead.size()); Position=0;
            if (Available) std::memcpy(Cache.data(),BytesRead.ptr(),Available);
            if (!Available) return Status;
        }
        Count=std::min(Count,Available-Position);
        if (Headers) {
            for (size_t Index=0;Index<Count;++Index) {
                unsigned char C=Cache[Position+Index];
                if ((C<32 && C!='\r' && C!='\n' && C!='\t') || C>=127) { Invalid=true; return ERR_INVALID_DATA; }
            }
            if (!Budget.ConsumeHeader(Count)) return ERR_OUT_OF_MEMORY;
            for (size_t Index=0;Index<Count;++Index) {
                char C=char(Cache[Position+Index]);
                HeaderText.push_back(C);
                if (C==':' && GLHttpPolicy::Lower(HeaderText.substr(HeaderLineStart))=="transfer-encoding:") TransferEncodingLine=true;
                // HTTP transfer-coding tokens are case-insensitive. The pinned
                // engine recognizes only lower-case "chunked". Normalize this
                // one parser input while retaining the original checked wire.
                if (TransferEncodingLine && C>='A' && C<='Z') Cache[Position+Index]=uint8_t(C-'A'+'a');
                if (C=='\n') { HeaderLineStart=HeaderText.size(); TransferEncodingLine=false; }
            }
        }
        std::memcpy(Buffer,Cache.data()+Position,Count); Position+=Count;
        *Received=int32_t(Count);
        return OK;
    }
    Error _get_data(uint8_t* Buffer,int32_t Bytes,int32_t* Received) override { return _get_partial_data(Buffer,Bytes,Received); }
    Error _put_partial_data(const uint8_t* Buffer,int32_t Bytes,int32_t* Sent) override {
        *Sent=0;
        if (Bytes<0 || Source.is_null()) return ERR_UNAVAILABLE;
        size_t Count=std::min(size_t(Bytes),Budget.Written);
        if (!Count) return OK;
        PackedByteArray Payload; Payload.resize(int64_t(Count));
        std::memcpy(Payload.ptrw(),Buffer,Count);
        Array Result=Source->put_partial_data(Payload);
        int64_t Written=int64_t(Result[1]);
        if (Written<0 || Written>int64_t(Count)) return ERR_INVALID_DATA;
        Budget.Written-=size_t(Written); *Sent=int32_t(Written);
        return Error(int64_t(Result[0]));
    }
    Error _put_data(const uint8_t* Buffer,int32_t Bytes,int32_t* Sent) override { return _put_partial_data(Buffer,Bytes,Sent); }
};

void RegisterGLHttpTypes() { ClassDB::register_internal_class<GLHttpStream>(); }

namespace {
bool Present(lua_State* Thread,int Index) { return !lua_isnoneornil(Thread,Index); }
std::string Argument(lua_State* Thread,int Index,size_t Maximum,bool Binary=false) {
    size_t Count=0;
    const char* Bytes=luaL_checklstring(Thread,Index,&Count);
    if (Count>Maximum || (!Binary && std::memchr(Bytes,0,Count))) luaL_error(Thread,"[Runtime:HTTP] Invalid or oversized input");
    return std::string(Bytes,Count);
}
struct Context { uint64_t Host; GLExecutionDomain* Domain; int Operation; };
int BeginRequest(lua_State* Thread) {
    auto& Context=*static_cast<struct Context*>(lua_touserdata(Thread,lua_upvalueindex(1)));
    auto Host=Object::cast_to<GLDomainHost>(ObjectDB::get_instance(Context.Host));
    if (!Host) luaL_error(Thread,"[Runtime:HTTP] Capability unavailable");
    return Host->BeginHttp(Thread,Context.Domain,Context.Operation);
}
int ContinueRequest(lua_State* Thread,int Status) {
    auto& Context=*static_cast<struct Context*>(lua_touserdata(Thread,lua_upvalueindex(1)));
    auto Host=Object::cast_to<GLDomainHost>(ObjectDB::get_instance(Context.Host));
    // A real completion removes its record before resuming. Any other resume
    // cancels the pending operation before Lua can start a different wait.
    if (!Host || Host->InterruptHttp(Thread)) luaL_error(Thread,"[Runtime:HTTP] Request resumed outside completion");
    if (Status!=LUA_OK) lua_error(Thread);
    return 1;
}
HTTPClient::Method Method(const std::string& Value) {
    if (Value=="POST") return HTTPClient::METHOD_POST;
    if (Value=="PUT") return HTTPClient::METHOD_PUT;
    if (Value=="PATCH") return HTTPClient::METHOD_PATCH;
    if (Value=="DELETE") return HTTPClient::METHOD_DELETE;
    if (Value=="HEAD") return HTTPClient::METHOD_HEAD;
    if (Value=="OPTIONS") return HTTPClient::METHOD_OPTIONS;
    return HTTPClient::METHOD_GET;
}
}

struct GLHttpManager::State {
    struct Request {
        lua_State* Thread=nullptr;
        lua_State* Anchor=nullptr;
        int Reference=LUA_NOREF, Operation=0;
        GLHttpPolicy::Url Url;
        std::string Method, Body, Response;
        PackedStringArray Headers;
        Ref<HTTPClient> Transport, Parser;
        Ref<GLHttpStream> Stream;
        uint64_t Deadline=0;
        int Status=0;
        int64_t Length=-1;
        bool Sent=false, ReadHeaders=false, Chunked=false, Done=false;
        const char* Error=nullptr;
        ~Request() { Close(); }
        void Close() { if (Parser.is_valid()) Parser->close(); if (Transport.is_valid()) Transport->close(); }
        void Fail(const char* Reason) { Error=Reason; Done=true; Status=0; Response.clear(); Close(); }
        void Poll() {
            if (Time::get_singleton()->get_ticks_msec()>=Deadline) { Fail("Request deadline exceeded"); return; }
            if (Transport.is_null()) {
                Transport.instantiate(); Transport->set_blocking_mode(false);
                if (Transport->connect_to_host(String::utf8(Url.Host.c_str()),Url.Port,Url.Tls?TLSOptions::client():Ref<TLSOptions>())!=OK) Fail("Connection failed");
                return;
            }
            if (!Sent) {
                godot::Error Code=Transport->poll();
                auto Status=Transport->get_status();
                if (Code!=OK || (Status!=HTTPClient::STATUS_RESOLVING && Status!=HTTPClient::STATUS_CONNECTING && Status!=HTTPClient::STATUS_CONNECTED)) { Fail("Connection or TLS failed"); return; }
                if (Status!=HTTPClient::STATUS_CONNECTED) return;
                Stream.instantiate(); Stream->SetSource(Transport->get_connection());
                Parser.instantiate(); Parser->set_blocking_mode(false); Parser->set_read_chunk_size(65536);
                Parser->set_connection(Stream);
                PackedByteArray Payload; Payload.resize(int64_t(Body.size()));
                if (!Body.empty()) std::memcpy(Payload.ptrw(),Body.data(),Body.size());
                if (Parser->request_raw(::Method(Method),String::utf8(Url.Target.c_str()),Headers,Payload)!=OK) { Fail("Request failed"); return; }
                Body.clear(); Sent=true;
                return;
            }
            Stream->Budget.Tick();
            if (!ReadHeaders) {
                if (Parser->poll()!=OK || Stream->Budget.Failed || Stream->Invalid) { Fail(Stream->Budget.Failed?"Response wire/header limit exceeded":"Invalid response headers"); return; }
                if (Parser->get_status()==HTTPClient::STATUS_REQUESTING) return;
                Status=Parser->get_response_code();
                Length=Parser->get_response_body_length();
                auto End=Stream->HeaderText.find("\r\n");
                std::string First=Stream->HeaderText.substr(0,End);
                if (End==std::string::npos || First.size()<12 || (First.rfind("HTTP/1.1 ",0)!=0 && First.rfind("HTTP/1.0 ",0)!=0) ||
                    First[9]<'1' || First[9]>'5' || First[10]<'0' || First[10]>'9' || First[11]<'0' || First[11]>'9' || (First.size()>12 && First[12]!=' ') ||
                    Status!=(First[9]-'0')*100+(First[10]-'0')*10+First[11]-'0' || Status<200 ||
                    (Length>int64_t(GLHttpPolicy::MaxResponse) && Method!="HEAD" && Status!=304) || Length< -1) { Fail("Invalid or oversized response"); return; }
                PackedStringArray Received=Parser->get_response_headers();
                size_t Count=0;
                bool SeenLength=false, SeenEncoding=false;
                for (const String& Header:Received) {
                    std::string Line(Header.utf8().get_data());
                    Count+=Line.size();
                    std::string Lower=GLHttpPolicy::Lower(Line);
                    if (Lower.rfind("content-length:",0)==0) {
                        String Text=String::utf8(Lower.c_str()).substr(15).strip_edges();
                        if (SeenLength || Text.is_empty() || Text.length()>18) { Fail("Ambiguous response framing"); return; }
                        for (int Index=0;Index<Text.length();++Index) if (Text[Index]<'0' || Text[Index]>'9') { Fail("Invalid response length"); return; }
                        if (Text.to_int()<0 || (Status==204 && Text.to_int()!=0)) { Fail("Invalid response length"); return; }
                        SeenLength=true;
                    }
                    if (Lower.rfind("transfer-encoding:",0)==0) {
                        if (SeenEncoding || String::utf8(Lower.c_str()).substr(18).strip_edges()!="chunked") { Fail("Unsupported response framing"); return; }
                        SeenEncoding=true; Chunked=true;
                    }
                    if (Lower.rfind("content-encoding:",0)==0 && String::utf8(Lower.c_str()).substr(17).strip_edges()!="identity") { Fail("Unsupported content encoding"); return; }
                }
                if (Count>GLHttpPolicy::MaxHeaderBytes || (SeenLength && SeenEncoding)) { Fail("Ambiguous or oversized response headers"); return; }
                if (Method!="HEAD" && Status!=204 && Status!=304 && !SeenLength && !SeenEncoding && Parser->get_status()!=HTTPClient::STATUS_BODY) { Fail("Response length unavailable"); return; }
                ReadHeaders=true; Stream->Headers=false;
                if (Method=="HEAD" || Status==204 || Status==304) { Done=true; Close(); return; }
            }
            auto Before=Parser->get_status();
            if (Before==HTTPClient::STATUS_BODY) {
                PackedByteArray Chunk=Parser->read_response_body_chunk();
                if (Stream->Budget.Failed || Stream->Invalid || size_t(Chunk.size())>GLHttpPolicy::MaxResponse-Response.size()) { Fail("Response byte limit exceeded"); return; }
                if (Chunk.size()) Response.append(reinterpret_cast<const char*>(Chunk.ptr()),size_t(Chunk.size()));
            }
            auto StatusNow=Parser->get_status();
            if (StatusNow==HTTPClient::STATUS_CONNECTED) {
                if (Length>=0 && int64_t(Response.size())!=Length) { Fail("Truncated response"); return; }
                Done=true; Close();
            } else if (StatusNow==HTTPClient::STATUS_DISCONNECTED && Length<0 && !Chunked) { Done=true; Close(); }
            else if (StatusNow!=HTTPClient::STATUS_BODY) Fail("Truncated or failed response");
        }
    };
    uint64_t Host;
    bool Enabled=false;
    uint64_t Timeout=10000;
    size_t Peak=0;
    std::vector<std::string> Origins;
    std::vector<std::unique_ptr<Request>> Requests;
};

GLHttpManager::GLHttpManager(GLDomainHost& Host):Data(std::make_unique<State>()) {
    Data->Host=uint64_t(Host.get_instance_id());
    auto Settings=ProjectSettings::get_singleton();
    if (!Settings || !Settings->has_setting("godot_luau/http/enabled")) return;
    Variant Enabled=Settings->get_setting("godot_luau/http/enabled");
    if (Enabled.get_type()!=Variant::BOOL || !bool(Enabled)) return;
    Variant Origins=Settings->get_setting("godot_luau/http/allowed_origins",Array());
    if (Origins.get_type()!=Variant::ARRAY && Origins.get_type()!=Variant::PACKED_STRING_ARRAY) return;
    Array Values;
    if (Origins.get_type()==Variant::PACKED_STRING_ARRAY) {
        PackedStringArray Packed=Origins;
        if (Packed.size()>32) return;
        for (const String& Origin:Packed) Values.push_back(Origin);
    } else Values=Origins;
    if (Values.is_empty() || Values.size()>32) return;
    for (int64_t Index=0;Index<Values.size();++Index) {
        if (Values[Index].get_type()!=Variant::STRING) return;
        String Value=Values[Index]; GLHttpPolicy::Url Origin;
        if (Value.length()>int64_t(GLHttpPolicy::MaxUrl)) return;
        if (!GLHttpPolicy::Parse(Value.utf8().get_data(),Origin) || Origin.Target!="/") return;
        Data->Origins.push_back(Origin.Origin);
    }
    Variant Timeout=Settings->get_setting("godot_luau/http/timeout_milliseconds",10000);
    if (Timeout.get_type()!=Variant::INT || int64_t(Timeout)<1 || int64_t(Timeout)>30000) return;
    Data->Timeout=uint64_t(int64_t(Timeout)); Data->Enabled=true;
}
GLHttpManager::~GLHttpManager() { Shutdown(); }
void GLHttpManager::Install(lua_State* Thread,GLExecutionDomain& Domain,uint64_t Host) {
    lua_newtable(Thread);
    const char* Names[]={"request","get","post"};
    for (int Index=0;Index<3;++Index) {
        auto Value=static_cast<Context*>(lua_newuserdatadtor(Thread,sizeof(Context),[](void*) {}));
        new(Value) Context{Host,&Domain,Index};
        lua_pushcclosurek(Thread,BeginRequest,Names[Index],1,ContinueRequest); lua_setfield(Thread,-2,Names[Index]);
    }
    // Retain the existing mutable facade. Its names/environment are not grants.
    lua_setglobal(Thread,"_HTTP");
}
int GLHttpManager::Begin(lua_State* Thread,GLExecutionDomain* Domain,int Operation) {
    auto Owner=GLGetOwner(Thread);
    if (!Owner || !Owner->Alive || Owner->Domain!=Domain || !Owner->NativeId || Domain->HasMemoryFailure() || Domain->GetMemoryAccount().Rejections)
        luaL_error(Thread,"[Runtime:HTTP] Capability unavailable");
    if (Domain->IsClosing()) luaL_error(Thread,"[Runtime:HTTP] Domain closing");
    if (!Data->Enabled || Domain->GetKind()!=GLDomainKind::Server || gl_net_role()==2)
        luaL_error(Thread,"[Runtime:HTTP] Server origin grant required");
    if (!lua_isyieldable(Thread)) luaL_error(Thread,"[Runtime:HTTP] Yieldable owner required");
    if (Data->Requests.size()>=GLHttpPolicy::MaxActive) luaL_error(Thread,"[Runtime:HTTP] Request admission limit exceeded");
    size_t Count=0;
    for (auto& R:Data->Requests) if (R->Anchor==GLGetOwnerState(Thread)) ++Count;
    if (Count>=GLHttpPolicy::MaxOwner) luaL_error(Thread,"[Runtime:HTTP] Owner request limit exceeded");
    auto R=std::make_unique<State::Request>();
    R->Method=Operation==0?(Present(Thread,1)?Argument(Thread,1,16):"GET"):Operation==1?"GET":"POST";
    for (char& C:R->Method) if (C>='a' && C<='z') C=char(C-'a'+'A');
    std::string Url=Argument(Thread,Operation==0?2:1,GLHttpPolicy::MaxUrl);
    if (!GLHttpPolicy::Method(R->Method) || !GLHttpPolicy::Parse(Url,R->Url)) luaL_error(Thread,"[Runtime:HTTP] Invalid method or URL");
    if (std::find(Data->Origins.begin(),Data->Origins.end(),R->Url.Origin)==Data->Origins.end()) luaL_error(Thread,"[Runtime:HTTP] Origin denied");
    int BodyIndex=Operation==0?3:Operation==2?2:0;
    if (BodyIndex && Present(Thread,BodyIndex)) R->Body=Argument(Thread,BodyIndex,GLHttpPolicy::MaxRequest,true);
    int HeadersIndex=Operation==0?4:Operation==1?2:4;
    std::set<std::string> Keys;
    size_t HeaderBytes=0;
    if (Present(Thread,HeadersIndex)) {
        luaL_checktype(Thread,HeadersIndex,LUA_TTABLE);
        lua_pushnil(Thread);
        while (lua_next(Thread,HeadersIndex)!=0) {
            if (Keys.size()>=GLHttpPolicy::MaxHeaders || lua_type(Thread,-2)!=LUA_TSTRING || (lua_type(Thread,-1)!=LUA_TSTRING && lua_type(Thread,-1)!=LUA_TNUMBER))
                luaL_error(Thread,"[Runtime:HTTP] Invalid request headers");
            std::string Name=Argument(Thread,-2,128),Value=Argument(Thread,-1,4096);
            HeaderBytes+=Name.size()+Value.size()+4;
            if (!GLHttpPolicy::Header(Name,Value) || HeaderBytes>GLHttpPolicy::MaxHeaderBytes || !Keys.insert(GLHttpPolicy::Lower(Name)).second)
                luaL_error(Thread,"[Runtime:HTTP] Invalid or oversized request headers");
            R->Headers.push_back(String::utf8((Name+": "+Value).c_str())); lua_pop(Thread,1);
        }
    }
    if (Operation==2) {
        std::string Type=Present(Thread,3)?Argument(Thread,3,256):"application/json";
        if (!GLHttpPolicy::Header("Content-Type",Type) || Keys.count("content-type")) luaL_error(Thread,"[Runtime:HTTP] Invalid or duplicate content type");
        R->Headers.push_back(String::utf8(("Content-Type: "+Type).c_str()));
    }
    if ((R->Method=="GET" || R->Method=="HEAD") && !R->Body.empty()) luaL_error(Thread,"[Runtime:HTTP] Body not allowed for method");
    R->Headers.push_back(String::utf8(("Host: "+R->Url.Host+":"+std::to_string(R->Url.Port)).c_str()));
    R->Headers.push_back("Connection: close"); R->Headers.push_back("Accept-Encoding: identity");
    R->Thread=Thread; R->Anchor=GLGetOwnerState(Thread); R->Operation=Operation;
    R->Deadline=Time::get_singleton()->get_ticks_msec()+Data->Timeout;
    R->Reference=GLCaptureWait(Thread); // admission before any DNS/connect/send
    Data->Requests.push_back(std::move(R)); Data->Peak=std::max(Data->Peak,Data->Requests.size());
    lua_pushliteral(Thread,"__WAIT_HTTP__"); return lua_yield(Thread,1);
}
void GLHttpManager::Tick() {
    std::vector<int> Snapshot;
    for (auto& R:Data->Requests) Snapshot.push_back(R->Reference);
    for (int Reference:Snapshot) {
        auto Found=std::find_if(Data->Requests.begin(),Data->Requests.end(),[&](const auto& R) { return R->Reference==Reference; });
        if (Found==Data->Requests.end()) continue;
        auto& R=**Found;
        auto Owner=GLReferenceAlive(R.Anchor,Reference)?GLGetOwner(R.Thread):nullptr;
        if (!Owner || !Owner->Alive || Owner->Domain->IsClosing() || Owner->Domain->HasMemoryFailure() || !Owner->Domain->CanResume(R.Thread) || gl_net_role()==2) {
            GLUnreference(nullptr,Reference); Data->Requests.erase(Found); continue;
        }
        R.Poll();
        if (!R.Done) continue;
        auto Complete=std::move(*Found); Data->Requests.erase(Found); // remove before Lua reentry
        Owner->Domain->ResumePrepared(Complete->Thread,[&](lua_State* Thread)->int {
            if (Complete->Operation!=0) {
                if (Complete->Error) { lua_pushfstring(Thread,"[Runtime:HTTP] %s",Complete->Error); return 1; }
                lua_pushlstring(Thread,Complete->Response.data(),Complete->Response.size()); return 1;
            }
            lua_newtable(Thread);
            lua_pushboolean(Thread,!Complete->Error && Complete->Status>=200 && Complete->Status<300); lua_setfield(Thread,-2,"Success");
            lua_pushinteger(Thread,Complete->Status); lua_setfield(Thread,-2,"StatusCode");
            std::string Message=Complete->Error?Complete->Error:Complete->Status>=200 && Complete->Status<300?"OK":"HTTP "+std::to_string(Complete->Status);
            lua_pushlstring(Thread,Message.data(),Message.size()); lua_setfield(Thread,-2,"StatusMessage");
            lua_pushlstring(Thread,Complete->Response.data(),Complete->Response.size()); lua_setfield(Thread,-2,"Body");
            return 1;
        },Complete->Operation!=0 && Complete->Error);
        GLUnreference(nullptr,Reference);
    }
}
void GLHttpManager::CancelOwner(lua_State* Anchor) {
    Data->Requests.erase(std::remove_if(Data->Requests.begin(),Data->Requests.end(),[&](const auto& R) {
        if (R->Anchor!=Anchor) return false; GLUnreference(nullptr,R->Reference); return true;
    }),Data->Requests.end());
}
void GLHttpManager::CancelThread(lua_State* Thread) {
    Data->Requests.erase(std::remove_if(Data->Requests.begin(),Data->Requests.end(),[&](const auto& R) {
        if (R->Thread!=Thread) return false; GLUnreference(nullptr,R->Reference); return true;
    }),Data->Requests.end());
}
bool GLHttpManager::Interrupt(lua_State* Thread) {
    bool Pending=std::any_of(Data->Requests.begin(),Data->Requests.end(),[&](const auto& R) { return R->Thread==Thread; });
    if (Pending) CancelThread(Thread);
    return Pending;
}
void GLHttpManager::Shutdown() { for (auto& R:Data->Requests) GLUnreference(nullptr,R->Reference); Data->Requests.clear(); }
size_t GLHttpManager::Pending(bool Client) const { return Client?0:Data->Requests.size(); }
size_t GLHttpManager::Peak() const { return Data->Peak; }
