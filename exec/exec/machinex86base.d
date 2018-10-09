module exec.machinex86base;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

// #pragma once

import exec.machine;
import exec.common;
import exec.thread;
import exec.threadx86;

class Breakpoint
{
    LONG mRefCount;
    Address mAddress;
    int32_t mStepCount;
    uint8_t mOrigInstByte;
    uint8_t mTempInstByte;
    bool mPatched;
    bool mUser;
    bool mLocked;

public:
    /+static Breakpoint opCall()
    {   mRefCount = ( 0 );
            mAddress = ( 0 );
            mStepCount = ( 0 );
            mOrigInstByte = ( 0 );
            mTempInstByte = ( 0 );
            mPatched = ( false );
            mUser = ( false );
            mLocked = ( false );
    }+/
    this()
    {

    }

    @nogc void AddRef()
    {
        mRefCount++;
    }

    @nogc void Release()
    {
        mRefCount--;
        assert(mRefCount >= 0);
        if (mRefCount == 0)
        {
            this.destroy;
        }
    }

    @nogc Address GetAddress()
    {
        return mAddress;
    }

    @nogc void SetAddress(Address address)
    {
        mAddress = address;
    }

    @nogc uint8_t GetOriginalInstructionByte()
    {
        return mOrigInstByte;
    }

    @nogc void SetOriginalInstructionByte(uint8_t data)
    {
        mOrigInstByte = data;
    }

    @nogc uint8_t GetTempInstructionByte()
    {
        return mTempInstByte;
    }

    @nogc void SetTempInstructionByte(uint8_t data)
    {
        mTempInstByte = data;
    }

    @nogc bool IsPatched()
    {
        return mPatched;
    }

    @nogc void SetPatched(bool value)
    {
        mPatched = value;
    }

    @nogc bool IsUser()
    {
        return mUser;
    }

    @nogc void SetUser(bool value)
    {
        mUser = value;
    }

    @nogc bool IsActive()
    {
        return mUser || mStepCount > 0 || mLocked;
    }

    @nogc bool IsStepping()
    {
        return mStepCount > 0;
    }

    void AddStepper()
    {
        assert(mStepCount >= 0);
        assert(mStepCount < limit_max(mStepCount));
        mStepCount++;
    }

    void RemoveStepper()
    {
        _ASSERT(mStepCount > 0);
        mStepCount--;
    }

    bool IsLocked()
    {
        return mLocked;
    }

    void SetLocked(bool value)
    {
        mLocked = value;
    }
}

alias BPAddressTable = Breakpoint[Address];

const uint8_t BreakpointInstruction = 0xCC;
const uint32_t STATUS_WX86_SINGLE_STEP = 0x4000001E;
const uint32_t STATUS_WX86_BREAKPOINT = 0x4000001F;

class MachineX86Base : IMachine
{
    alias ThreadMap = ThreadX86Base[uint32_t];
    //alias  std.map!( uint32_t, ThreadX86Base* )    ThreadMap;
    alias RangeStepPtr = RangeStep;
    //alias  UniquePtr!(RangeStep)                    RangeStepPtr;

    LONG mRefCount;

    // keep a weak pointer to the process object, because process owns machine
    Process mProcess;
    HANDLE mhProcess;
    BPAddressTable mAddrTable;
    uint32_t mStoppedThreadId;
    bool mStoppedOnException;
    bool mStopped;

    ThreadMap mThreads;
    ThreadX86Base mCurThread;
    uint32_t mIsolatedThreadId;
    bool mIsolatedThread;

    IProbeCallback mCallback;
    Address mPendCBAddr;

public:
    this()
    {

    }

    ~this()
    {
        if (mAddrTable !is null)
        {
            for (BPAddressTable.iterator it = mAddrTable.begin(); it != mAddrTable.end();
                    it++)
            {
                it.second.Release();
            }
        }

        for (ThreadMap.iterator it = mThreads.begin(); it != mThreads.end(); it++)
        {

        }
    }

    void AddRef()
    {
        InterlockedIncrement(&mRefCount);
    }

    void Release()
    {
        LONG newRef = InterlockedDecrement(&mRefCount);
        assert(newRef >= 0);
        if (newRef == 0)
        {
            delete this;
        }
    }

    HRESULT Init()
    {
        //std.auto_ptr < BPAddressTable > addrTable(new BPAddressTable());

        /+if (addrTable.get() is null)
            return E_OUTOFMEMORY;

        mAddrTable = addrTable.release();+/

        return S_OK;
    }

    void SetProcess(HANDLE hProcess, Process* process)
    {
        assert(mProcess is null);
        assert(mhProcess is null);
        assert(hProcess !is null);
        assert(process !is null);

        mProcess = process;
        mhProcess = hProcess;
    }

    void SetCallback(IProbeCallback callback)
    {
        mCallback = callback;
    }

    void GetPendingCallbackBP(ref Address address)
    {
        address = mPendCBAddr;
    }

    HRESULT ReadMemory(Address address, uint32_t length, ref uint32_t lengthRead,
            ref uint32_t lengthUnreadable, uint8_t* buffer)
    {
        return ReadCleanMemory(address, length, lengthRead, lengthUnreadable, buffer);
    }

    HRESULT WriteMemory(Address address, uint32_t length,
            ref uint32_t lengthWritten, uint8_t* buffer)
    {
        assert(mStoppedThreadId != 0);
        if (mStoppedThreadId == 0)
            return E_WRONG_STATE;

        return WriteCleanMemory(address, length, lengthWritten, buffer);
    }

