module exec.ithread;

enum CreateMethod
{
    launch,
    attach,
}
enum Create_Launch = CreateMethod.launch;
enum Create_Attach = CreateMethod.attach;

class IProcess
{
public:
    
    void            AddRef();
    void            Release();

    CreateMethod    GetCreateMethod();
    HANDLE          GetHandle();
    uint32_t        GetId();
    const wchar_t*  GetExePath();
    Address         GetEntryPoint();
    uint16_t        GetMachineType();
    Address         GetImageBase();
    uint32_t        GetImageSize();

    bool            IsStopped();
    bool            IsDeleted();
    bool            IsTerminating();
    bool            ReachedLoaderBp();

    // threads

    bool            FindThread( uint32_t id, ref Thread thread );
    HRESULT         EnumThreads(ref Enumerator!Thread en );
}