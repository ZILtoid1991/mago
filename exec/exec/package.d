module exec.package;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import exec.Common;
import exec.Process;
import exec.Thread;
import exec.Module;
import exec.PathResolver;
import exec.EventCallback;
import exec.Machine;
import exec.MakeMachine;

struct LaunchInfo
{
    const(wchar_t)* Exe;
    const(wchar_t)* CommandLine;
    const(wchar_t)* Dir;
    const(wchar_t)* EnvBstr;
    HANDLE StdInput;
    HANDLE StdOutput;
    HANDLE StdError;
    bool NewConsole;
    bool Suspend;
};

//struct RefPtr(struct T);

/*
Mode    Disp.   Thread  Method
        Allowed
------------------------------------
any     yes     any     ReadMemory
break   yes     any     WriteMemory
any     yes     any     SetBreakpoint
any     yes     any     RemoveBreakpoint
break   no*     Debug   StepOut
break   no*     Debug   StepInstruction
break   no*     Debug   StepRange
break   no*     Debug   CancelStep
run     yes     any     AsyncBreak
break   yes     any     GetThreadContext
break   yes     any     SetThreadContext

N/A     no      Debug   Init
N/A     no      Debug   Shutdown
N/A     no      Debug   WaitForEvent
N/A     no      Debug   DispatchEvent
break   no*     Debug   Continue
N/A     yes     Debug   Launch
N/A     yes     Debug   Attach
any     yes     Debug   Terminate
any     yes     Debug   Detach
any     yes     Debug   ResumeLaunchedProcess

Some actions are only possible while a debuggee is in break or run mode. 
Calling a method when the debuggee is in the wrong mode returns E_WRONG_STATE.

Methods that process debugging events cannot be called in the middle of an 
event callback. Doing so returns E_WRONG_STATE.

Some actions have an affinity to the thread where Exec was initialized. These 
have to do with debugging events, and controlling the run state of a process. 
Calling these methods outside the Debug Thread returns E_WRONG_THREAD.

If a method takes a process object, but the process is ending or has already 
ended, then the method fails with E_PROCESS_ENDED.

Init fails with E_ALREADY_INIT, if called after a successful call to Init.

All methods fail with E_WRONG_STATE, if called after Shutdown.
*/

immutable uint32_t NormalTerminateCode = 0;
immutable uint32_t AbnormalTerminateCode = _UI32_MAX;

/+
This probably will be replaced with something in D

class ProcessMap : public std::map< uint32_t, RefPtr< Process > >
{
}+/
alias ProcessMap = Process[uint32_t];

class  ProbeCallback : public  IProbeCallback
{
    IEventCallback mCallback;
    Process        mProcess;

public:
    this( IEventCallback callback, Process process )
    {   mCallback = ( callback );
            mProcess = ( process );
        assert( callback !is  null );
        assert( process !is  null );
    }

    ProbeRunMode  OnCallProbe( 
        IProcess process, uint32_t  threadId, Address  address, ref AddressRange  thunkRange )
    {
        mProcess.Unlock();
        ProbeRunMode  mode = mCallback.OnCallProbe( process, threadId, address, thunkRange );
        mProcess.Lock();
        return  mode;
    }
}

// indexed by Win32 Debug API Event Code (for ex: EXCEPTION_DEBUG_EVENT)
const  IEventCallback.EventCode      gEventMap[] = 
[
    { IEventCallback.Event_None, },
    { IEventCallback.Event_Exception, },
    { IEventCallback.Event_ThreadStart, },
    { IEventCallback.Event_ProcessStart, },
    { IEventCallback.Event_ThreadExit, },
    { IEventCallback.Event_ProcessExit, },
    { IEventCallback.Event_ModuleLoad, },
    { IEventCallback.Event_ModuleUnload, },
    { IEventCallback.Event_OutputString, },
    { IEventCallback.Event_None },
];

class Exec
{
    // because of thread affinity of debugging APIs, 
    // keep track of starting thread ID
    uint32_t mTid;

    IEventCallback mCallback;

    DEBUG_EVENT mLastEvent;

    wchar_t* mPathBuf;
    uint32_t mPathBufLen;

    ProcessMap mProcMap;
    PathResolver mResolver;

    bool mIsDispatching;
    bool mIsShutdown;

    MagoCore.DebuggerProxy mDebuggerProxy; // backward reference

public:
    static Exec opCall();
    this()
    {
        mTid = 0;
        mCallback = null;
        mPathBuf = null;
        mPathBufLen = 0;
        mProcMap = null;
        mResolver = null;
        mIsDispatching = false;
        mIsShutdown = false;
        //memset(&mLastEvent, 0, mLastEvent.sizeof);
    }

    ~this()
    {
        if (mTid == 0 || mTid == GetCurrentThreadId())
            Shutdown();

        delete[] mPathBuf;
        delete mProcMap;
        delete mResolver;

        if (mCallback !is null)
        {
            mCallback.Release();
            mCallback = null;
        }
    }

    /// Initializes the core debugger. Associates it with an event callback 
    /// which will handle all debugging events. The core debugger is bound to 
    /// the current thread (the Debug Thread), so that subsequent calls to 
    /// event handling methods and some control methods must be made from that 
    /// thread.
    ///
    HRESULT Init(IEventCallback callback, DebuggerProxy debuggerProxy)
    {
        // already initialized?
        if (mTid != 0)
            return E_ALREADY_INIT;
        if (callback is null)
            return E_INVALIDARG;
        if (debuggerProxy is null)
            return E_INVALIDARG;

        HRESULT hr = S_OK;

        auto_ptr < ProcessMap > map(new ProcessMap());
        if (map.get() is null)
            return E_OUTOFMEMORY;

        auto_ptr < PathResolver > resolver(new PathResolver());
        if (resolver.get() is null)
            return E_OUTOFMEMORY;

        hr = resolver.Init();
        if (FAILED(hr))
            return hr;

        mPathBuf = new wchar_t[MAX_PATH];
        if (mPathBuf is null)
            return E_OUTOFMEMORY;
        mPathBufLen = MAX_PATH;

        callback.AddRef();

        mCallback = callback;
        mDebuggerProxy = debuggerProxy;
        mProcMap = map.release();
        mResolver = resolver.release();

        // start off our thread affinity
        mTid = GetCurrentThreadId();

        return S_OK;
    }