    HRESULT SetBreakpoint(Address address)
    {
        assert(mhProcess !is null);
        if (mhProcess is null)
            return E_UNEXPECTED;

        return SetBreakpointInternal(address, true);
    }

    HRESULT RemoveBreakpoint(Address address)
    {
        assert(mhProcess !is null);
        if (mhProcess is null)
            return E_UNEXPECTED;

        return RemoveBreakpointInternal(address, true);
    }

    bool IsBreakpointActive(Address address)
    {
        BPAddressTable.iterator it = mAddrTable.find(address);
        bool isActive = false;

        if (it != mAddrTable.end())
            isActive = true;

        return isActive;
    }

    HRESULT SetContinue()
    {
        assert(mhProcess !is null);
        assert(mStoppedThreadId != 0);

        HRESULT hr = S_OK;
        Address pc = 0;
        Breakpoint bp = null;
        InstructionType instType = Inst_None;
        int instLen = 0;

        if (!mStoppedOnException)
            return S_OK;

        if (mCurThread is null)
            return S_OK;

        hr = GetCurrentPC(pc);
        if (FAILED(hr))
            goto Error;

        bp = FindBP(pc);

        hr = ReadInstruction(pc, instType, instLen);
        if (FAILED(hr))
            goto Error;

        if (instType == Inst_Breakpoint)
        {
            assert(mCurThread.GetExpectedCount() == 0);

            // when we came to break mode, we rewound the PC
            // move it back, because we don't want to run the BP instruction again

            // skip over the BP instruction
            hr = ChangeCurrentPC(1);
            if (FAILED(hr))
                goto Error;
        }
        else
        {
            assert(mCurThread.GetExpectedCount() < 2);
            if (bp !is null && bp.IsPatched())
            {
                int notifier = NotifyRun;

                ExpectedEvent event = mCurThread.GetTopExpected();
                if (event !is null && event.Code == Expect_SS)
                    notifier = NotifyTrigger;

                RangeStepPtr emptyRangeStep;
                hr = PassBP(pc, instType, instLen, notifier, Motion_None, emptyRangeStep);
                if (FAILED(hr))
                    goto Error;
            }
            // else, nothing to do, you can continue
        }

    Error:
        return hr;
    }

    HRESULT SetStepOut(Address targetAddress)
    {
        assert(mhProcess !is null);
        if (mhProcess is null)
            return E_UNEXPECTED;
        assert(mStoppedThreadId != 0);
        if (mStoppedThreadId == 0)
            return E_WRONG_STATE;

        HRESULT hr = S_OK;
        ExpectedEvent event;

        if (!mStoppedOnException)
            return S_OK;

        hr = CancelStep();
        if (FAILED(hr))
            goto Error;

        event = mCurThread.PushExpected(Expect_BP, NotifyStepComplete);
        if (event is null)
        {
            hr = E_FAIL;
            goto Error;
        }

        event.BPAddress = targetAddress;
        event.RemoveBP = true;

        hr = SetBreakpointInternal(targetAddress, false);
        if (FAILED(hr))
            goto Error;

        hr = SetContinue();
        if (FAILED(hr))
            goto Error;

    Error:
        if (FAILED(hr))
        {
            if (event !is null)
                mCurThread.PopExpected();
        }
        return hr;
    }

    HRESULT SetStepInstruction(bool stepIn)
    {
        RangeStep emptyRangeStep;
        Motion motion = stepIn ? Motion_StepIn : Motion_StepOver;

        return SetStepInstructionCore(motion, emptyRangeStep, NotifyStepComplete);
    }

    HRESULT SetStepRange(bool stepIn, AddressRange range)
    {
        Motion motion = stepIn ? Motion_RangeStepIn : Motion_RangeStepOver;

        RangeStep rangeStep = RangeStep(ThreadX86Base.AllocRange());
        if (rangeStep is null)
            return E_OUTOFMEMORY;

        rangeStep.Range = range;

        return SetStepInstructionCore(motion, rangeStep, NotifyCheckRange);
    }

    HRESULT CancelStep()
    {
        assert(mStoppedThreadId != 0);
        if (mStoppedThreadId == 0)
            return E_WRONG_STATE;

        HRESULT hr = S_OK;
        MachineResult result = MacRes_NotHandled;

        while (mCurThread.GetExpectedCount() > 0)
        {
            hr = RunAllActions(true, result);
            if (FAILED(hr))
                return hr;
        }

        return S_OK;
    }

    HRESULT GetThreadContext(uint32_t threadId, uint32_t features,
            uint64_t extFeatures, void* context, uint32_t size)
    {
        assert(mhProcess !is null);
        if (mhProcess is null)
            return E_UNEXPECTED;
        assert(mStoppedThreadId != 0);
        if (mStoppedThreadId == 0)
            return E_WRONG_STATE;

        if (context is null)
            return E_INVALIDARG;

        return GetThreadContextInternal(threadId, features, extFeatures, context, size);
    }

    HRESULT SetThreadContext(uint32_t threadId, const(void)* context, uint32_t size)
    {
        assert(mhProcess !is null);
        if (mhProcess is null)
            return E_UNEXPECTED;
        assert(mStoppedThreadId != 0);
        if (mStoppedThreadId == 0)
            return E_WRONG_STATE;

        if (context is null)
            return E_INVALIDARG;

        return SetThreadContextInternal(threadId, context, size);
    }

    void OnStopped(uint32_t threadId)
    {
        mStopped = true;
        mStoppedThreadId = threadId;
        mStoppedOnException = false;
        mCurThread = FindThread(threadId);
    }

