module RpcUtil_cpp;

/*
   Copyright (c) 2013 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import RpcUtil;


// Procedures that the RPC runtime calls when a remote call needs dynamic memory

void  /* SYNTAX ERROR: (14): expected ; instead of midl_user_allocate */ 

     
     /* SYNTAX ERROR: (17): expected <identifier> instead of return */ 
 /* SYNTAX ERROR: unexpected trailing } */ }

void  /* SYNTAX ERROR: (20): expected ; instead of midl_user_free */ 

    
 /* SYNTAX ERROR: unexpected trailing } */ }

// The documentation for RpcExceptionFilter says that it handles STATUS_POSSIBLE_DEADLOCK,
// STATUS_INSTRUCTION_MISALIGNMENT, and STATUS_HANDLE_NOT_CLOSABLE. But, these three macros 
// are defined in ntstatus.h instead of WinNT.h, which is the usual header file. Use their 
// values here.

static if(!defined( STATUS_POSSIBLE_DEADLOCK )) {
enum  STATUS_POSSIBLE_DEADLOCK =            0xC0000194;
}

static if(!defined( STATUS_INSTRUCTION_MISALIGNMENT )) {
enum  STATUS_INSTRUCTION_MISALIGNMENT =     0xC00000AA;
}

static if(!defined( STATUS_HANDLE_NOT_CLOSABLE )) {
enum  STATUS_HANDLE_NOT_CLOSABLE =          0xC0000235;
}

static if(!defined( STATUS_STACK_BUFFER_OVERRUN )) {
enum  STATUS_STACK_BUFFER_OVERRUN =         0xC0000409;
}

static if(!defined( STATUS_ASSERTION_FAILURE )) {
enum  STATUS_ASSERTION_FAILURE =            0xC0000420;
}

// This function is modeled after RpcExceptionFilter declared in rpcdce.h, which is only available 
// in Windows Vista and later.

uint  /* SYNTAX ERROR: (53): expected ; instead of CommonRpcExceptionFilter */ 

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
        

     /* SYNTAX ERROR: (73): expected <identifier> instead of default */ 
        
     /* SYNTAX ERROR: unexpected trailing } */ }
 /* SYNTAX ERROR: unexpected trailing } */ }