    /// Stops debugging all processes, and frees resources. 
    ///
    RESULT Shutdown()
    {
        assert(mTid == 0 || mTid == GetCurrentThreadId());
        if (mTid != 0 && mTid != GetCurrentThreadId())
            return E_WRONG_THREAD;
        if (mIsDispatching)
            return E_WRONG_STATE;
        if (mIsShutdown)
            return S_OK;

        mIsShutdown = true;

        if (mProcMap !is null)
        {
            for (ProcessMap.iterator it = mProcMap.begin(); it != mProcMap.end();
                    it++)
            {
                Process* proc = it.second.Get();

                ProcessGuard guard = ProcessGuard(proc);

                if (!proc.IsDeleted())
                {
                    // TODO: if detaching: lock process and detach its machine, then detach process

                    // we still have process running, 
                    // so treat it as if we're shutting down our own app
                    TerminateProcess(proc.GetHandle(), AbnormalTerminateCode);

                    // we're still debugging, so stop, so the debuggee can really close
                    DebugActiveProcessStop(proc.GetId());

                    proc.SetDeleted();
                    proc.SetMachine(null);
                }
            }

            mProcMap.clear();
        }

        CleanupLastDebugEvent();

        // it would be nice to release the callback here

        return S_OK;
    }

    /// Waits for a debugging event to happen.
    ///
    /// Returns: S_OK, if an event was captured.
    ///          E_TIMEOUT, if the timeout elapsed.
    ///          See the table above for other errors.
    ///
    HRESULT WaitForEvent(uint32_t millisTimeout)
    {
        assert(mTid == GetCurrentThreadId());
        if (mTid != GetCurrentThreadId())
            return E_WRONG_THREAD;
        assert(mLastEvent.dwDebugEventCode == NO_DEBUG_EVENT);
        if (mLastEvent.dwDebugEventCode != NO_DEBUG_EVENT)
            return E_UNEXPECTED;
        if (mIsShutdown || mIsDispatching)
            return E_WRONG_STATE;
        // if we haven't continued since the last wait, we'll just return E_TIMEOUT

        HRESULT hr = S_OK;
        BOOL bRet = FALSE;

        bRet = .WaitForDebugEvent(&mLastEvent, millisTimeout);
        if (!bRet)
        {
            hr = GetLastHr();
            goto Error;
        }

    Error:
        return hr;
    }

    /// Handle a debugging event. The process object is marked stopped, and the 
    /// appropriate event callback method will be called.
    ///
    /// Returns: S_OK, if ContinueDebug should be called after this call.
    ///          S_FALSE to stay in break mode.
    ///          See the table above for other errors.
    ///
    HRESULT DispatchEvent()
    {
        assert(mTid == GetCurrentThreadId());
        if (mTid != GetCurrentThreadId())
            return E_WRONG_THREAD;
        assert(mLastEvent.dwDebugEventCode != NO_DEBUG_EVENT);
        if (mLastEvent.dwDebugEventCode == NO_DEBUG_EVENT)
            return E_UNEXPECTED;
        if (mIsShutdown || mIsDispatching)
            return E_WRONG_STATE;

        HRESULT hr = S_OK;
        Process proc;

        Log.LogDebugEvent(mLastEvent);

        proc = FindProcess(mLastEvent.dwProcessId);
        assert(proc !is null);
        if (proc is null)
        {
            hr = E_UNEXPECTED;
            goto Error;
        }

        {
            ProcessGuard guard = ProcessGuard(proc);

            // hand off the event
            proc.SetLastEvent(mLastEvent);
            proc.SetStopped(true);

            hr = DispatchAndContinue(proc, mLastEvent);
        }

    Error:
        // if there was an error, leave the debuggee in break mode
        CleanupLastDebugEvent();
        return hr;
    }

    /// Runs a process that reported a debugging event. Marks the process 
    /// object as running.
    ///
    HRESULT Continue(IProcess process, bool handleException)
    {
        assert(mTid == GetCurrentThreadId());
        if (mTid != GetCurrentThreadId())
            return E_WRONG_THREAD;
        assert(process !is null);
        if (process is null)
            return E_INVALIDARG;
        if (mIsShutdown || mIsDispatching)
            return E_WRONG_STATE;

        HRESULT hr = S_OK;
        Process proc = cast(Process) process;

        ProcessGuard guard = ProcessGuard(proc);

        if (!process.IsStopped())
            return E_WRONG_STATE;

        hr = ContinueNoLock(proc, handleException);

        return hr;
    }

    // Starts a process. The process object that's returned is used to control 
    // the process.
    //
    HRESULT Launch(LaunchInfo launchInfo, ref IProcess process)
    {
        assert(mTid == GetCurrentThreadId());
        if (mTid != GetCurrentThreadId())
            return E_WRONG_THREAD;
        assert(launchInfo !is null);
        if (launchInfo is null)
            return E_INVALIDARG;
        if (mIsShutdown)
            return E_WRONG_STATE;

        HRESULT hr = S_OK;
        wchar_t* cmdLine = null;
        BOOL bRet = FALSE;
        STARTUPINFO startupInfo = {startupInfo.sizeof};
        PROCESS_INFORMATION procInfo = {0};
        BOOL inheritHandles = FALSE;
        DWORD flags = DEBUG_ONLY_THIS_PROCESS | CREATE_UNICODE_ENVIRONMENT
            | CREATE_DEFAULT_ERROR_MODE;
        HandlePtr hProcPtr;
        HandlePtr hThreadPtr;
        ImageInfo imageInfo = {0};
        IMachine machine;
        Process proc;

        startupInfo.dwFlags = STARTF_USESHOWWINDOW;
        startupInfo.wShowWindow = SW_SHOW;

        if ((launchInfo.StdInput !is null) || (launchInfo.StdOutput !is null)
                || (launchInfo.StdError !is null))
        {
            startupInfo.hStdInput = launchInfo.StdInput;
            startupInfo.hStdOutput = launchInfo.StdOutput;
            startupInfo.hStdError = launchInfo.StdError;
            startupInfo.dwFlags |= STARTF_USESTDHANDLES;
            inheritHandles = TRUE;
        }

        if (launchInfo.NewConsole)
            flags |= CREATE_NEW_CONSOLE;
        if (launchInfo.Suspend)
            flags |= CREATE_SUSPENDED;

        wchar_t* pathRet = _wfullpath(mPathBuf, launchInfo.Exe, mPathBufLen);
        if (pathRet is null)
        {
            hr = E_UNEXPECTED;
            goto Error;
        }

        hr = GetImageInfo(mPathBuf, imageInfo);
        if (FAILED(hr))
            goto Error;

        hr = MakeMachine(imageInfo.MachineType, machine.Ref());
        if (FAILED(hr))
            goto Error;

        cmdLine = _wcsdup(launchInfo.CommandLine);
        if (cmdLine is null)
        {
            hr = E_OUTOFMEMORY;
            goto Error;
        }

        bRet = CreateProcess(null, cmdLine, null, null, inheritHandles, flags,
                cast(void*) launchInfo.EnvBstr, launchInfo.Dir, &startupInfo, &procInfo);
        if (!bRet)
        {
            hr = GetLastHr();
            goto Error;
        }

        hThreadPtr.Attach(procInfo.hThread);
        hProcPtr.Attach(procInfo.hProcess);

        proc = new Process(Create_Launch, procInfo.hProcess, procInfo.dwProcessId, mPathBuf);
        if (proc.Get() is null)
        {
            hr = E_OUTOFMEMORY;
            goto Error;
        }

        hProcPtr.Detach();

        mProcMap.insert(ProcessMap.value_type(procInfo.dwProcessId, proc));

        machine.SetProcess(proc.GetHandle(), proc.Get());
        proc.SetMachine(machine.Get());

        proc.SetMachineType(imageInfo.MachineType);

        if (launchInfo.Suspend)
            proc.SetLaunchedSuspendedThread(hThreadPtr.Detach());

        process = proc.Detach();

    Error:
        if (FAILED(hr))
        {
            if (!hProcPtr.IsEmpty())
            {
                TerminateProcess(hProcPtr.Get(), AbnormalTerminateCode);
                DebugActiveProcessStop(procInfo.dwProcessId);
            }
        }

        if (cmdLine !is null)
            free(cmdLine);

        return hr;
    }

