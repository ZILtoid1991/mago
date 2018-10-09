module ArchData_cpp;

/*
   Copyright (c) 2013 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import ArchData;
import ArchDataX86;
import ArchDataX64;


namespace  Mago
{
    this.ArchData()
    {   mRefCount = ( 0 );
    }

    void  ArchData.AddRef()
    {
        InterlockedIncrement( &mRefCount );
    }

    void  ArchData.Release()
    {
        int  newRefCount = InterlockedDecrement( &mRefCount );
        if ( newRefCount == 0 )
            delete  this;
    }

    HRESULT  ArchData.MakeArchData( uint  procType, UINT64  procFeatures, ref ArchData*  archData )
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
}
