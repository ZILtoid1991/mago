module exec.debuggerproxy;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

//alias uint( * CrtThreadProc)(void * );

// these values can be tweaked, as long as we're responsive and don't spin
immutable DWORD EventTimeoutMillis = 50;
immutable DWORD CommandTimeoutMillis = 0;

class DebuggerProxy
{
    Exec mExec;
    HANDLE mhThread;
    DWORD mWorkerTid;
    IEventCallback* mCallback;
    HANDLE mhReadyEvent;
    HANDLE mhCommandEvent;
    HANDLE mhResultEvent;
    CommandFunctor* mCurCommand;
    volatile bool mShutdown;
    Guard mCommandGuard;
    wstring mSymbolSearchPath;

public:
    this()
    {
        mhThread = null;
        mWorkerTid = 0;
        mCallback = null;
        mhReadyEvent = null;
        mhCommandEvent = null;
        mhResultEvent = null;
        mCurCommand = null;
        mShutdown = false;
    }

    ~this()
    {
        // TODO: use smart pointers

        Shutdown();

        if (mhThread !is null)
            CloseHandle(mhThread);

        if (mhReadyEvent !is null)
            CloseHandle(mhReadyEvent);

        if (mhCommandEvent !is null)
            CloseHandle(mhCommandEvent);

        if (mhResultEvent !is null)
            CloseHandle(mhResultEvent);
    }

    HRESULT Init(IEventCallback callback)
    {
        assert(callback !is null);
        if ((callback is null))
            return E_INVALIDARG;
        if ((mCallback !is null))
            return E_ALREADY_INIT;

        HandlePtr hReadyEvent;
        HandlePtr hCommandEvent;
        HandlePtr hResultEvent;

        hReadyEvent = CreateEvent(null, TRUE, FALSE, null);
        if (hReadyEvent.IsEmpty())
            return GetLastHr();

        hCommandEvent = CreateEvent(null, TRUE, FALSE, null);
        if (hCommandEvent.IsEmpty())
            return GetLastHr();

        hResultEvent = CreateEvent(null, TRUE, FALSE, null);
        if (hResultEvent.IsEmpty())
            return GetLastHr();

        mhReadyEvent = hReadyEvent.Detach();
        mhCommandEvent = hCommandEvent.Detach();
        mhResultEvent = hResultEvent.Detach();

        mCallback = callback;
        mCallback.AddRef();

        return S_OK;
    }

    HRESULT Start()
    {
        assert(mCallback !is null);
        if ((mCallback is null))
            return E_UNEXPECTED;
        if (mhThread !is null)
            return E_UNEXPECTED;

        HandlePtr hThread;

        hThread = cast(HANDLE) _beginthreadex(null, 0,
                cast(CrtThreadProc) DebugPollProc, this, 0, null);
        if (hThread.IsEmpty())
            return GetLastHr();

        HANDLE waitObjs[2] = [mhReadyEvent, hThread.Get()];
        DWORD waitRet = 0;

        // TODO: on error, thread will be shutdown from Shutdown method

        waitRet = WaitForMultipleObjects(waitObjs.length, waitObjs, FALSE, INFINITE);
        if (waitRet == WAIT_FAILED)
            return GetLastHr();

        if (waitRet == WAIT_OBJECT_0 + 1)
        {
            DWORD exitCode = cast(DWORD) E_FAIL;

            // the thread ended because of an error, let's get the return exit code
            GetExitCodeThread(hThread.Get(), &exitCode);

            return cast(HRESULT) exitCode;
        }
        assert(waitRet == WAIT_OBJECT_0);

        mhThread = hThread.Detach();

        return S_OK;
    }

    void Shutdown()
    {
        // TODO: is this enough?

        mShutdown = true;

        if (mhThread !is null)
        {
            // there are no infinite waits on the poll thread, so it'll detect shutdown signal
            WaitForSingleObject(mhThread, INFINITE);
        }

        if (mCallback !is null)
        {
            mCallback.Release();
            mCallback = null;
        }
    }

    //----------------------------------------------------------------------------
    // Commands
    //----------------------------------------------------------------------------

    HRESULT Launch(LaunchInfo launchInfo, ref IProcess process)
    {
        HRESULT hr = S_OK;
        LaunchParams params = LaunchParams(mExec);

        params.Settings = launchInfo;

        hr = InvokeCommand(params);
        if (FAILED(hr))
            return hr;

        if (SUCCEEDED(params.OutHResult))
            process = params.OutProcess.Detach();

        return params.OutHResult;
    }

