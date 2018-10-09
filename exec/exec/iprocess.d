module exec.iprocess;

// Methods of the IProcess class are safe to call from any thread.
// They are accurate when run from the debug thread, or when the process is stopped.

// See the WinNT.h header file for processor-specific definitions of 
// machine type. For x86, the machine type is IMAGE_FILE_MACHINE_I386.

interface IProcess
{
public:
    void AddRef();
    void Release();
    CreateMethod GetCreateMethod();
    HANDLE GetHandle();
    uint32_t GetId();
    const wchar_t* GetExePath();
    Address GetEntryPoint();
    uint16_t GetMachineType();
    Address GetImageBase();
    uint32_t GetImageSize();
    bool IsStopped();
    bool IsDeleted();
    bool IsTerminating();
    bool ReachedLoaderBp();

    // threads

    bool FindThread(uint32_t id, ref Thread thread);
    HRESULT EnumThreads(ref Enumerator!(Thread) en);
}
