module exec.eventcallback;

import exec.iprocess;

abstract class IEventCallback
{
public:
    enum EventCode
    {
        none,
        processStart,
        processExit,
        threadStart,
        threadExit,
        moduleLoad,
        moduleUnload,
        outputString,
        exception,
    }

    enum Event_None = EventCode.none;
    enum Event_ProcessStart = EventCode.processStart;
    enum Event_ProcessExit = EventCode.processExit;
    enum Event_ThreadStart = EventCode.threadStart;
    enum Event_ThreadExit = EventCode.threadExit;
    enum Event_ModuleLoad = EventCode.moduleLoad;
    enum Event_ModuleUnload = EventCode.moduleUnload;
    enum Event_OutputString = EventCode.outputString;
    enum Event_Exception = EventCode.exception;

    abstract void AddRef();
    abstract void Release();
    abstract void OnProcessStart(IProcess process);
    abstract void OnProcessExit(IProcess process, DWORD exitCode);
    abstract void OnThreadStart(IProcess process, Thread thread);
    abstract void OnThreadExit(IProcess process, DWORD threadId, DWORD exitCode);
    abstract void OnModuleLoad(IProcess process, IModulemodule );
    abstract void OnModuleUnload(IProcess process, Address baseAddr);
    abstract void OnOutputString(IProcess process, const wchar_t* outputString);
    abstract void OnLoadComplete(IProcess process, DWORD threadId);
    abstract RunMode OnException(IProcess process, DWORD threadId,
            bool firstChance, const EXCEPTION_RECORD* exceptRec);
    abstract RunMode OnBreakpoint(IProcess process, uint32_t threadId,
            Address address, bool embedded);
    abstract void OnStepComplete(IProcess process, uint32_t threadId);
    abstract void OnAsyncBreakComplete(IProcess process, uint32_t threadId);
    abstract void OnError(IProcess process, HRESULT hrErr, EventCode event);
    abstract ProbeRunMode OnCallProbe(IProcess process, uint32_t threadId,
            Address address, ref AddressRange thunkRange);
};
