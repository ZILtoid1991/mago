module exec.process;

import exec.common;
import exec.iprocess;
import exec.machine;
import exec.thread;
import exec.iter;
import exec.module ;

class Process : IProcess
{
public : alias ThreadList = Thread[];

    //typedef std::list< RefPtr<Thread> > ThreadList;
    alias ThreadIterator = Thread*;
    //typedef ThreadList::const_iterator ThreadIterator;

private:
    LONG mRefCount;

    CreateMethod mCreateWay;
    HANDLE mhProcess;
    HANDLE mhSuspendedThread;
    uint32_t mId;
    wstring mExePath;
    Address mEntryPoint;
    IMachine mMachine;
    uint16_t mMachineType;
    Address mImageBase;
    uint32_t mSize;

    bool mReachedLoaderBp;
    bool mTerminating;
    bool mDeleted;
    bool mStopped;
    bool mStarted;
    int32_t mSuspendCount;
    ShortDebugEvent mLastEvent;
    Module mOSMod;

    ThreadList mThreads;

    CRITICAL_SECTION mLock;
public:
    this(CreateMethod way, HANDLE hProcess, uint32_t id, const(wchar_t)* exePath)
    {
        mRefCount = (0);
        mCreateWay = (way);
        mhProcess = (hProcess);
        mhSuspendedThread = (null);
        mId = (id);
        mExePath = (exePath);
        mEntryPoint = (0);
        mMachineType = (0);
        mImageBase = (0);
        mSize = (0);
        mMachine = (null);
        mReachedLoaderBp = (false);
        mTerminating = (false);
        mDeleted = (false);
        mStopped = (false);
        mStarted = (false);
        mSuspendCount = (0);
        mOSMod = (null);
        assert(hProcess !is null);
        assert(id != 0);
        assert((way == Create_Attach) || (way == Create_Launch));
        InitializeCriticalSection(&mLock);
        memset(&mLastEvent, 0, mLastEvent.sizeof);
    }

