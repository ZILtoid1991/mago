module exec._module;

import MagoCore = exec.debuggerproxy;
import exec.imodule;

class Module : public IModule
{
    LONG mRefCount;
    MagoCore.DebuggerProxy mDebuggerProxy; /// backward reference

    Address mImageBase;
    Address mPrefImageBase;
    uint32_t mDebugInfoFileOffset;
    uint32_t mDebugInfoSize;
    uint32_t mSize;
    uint16_t mMachine;
    wstring mPath;

    bool mDeleted;

    this(MagoCore.DebuggerProxy debuggerProxy, Address imageBase, uint32_t size, uint16_t machine,
            const(wchar_t)* path, uint32_t debugInfoFileOffset, uint32_t debugInfoSize)
    {
        mRefCount = (0);
        mDebuggerProxy = (debuggerProxy);
        mImageBase = (imageBase);
        mPrefImageBase = (0);
        mSize = (size);
        mMachine = (machine);
        mPath = (path);
        mDebugInfoFileOffset = (debugInfoFileOffset);
        mDebugInfoSize = (debugInfoSize);
        mDeleted = (false);
        assert(size > 0);
        assert(path !is null);
    }

     ~ this. ~ Module()
    {
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

    Address GetImageBase()
    {
        return mImageBase;
    }

    uint32_t GetDebugInfoFileOffset()
    {
        return mDebugInfoFileOffset;
    }

    uint32_t GetDebugInfoSize()
    {
        return mDebugInfoSize;
    }

    uint32_t GetSize()
    {
        return mSize;
    }

    uint16_t GetMachine()
    {
        return mMachine;
    }

    const(wchar_t)* GetPath()
    {
        return mPath.c_str();
    }

    const(wchar_t)* GetSymbolSearchPath()
    {
        return mDebuggerProxy.GetSymbolSearchPath().data();
    }

    Address GetPreferredImageBase()
    {
        return mPrefImageBase;
    }

    void SetPreferredImageBase(Address address)
    {
        mPrefImageBase = address;
    }

    bool IsDeleted()
    {
        return mDeleted;
    }

    void SetDeleted()
    {
        mDeleted = true;
    }

    bool Contains(Address addr)
    {
        Address modAddr = GetImageBase();
        return (addr >= modAddr) && ((addr - modAddr) < GetSize());
    }

}