    HRESULT OnCreateThread(Thread thread)
    {
        assert(thread !is null);

        HRESULT hr = S_OK;
        ThreadX86Base threadX86 = new ThreadX86Base(thread);

        if (threadX86.get() is null)
            return E_OUTOFMEMORY;

        mThreads.insert(ThreadMap.value_type(thread.GetId(), threadX86.get()));

        mCurThread = threadX86.release();

        if (mIsolatedThread)
        {
            // add the created thread to the set of those suspended and waiting for a BP restore
            ThreadControlProc suspendProc = GetWinSuspendThreadProc();
            hr = ControlThread(thread.GetHandle(), suspendProc);
            if (FAILED(hr))
                return hr;
        }

        return S_OK;
    }

    HRESULT OnExitThread(uint32_t threadId)
    {
        HRESULT hr = S_OK;
        ThreadMap.iterator it = mThreads.find(threadId);

        hr = CancelStep();
        if (FAILED(hr))
            return hr;

        if (it != mThreads.end())
        {
            delete it.second;
            mThreads.erase(it);
        }

        mCurThread = null;

        return S_OK;
    }

    HRESULT OnException(uint32_t threadId, const EXCEPTION_DEBUG_INFO* exceptRec,
            ref MachineResult result)
    {
        //UNREFERENCED_PARAMETER( threadId );
        assert(mhProcess !is null);
        if (mhProcess is null)
            return E_UNEXPECTED;
        assert(threadId != 0);
        assert(exceptRec !is null);
        assert(mCurThread !is null);

        HRESULT hr = S_OK;

        hr = CacheThreadContext();
        if (FAILED(hr))
            return hr;

        mStoppedOnException = true;

        if (exceptRec.ExceptionRecord.ExceptionCode == EXCEPTION_SINGLE_STEP)
        {
            return DispatchSingleStep(exceptRec, result);
        }

        if (exceptRec.ExceptionRecord.ExceptionCode == EXCEPTION_BREAKPOINT)
        {
            return DispatchBreakpoint(exceptRec, result);
        }

        hr = CancelStep();
        if (FAILED(hr))
            return hr;

        result = MacRes_NotHandled;
        return S_OK;
    }

    HRESULT OnContinue()
    {
        if (mhProcess is null)
            return E_UNEXPECTED;

        HRESULT hr = S_OK;

        hr = FlushThreadContext();
        if (FAILED(hr))
            goto Error;

        mStopped = false;
        mStoppedThreadId = 0;
        mCurThread = null;

    Error:
        return hr;
    }

    void OnDestroyProcess()
    {
        mhProcess = null;
        mProcess = null;
        mCurThread = null;
    }

    HRESULT Detach()
    {
        if (mIsolatedThread)
        {
            ResumeOtherThreads(mIsolatedThreadId);

            mIsolatedThread = false;
            mIsolatedThreadId = 0;
        }

        if (mAddrTable !is null)
        {
            for (BPAddressTable.iterator it = mAddrTable.begin(); it != mAddrTable.end();
                    it++)
            {
                Breakpoint* bp = it.second;

                if (bp.IsPatched())
                {
                    UnpatchBreakpoint(bp);
                }

                bp.Release();
            }

            mAddrTable.clear();
        }

        if (mStopped)
        {
            SetSingleStep(false);
            FlushThreadContext();
        }

        return S_OK;
    }

protected:
    abstract bool Is64Bit();
    abstract HRESULT CacheThreadContext();
    abstract HRESULT FlushThreadContext();
    // Only call after caching the thread context
    abstract HRESULT ChangeCurrentPC(int32_t byteOffset);
    abstract HRESULT SetSingleStep(bool enable);
    abstract HRESULT ClearSingleStep();
    abstract HRESULT GetCurrentPC(ref Address address);
    abstract HRESULT GetReturnAddress(ref Address address);

    abstract HRESULT SuspendThread(Thread* thread);
    abstract HRESULT ResumeThread(Thread* thread);

    abstract HRESULT GetThreadContextInternal(uint32_t threadId,
            uint32_t features, uint64_t extFeatures, void* context, uint32_t size);
    abstract HRESULT SetThreadContextInternal(uint32_t threadId, const(void)* context, uint32_t size);

    bool Stopped()
    {
        return mStopped;
    }

    ThreadX86Base GetStoppedThread()
    {
        return mCurThread;
    }

    HANDLE GetProcessHandle()
    {
        return mhProcess;
    }

private:
    HRESULT ReadCleanMemory(Address address, uint32_t length,
            ref uint32_t lengthRead, ref uint32_t lengthUnreadable, uint8_t* buffer)
    {
        HRESULT hr = S_OK;

        hr = .ReadMemory(mhProcess, address, length, lengthRead, lengthUnreadable, buffer);
        if (FAILED(hr))
            return hr;

        if (lengthRead > 0)
        {
            Address startAddr = address;
            Address endAddr = address + lengthRead - 1;

            // unpatch all BPs from the memory area we're returning

            for (BPAddressTable.iterator it = mAddrTable.begin(); it != mAddrTable.end();
                    it++)
            {
                Breakpoint bp = it.second;

                if (bp.IsPatched() && (it.first >= startAddr) && (it.first <= endAddr))
                {
                    Address offset = it.first - startAddr;
                    buffer[offset] = bp.GetOriginalInstructionByte();
                }
            }
        }

        return hr;
    }

