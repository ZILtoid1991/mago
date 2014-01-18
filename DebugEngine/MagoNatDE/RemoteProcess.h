/*
   Copyright (c) 2013 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

#pragma once

#include "ICoreProcess.h"


namespace Mago
{
    class RemoteProcess : public ICoreProcess
    {
        long                mRefCount;
        RefPtr<ArchData>    mArchData;

        std::wstring        mExePath;
        uint32_t            mPid;
        CreateMethod        mCreateMethod;
        uint16_t            mMachineType;

    public:
        RemoteProcess();

        virtual void            AddRef();
        virtual void            Release();

        virtual CreateMethod    GetCreateMethod();
        virtual uint32_t        GetPid();
        virtual const wchar_t*  GetExePath();
        virtual uint16_t        GetMachineType();

        virtual ArchData*       GetArchData();
        virtual CoreProcessType GetProcessType();

        void                    Init(
            uint32_t pid, 
            const wchar_t* exePath, 
            CreateMethod createMethod, 
            uint16_t machineType,
            ArchData* archData );

    private:
        RemoteProcess( const RemoteProcess& );
        RemoteProcess& operator=( const RemoteProcess& );
    };


    class RemoteThread : public ICoreThread
    {
        long                mRefCount;

        uint32_t            mTid;
        Address             mStartAddr;
        Address             mTebBase;

    public:
        RemoteThread( uint32_t tid, Address startAddr, Address tebBase );

        virtual void            AddRef();
        virtual void            Release();

        virtual uint32_t        GetTid();
        virtual Address         GetStartAddr();
        virtual Address         GetTebBase();
        virtual CoreProcessType GetProcessType();

    private:
        RemoteThread( const RemoteThread& );
        RemoteThread& operator=( const RemoteThread& );
    };


    class RemoteModule : public ICoreModule
    {
        long                mRefCount;

        Address             mImageBase;
        Address             mPrefImageBase;
        uint32_t            mSize;
        uint16_t            mMachineType;
        std::wstring        mPath;

    public:
        RemoteModule( 
            Address imageBase, 
            Address prefImageBase, 
            uint32_t size, 
            uint16_t machineType, 
            const wchar_t* path );

        virtual void            AddRef();
        virtual void            Release();

        virtual Address         GetImageBase();
        virtual Address         GetPreferredImageBase();
        virtual uint32_t        GetSize();
        virtual uint16_t        GetMachine();
        virtual const wchar_t*  GetPath();

    private:
        RemoteModule( const RemoteModule& );
        RemoteModule& operator=( const RemoteModule& );
    };
}