    /// Brings a running process under the control of the debugger. The process 
    /// object that's returned is used to control the process.
    ///
    HRESULT Attach(uint32_t id, ref IProcess process)
    {
        assert(mTid == GetCurrentThreadId());
        if (mTid != GetCurrentThreadId())
            return E_WRONG_THREAD;
        if (mIsShutdown)
            return E_WRONG_STATE;

        HRESULT hr = S_OK;
        BOOL bRet = FALSE;
        HandlePtr hProcPtr;
        wstring filename;
        Process proc;
        IMachine machine;
        ImageInfo imageInfo;

        hProcPtr = OpenProcess(PROCESS_ALL_ACCESS, FALSE, id);
        if (hProcPtr.Get() is null)
        {
            hr = GetLastHr();
            goto Error;
        }

        hr = mResolver.GetProcessModulePath(hProcPtr.Get(), filename);
        if (FAILED(hr)) // getting ERROR_PARTIAL_COPY here usually means we won't be able to attach
            goto Error;

        hr = GetProcessImageInfo(hProcPtr.Get(), imageInfo);
        if (FAILED(hr))
            goto Error;

        hr = MakeMachine(imageInfo.MachineType, machine.Ref());
        if (FAILED(hr))
            goto Error;

        bRet = DebugActiveProcess(id);
        if (!bRet)
        {
            hr = GetLastHr();
            goto Error;
        }

        proc = new Process(Create_Attach, hProcPtr.Get(), id, filename.c_str());
        if (proc.Get() is null)
        {
            hr = E_OUTOFMEMORY;
            goto Error;
        }

        hProcPtr.Detach();

        mProcMap.insert(ProcessMap.value_type(id, proc));

        machine.SetProcess(proc.GetHandle(), proc.Get());
        proc.SetMachine(machine.Get());

        proc.SetMachineType(imageInfo.MachineType);

        process = proc.Detach();

    Error:
        if (FAILED(hr))
        {
            DebugActiveProcessStop(id);
        }

        return hr;
    }

    /// Ends a process. If the OnCreateProcess callback has not fired, then the 
    /// debuggee is immediately ended and detached. Otherwise, the caller must 
    /// keep pumping events until OnExitProcess is fired. Any other events 
    /// before it are discarded and will not fire a callback. Also, if the 
    /// debuggee is in break mode, then this method runs it.
    ///
    HRESULT Terminate(IProcess process)
    {
        assert(mTid == GetCurrentThreadId());
        if (mTid != GetCurrentThreadId())
            return E_WRONG_THREAD;
        assert(process !is null);
        if (process is null)
            return E_INVALIDARG;
        if (mIsShutdown)
            return E_WRONG_STATE;

        HRESULT hr = S_OK;
        BOOL bRet = FALSE;
        Process proc = cast(Process) process;

        ProcessGuard guard = ProcessGuard(proc);

        if (proc.IsDeleted() || proc.IsTerminating())
            return E_PROCESS_ENDED;

        proc.SetTerminating();

        bRet = TerminateProcess(process.GetHandle(), NormalTerminateCode);
        assert(bRet);
        if (!bRet)
        {
            hr = GetLastHr();
        }

        if (proc.IsStarted())
        {
            if (process.IsStopped())
            {
                ContinueInternal(proc, true);
            }
        }
        else
        {
            bRet = DebugActiveProcessStop(proc.GetId());

            proc.SetDeleted();
            proc.SetMachine(null);

            mProcMap.erase(process.GetId());
        }

        // the process will end even if all threads are suspended
        // we only have to detach or keep pumping its events

        return hr;
    }

    /// Stops debugging a process. No event callbacks are called.
    ///
    HRESULT Detach(IProcess process);
    {
        assert(mTid == GetCurrentThreadId());
        if (mTid != GetCurrentThreadId())
            return E_WRONG_THREAD;
        assert(process !is null);
        if (process is null)
            return E_INVALIDARG;
        if (mIsShutdown)
            return E_WRONG_STATE;

        HRESULT hr = S_OK;
        Process proc = cast(Process*) process;

        ProcessGuard guard = ProcessGuard(proc);

        if (proc.IsDeleted() || proc.IsTerminating())
            return E_PROCESS_ENDED;

        IMachine* machine = proc.GetMachine();
        assert(machine !is null);

        machine.Detach();

        // do the least needed to shut down
        proc.SetTerminating();

        if (proc.IsStopped())
        {
            // Throw out exceptions that are used for debugging, so that the 
            // debuggee isn't stuck with them, and likely crash.
            // Let the debuggee handle all other exceptions and events.

            ShortDebugEvent lastEvent = proc.GetLastEvent();

            if ((lastEvent.EventCode == EXCEPTION_DEBUG_EVENT) && (lastEvent.ExceptionCode == EXCEPTION_BREAKPOINT
                    || lastEvent.ExceptionCode == EXCEPTION_SINGLE_STEP))
            {
                ContinueInternal(proc, true);
            }
        }

        DebugActiveProcessStop(process.GetId());
        ResumeSuspendedProcess(process);

        proc.SetDeleted();
        proc.SetMachine(null);

        if (proc.IsStarted() && mCallback !is null)
        {
            proc.Unlock();
            mCallback.OnProcessExit(proc, 0);
            proc.Lock();
        }

        mProcMap.erase(process.GetId());

        return hr;
    }