    HRESULT WriteCleanMemory(Address address, uint32_t length,
            ref uint32_t lengthWritten, uint8_t* buffer)
    {
        BOOL bRet = FALSE;

        // The memory we're overwriting might be patched with BPs, so do it in 3 steps:
        // 1. For each BP in the target mem. range, 
        //      replace its original saved data with what's in the source buffer.
        // 2. For each BP in the target mem. range,
        //      patch a BP instruction in the source buffer.
        // 3. Write the source buffer to the process.

        if (length == 0)
            return S_OK;

        Address startAddr = address;
        Address endAddr = address + length - 1;

        for (BPAddressTable.iterator it = mAddrTable.begin(); it != mAddrTable.end();
                it++)
        {
            Breakpoint* bp = it.second;

            if (bp.IsPatched() && (it.first >= startAddr) && (it.first <= endAddr))
            {
                Address offset = it.first - startAddr;

                bp.SetTempInstructionByte(buffer[offset]);
                buffer[offset] = BreakpointInstruction;
            }
        }

        SIZE_T lenWritten = 0;

        bRet = WriteProcessMemory(mhProcess, cast(void*) address, buffer, length, &lenWritten);
        if (!bRet)
            return GetLastHr();

        lengthWritten = cast(uint32_t) lenWritten;

        // now commit all the bytes for the BPs we overwrote

        if (lengthWritten != length)
            return HRESULT_FROM_WIN32(ERROR_PARTIAL_COPY);

        endAddr = address + lengthWritten - 1;

        for (BPAddressTable.iterator it = mAddrTable.begin(); it != mAddrTable.end();
                it++)
        {
            Breakpoint* bp = it.second;

            if (bp.IsPatched() && (it.first >= startAddr) && (it.first <= endAddr))
            {
                bp.SetOriginalInstructionByte(bp.GetTempInstructionByte());
            }
        }

        return S_OK;
    }

    HRESULT SetBreakpointInternal(Address address, bool user)
    {
        HRESULT hr = S_OK;
        BPAddressTable.iterator it = mAddrTable.find(address);
        Breakpoint bp = null;
        bool wasActive = false;

        if (it == mAddrTable.end())
        {
            Breakpoint newBp = new Breakpoint();

            if (newBp.Get() is null)
            {
                hr = E_OUTOFMEMORY;
                goto Error;
            }

            mAddrTable.insert(BPAddressTable.value_type(address, newBp.Get()));
            bp = newBp.Detach();

            bp.SetAddress(address);
        }
        else
        {
            bp = it.second;
            wasActive = true;
        }

        if (user)
            bp.SetUser(true);
        else
            bp.AddStepper();

        // need to patch when going from not active to active
        if (!wasActive)
        {
            hr = PatchBreakpoint(bp);
            if (FAILED(hr))
                goto Error;
        }

    Error:
        return hr;
    }

    HRESULT RemoveBreakpointInternal(Address address, bool user)
    {
        HRESULT hr = S_OK;
        BPAddressTable.iterator it = mAddrTable.find(address);

        if (it == mAddrTable.end())
            return S_OK;

        Breakpoint bp = it.second;

        if (user)
            bp.SetUser(false);
        else
            bp.RemoveStepper();

        // not the last one, so nothing else to do
        if (bp.IsActive())
            return S_OK;

        // need to unpatch when going from active to not active

        hr = UnpatchBreakpoint(bp);

        mAddrTable.erase(it);

        bp.Release();

        if (FAILED(hr))
            goto Error;

    Error:
        return hr;
    }

    HRESULT PatchBreakpoint(Breakpoint bp)
    {
        assert(bp !is null);
        assert(!bp.IsPatched());

        HRESULT hr = S_OK;
        BOOL bRet = FALSE;
        uint8_t origData = 0;
        SIZE_T bytesRead = 0;
        SIZE_T bytesWritten = 0;
        void* address = cast(void*) bp.GetAddress();

        bRet = .ReadProcessMemory(mhProcess, address, &origData, 1, &bytesRead);
        if (!bRet)
        {
            hr = GetLastHr();
            goto Error;
        }

        bp.SetOriginalInstructionByte(origData);

        // looks like we don't have to worry about memory protection; VS doesn't
        // As a debugger, the only thing we can't write to is PAGE_NOACCESS.
        bRet = .WriteProcessMemory(mhProcess, address, &BreakpointInstruction, 1, &bytesWritten);
        if (!bRet)
        {
            hr = GetLastHr();
            goto Error;
        }

        .FlushInstructionCache(mhProcess, address, 1);
        bp.SetPatched(true);

    Error:
        return hr;
    }

    HRESULT UnpatchBreakpoint(Breakpoint bp)
    {
        assert(bp !is null);
        assert(bp.IsPatched());

        // already unpatched
        if (!bp.IsPatched())
            return S_OK;

        HRESULT hr = S_OK;
        BOOL bRet = FALSE;
        uint8_t origData = bp.GetOriginalInstructionByte();
        SIZE_T bytesWritten = 0;
        void* address = cast(void*) bp.GetAddress();

        // looks like we don't have to worry about memory protection; VS doesn't
        // As a debugger, the only thing we can't write to is PAGE_NOACCESS.
        bRet = .WriteProcessMemory(mhProcess, address, &origData, 1, &bytesWritten);
        if (!bRet)
        {
            hr = GetLastHr();
            goto Error;
        }

        .FlushInstructionCache(mhProcess, address, 1);
        bp.SetPatched(false);

    Error:
        return hr;
    }

