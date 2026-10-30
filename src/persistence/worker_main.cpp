#include "gl_datastore_backend.h"
#include <cstdio>
#include <cstring>
#ifdef _WIN32
#include <io.h>
#include <fcntl.h>
#endif
int main() {
#ifdef _WIN32
    SetErrorMode(0x8003);
    _setmode(_fileno(stdin),_O_BINARY); _setmode(_fileno(stdout),_O_BINARY);
#endif
    using namespace GLDataStoreProtocol;
    char Header[32];
    if (std::fread(Header,1,32,stdin)!=32 || std::memcmp(Header,Magic,8)) return 2;
    uint32_t Sizes[6];
    for (unsigned Index=0;Index<6;++Index) Sizes[Index]=Number(Header+8+Index*4);
    if (!Sizes[0] || Sizes[0]>4096 || !Sizes[1] || Sizes[1]>240 || Sizes[2]>MaxData || Sizes[3]>MaxData || Sizes[4]>2 || Sizes[5]>1) return 3;
    Request Input;
    std::string* Fields[]={&Input.Root,&Input.Leaf,&Input.Expected,&Input.Data};
    for (unsigned Index=0;Index<4;++Index) {
        Fields[Index]->resize(Sizes[Index]);
        if (std::fread(Fields[Index]->data(),1,Sizes[Index],stdin)!=Sizes[Index]) return 4;
    }
    Input.Op=Operation(Sizes[4]); Input.Exists=Sizes[5]!=0;
    Result Value=GLDataStoreBackend::Execute(Input);
    std::string Output=Encode(Value);
    return std::fwrite(Output.data(),1,Output.size(),stdout)==Output.size() && std::fflush(stdout)==0 ? 0:5;
}