    /// Resumes a process, if it was started suspended.
    ///
    HRESULT ResumeLaunchedProcess(IProcess process)
    {
        _ASSERT(mTid == GetCurrentThreadId());
        if (mTid != GetCurrentThreadId())
            return E_WRONG_THREAD;
        _ASSERT(process !is null);
        if (process is null)
            return E_INVALIDARG;
        if (mIsShutdown)
            return E_WRONG_STATE;

        Process* proc = cast(Process*) process;

        // lock the process, in case someone uses it when they shouldn't
        ProcessGuard guard = ProcessGuard(proc);

        if (proc.IsDeleted() || proc.IsTerminating())
            return E_PROCESS_ENDED;

        ResumeSuspendedProcess(process);

        return S_OK;
    }

    /// Reads a block of memory from a process's address space. The memory is 
    /// read straight from the debuggee and not cached.
    ///
    HRESULT ReadMemory(IProcess* process, Address address, uint32_t length,
            ref uint32_t lengthRead, ref uint32_t lengthUnreadable, uint8_t* buffer)
    {
        _ASSERT(process !is null);
        if (process is null)
            return E_INVALIDARG;
        if (mIsShutdown)
            return E_WRONG_STATE;

        HRESULT hr = S_OK;
        Process* proc = cast(Process*) process;

        ProcessGuard guard = ProcessGuard(proc);

        if (proc.IsDeleted() || proc.IsTerminating())
            return E_PROCESS_ENDED;

        IMachine* machine = proc.GetMachine();
        _ASSERT(machine !is null);

        hr = machine.ReadMemory(cast(Address) address, length, lengthRead,
                lengthUnreadable, buffer);

        return hr;
    }

    /// Writes a block of memory to a process's address space. The memory is 
    /// written straight to the debuggee and not cached.
    ///
    HRESULT WriteMemory(IProcess process, Address address, uint32_t length,
            ref uint32_t lengthWritten, uint8_t* buffer)
    {
        assert(process !is null);
        if (process is null)
            return E_INVALIDARG;
        if (mIsShutdown)
            return E_WRONG_STATE;

        HRESULT hr = S_OK;
        Process proc = cast(Process) process;

        ProcessGuard guard = ProcessGuard(proc);

        if (proc.IsDeleted() || proc.IsTerminating())
            return E_PROCESS_ENDED;
        if (!proc.IsStopped())
            return E_WRONG_STATE;

        IMachine machine = proc.GetMachine();
        assert(machine !is null);

        hr = machine.WriteMemory(cast(Address) address, length, lengthWritten, buffer);

        return hr;
    }
    // Adds or removes a breakpoint. If the process is running when this 
    // method is called, then all threads will be suspended first.
    //
    HRESULT SetBreakpoint(IProcess process, Address address)
    {
        assert(process !is null);
        if (process is null)
            return E_INVALIDARG;
        if (mIsShutdown)
            return E_WRONG_STATE;

        HRESULT hr = S_OK;
        Process proc = cast(Process) process;

        ProcessGuard guard = ProcessGuard(proc);

        if (proc.IsDeleted() || proc.IsTerminating())
            return E_PROCESS_ENDED;

        IMachine machine = proc.GetMachine();
        assert(machine !is null);
        bool suspend = !proc.IsStopped() && !machine.IsBreakpointActive(address);

        if (suspend)
        {
            hr = SuspendProcess(proc, machine.GetWinSuspendThreadProc());
            if (FAILED(hr))
                goto Error;
        }

        hr = machine.SetBreakpoint(address);

        if (suspend)
        {
            HRESULT hrResume = ResumeProcess(proc, machine.GetWinSuspendThreadProc());
            if (SUCCEEDED(hr))
                hr = hrResume;
        }

    Error:
        return hr;
    }

    HRESULT RemoveBreakpoint(IProcess process, Address address)
    {
        assert(process !is null);
        if (process is null)
            return E_INVALIDARG;
        if (mIsShutdown)
            return E_WRONG_STATE;

        HRESULT hr = S_OK;
        Process proc = cast(Process) process;

        ProcessGuard guard = ProcessGuard(proc);

        if (proc.IsDeleted() || proc.IsTerminating())
            return E_PROCESS_ENDED;

        IMachine machine = proc.GetMachine();
        assert(machine !is null);
        bool suspend = !proc.IsStopped() && !machine.IsBreakpointActive(address);

        if (suspend)
        {
            hr = SuspendProcess(proc, machine.GetWinSuspendThreadProc());
            if (FAILED(hr))
                goto Error;
        }

        hr = machine.RemoveBreakpoint(address);

        if (suspend)
        {
            HRESULT hrResume = ResumeProcess(proc, machine.GetWinSuspendThreadProc());
            if (SUCCEEDED(hr))
                hr = hrResume;
        }

    Error:
        return hr;
    }

    /// Sets up or cancels stepping for the current thread. Only one stepping 
    /// action is allowed in a thread at a time. The debuggee is run to allow 
    /// the step to begin.
    ///
    HRESULT StepOut(IProcess process, Address address, bool handleException)
    {
        assert(mTid == GetCurrentThreadId());
        if (mTid != GetCurrentThreadId())
            return E_WRONG_THREAD;
        assert(process !is null);
        if (process is null)
            return E_INVALIDARG;
        if (mIsShutdown || mIsDispatching)
            return E_WRONG_STATE;

        HRESULT hr = S_OK;
        Process proc = cast(Process) process;

        ProcessGuard guard = ProcessGuard(proc);

        if (proc.IsDeleted() || proc.IsTerminating())
            return E_PROCESS_ENDED;
        if (!proc.IsStopped())
            return E_WRONG_STATE;

        IMachine machine = proc.GetMachine();
        assert(machine !is null);

        hr = machine.SetStepOut(address);
        if (FAILED(hr))
            goto Error;

        hr = ContinueInternal(proc, handleException);
        if (FAILED(hr))
            goto Error;

    Error:
        return hr;
    }

    HRESULT StepInstruction(IProcess process, bool stepIn, bool handleException)
    {
        assert(mTid == GetCurrentThreadId());
        if (mTid != GetCurrentThreadId())
            return E_WRONG_THREAD;
        assert(process !is null);
        if (process is null)
            return E_INVALIDARG;
        if (mIsShutdown || mIsDispatching)
            return E_WRONG_STATE;

        HRESULT hr = S_OK;
        Process proc = cast(Process*) process;

        ProcessGuard guard = ProcessGuard(proc);

        if (proc.IsDeleted() || proc.IsTerminating())
            return E_PROCESS_ENDED;
        if (!proc.IsStopped())
            return E_WRONG_STATE;

        IMachine machine = proc.GetMachine();
        assert(machine !is null);

        hr = machine.SetStepInstruction(stepIn);
        if (FAILED(hr))
            goto Error;

        hr = ContinueInternal(proc, handleException);
        if (FAILED(hr))
            goto Error;

    Error:
        return hr;
    }