    HRESULT TempPatchBreakpoint(Breakpoint bp)
    {
        assert(bp !is null);
        assert(bp.IsLocked());

        HRESULT hr = S_OK;

        bp.SetLocked(false);

        if (bp.IsActive())
        {
            hr = PatchBreakpoint(bp);
            if (FAILED(hr))
                return hr;
        }
        else
        {
            mAddrTable.erase(bp.GetAddress());
        }

        return S_OK;
    }

    HRESULT TempUnpatchBreakpoint(Breakpoint bp)
    {
        assert(bp !is null);
        assert(!bp.IsLocked());

        HRESULT hr = S_OK;

        hr = UnpatchBreakpoint(bp);
        if (FAILED(hr))
            return hr;

        bp.SetLocked(true);
        return S_OK;
    }

    HRESULT ReadInstruction(Address address, ref InstructionType type, ref int size)
    {
        HRESULT hr = S_OK;
        BYTE mem[MAX_INSTRUCTION_SIZE] = [0];
        uint32_t lenRead = 0;
        uint32_t lenUnreadable = 0;
        int instLen = 0;
        InstructionType instType = Inst_None;
        CpuSizeMode cpu = Is64Bit() ? Cpu_64 : Cpu_32;

        // this unpatches all BPs in the buffer
        hr = ReadCleanMemory(curAddress, MAX_INSTRUCTION_SIZE, lenRead, lenUnreadable, mem);
        if (FAILED(hr))
            return hr;

        instType = GetInstructionTypeAndSize(mem, cast(int) lenRead, cpu, instLen);
        if (instType == Inst_None)
            return E_UNEXPECTED;

        size = instLen;
        type = instType;
        return S_OK;
    }

    HRESULT PassBP(Address pc, InstructionType instType, int instLen, int notifier,
            Motion motion, ref RangeStepPtr rangeStep)
    {
        assert(instType != Inst_Breakpoint);
        HRESULT hr = S_OK;

        switch (instType)
        {
        case Inst_Call:
            hr = PassBPCall(pc, instLen, notifier, motion, rangeStep);
            break;

        case Inst_Syscall:
            hr = PassBPSyscall(pc, instLen, notifier, motion, rangeStep);
            break;

        case Inst_RepString:
            hr = PassBPRepString(pc, instLen, notifier, motion, rangeStep);
            break;

        default:
            hr = PassBPSimple(pc, instLen, notifier, motion, rangeStep);
            break;
        }

        return hr;
    }

    HRESULT PassBPSimple(Address pc, int instLen, int notifier, Motion motion,
            ref RangeStepPtr rangeStep)
    {
        return SetupInstructionStep(pc, instLen, notifier, Expect_SS, true,
                true, false, motion, rangeStep);
    }

    HRESULT PassBPCall(Address pc, int instLen, int notifier, Motion motion,
            ref RangeStepPtr rangeStep)
    {
        if (motion == Motion_RangeStepIn)
        {
            _ASSERT(notifier == NotifyCheckRange);
            notifier = NotifyCheckCall;
        }
        else if (motion == Motion_StepOver || motion == Motion_RangeStepOver)
        {
            _ASSERT(notifier == NotifyStepComplete || notifier == NotifyCheckRange);
            notifier = NotifyStepOut;
        }

        return SetupInstructionStep(pc, instLen, notifier, Expect_SS, true,
                true, false, motion, rangeStep);
    }

    HRESULT PassBPSyscall(Address pc, int instLen, int notifier, Motion motion,
            ref RangeStepPtr rangeStep)
    {
        return SetupInstructionStep(pc, instLen, notifier, Expect_SS, true,
                false, true, motion, rangeStep);
    }

    HRESULT PassBPRepString(Address pc, int instLen, int notifier, Motion motion,
            ref RangeStepPtr rangeStep)
    {
        return SetupInstructionStep(pc, instLen, notifier, Expect_BP, true,
                true, false, motion, rangeStep);
    }

    HRESULT SetupInstructionStep(Address pc, int instLen, int notifier, ExpectedCode code,
            bool unpatch, bool resumeThreads, bool clearTF, Motion motion,
            ref RangeStepPtr rangeStep)
    {
        HRESULT hr = S_OK;
        Breakpoint* bp = null;
        Address nextAddr = pc + instLen;
        bool suspended = false;
        bool unpatched = false;
        bool setBP = false;
        bool setSS = false;

        if (resumeThreads)
        {
            hr = SuspendOtherThreads(mStoppedThreadId);
            if (FAILED(hr))
                goto Error;
            suspended = true;
        }

        if (unpatch)
        {
            bp = FindBP(pc);

            hr = TempUnpatchBreakpoint(bp);
            if (FAILED(hr))
                goto Error;
            unpatched = true;
        }

        if (code == Expect_SS)
        {
            hr = SetSingleStep(true);
            if (FAILED(hr))
                goto Error;
            setSS = true;
        }
        else
        {
            hr = SetBreakpointInternal(nextAddr, false);
            if (FAILED(hr))
                goto Error;
            setBP = true;
        }

        ExpectedEvent* event = mCurThread.PushExpected(code, notifier);
        if (event is null)
        {
            hr = E_FAIL;
            goto Error;
        }

        if (unpatch)
        {
            event.UnpatchedAddress = pc;
            event.PatchBP = true;
        }
        if (code == Expect_BP)
        {
            event.BPAddress = nextAddr;
            event.RemoveBP = true;
        }
        event.ResumeThreads = resumeThreads;
        event.ClearTF = clearTF;
        event.Motion = motion;
        event.Range = rangeStep.Detach();

    Error:
        if (FAILED(hr))
        {
            if (setSS)
                SetSingleStep(false);
            if (setBP)
                RemoveBreakpointInternal(nextAddr, false);
            if (unpatched)
                TempPatchBreakpoint(bp);
            if (suspended)
                ResumeOtherThreads(mStoppedThreadId);
        }
        return hr;
    }