    HRESULT Attach(uint32_t id, ref IProcess process)
    {
        HRESULT hr = S_OK;
        AttachParams params = AttachParams(mExec);

        params.ProcessId = id;

        hr = InvokeCommand(params);
        if (FAILED(hr))
            return hr;

        if (SUCCEEDED(params.OutHResult))
            process = params.OutProcess.Detach();

        return params.OutHResult;
    }

    HRESULT Terminate(IProcess process)
    {
        HRESULT hr = S_OK;
        TerminateParams params = TerminateParams(mExec);

        params.Process = process;

        hr = InvokeCommand(params);
        if (FAILED(hr))
            return hr;

        return params.OutHResult;
    }

    HRESULT Detach(IProcess process)
    {
        HRESULT hr = S_OK;
        DetachParams params = DetachParams(mExec);

        params.Process = process;

        hr = InvokeCommand(params);
        if (FAILED(hr))
            return hr;

        return params.OutHResult;
    }

    HRESULT ResumeLaunchedProcess(IProcess process)
    {
        HRESULT hr = S_OK;
        ResumeLaunchedProcessParams params = ResumeLaunchedProcessParams(mExec);

        params.Process = process;

        hr = InvokeCommand(params);
        if (FAILED(hr))
            return hr;

        return params.OutHResult;
    }

    HRESULT ReadMemory(IProcess process, Address address, uint32_t length,
            ref uint32_t lengthRead, ref uint32_t lengthUnreadable, uint8_t* buffer)
    {
        // call it directly for performance (it gets called a lot for stack walking)
        // we're allowed to, since this function is now free threaded
        return mExec.ReadMemory(process, address, length, lengthRead, lengthUnreadable, buffer);
    }

    HRESULT WriteMemory(IProcess process, Address address, uint32_t length,
            ref uint32_t lengthWritten, uint8_t* buffer)
    {
        HRESULT hr = S_OK;
        WriteMemoryParams params = WriteMemoryParams(mExec);

        params.Process = process;
        params.Address = address;
        params.Length = length;
        params.Buffer = buffer;

        hr = InvokeCommand(params);
        if (FAILED(hr))
            return hr;

        if (SUCCEEDED(params.OutHResult))
            lengthWritten = params.OutLengthWritten;

        return params.OutHResult;
    }

    HRESULT SetBreakpoint(IProcess process, Address address)
    {
        return mExec.SetBreakpoint(process, address);
    }

    HRESULT RemoveBreakpoint(IProcess process, Address address)
    {
        return mExec.RemoveBreakpoint(process, address);
    }

    HRESULT StepOut(IProcess process, Address targetAddr, bool handleException)
    {
        HRESULT hr = S_OK;
        StepOutParams params = StepOutParams(mExec);

        params.Process = process;
        params.TargetAddress = targetAddr;
        params.HandleException = handleException;

        hr = InvokeCommand(params);
        if (FAILED(hr))
            return hr;

        return params.OutHResult;
    }

    HRESULT StepInstruction(IProcess process, bool stepIn, bool handleException)
    {
        HRESULT hr = S_OK;
        StepInstructionParams params = StepInstructionParams(mExec);

        params.Process = process;
        params.StepIn = stepIn;
        params.HandleException = handleException;

        hr = InvokeCommand(params);
        if (FAILED(hr))
            return hr;

        return params.OutHResult;
    }

    HRESULT StepRange(IProcess process, bool stepIn, AddressRange range, bool handleException)
    {
        HRESULT hr = S_OK;
        StepRangeParams params = StepRangeParams(mExec);

        params.Process = process;
        params.StepIn = stepIn;
        params.Range = range;
        params.HandleException = handleException;

        hr = InvokeCommand(params);
        if (FAILED(hr))
            return hr;

        return params.OutHResult;
    }

    HRESULT Continue(IProcess process, bool handleException)
    {
        HRESULT hr = S_OK;
        ContinueParams params = ContinueParams(mExec);

        params.Process = process;
        params.HandleException = handleException;

        hr = InvokeCommand(params);
        if (FAILED(hr))
            return hr;

        return params.OutHResult;
    }

    HRESULT Execute(IProcess process, bool handleException)
    {
        HRESULT hr = S_OK;
        ExecuteParams params = ExecuteParams(mExec);

        params.Process = process;
        params.HandleException = handleException;

        hr = InvokeCommand(params);
        if (FAILED(hr))
            return hr;

        return params.OutHResult;
    }

    HRESULT AsyncBreak(IProcess process)
    {
        HRESULT hr = S_OK;
        AsyncBreakParams params = AsyncBreakParams(mExec);

        params.Process = process;

        hr = InvokeCommand(params);
        if (FAILED(hr))
            return hr;

        return params.OutHResult;
    }

