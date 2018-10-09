module exec.thread;

import exec.ithread;
import exec.common;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

class Thread
{
    LONG mRefCount;
    HANDLE mhThread;
    uint32_t mId;
    Address mStartAddr;
    Address mTebBase;
public:
    this(HANDLE hThread, uint32_t id, Address startAddr, Address tebBase)
    {
        mRefCount = 0;
        mhThread = hThread;
        mId = id;
        mStartAddr = startAddr;
        mTebBase = tebBase;
        assert(hThread !is null);
        assert(id != 0);
    }

    ~this()
    {
        if (mhThread !is null)
        {
            CloseHandle(mhThread);
        }
    }

    void AddRef()
    {
        InterlockedIncrement(&mRefCount);
    }

    void Release()
    {
        LONG newRefCount = InterlockedDecrement(&mRefCount);
        assert(newRefCount >= 0);
        if (newRefCount == 0)
        {
            delete this;
        }
    }

    HANDLE GetHandle()
    {
        return mhThread;
    }

    uint32_t GetId()
    {
        return mId;
    }

    Address GetStartAddr()
    {
        return mStartAddr;
    }

    Address GetTebBase()
    {
        return mTebBase;
    }
}
