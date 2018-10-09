module exec.machine;

import exec.common;
import exec;

enum  MachineResult
{
    notHandled,
    handledContinue,
    handledStopped,
    pendingCallbackBP,
    pendingCallbackStep,
    pendingCallbackEmbeddedBP,
    pendingCallbackEmbeddedStep,
}

enum MacRes_NotHandled = MachineResult.notHandled;
enum MacRes_HandledContinue = MachineResult.handledContinue;
enum MacRes_HandledStopped = MachineResult.handledStopped;
enum MacRes_PendingCallbackBP = MachineResult.pendingCallbackBP;
enum MacRes_PendingCallbackStep = MachineResult.pendingCallbackStep;
enum MacRes_PendingCallbackEmbeddedBP = MachineResult.pendingCallbackEmbeddedBP;
enum MacRes_PendingCallbackEmbeddedStep = MachineResult.pendingCallbackEmbeddedStep;

interface  IProbeCallback
{
public:
    ProbeRunMode  OnCallProbe( 
        IProcess process, uint32_t  threadId, Address  address, ref AddressRange  thunkRange );
}


interface  IMachine
{
public:
    //this~IMachine() { }

    void     AddRef();
    void     Release();

    void     SetProcess( HANDLE  hProcess, Process process );
    void     SetCallback( IProbeCallback callback );
    void     GetPendingCallbackBP( ref Address  address );

    HRESULT  ReadMemory( 
        Address  address,
        uint32_t  length, 
        ref uint32_t  lengthRead, 
        ref uint32_t  lengthUnreadable, 
        uint8_t* buffer );

    HRESULT  WriteMemory( 
        Address  address,
        uint32_t  length, 
        ref uint32_t  lengthWritten, 
        uint8_t* buffer );

    HRESULT  SetBreakpoint( Address  address );
    HRESULT  RemoveBreakpoint( Address  address );
    bool  IsBreakpointActive( Address  address );

    HRESULT  SetContinue();
    HRESULT  SetStepOut( Address  targetAddress );
    HRESULT  SetStepInstruction( bool  stepIn );
    HRESULT  SetStepRange( bool  stepIn, AddressRange  range );
    HRESULT  CancelStep();

    HRESULT  GetThreadContext( 
        uint32_t  threadId, 
        uint32_t  features, 
        uint64_t  extFeatures, 
        void * context, 
        uint32_t  size );
    HRESULT  SetThreadContext( uint32_t  threadId, const(void) * context, uint32_t  size );

    ThreadControlProc  GetWinSuspendThreadProc();

    void     OnStopped( uint32_t  threadId );
    HRESULT  OnCreateThread( Thread* thread );
    HRESULT  OnExitThread( uint32_t  threadId );
    HRESULT  OnException( 
        uint32_t  threadId, 
        const  EXCEPTION_DEBUG_INFO* exceptRec, 
        ref MachineResult  result );
    HRESULT  OnContinue();
    void     OnDestroyProcess();

    HRESULT  Detach();
}
