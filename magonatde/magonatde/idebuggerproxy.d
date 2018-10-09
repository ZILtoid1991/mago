module MagoNatDE.idebuggerproxy;

interface IDebuggerProxy
{
public:
    HRESULT Launch(LaunchInfo launchInfo, ref ICoreProcess process);
    HRESULT Attach(uint32_t id, ref ICoreProcess process);

    HRESULT Terminate(ICoreProcess process);
    HRESULT Detach(ICoreProcess process);

    HRESULT ResumeLaunchedProcess(ICoreProcess process);

    HRESULT ReadMemory(ICoreProcess process, Address64 address, uint32_t length,
            ref uint32_t lengthRead, ref uint32_t lengthUnreadable, uint8_t* buffer);

    HRESULT WriteMemory(ICoreProcess process, Address64 address, uint32_t length,
            ref uint32_t lengthWritten, uint8_t* buffer);

    HRESULT SetBreakpoint(ICoreProcess process, Address64 address);
    HRESULT RemoveBreakpoint(ICoreProcess process, Address64 address);

    HRESULT StepOut(ICoreProcess process, Address64 targetAddr, bool handleException);
    HRESULT StepInstruction(ICoreProcess process, bool stepIn, bool handleException);
    HRESULT StepRange(ICoreProcess* process, bool stepIn, AddressRange64 range, bool handleException);

    HRESULT Continue(ICoreProcess process, bool handleException);
    HRESULT Execute(ICoreProcess process, bool handleException);

    HRESULT AsyncBreak(ICoreProcess process);

    HRESULT GetThreadContext(ICoreProcess process, ICoreThread thread, ref IRegisterSet regSet);
    HRESULT SetThreadContext(ICoreProcess process, ICoreThread thread, IRegisterSet regSet);

    HRESULT GetPData(ICoreProcess process, Address64 address, Address64 imageBase,
            uint32_t size, ref uint32_t sizeRead, uint8_t* pdata);
}
