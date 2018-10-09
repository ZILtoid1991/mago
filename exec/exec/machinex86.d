module exec.machinex86;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

// #pragma once

import exec.machinex86base;
import exec.common;
import exec.decodex86;
import exec.eventcallback;
import exec.iprocess;
import exec.process;
import exec.thread;
import exec.threadX86;

static if (defined(_WIN64))
{
    enum
    {
        MIN_CONTEXT_FLAGS = WOW64_CONTEXT_FULL | WOW64_CONTEXT_FLOATING_POINT
            | WOW64_CONTEXT_EXTENDED_REGISTERS
    };
    alias WOW64_CONTEXT CONTEXT_X86;
    alias WOW64_CONTEXT_i386 CONTEXT_X86_i386;
    alias WOW64_CONTEXT_CONTROL CONTEXT_X86_CONTROL;
    alias WOW64_CONTEXT_INTEGER CONTEXT_X86_INTEGER;
    alias WOW64_CONTEXT_SEGMENTS CONTEXT_X86_SEGMENTS;
    alias WOW64_CONTEXT_FLOATING_POINT CONTEXT_X86_FLOATING_POINT;
    alias WOW64_CONTEXT_DEBUG_REGISTERS CONTEXT_X86_DEBUG_REGISTERS;
    alias WOW64_CONTEXT_EXTENDED_REGISTERS CONTEXT_X86_EXTENDED_REGISTERS;
    // #define GetThreadContextX86             ::Wow64GetThreadContext
    // #define SetThreadContextX86             ::Wow64SetThreadContext
    // #define SuspendThreadX86                ::Wow64SuspendThread
}
else
{
    enum
    {
        MIN_CONTEXT_FLAGS = CONTEXT_FULL | CONTEXT_FLOATING_POINT | CONTEXT_EXTENDED_REGISTERS
    };
    alias CONTEXT CONTEXT_X86;
    alias CONTEXT_i386 CONTEXT_X86_i386;
    alias CONTEXT_CONTROL CONTEXT_X86_CONTROL;
    alias CONTEXT_INTEGER CONTEXT_X86_INTEGER;
    alias CONTEXT_SEGMENTS CONTEXT_X86_SEGMENTS;
    alias CONTEXT_FLOATING_POINT CONTEXT_X86_FLOATING_POINT;
    alias CONTEXT_DEBUG_REGISTERS CONTEXT_X86_DEBUG_REGISTERS;
    alias CONTEXT_EXTENDED_REGISTERS CONTEXT_X86_EXTENDED_REGISTERS;
    // #define GetThreadContextX86             ::GetThreadContext
    // #define SetThreadContextX86             ::SetThreadContext
    // #define SuspendThreadX86                ::SuspendThread
}

immutable DWORD TRACE_FLAG = 0x100;

class MachineX86 : MachineX86Base
{
    // A cached context for the thread that reported an event
    static if (defined(_WIN64))
    {
        WOW64_CONTEXT mContext;
    }
    else
    {
        CONTEXT mContext;
    }
    bool mIsContextCached;
    bool mEnableSS;

public:
    this()
    {
        mIsContextCached = (false);
        mEnableSS = (false);
        memset(&mContext, 0, mContext.sizeof);
    }

protected:
    bool Is64Bit()
    {
        return false;
    }

    HRESULT CacheThreadContext()
    {
        HRESULT hr = S_OK;
        ThreadX86Base threadX86 = GetStoppedThread();
        Thread thread = threadX86.GetExecThread();

        mContext.ContextFlags = MIN_CONTEXT_FLAGS;
        if (!GetThreadContextX86(thread.GetHandle(), &mContext))
        {
            hr = GetLastHr();
            goto Error;
        }

        mIsContextCached = true;

    Error:
        return hr;
    }

    HRESULT FlushThreadContext()
    {
        if (!mIsContextCached)
            return S_OK;

        HRESULT hr = S_OK;
        ThreadX86Base threadX86 = GetStoppedThread();
        Thread thread = threadX86.GetExecThread();

        if (mEnableSS)
        {
            mContext.EFlags |= TRACE_FLAG;
            mEnableSS = false;
        }

        if (!SetThreadContextX86(thread.GetHandle(), &mContext))
        {
            hr = GetLastHr();
            goto Error;
        }

        mIsContextCached = false;

    Error:
        return hr;
    }

