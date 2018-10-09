module magonatde.archdata;

import magonatde.common;

struct Reg
{
    const wchar_t* Name;
    uint16_t FullReg;
    uint8_t Length;
    uint8_t Shift;
    uint32_t Mask;
}

struct RegGroup
{
    uint32_t StrId;
    const Reg* Regs;
    uint32_t RegCount;
}

struct RegGroupInternal
{
    uint32_t StrId;
    const Reg* Regs;
    uint32_t RegCount;
    uint32_t NeededFeature;
}

struct ArchThreadContextSpec
{
    int Size;
    uint32_t FeatureMask;
    uint64_t ExtFeatureMask;
}

alias ReadProcessMemory64Proc = BOOL delegate(void* processContext,
        DWORD64 baseAddress, void* buffer, DWORD size, DWORD* numberOfBytesRead);

alias FunctionTableAccess64Proc = void* delegate(void* processContext, DWORD64 addrBase);

alias GetModuleBase64Proc = DWORD64 delegate(void* processContext, DWORD64 address);

abstract class ArchData
{
    this(){

    }
    void  AddRef()
    {
        InterlockedIncrement( &mRefCount );
    }

    void  Release()
    {
        int  newRefCount = InterlockedDecrement( &mRefCount );
        if ( newRefCount == 0 )
            delete  this;
    }

    static HRESULT  MakeArchData( uint  procType, UINT64  procFeatures, ref ArchData  archData )
    {
        switch ( procType )
        {
        case  IMAGE_FILE_MACHINE_I386:
            archData = new  ArchDataX86( procFeatures );
            break;

        case  IMAGE_FILE_MACHINE_AMD64:
            archData = new  ArchDataX64( procFeatures );
            break;

        default:
            return  E_UNSUPPORTED_BINARY;
        }

        if ( archData  is  null )
            return  E_OUTOFMEMORY;

        archData.AddRef();

        return  S_OK;
    }
    abstract LONG mRefCount;
    abstract HRESULT BeginWalkStack(IRegisterSet topRegSet, void* processContext, ReadProcessMemory64Proc readMemProc,
            FunctionTableAccess64Proc funcTabProc,
            GetModuleBase64Proc getModBaseProc, ref StackWalker stackWalker);

    abstract HRESULT BuildRegisterSet(const void* threadContext,
            uint32_t threadContextSize, ref IRegisterSet regSet);
    abstract HRESULT BuildTinyRegisterSet(const void* threadContext,
            uint32_t threadContextSize, ref IRegisterSet regSet);

    abstract uint32_t GetRegisterGroupCount();
    abstract bool GetRegisterGroup(uint32_t index, ref RegGroup group);

    // Maps a debug info register ID to an ID specific to this 
    // Returns the mapped register ID, and -1 if no mapping is found.
    abstract int GetArchRegId(int debugRegId);
    abstract int GetPointerSize();
    abstract void GetThreadContextSpec(ref ArchThreadContextSpec spec);
    abstract int GetPDataSize();
    abstract void GetPDataRange(Address64 imageBase, const void* pdata,
            ref Address64 begin, ref Address64 end);
}