    HRESULT StepRange(IProcess process, bool stepIn, AddressRange range, bool handleException)
    {
        assert(mTid == GetCurrentThreadId());
        if (mTid != GetCurrentThreadId())
            return E_WRONG_THREAD;
        assert(process !is null);
        if (process is null)
            return E_INVALIDARG;
        if (mIsShutdown || mIsDispatching)
            return E_WRONG_STATE;

        HRESULT hr = S_OK;
        Process proc = cast(Process) process;

        ProcessGuard guard = ProcessGuard(proc);

        if (proc.IsDeleted() || proc.IsTerminating())
            return E_PROCESS_ENDED;
        if (!proc.IsStopped())
            return E_WRONG_STATE;

        IMachine machine = proc.GetMachine();
        assert(machine !is null);

        hr = machine.SetStepRange(stepIn, range);
        if (FAILED(hr))
            goto Error;

        hr = ContinueInternal(proc, handleException);
        if (FAILED(hr))
            goto Error;

    Error:
        return hr;
    }

    HRESULT CancelStep(IProcess process)
    {
        assert(mTid == GetCurrentThreadId());
        if (mTid != GetCurrentThreadId())
            return E_WRONG_THREAD;
        assert(process !is null);
        if (process is null)
            return E_INVALIDARG;
        if (mIsShutdown || mIsDispatching)
            return E_WRONG_STATE;

        HRESULT hr = S_OK;
        Process proc = cast(Process*) process;

        ProcessGuard guard = ProcessGuard(proc);

        if (proc.IsDeleted() || proc.IsTerminating())
            return E_PROCESS_ENDED;
        if (!proc.IsStopped())
            return E_WRONG_STATE;

        IMachine machine = proc.GetMachine();
        assert(machine !is null);

        hr = machine.CancelStep();

        return hr;
    }

    // Causes a running process to enter break mode. A subsequent event will 
    // fire the OnBreakpoint callback.
    //
    HRESULT AsyncBreak(IProcess process)
    {
        assert(process !is null);
        if (process is null)
            return E_INVALIDARG;
        if (mIsShutdown)
            return E_WRONG_STATE;

        BOOL bRet = FALSE;
        Process* proc = cast(Process*) process;

        ProcessGuard guard = ProcessGuard(proc);

        if (proc.IsDeleted() || proc.IsTerminating())
            return E_PROCESS_ENDED;
        if (proc.IsStopped())
            return E_WRONG_STATE;

        bRet = DebugBreakProcess(process.GetHandle());
        if (!bRet)
            return GetLastHr();

        return S_OK;
    }

    /// Gets or sets the register context of a thread.
    /// See the WinNT.h header file for processor-specific definitions of 
    /// the context records to pass to this method.
    ///
    HRESULT GetThreadContext(IProcess process, uint32_t threadId,
            uint32_t features, uint64_t extFeatures, void* context, uint32_t size)
    {
        assert(process !is null);
        if (process is null)
            return E_INVALIDARG;
        if (mIsShutdown)
            return E_WRONG_STATE;

        HRESULT hr = S_OK;
        Process proc = cast(Process) process;

        ProcessGuard guard = ProcessGuard(proc);

        if (proc.IsDeleted() || proc.IsTerminating())
            return E_PROCESS_ENDED;
        if (!proc.IsStopped())
            return E_WRONG_STATE;

        IMachine machine = proc.GetMachine();
        assert(machine !is null);

        hr = machine.GetThreadContext(threadId, features, extFeatures, context, size);

        return hr;
    }

    HRESULT SetThreadContext(IProcess process, uint32_t threadId,
            const(void)* context, uint32_t size)
    {
        assert(process !is null);
        if (process is null)
            return E_INVALIDARG;
        if (mIsShutdown)
            return E_WRONG_STATE;

        HRESULT hr = S_OK;
        Process proc = cast(Process) process;

        ProcessGuard guard = ProcessGuard(proc);

        if (proc.IsDeleted() || proc.IsTerminating())
            return E_PROCESS_ENDED;
        if (!proc.IsStopped())
            return E_WRONG_STATE;

        IMachine machine = proc.GetMachine();
        assert(machine !is null);

        hr = machine.SetThreadContext(threadId, context, size);

        return hr;
    }