    HRESULT DontPassBP(Motion motion, Address pc, InstructionType instType,
            int instLen, int notifier, ref RangeStepPtr rangeStep)
    {
        assert(instType != Inst_Breakpoint);
        HRESULT hr = S_OK;

        switch (instType)
        {
        case Inst_Call:
            hr = DontPassBPCall(motion, pc, instLen, notifier, rangeStep);
            break;

        case Inst_Syscall:
            hr = DontPassBPSyscall(motion, pc, instLen, notifier, rangeStep);
            break;

        case Inst_RepString:
            hr = DontPassBPRepString(motion, pc, instLen, notifier, rangeStep);
            break;

        default:
            hr = DontPassBPSimple(motion, pc, instLen, notifier, rangeStep);
            break;
        }

        return hr;
    }

    HRESULT DontPassBPSimple(Motion motion, Address pc, int instLen, int notifier,
            ref RangeStepPtr rangeStep)
    {
        return SetupInstructionStep(pc, instLen, notifier, Expect_SS, false,
                false, false, motion, rangeStep);
    }

    HRESULT DontPassBPCall(Motion motion, Address pc, int instLen, int notifier,
            ref RangeStepPtr rangeStep)
    {
        if (motion == Motion_RangeStepIn)
        {
            assert(notifier == NotifyCheckRange);
            notifier = NotifyCheckCall;
        }

        if (motion == Motion_StepIn || motion == Motion_RangeStepIn)
            return SetupInstructionStep(pc, instLen, notifier, Expect_SS,
                    false, false, false, motion, rangeStep);
        else if (motion == Motion_StepOver || motion == Motion_RangeStepOver)
            return SetupInstructionStep(pc, instLen, notifier, Expect_BP,
                    false, false, false, motion, rangeStep);

        return E_UNEXPECTED;
    }

    HRESULT DontPassBPSyscall(Motion motion, Address pc, int instLen, int notifier,
            ref RangeStepPtr rangeStep)
    {
        return SetupInstructionStep(pc, instLen, notifier, Expect_SS, false,
                false, true, motion, rangeStep);
    }

    HRESULT DontPassBPRepString(Motion motion, Address pc, int instLen,
            int notifier, ref RangeStepPtr rangeStep)
    {
        if (motion == Motion_StepIn)
            return SetupInstructionStep(pc, instLen, notifier, Expect_SS,
                    false, false, false, motion, rangeStep);
        else if (motion == Motion_StepOver || motion == Motion_RangeStepIn
                || motion == Motion_RangeStepOver)
            return SetupInstructionStep(pc, instLen, notifier, Expect_BP,
                    false, false, false, motion, rangeStep);

        return E_UNEXPECTED;
    }

    HRESULT SetStepInstructionCore(Motion motion, ref RangeStepPtr rangeStep, int notifier)
    {
        assert(mhProcess !is null);
        if (mhProcess is null)
            return E_UNEXPECTED;
        assert(mStoppedThreadId != 0);
        assert(mCurThread !is null);
        if (mStoppedThreadId == 0)
            return E_WRONG_STATE;

        HRESULT hr = S_OK;
        Address pc = 0;
        Breakpoint bp = null;
        InstructionType instType = Inst_None;
        int instLen = 0;

        if (!mStoppedOnException)
            return S_OK;

        hr = CancelStep();
        if (FAILED(hr))
            goto Error;

        hr = GetCurrentPC(pc);
        if (FAILED(hr))
            goto Error;

        bp = FindBP(pc);

        hr = ReadInstruction(pc, instType, instLen);
        if (FAILED(hr))
            goto Error;

        if (instType == Inst_Breakpoint)
        {
            ExpectedEvent event = mCurThread.PushExpected(Expect_BP, notifier);
            if (event is null)
            {
                hr = E_FAIL;
                goto Error;
            }

            event.BPAddress = pc;
            // don't try to remove a BP
            event.ClearTF = true;
            event.Motion = motion;
            event.Range = rangeStep.Detach();
        }
        else
        {
            if (bp !is null && bp.IsPatched())
            {
                hr = PassBP(pc, instType, instLen, notifier, motion, rangeStep);
                if (FAILED(hr))
                    goto Error;
            }
            else
            {
                hr = DontPassBP(motion, pc, instType, instLen, notifier, rangeStep);
                if (FAILED(hr))
                    goto Error;
            }
        }

    Error:
        return hr;
    }

    HRESULT SuspendOtherThreads(uint threadId)
    {
        assert(!mIsolatedThread);

        HRESULT hr = S_OK;

        hr = .SuspendOtherThreads(mProcess, threadId, GetWinSuspendThreadProc());
        if (FAILED(hr))
            return hr;

        mIsolatedThread = true;
        mIsolatedThreadId = threadId;
        return S_OK;
    }

    HRESULT ResumeOtherThreads(uint threadId)
    {
        assert(mIsolatedThread);

        HRESULT hr = S_OK;

        hr = .ResumeOtherThreads(mProcess, threadId, GetWinSuspendThreadProc());
        if (FAILED(hr))
            return hr;

        mIsolatedThread = false;
        mIsolatedThreadId = 0;
        return S_OK;
    }