    ~this()
    {
        DeleteCriticalSection(&mLock);

        if (mMachine !is null)
        {
            mMachine.OnDestroyProcess();
            mMachine.Release();
        }

        if (mhProcess !is null)
        {
            CloseHandle(mhProcess);
        }

        if (mhSuspendedThread !is null)
        {
            CloseHandle(mhSuspendedThread);
        }

        if (mOSMod !is null)
        {
            mOSMod.Release();
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

    CreateMethod GetCreateMethod()
    {
        return mCreateWay;
    }

    HANDLE GetHandle()
    {
        return mhProcess;
    }

    uint32_t GetId()
    {
        return mId;
    }

    const(wchar_t)* GetExePath()
    {
        return mExePath.c_str();
    }

    Address GetEntryPoint()
    {
        return mEntryPoint;
    }

    void SetEntryPoint(Address entryPoint)
    {
        mEntryPoint = entryPoint;
    }

    uint16_t GetMachineType()
    {
        return mMachineType;
    }

    void SetMachineType(uint16_t machineType)
    {
        mMachineType = machineType;
    }

    Address GetImageBase()
    {
        return mImageBase;
    }

    void SetImageBase(Address address)
    {
        mImageBase = address;
    }

    uint32_t GetImageSize()
    {
        return mSize;
    }

    void SetImageSize(uint32_t size)
    {
        mSize = size;
    }

    HANDLE GetLaunchedSuspendedThread()
    {
        return mhSuspendedThread;
    }

    void SetLaunchedSuspendedThread(HANDLE hThread)
    {
        if (mhSuspendedThread !is null)
            CloseHandle(mhSuspendedThread);

        mhSuspendedThread = hThread;
    }

    IMachine GetMachine()
    {
        return mMachine;
    }

    void SetMachine(IMachine machine)
    {
        if (mMachine !is null)
        {
            mMachine.OnDestroyProcess();
            mMachine.Release();
        }

        mMachine = machine;

        if (machine !is null)
        {
            machine.AddRef();
        }
    }

    bool IsStopped()
    {
        return mStopped;
    }

    void SetStopped(bool value)
    {
        mStopped = value;
    }

    bool IsDeleted()
    {
        return mDeleted;
    }

    void SetDeleted()
    {
        mDeleted = true;
    }

    bool IsTerminating()
    {
        return mTerminating;
    }

    void SetTerminating()
    {
        mTerminating = true;
    }

    bool ReachedLoaderBp()
    {
        return mReachedLoaderBp;
    }

    void SetReachedLoaderBp()
    {
        mReachedLoaderBp = true;
    }

    bool IsStarted()
    {
        return mStarted;
    }

    void SetStarted()
    {
        mStarted = true;
    }

    size_t GetThreadCount()
    {
        return mThreads.size();
    }

    HRESULT EnumThreads(ref Enumerator!(Thread*)* enumerator)
    {
        ProcessGuard guard = ProcessGuard(this);

        _RefReleasePtr < ArrayRefEnum < Thread * /* SYNTAX ERROR: (242): expression expected, not > */  >  > .type en(
                    new ArrayRefEnum < Thread *  > ());

        if (en.Get() is null)
            return E_OUTOFMEMORY;

        if (!en.Init(mThreads.begin(), mThreads.end(), cast(int) mThreads.size()))
            return E_OUTOFMEMORY;

        enumerator = en.Detach();

        return S_OK;
    }

    void AddThread(Thread* thread)
    {
        assert(FindThread(thread.GetId()) is null);

        mThreads.push_back(thread);
    }

    void DeleteThread(uint32_t threadId)
    {
        for (std.list < RefPtr < Thread > /* SYNTAX ERROR: (264): expression expected, not > */  > .iterator it
                = mThreads.begin(); it != mThreads.end(); it++)
        {
            if (threadId == (*it).GetId())
            {
                mThreads.erase(it);
                break;
            }
        }
    }

    Thread FindThread(uint32_t id)
    {
        for (std.list < RefPtr < Thread > /* SYNTAX ERROR: (278): expression expected, not > */  > .iterator it
                = mThreads.begin(); it != mThreads.end(); it++)
        {
            if (id == (*it).GetId())
                return it.Get();
        }

        return null;
    }

    bool FindThread(uint32_t id, ref Thread* thread)
    {
        ProcessGuard guard = ProcessGuard(this);

        Thread* t = FindThread(id);

        if (t is null)
            return false;

        thread = t;
        thread.AddRef();

        return true;
    }

    Process.ThreadIterator ThreadsBegin()
    {
        return mThreads.begin();
    }

    Process.ThreadIterator ThreadsEnd()
    {
        return mThreads.end();
    }

    int32_t GetSuspendCount()
    {
        return mSuspendCount;
    }

    void SetSuspendCount(int32_t count)
    {
        mSuspendCount = count;
    }

    ShortDebugEvent GetLastEvent()
    {
        ShortDebugEvent event;

        event.EventCode = mLastEvent.EventCode;
        event.ThreadId = mLastEvent.ThreadId;
        event.ExceptionCode = mLastEvent.ExceptionCode;

        return event;
    }

    void SetLastEvent(ref const DEBUG_EVENT debugEvent)
    {
        mLastEvent.EventCode = debugEvent.dwDebugEventCode;
        mLastEvent.ThreadId = debugEvent.dwThreadId;
        mLastEvent.ExceptionCode = debugEvent.u.Exception.ExceptionRecord.ExceptionCode;
    }

    void ClearLastEvent()
    {
        memset(&mLastEvent, 0, mLastEvent.sizeof);
    }

    Module GetOSModule()
    {
        return mOSMod;
    }

    void SetOSModule(Module osModule)
    {
        if (mOSMod !is null)
        {
            mOSMod.Release();
        }

        mOSMod = osModule;

        if (mOSMod !is null)
        {
            mOSMod.AddRef();
        }
    }

    void Lock()
    {
        EnterCriticalSection(&mLock);
    }

    void Unlock()
    {
        LeaveCriticalSection(&mLock);
    }

}

class ProcessGuard
{
    Process    mProcess;

public:
    this( Process process )
        
    {
		this.mProcess = process;
        assert( process != NULL );
        mProcess.Lock();
    }

    ~ProcessGuard()
    {
        mProcess.Unlock();
    }

private:
    this( const ref ProcessGuard ){

	}
    //ref ProcessGuard opAssign()( const ref ProcessGuard );
}