    HRESULT GetThreadContext(IProcess process, uint32_t threadId,
            uint32_t features, uint64_t extFeatures, void* context, uint32_t size)
    {
        assert(process !is null);
        if (process is null)
            return E_INVALIDARG;

        HRESULT hr = S_OK;

        hr = mExec.GetThreadContext(process, threadId, features, extFeatures, context, size);
        if (FAILED(hr))
            return hr;

        return S_OK;
    }

    HRESULT DebuggerProxy.SetThreadContext(IProcess process, uint32_t threadId,
            const(void) * context, uint32_t size)
    {
        assert(process !is null);
        if (process is null)
            return E_INVALIDARG;

        HRESULT hr = S_OK;

        hr = mExec.SetThreadContext(process, threadId, context, size);
        if (FAILED(hr))
            return hr;

        return S_OK;
    }

    HRESULT GetPData(IProcess process, Address address, Address imageBase,
            uint32_t size, ref uint32_t sizeRead, uint8_t* pdata)
    {
        assert(process !is null);
        if (process is null)
            return E_INVALIDARG;

        HRESULT hr = S_OK;

        hr = mExec.GetPData(process, address, imageBase, size, sizeRead, pdata);
        if (FAILED(hr))
            return hr;

        return S_OK;
    }

    //----------------------------------------------------------------------------
    //  Poll thread
    //----------------------------------------------------------------------------

    void SetSymbolSearchPath(ref const wstring searchPath)
    {
        mSymbolSearchPath = searchPath;
    }

    ref const std.wstring GetSymbolSearchPath() const
    {
        return mSymbolSearchPath;
    }

private:
    DWORD DebugPollProc(void* param)
    {
        assert(param !is null);

        DebuggerProxy* pThis = cast(DebuggerProxy*) param;

        CoInitializeEx(null, COINIT_MULTITHREADED);
        HRESULT hr = pThis.PollLoop();
        CoUninitialize();

        return hr;
    }

    HRESULT PollLoop()
    {
        HRESULT hr = S_OK;

        hr = mExec.Init(mCallback, this);
        if (FAILED(hr))
            return hr;

        SetReadyThread();

        while (!mShutdown)
        {
            hr = mExec.WaitForEvent(EventTimeoutMillis);
            if (FAILED(hr))
            {
                if (hr == E_HANDLE)
                {
                    // no debuggee has started yet
                    Sleep(EventTimeoutMillis);
                }
                else if (hr != E_TIMEOUT)
                    break;
            }
            else
            {
                hr = mExec.DispatchEvent();
                if (FAILED(hr))
                    break;
            }

            hr = CheckMessage();
            if (FAILED(hr))
                break;
        }

        mExec.Shutdown();

        Log.LogMessage("Poll loop shutting down.\n");
        return hr;
    }

    void SetReadyThread()
    {
        assert(mhReadyEvent !is null);

        mWorkerTid = GetCurrentThreadId();
        SetEvent(mhReadyEvent);
    }

    HRESULT CheckMessage()
    {
        HRESULT hr = S_OK;
        DWORD waitRet = 0;

        waitRet = WaitForSingleObject(mhCommandEvent, CommandTimeoutMillis);
        if (waitRet == WAIT_FAILED)
            return GetLastHr();

        if (waitRet == WAIT_TIMEOUT)
            return S_OK;

        hr = ProcessCommand(mCurCommand);
        if (FAILED(hr))
            return hr;

        ResetEvent(mhCommandEvent);
        SetEvent(mhResultEvent);

        return S_OK;
    }

    HRESULT ProcessCommand(CommandFunctor cmd)
    {
        assert(cmd !is null);
        if (cmd is null)
            return E_POINTER;

        cmd.Run();

        return S_OK;
    }

    HRESULT InvokeCommand(ref CommandFunctor cmd)
    {
        if (mWorkerTid == GetCurrentThreadId())
        {
            // since we're on the poll thread, we can run the command directly
            cmd.Run();
        }
        else
        {
            GuardedArea area = GuardedArea(mCommandGuard);

            mCurCommand = cmd;

            ResetEvent(mhResultEvent);
            SetEvent(mhCommandEvent);

            DWORD waitRet = 0;
            HANDLE handles[2] = [mhResultEvent, mhThread];

            waitRet = WaitForMultipleObjects(handles.length, handles, FALSE, INFINITE);
            mCurCommand = null;
            if (waitRet == WAIT_FAILED)
                return GetLastHr();

            if (waitRet == WAIT_OBJECT_0 + 1)
                return CO_E_REMOTE_COMMUNICATION_FAILURE;
        }

        return S_OK;
    }
}