    HRESULT GetPData(IProcess* process, Address address, Address imageBase,
            uint32_t size, ref uint32_t sizeRead, uint8_t* pdata)
    {
        static if (defined(_M_IX86))
        {
            // Unreferenced parameters
            /*process;
            address;
            imageBase;
            size;
            sizeRead;
            pdata;*/
            return E_NOTIMPL;
        }
        else static if (defined(_M_X64))
        {
            const(int) RecordSize = IMAGE_RUNTIME_FUNCTION_ENTRY.sizeof;

            if (process is null || pdata is null)
                return E_INVALIDARG;
            if (size < RecordSize)
                return E_INVALIDARG;
            if (mIsShutdown)
                return E_WRONG_STATE;

            HRESULT hr = S_OK;
            Process* proc = cast(Process*) process;

            ProcessGuard guard = ProcessGuard(proc);

            if (proc.IsDeleted() || proc.IsTerminating())
                return E_PROCESS_ENDED;
            if (!proc.IsStopped())
                return E_WRONG_STATE;

            IMachine* machine = proc.GetMachine();
            assert(machine !is null);

            IMAGE_DOS_HEADER dosHeader;
            IMAGE_NT_HEADERS32 ntHeaders32;
            DWORD dataDirCount = 0;
            IMAGE_DATA_DIRECTORY* dataDirs = null;
            IMAGE_DATA_DIRECTORY* pdataDir = null;
            uint32_t lenRead;
            uint32_t lenUnread;
            Address pdataBase;
            Address modBase = cast(Address) imageBase;
            Address rva = cast(Address) address - modBase;
            int nRec;
            int iFirst;
            int iLast;

            hr = machine.ReadMemory(modBase, dosHeader.sizeof, lenRead,
                    lenUnread, cast(uint8_t*)&dosHeader);
            if (FAILED(hr))
                return hr;

            hr = machine.ReadMemory(modBase + dosHeader.e_lfanew, ntHeaders32.sizeof,
                    lenRead, lenUnread, cast(uint8_t*)&ntHeaders32);
            if (FAILED(hr))
                return hr;

            if (ntHeaders32.OptionalHeader.Magic == IMAGE_NT_OPTIONAL_HDR32_MAGIC)
            {
                dataDirCount = ntHeaders32.OptionalHeader.NumberOfRvaAndSizes;
                dataDirs = ntHeaders32.OptionalHeader.DataDirectory;
            }
            else if (ntHeaders32.OptionalHeader.Magic == IMAGE_NT_OPTIONAL_HDR64_MAGIC)
            {
                IMAGE_NT_HEADERS64* ntHeaders64 = cast(IMAGE_NT_HEADERS64*)&ntHeaders32;

                dataDirCount = ntHeaders64.OptionalHeader.NumberOfRvaAndSizes;
                dataDirs = ntHeaders64.OptionalHeader.DataDirectory;
            }

            pdataDir = &dataDirs[IMAGE_DIRECTORY_ENTRY_EXCEPTION];

            if (pdataDir.Size == 0 || pdataDir.VirtualAddress == 0 || pdataDir.Size < RecordSize)
                return S_FALSE;

            pdataBase = modBase + pdataDir.VirtualAddress;

            nRec = pdataDir.Size / RecordSize;
            iFirst = 0;
            iLast = nRec - 1;

            IMAGE_RUNTIME_FUNCTION_ENTRY midRec;

            while (iLast >= iFirst)
            {
                int iMid = (iLast + iFirst) / 2;

                hr = machine.ReadMemory(pdataBase + iMid * RecordSize,
                        RecordSize, lenRead, lenUnread, cast(uint8_t*)&midRec);
                if (FAILED(hr))
                    return hr;

                if (rva >= midRec.BeginAddress && rva <= midRec.EndAddress)
                {
                    memcpy(pdata, &midRec, RecordSize);
                    sizeRead = RecordSize;
                    return S_OK;
                }

                if (rva < midRec.BeginAddress)
                    iLast = iMid - 1;
                else
                    iFirst = iMid + 1;
            }

            return S_FALSE;
        }
        else
        {
            // #error Customize this implementation by getting pdata size and comparing routines from IMachine.
        }
    }

private:
    HRESULT DispatchAndContinue(Process proc, ref const DEBUG_EVENT debugEvent)
    {
        HRESULT hr = S_OK;

        hr = DispatchProcessEvent(proc, debugEvent);
        if (FAILED(hr))
            goto Error;

        if (hr == S_OK)
        {
            hr = ContinueNoLock(proc, false);
        }
        else
        {
            // leave the debuggee in break mode
            hr = S_OK;
        }

    Error:
        return hr;
    }

    HRESULT DispatchProcessEvent(Process proc, ref const DEBUG_EVENT debugEvent)
    {
        assert(proc !is null);

        HRESULT hr = S_OK;
        // because of the lock, hold onto the process, 
        // even if EXIT_PROCESS event would have destroyed it
        Process procRef = proc;
        IMachine machine = proc.GetMachine();

        // we shouldn't handle any stopping events after Terminate
        if (proc.IsDeleted() || (proc.IsTerminating()
                && debugEvent.dwDebugEventCode != EXIT_PROCESS_DEBUG_EVENT))
        {
            // continue
            hr = S_OK;
            goto Error;
        }
        assert(machine !is null);

        machine.OnStopped(debugEvent.dwThreadId);
        mIsDispatching = true;

        switch (debugEvent.dwDebugEventCode)
        {
        case CREATE_PROCESS_DEBUG_EVENT:
            {
                Module mod;
                Thread thread;
                ImageInfo imageInfo = {0};

                hr = CreateModule(proc, debugEvent, mod);
                if (FAILED(hr))
                    goto Error;

                hr = CreateThread(proc, debugEvent, thread);
                if (FAILED(hr))
                    goto Error;

                GetLoadedImageInfo(debugEvent.u.CreateProcessInfo.hProcess,
                        debugEvent.u.CreateProcessInfo.lpBaseOfImage, imageInfo);

                proc.AddThread(thread.Get());
                proc.SetEntryPoint(cast(Address) debugEvent.u.CreateProcessInfo.lpStartAddress);
                proc.SetImageBase(cast(Address) debugEvent.u.CreateProcessInfo.lpBaseOfImage);
                proc.SetImageSize(imageInfo.Size);
                proc.SetStarted();

                machine.OnCreateThread(thread.Get());

                if (mCallback !is null)
                {
                    proc.Unlock();
                    mCallback.OnProcessStart(proc);
                    mCallback.OnModuleLoad(proc, mod.Get());
                    mCallback.OnThreadStart(proc, thread.Get());
                    proc.Lock();
                }
            }
            break;

        case CREATE_THREAD_DEBUG_EVENT:
            {
                hr = HandleCreateThread(proc, debugEvent);
            }
            break;

        case EXIT_THREAD_DEBUG_EVENT:
            {
                if (mCallback !is null)
                {
                    proc.Unlock();
                    mCallback.OnThreadExit(proc, debugEvent.dwThreadId,
                            debugEvent.u.ExitThread.dwExitCode);
                    proc.Lock();
                }

                proc.DeleteThread(debugEvent.dwThreadId);

                hr = machine.OnExitThread(debugEvent.dwThreadId);
            }
            break;

        case EXIT_PROCESS_DEBUG_EVENT:
            {
                proc.SetDeleted();
                proc.SetMachine(null);

                if (proc.IsStarted() && mCallback !is null)
                {
                    proc.Unlock();
                    mCallback.OnProcessExit(proc, debugEvent.u.ExitProcess.dwExitCode);
                    proc.Lock();
                }

                mProcMap.erase(debugEvent.dwProcessId);
            }
            break;

        case LOAD_DLL_DEBUG_EVENT:
            {
                Module mod;

                hr = CreateModule(proc, debugEvent, mod);
                if (FAILED(hr))
                    goto Error;

                if (proc.GetOSModule() is null)
                {
                    proc.SetOSModule(mod);
                }

                if (mCallback !is null)
                {
                    proc.Unlock();
                    mCallback.OnModuleLoad(proc, mod.Get());
                    proc.Lock();
                }
            }
            break;

        case UNLOAD_DLL_DEBUG_EVENT:
            {
                if (mCallback !is null)
                {
                    proc.Unlock();
                    mCallback.OnModuleUnload(proc, cast(Address) debugEvent.u.UnloadDll.lpBaseOfDll);
                    proc.Lock();
                }
            }
            break;

        case EXCEPTION_DEBUG_EVENT:
            {
                hr = HandleException(proc, debugEvent);
            }
            break;

        case OUTPUT_DEBUG_STRING_EVENT:
            {
                hr = HandleOutputString(proc, debugEvent);
            }
            break;

        case RIP_EVENT:
            break;
        default:
            break;
        }

    Error:
        if (FAILED(hr))
        {
            assert(debugEvent.dwDebugEventCode < gEventMap.length);
            IEventCallback.EventCode code = gEventMap[debugEvent.dwDebugEventCode];

            if (mCallback !is null)
            {
                proc.Unlock();
                mCallback.OnError(proc, hr, code);
                proc.Lock();
            }
        }

        mIsDispatching = false;

        return hr;
    }