    HRESULT ChangeCurrentPC(int32_t byteOffset)
    {
        assert(mIsContextCached);
        if (!mIsContextCached)
            return E_FAIL;

        mContext.Eip += byteOffset;
        return S_OK;
    }

    HRESULT SetSingleStep(bool enable)
    {
        assert(mIsContextCached);
        if (!mIsContextCached)
            return E_FAIL;

        mEnableSS = enable;
        return S_OK;
    }

    HRESULT ClearSingleStep()
    {
        assert(mIsContextCached);
        if (!mIsContextCached)
            return E_FAIL;

        mContext.EFlags &= ~TRACE_FLAG;

        return S_OK;
    }

    HRESULT GetCurrentPC(ref Address address)
    {
        assert(mIsContextCached);
        if (!mIsContextCached)
            return E_FAIL;

        address = mContext.Eip;
        return S_OK;
    }

    HRESULT GetReturnAddress(ref Address address)
    {
        assert(mIsContextCached);
        if (!mIsContextCached)
            return E_FAIL;

        BOOL bRet = ReadProcessMemory(GetProcessHandle(),
                cast(void*) mContext.Esp, &address, address.sizeof, null);
        if (!bRet)
            return GetLastHr();

        return S_OK;
    }

    HRESULT SuspendThread(Thread thread)
    {
        DWORD suspendCount = SuspendThreadX86(thread.GetHandle());

        if (suspendCount == DWORD - 1)
        {
            HRESULT hr = GetLastHr();

            // if the thread can't be accessed, then it's probably on the way out
            // and there's nothing we should do about it
            if (hr == E_ACCESSDENIED)
                return S_OK;

            return hr;
        }

        return S_OK;
    }

    HRESULT ResumeThread(Thread thread)
    {
        // there's no Wow64ResumeThread
        DWORD suspendCount = .ResumeThread(thread.GetHandle());

        if (suspendCount == DWORD - 1)
        {
            HRESULT hr = GetLastHr();

            // if the thread can't be accessed, then it's probably on the way out
            // and there's nothing we should do about it
            if (hr == E_ACCESSDENIED)
                return S_OK;

            return hr;
        }

        return S_OK;
    }

    HRESULT GetThreadContextInternal(uint32_t threadId, uint32_t features,
            uint64_t extFeatures, void* context, uint32_t size)
    {
        UNREFERENCED_PARAMETER(extFeatures);

        if (size < CONTEXT_X86.sizeof)
            return E_INVALIDARG;

        ThreadX86Base* threadX86 = GetStoppedThread();
        Thread* thread = threadX86.GetExecThread();
        CONTEXT_X86* context = cast(CONTEXT_X86*) contextBuf;

        context.ContextFlags = features;

        if (threadId == thread.GetId() && mIsContextCached)
        {
            return GetThreadContextWithCache(thread.GetHandle(), context, size);
        }

        HRESULT hr = S_OK;
        HANDLE hThread = OpenThread(THREAD_ALL_ACCESS, FALSE, threadId);

        if (hThread is null)
        {
            hr = GetLastHr();
            goto Error;
        }

        if (!GetThreadContextX86(hThread, context))
        {
            hr = GetLastHr();
            goto Error;
        }

    Error:
        if (hThread !is null)
            CloseHandle(hThread);

        return hr;
    }

    HRESULT SetThreadContextInternal(uint32_t threadId, const(void)* context, uint32_t size)
    {
        if (size < CONTEXT_X86.sizeof)
            return E_INVALIDARG;

        ThreadX86Base* threadX86 = GetStoppedThread();
        Thread* thread = threadX86.GetExecThread();

        if (threadId == thread.GetId() && mIsContextCached)
        {
            return SetThreadContextWithCache(thread.GetHandle(), context, size);
        }

        HRESULT hr = S_OK;
        HANDLE hThread = OpenThread(THREAD_ALL_ACCESS, FALSE, threadId);

        if (hThread is null)
        {
            hr = GetLastHr();
            goto Error;
        }

        if (!SetThreadContextX86(hThread, cast(const CONTEXT_X86*) context))
        {
            hr = GetLastHr();
            goto Error;
        }

    Error:
        if (hThread !is null)
            CloseHandle(hThread);

        return hr;
    }