    HRESULT DispatchSingleStep(const EXCEPTION_DEBUG_INFO* exceptRec, ref MachineResult result)
    {
        //as(exceptRec);

        HRESULT hr = S_OK;

        result = MacRes_NotHandled;

        ExpectedEvent event = mCurThread.GetTopExpected();

        if (event is null)
        {
            // always treat the SS exception as a step complete, instead of an exception
            // even if the user wasn't stepping
            result = MacRes_PendingCallbackEmbeddedStep;
            return S_OK;
        }

        if (event.Code == Expect_SS)
        {
            return RunAllActions(false, result);
        }

        if (event.Code == Expect_BP)
        {
            hr = CancelStep();
            if (FAILED(hr))
                return hr;

            result = MacRes_PendingCallbackEmbeddedStep;
            return S_OK;
        }

        return E_UNEXPECTED;
    }

    HRESULT DispatchBreakpoint(const EXCEPTION_DEBUG_INFO* exceptRec, ref MachineResult result)
    {
        HRESULT hr = S_OK;
        Address exceptAddr = cast(Address) exceptRec.ExceptionRecord.ExceptionAddress;
        Breakpoint* bp = null;
        bool embeddedBP = false;

        result = MacRes_NotHandled;

        bp = FindBP(exceptAddr);
        embeddedBP = AtEmbeddedBP(exceptAddr, bp);

        ExpectedEvent* event = mCurThread.GetTopExpected();

        if (event !is null && event.Code == Expect_BP && event.BPAddress == exceptAddr)
        {
            if (!embeddedBP)
            {
                hr = Rewind();
                if (FAILED(hr))
                    return hr;
            }

            return RunAllActions(false, result);
        }

        if (embeddedBP)
        {
            hr = CancelStep();
            if (FAILED(hr))
                return hr;

            Rewind();
            result = MacRes_PendingCallbackEmbeddedBP;
            mPendCBAddr = exceptAddr;
            return S_OK;
        }

        if (bp.IsUser())
        {
            Rewind();
            result = MacRes_PendingCallbackBP;
            mPendCBAddr = exceptAddr;
            return S_OK;
        }

        Rewind();
        result = MacRes_HandledContinue;
        return S_OK;
    }

    HRESULT RunAllActions(bool cancel, ref MachineResult result)
    {
        HRESULT hr = S_OK;
        ExpectedEvent event = mCurThread.GetTopExpected();
        _ASSERT(event !is null);
        RangeStepPtr rangeStep;

        if (event.ClearTF && !cancel)
        {
            hr = ClearSingleStep();
            if (FAILED(hr))
                goto Error;
        }

        if (event.PatchBP)
        {
            Breakpoint bp = FindBP(event.UnpatchedAddress);

            hr = TempPatchBreakpoint(bp);
            if (FAILED(hr))
                goto Error;
        }

        if (event.RemoveBP)
        {
            hr = RemoveBreakpointInternal(event.BPAddress, false);
            if (FAILED(hr))
                goto Error;
        }

        if (event.ResumeThreads)
        {
            hr = ResumeOtherThreads(mStoppedThreadId);
            if (FAILED(hr))
                goto Error;
        }

        int notifier = event.NotifyAction;
        Motion motion = event.Motion;

        // Take over the range step and clear it, so that popping the event won't delete it again.
        rangeStep.Attach(event.Range);
        event.Range = null;

        mCurThread.PopExpected();

        if (!cancel)
        {
            hr = RunNotifierAction(notifier, motion, rangeStep, result);
        }

    Error:
        return hr;
    }

    HRESULT RunNotifierAction(int notifier, Motion motion,
            ref RangeStepPtr rangeStep, ref MachineResult result)
    {
        HRESULT hr = S_OK;

        switch (notifier)
        {
        case NotifyRun:
            result = MacRes_HandledContinue;
            break;

        case NotifyStepComplete:
            result = MacRes_PendingCallbackStep;
            break;

        case NotifyTrigger:
            // This will run the next set of actions, 
            // because we already popped the one we were working on.
            hr = RunAllActions(false, result);
            break;

        case NotifyCheckRange:
            hr = RunNotifyCheckRange(motion, rangeStep, result);
            break;

        case NotifyCheckCall:
            hr = RunNotifyCheckCall(motion, rangeStep, result);
            break;

        case NotifyStepOut:
            hr = RunNotifyStepOut(motion, rangeStep, result);
            break;

        default:
            assert(false, "The notifier action is wrong."w);
            result = MacRes_HandledContinue;
            break;
        }

        return hr;
    }