    HRESULT HandleCreateThread(Process proc, ref const DEBUG_EVENT debugEvent)
    {
        HRESULT hr = S_OK;
        IMachine machine = proc.GetMachine();
        Thread thread;

        hr = CreateThread(proc, debugEvent, thread);
        if (FAILED(hr))
            goto Error;

        proc.AddThread(thread.Get());

        hr = machine.OnCreateThread(thread.Get());
        if (FAILED(hr))
            goto Error;

        if (proc.GetSuspendCount() > 0)
        {
            // if all threads are meant to be suspended, then include this one
            ThreadControlProc controlProc = machine.GetWinSuspendThreadProc();
            HANDLE hThread = debugEvent.u.CreateThread.hThread;

            for (int i = 0; i < proc.GetSuspendCount(); i++)
            {
                DWORD suspendCount = controlProc(hThread);
                if (suspendCount == DWORD - 1)
                {
                    hr = GetLastHr();
                    goto Error;
                }
            }
        }

        if (mCallback !is null)
        {
            proc.Unlock();
            mCallback.OnThreadStart(proc, thread.Get());
            proc.Lock();
        }

    Error:
        return hr;
    }

    HRESULT HandleException(Process proc, ref const DEBUG_EVENT debugEvent)
    {
        HRESULT hr = S_OK;
        IMachine* machine = proc.GetMachine();

        // it doesn't matter if we launched or attached
        if (FoundLoaderBp(proc, debugEvent))
        {
            proc.SetReachedLoaderBp();

            if (mCallback !is null)
            {
                proc.Unlock();
                mCallback.OnLoadComplete(proc, debugEvent.dwThreadId);
                proc.Lock();
            }

            hr = S_FALSE;
        }
        else
        {
            MachineResult result = MacRes_NotHandled;
            ProbeCallback probeCallback = new ProbeCallback(mCallback, proc);

            machine.SetCallback(&probeCallback);
            hr = machine.OnException(debugEvent.dwThreadId, &debugEvent.u.Exception, result);
            machine.SetCallback(null);
            if (FAILED(hr))
                goto Error;

            if (result == MacRes_PendingCallbackBP || result == MacRes_PendingCallbackEmbeddedBP)
            {
                Address addr = 0;
                bool embedded = (result == MacRes_PendingCallbackEmbeddedBP);

                machine.GetPendingCallbackBP(addr);

                proc.Unlock();
                RunMode mode = mCallback.OnBreakpoint(proc, debugEvent.dwThreadId, addr, embedded);
                proc.Lock();
                if (mode == RunMode_Run)
                    result = MacRes_HandledContinue;
                else if (mode == RunMode_Wait)
                    result = MacRes_HandledStopped;
                else // Break
                {
                    result = MacRes_HandledStopped;
                    hr = machine.CancelStep();
                    if (FAILED(hr))
                        goto Error;
                }
            }
            else if (result == MacRes_PendingCallbackStep
                    || result == MacRes_PendingCallbackEmbeddedStep)
            {
                proc.Unlock();
                mCallback.OnStepComplete(proc, debugEvent.dwThreadId);
                proc.Lock();
                result = MacRes_HandledStopped;
            }

            if (result == MacRes_NotHandled)
            {
                hr = S_FALSE;
                if (mCallback !is null)
                {
                    proc.Unlock();
                    if (mCallback.OnException(proc, debugEvent.dwThreadId,
                            (debugEvent.u.Exception.dwFirstChance > 0),
                            &debugEvent.u.Exception.ExceptionRecord) == RunMode_Run)
                        hr = S_OK;
                    proc.Lock();
                }
            }
            else if (result == MacRes_HandledStopped)
            {
                hr = S_FALSE;
            }
            // else, MacRes_HandledContinue, hr == S_OK
        }

    Error:
        return hr;
    }

    HRESULT HandleOutputString(Process proc, ref const DEBUG_EVENT debugEvent)
    {
        HRESULT hr = S_OK;
        const uint16_t TotalLen = debugEvent.u.DebugString.nDebugStringLength;
        SIZE_T bytesRead = 0;
        BOOL bRet = FALSE;
        /+UniquePtr<wchar_t[]> wstr(
                new wchar_t[TotalLen]);+/

        if (wstr.Get() is null)
            return E_OUTOFMEMORY;

        if (debugEvent.u.DebugString.fUnicode)
        {
            bRet = ReadProcessMemory(proc.GetHandle(), debugEvent.u.DebugString.lpDebugStringData,
                    wstr.Get(), TotalLen * wchar_t.sizeof, &bytesRead);
            wstr[TotalLen - 1] = '\0';

            if (!bRet)
                return GetLastHr();
        }
        else
        {
            /+UniquePtr<char[]> astr(
                    new char[TotalLen]);+/
            int countRet = 0;

            if (astr is null)
                return E_OUTOFMEMORY;

            bRet = ReadProcessMemory(proc.GetHandle(), debugEvent.u.DebugString.lpDebugStringData,
                    astr.Get(), TotalLen * char.sizeof, &bytesRead);
            astr[TotalLen - 1] = '\0';

            if (!bRet)
                return GetLastHr();

            countRet = MultiByteToWideChar(CP_ACP, MB_ERR_INVALID_CHARS | MB_USEGLYPHCHARS,
                    astr.Get(), -1, wstr.Get(), TotalLen);

            if (countRet == 0)
                return GetLastHr();
        }

        if (mCallback !is null)
        {
            proc.Unlock();
            mCallback.OnOutputString(proc, wstr.Get());
            proc.Lock();
        }

        return hr;
    }

    HRESULT ContinueNoLock(Process process, bool handleException)
    {
        assert(proc !is null);
        assert(proc.IsStopped());

        HRESULT hr = S_OK;

        if (!proc.IsDeleted() && !proc.IsTerminating())
        {
            IMachine machine = proc.GetMachine();
            assert(machine !is null);

            hr = machine.SetContinue();
            if (FAILED(hr))
                goto Error;
        }

        hr = ContinueInternal(proc, handleException);

    Error:
        return hr;
    }