    ThreadControlProc GetWinSuspendThreadProc()
    {
        return SuspendThreadX86;
    }

private:
    HRESULT GetThreadContextWithCache(HANDLE hThread, void* context, uint32_t size)
    {
        assert(hThread !is null);
        assert(contextBuf !is null);
        assert(size >= CONTEXT_X86.sizeof);
        assert(mIsContextCached);
        if (size < CONTEXT_X86.sizeof)
            return E_INVALIDARG;

        // ContextFlags = 0 and CONTEXT_i386 are OK

        CONTEXT_X86* context = cast(CONTEXT_X86*) contextBuf;
        DWORD callerFlags = context.ContextFlags & ~CONTEXT_X86_i386;
        DWORD cacheFlags = mContext.ContextFlags & ~CONTEXT_X86_i386;
        DWORD cachedFlags = callerFlags & cacheFlags;
        DWORD notCachedFlags = callerFlags & ~cacheFlags;

        if (notCachedFlags != 0)
        {
            // only get from the target what isn't cached
            context.ContextFlags = notCachedFlags | CONTEXT_X86_i386;
            if (!GetThreadContextX86(hThread, context))
                return GetLastHr();
        }

        if (cachedFlags != 0)
        {
            CopyContext(cachedFlags | CONTEXT_X86_i386, &mContext, context);
            context.ContextFlags |= cachedFlags | CONTEXT_X86_i386;
        }

        return S_OK;
    }

    HRESULT SetThreadContextWithCache(HANDLE hThread, const(void)* context, uint32_t size)
    {
        assert(hThread !is null);
        assert(contextBuf !is null);
        assert(size >= CONTEXT_X86.sizeof);
        assert(mIsContextCached);
        if (size < CONTEXT_X86.sizeof)
            return E_INVALIDARG;

        // ContextFlags = 0 and CONTEXT_i386 are OK

        const CONTEXT_X86* context = cast(const CONTEXT_X86*) contextBuf;
        DWORD callerFlags = context.ContextFlags & ~CONTEXT_X86_i386;
        DWORD cacheFlags = mContext.ContextFlags & ~CONTEXT_X86_i386;
        DWORD cachedFlags = callerFlags & cacheFlags;
        DWORD notCachedFlags = callerFlags & ~cacheFlags;

        if (notCachedFlags != 0)
        {
            // set everything, in order to avoid copying the context 
            // or writing restricted flags to the const context
            if (!SetThreadContextX86(hThread, context))
                return GetLastHr();
        }

        if (cachedFlags != 0)
        {
            CopyContext(cachedFlags | CONTEXT_X86_i386, context, &mContext);
        }

        return S_OK;
    }

}

HRESULT MakeMachineX86(ref IMachine machine)
{
    HRESULT hr = S_OK;
    MachineX86 machX86 = new MachineX86();

    if (machX86.Get() is null)
        return E_OUTOFMEMORY;

    hr = machX86.Init();
    if (FAILED(hr))
        return hr;

    machine = machX86;
    return S_OK;
}

static void CopyContext(DWORD flags, const CONTEXT_X86* srcContext, CONTEXT_X86* dstContext)
{
    assert(srcContext !is null);
    assert(dstContext !is null);
    assert((flags & ~MIN_CONTEXT_FLAGS) == 0);

    if ((flags & CONTEXT_X86_CONTROL) == CONTEXT_X86_CONTROL)
    {
        memcpy(&dstContext.Ebp, &srcContext.Ebp, DWORD.sizeof * 6);
    }

    if ((flags & CONTEXT_X86_INTEGER) == CONTEXT_X86_INTEGER)
    {
        memcpy(&dstContext.Edi, &srcContext.Edi, DWORD.sizeof * 6);
    }

    if ((flags & CONTEXT_X86_SEGMENTS) == CONTEXT_X86_SEGMENTS)
    {
        memcpy(&dstContext.SegGs, &srcContext.SegGs, DWORD.sizeof * 4);
    }

    if ((flags & CONTEXT_X86_FLOATING_POINT) == CONTEXT_X86_FLOATING_POINT)
    {
        dstContext.FloatSave = srcContext.FloatSave;
    }

    if ((flags & CONTEXT_X86_EXTENDED_REGISTERS) == CONTEXT_X86_EXTENDED_REGISTERS)
    {
        memcpy(dstContext.ExtendedRegisters, srcContext.ExtendedRegisters,
                dstContext.ExtendedRegisters.sizeof);
    }
}