    HRESULT RunNotifyCheckCall(Motion motion, ref RangeStepPtr rangeStep, ref MachineResult result)
    {
        if (rangeStep.Get() is null)
            return E_FAIL;

        HRESULT hr = S_OK;
        Address pc = 0;
        Address retAddr = 0;
        ExpectedEvent event = null;
        bool setBP = false;
        ProbeRunMode mode = ProbeRunMode_Run;
        AddressRange thunkRange = {0};

        hr = GetCurrentPC(pc);
        if (FAILED(hr))
            goto Error;

        if (pc >= rangeStep.Range.Begin && pc <= rangeStep.Range.End)
        {
            // if you call a procedure in the same range, then there's no need to probe
            mode = ProbeRunMode_Run;
        }
        else
        {
            assert(mCallback !is null);
            mode = mCallback.OnCallProbe(mProcess, mStoppedThreadId, pc, thunkRange);
        }

        if (mode == RunMode_Break)
        {
            hr = CancelStep();
            if (FAILED(hr))
                goto Error;

            result = MacRes_PendingCallbackStep;
        }
        else if (mode == RunMode_Run)
        {
            hr = GetReturnAddress(retAddr);
            if (FAILED(hr))
                goto Error;

            event = mCurThread.PushExpected(Expect_BP, NotifyCheckRange);
            if (event is null)
            {
                hr = E_FAIL;
                goto Error;
            }

            rangeStep.InThunk = false;

            event.BPAddress = retAddr;
            event.RemoveBP = true;
            event.Motion = motion;
            event.Range = rangeStep.Detach();

            hr = SetBreakpointInternal(retAddr, false);
            if (FAILED(hr))
                goto Error;
            setBP = true;

            hr = SetContinue();
            if (FAILED(hr))
                goto Error;

            result = MacRes_HandledContinue;
        }
        else if (mode == ProbeRunMode_WalkThunk)
        {
            rangeStep.InThunk = true;
            rangeStep.ThunkRange = thunkRange;

            hr = SetStepRange(true, rangeStep);
            if (FAILED(hr))
                goto Error;

            result = MacRes_HandledContinue;
        }
        else // RunMode_Wait
        {
            // leave the step active
            result = MacRes_HandledStopped;
        }

    Error:
        if (FAILED(hr))
        {
            if (setBP)
                RemoveBreakpointInternal(retAddr, false);
            if (event !is null)
                mCurThread.PopExpected();
        }
        return hr;
    }

    HRESULT RunNotifyCheckRange(Motion motion, ref RangeStepPtr rangeStep, ref MachineResult result)
    {
        if (rangeStep.Get() is null)
            return E_FAIL;

        HRESULT hr = S_OK;
        Address pc = 0;

        hr = GetCurrentPC(pc);
        if (FAILED(hr))
            goto Error;

        if ((rangeStep.InThunk && pc >= rangeStep.ThunkRange.Begin
                && pc <= rangeStep.ThunkRange.End) || (!rangeStep.InThunk
                && pc >= rangeStep.Range.Begin && pc <= rangeStep.Range.End))
        {
            bool stepIn = (motion == Motion_RangeStepIn) ? true : false;

            hr = SetStepRange(stepIn, rangeStep);
            if (FAILED(hr))
                goto Error;

            result = MacRes_HandledContinue;
        }
        else if (rangeStep.InThunk)
        {
            rangeStep.InThunk = false;

            hr = RunNotifyCheckCall(motion, rangeStep, result);
            if (FAILED(hr))
                goto Error;
        }
        else
        {
            result = MacRes_PendingCallbackStep;
        }

    Error:
        return hr;
    }

    HRESULT RunNotifyStepOut(Motion motion, ref RangeStepPtr rangeStep, ref MachineResult result)
    {
        HRESULT hr = S_OK;
        Address pc = 0;
        Address retAddr = 0;
        ExpectedEvent event = null;
        bool setBP = false;
        int notifier = NotifyNone;

        if (motion == Motion_StepOver)
            notifier = NotifyStepComplete;
        else if (motion == Motion_RangeStepOver)
            notifier = NotifyCheckRange;

        hr = GetCurrentPC(pc);
        if (FAILED(hr))
            goto Error;

        hr = GetReturnAddress(retAddr);
        if (FAILED(hr))
            goto Error;

        event = mCurThread.PushExpected(Expect_BP, notifier);
        if (event is null)
        {
            hr = E_FAIL;
            goto Error;
        }

        event.BPAddress = retAddr;
        event.RemoveBP = true;
        event.Motion = motion;
        event.Range = rangeStep.Detach();

        hr = SetBreakpointInternal(retAddr, false);
        if (FAILED(hr))
            goto Error;
        setBP = true;

        hr = SetContinue();
        if (FAILED(hr))
            goto Error;

        result = MacRes_HandledContinue;

    Error:
        if (FAILED(hr))
        {
            if (setBP)
                RemoveBreakpointInternal(retAddr, false);
            if (event !is null)
                mCurThread.PopExpected();
        }
        return hr;
    }

    HRESULT Rewind()
    {
        return ChangeCurrentPC(-1);
    }

    Breakpoint FindBP(Address address)
    {
        BPIterator bpIt = mAddrTable.find(address);
        Breakpoint bp = null;

        if (bpIt != mAddrTable.end())
            bp = bpIt.second;

        return bp;
    }

    ThreadX86Base FindThread(uint32_t threadId)
    {
        ThreadMap.iterator it = mThreads.find(threadId);

        if (it == mThreads.end())
            return null;

        return it.second;
    }

    bool AtEmbeddedBP(Address address, Breakpoint* bp)
    {
        HRESULT hr = S_OK;
        BOOL bRet = FALSE;
        uint8_t origData = 0;
        void* ptr = cast(void*) address;

        if (bp !is null)
        {
            return bp.GetOriginalInstructionByte() == BreakpointInstruction;
        }

        bRet = .ReadProcessMemory(mhProcess, ptr, &origData, 1, null);
        if (!bRet)
        {
            hr = GetLastHr();
            goto Error;
        }

        if (origData == BreakpointInstruction)
        {
            return true;
        }

    Error:
        return false;
    }

    // like the public SetStepRange, but uses the range info we already have
    HRESULT SetStepRange(bool stepIn, ref RangeStepPtr rangeStep)
    {
        Motion motion = stepIn ? Motion_RangeStepIn : Motion_RangeStepOver;

        return SetStepInstructionCore(motion, rangeStep, NotifyCheckRange);
    }
}
