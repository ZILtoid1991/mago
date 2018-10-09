module LocalProcess_cpp;

/*
   Copyright (c) 2013 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

// #pragma once

import Common;
import LocalProcess;
import ArchData;


namespace  Mago
{
    //------------------------------------------------------------------------
    //  LocalProcess
    //------------------------------------------------------------------------

    this.LocalProcess( ArchData* archData )
    {   mRefCount = ( 0 );
            mArchData = ( archData );
        _ASSERT( archData !is  null );
    }

    void  LocalProcess.AddRef()
    {
        InterlockedIncrement( &mRefCount );
    }

    void  LocalProcess.Release()
    {
        int  ref = InterlockedDecrement( &mRefCount );
        _ASSERT( ref >= 0 );
        if ( ref == 0 )
        {
            delete  this;
        }
    }

    CreateMethod  LocalProcess.GetCreateMethod()
    {
        return  mExecProc.GetCreateMethod();
    }

    uint32_t  LocalProcess.GetPid()
    {
        return  mExecProc.GetId();
    }

    const(wchar_t) * LocalProcess.GetExePath()
    {
        return  mExecProc.GetExePath();
    }

    uint16_t  LocalProcess.GetMachineType()
    {
        return  mExecProc.GetMachineType();
    }

    ArchData* LocalProcess.GetArchData()
    {
        return  mArchData.Get();
    }

    CoreProcessType  LocalProcess.GetProcessType()
    {
        return  CoreProcess_Local;
    }

    void  LocalProcess.Init( IProcess* execProc )
    {
        _ASSERT( execProc !is  null );
        mExecProc = execProc;
    }

    IProcess* LocalProcess.GetExecProcess()
    {
        return  mExecProc;
    }


    //------------------------------------------------------------------------
    //  LocalThread
    //------------------------------------------------------------------------

      /* SYNTAX ERROR: (89): expected <identifier> instead of :: */ 
           
            
    
        
    }

    void  LocalThread.AddRef()
    {
        InterlockedIncrement( &mRefCount );
    }

    void  LocalThread.Release()
    {
        int  ref = InterlockedDecrement( &mRefCount );
        _ASSERT( ref >= 0 );
        if ( ref == 0 )
        {
            delete  this;
        }
    }

    uint32_t  LocalThread.GetTid()
    {
        return  mExecThread.GetId();
    }

    Address64     LocalThread.GetStartAddr()
    {
        return  mExecThread.GetStartAddr();
    }

    Address64     LocalThread.GetTebBase()
    {
        return  mExecThread.GetTebBase();
    }

    CoreProcessType  LocalThread.GetProcessType()
    {
        return  CoreProcess_Local;
    }

     /* SYNTAX ERROR: (131): expected <identifier> instead of :: */ 
    
        
     /* SYNTAX ERROR: unexpected trailing } */ }


    //------------------------------------------------------------------------
    //  LocalModule
    //------------------------------------------------------------------------

    this.LocalModule( IModule* execModule )
    {   mRefCount = ( 0 );
            mExecMod = ( execModule );
        _ASSERT( execModule !is  null );
    }

    void  LocalModule.AddRef()
    {
        InterlockedIncrement( &mRefCount );
    }

    void  LocalModule.Release()
    {
        int  ref = InterlockedDecrement( &mRefCount );
        _ASSERT( ref >= 0 );
        if ( ref == 0 )
        {
            delete  this;
        }
    }

    Address64         LocalModule.GetImageBase()
    {
        return  mExecMod.GetImageBase();
    }

    Address64         LocalModule.GetPreferredImageBase()
    {
        return  mExecMod.GetPreferredImageBase();
    }

    uint32_t  LocalModule.GetSize()
    {
        return  mExecMod.GetSize();
    }

    uint16_t  LocalModule.GetMachine()
    {
        return  mExecMod.GetMachine();
    }

    const(wchar_t) * LocalModule.GetPath()
    {
        return  mExecMod.GetPath();
    }

    const(wchar_t) * LocalModule.GetSymbolSearchPath()
    {
        return  mExecMod.GetSymbolSearchPath();
    }
 /* SYNTAX ERROR: unexpected trailing } */ }