    HRESULT ContinueInternal(Process proc, bool handleException)
    {
        assert(proc !is null);
        assert(proc.IsStopped());

        HRESULT hr = S_OK;
        BOOL bRet = FALSE;
        DWORD status = DBG_CONTINUE;
        ShortDebugEvent lastEvent = proc.GetLastEvent();

        // always treat the SS exception as a step complete
        // always treat the BP exception as a user BP, instead of an exception

        if ((lastEvent.EventCode == EXCEPTION_DEBUG_EVENT) && (lastEvent.ExceptionCode != EXCEPTION_BREAKPOINT)
                && (lastEvent.ExceptionCode != EXCEPTION_SINGLE_STEP))
            status = handleException ? DBG_CONTINUE : DBG_EXCEPTION_NOT_HANDLED;

        if (!proc.IsDeleted() && !proc.IsTerminating())
        {
            IMachine* machine = proc.GetMachine();
            assert(machine !is null);

            hr = machine.OnContinue();
            if (FAILED(hr))
                goto Error;
        }

        bRet = .ContinueDebugEvent(proc.GetId(), lastEvent.ThreadId, status);
        assert(bRet);
        if (!bRet)
        {
            hr = GetLastHr();
            goto Error;
        }

        proc.SetStopped(false);
        proc.ClearLastEvent();

    Error:
        return hr;
    }

    void CleanupLastDebugEvent()
    {
        if (mLastEvent.dwDebugEventCode == CREATE_PROCESS_DEBUG_EVENT)
        {
            CloseHandle(mLastEvent.u.CreateProcessInfo.hFile);
        }
        else if (mLastEvent.dwDebugEventCode == LOAD_DLL_DEBUG_EVENT)
        {
            CloseHandle(mLastEvent.u.LoadDll.hFile);
        }

        memset(&mLastEvent, 0, mLastEvent.sizeof);
    }

    void ResumeSuspendedProcess(IProcess process)

    {
        Process proc = cast(Process) process;
        if (proc.GetLaunchedSuspendedThread() !is null)
        {
            ResumeThread(proc.GetLaunchedSuspendedThread());
            proc.SetLaunchedSuspendedThread(null);
        }
    }

    Process FindProcess(uint32_t id)
    {
        ProcessMap.iterator it = mProcMap.find(id);

        if (it == mProcMap.end())
            return null;

        return it.second.Get();
    }

    HRESULT CreateModule(Process proc, ref const DEBUG_EVENT event, ref mod)
    {
        assert(proc !is null);

        HRESULT hr = S_OK;
        wstring path;
        RefPtr < Module > newMod;
        const LOAD_DLL_DEBUG_INFO* loadInfo = &event.u.LoadDll;
        LOAD_DLL_DEBUG_INFO fakeLoadInfo = {0};
        ImageInfo imageInfo = {0};

        if (event.dwDebugEventCode == CREATE_PROCESS_DEBUG_EVENT)
        {
            loadInfo = &fakeLoadInfo;
            fakeLoadInfo.lpBaseOfDll = event.u.CreateProcessInfo.lpBaseOfImage;
            fakeLoadInfo.dwDebugInfoFileOffset = event.u.CreateProcessInfo.dwDebugInfoFileOffset;
            fakeLoadInfo.nDebugInfoSize = event.u.CreateProcessInfo.nDebugInfoSize;
            fakeLoadInfo.hFile = event.u.CreateProcessInfo.hFile;
        }
        else
        {
            assert(event.dwDebugEventCode == LOAD_DLL_DEBUG_EVENT);
        }

        hr = mResolver.GetFilePath(proc.GetHandle(), loadInfo.hFile, loadInfo.lpBaseOfDll, path);
        if (FAILED(hr))
            goto Error;

        hr = GetLoadedImageInfo(proc.GetHandle(), loadInfo.lpBaseOfDll, imageInfo);
        if (FAILED(hr))
            goto Error;

        newMod = new Module(mDebuggerProxy, cast(Address) loadInfo.lpBaseOfDll, imageInfo.Size, imageInfo.MachineType,
                path.c_str(), loadInfo.dwDebugInfoFileOffset, loadInfo.nDebugInfoSize);
        if (newMod is null)
        {
            hr = E_OUTOFMEMORY;
            goto Error;
        }

        mod = newMod;
        mod.SetPreferredImageBase(imageInfo.PrefImageBase);

    Error:
        return hr;
    }

    HRESULT CreateThread(Process proc, ref const DEBUG_EVENT event, ref thread)
    {
        _ASSERT(proc !is null);
        UNREFERENCED_PARAMETER(proc);

        HRESULT hr = S_OK;
        RefPtr < Thread > newThread;
        const CREATE_THREAD_DEBUG_INFO* createInfo = &event.u.CreateThread;
        CREATE_THREAD_DEBUG_INFO fakeCreateInfo = {0};

        if (event.dwDebugEventCode == CREATE_PROCESS_DEBUG_EVENT)
        {
            createInfo = &fakeCreateInfo;
            fakeCreateInfo.hThread = event.u.CreateProcessInfo.hThread;
            fakeCreateInfo.lpThreadLocalBase = event.u.CreateProcessInfo.lpThreadLocalBase;
            fakeCreateInfo.lpStartAddress = event.u.CreateProcessInfo.lpStartAddress;
        }
        else
        {
            _ASSERT(event.dwDebugEventCode == CREATE_THREAD_DEBUG_EVENT);
        }

        HandlePtr hThreadPtr;
        HANDLE hCurProc = GetCurrentProcess();
        BOOL bRet = DuplicateHandle(hCurProc, createInfo.hThread, hCurProc,
                &hThreadPtr.Ref(), 0, FALSE, DUPLICATE_SAME_ACCESS);
        if (!bRet)
        {
            hr = GetLastHr();
            goto Error;
        }

        newThread = new Thread(hThreadPtr.Get(), event.dwThreadId,
                cast(Address) createInfo.lpStartAddress, cast(Address) createInfo.lpThreadLocalBase);
        if (newThread is null)
        {
            hr = E_OUTOFMEMORY;
            goto Error;
        }

        hThreadPtr.Detach();
        thread = newThread;

    Error:
        return hr;
    }

    bool FoundLoaderBp(Process proc, ref const DEBUG_EVENT event)
    {
        if (!proc.ReachedLoaderBp())
        {
            if (debugEvent.u.Exception.ExceptionRecord.ExceptionCode == STATUS_BREAKPOINT)
            {
                Address exceptAddr = cast(Address) debugEvent.u.Exception
                    .ExceptionRecord.ExceptionAddress;
                Module osMod = proc.GetOSModule();

                if (osMod !is null && osMod.Contains(exceptAddr))
                {
                    return true;
                }
            }
        }

        return false;
    }
}
