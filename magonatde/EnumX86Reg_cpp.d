module EnumX86Reg_cpp;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import Common;
import EnumX86Reg;
import RegProperty;
import ArchDataX86;
// #include <MagoDECommon.h>


namespace  Mago
{
    static  const  Reg     gX86CpuRegList[] = 
    [
        { "EAX"w, RegX86_EAX, 32, 0, 0xFFFFFFFF },
        { "EBX"w, RegX86_EBX, 32, 0, 0xFFFFFFFF },
        { "ECX"w, RegX86_ECX, 32, 0, 0xFFFFFFFF },
        { "EDX"w, RegX86_EDX, 32, 0, 0xFFFFFFFF },
        { "ESI"w, RegX86_ESI, 32, 0, 0xFFFFFFFF },
        { "EDI"w, RegX86_EDI, 32, 0, 0xFFFFFFFF },
        { "EBP"w, RegX86_EBP, 32, 0, 0xFFFFFFFF },
        { "ESP"w, RegX86_ESP, 32, 0, 0xFFFFFFFF },
        { "EIP"w, RegX86_EIP, 32, 0, 0xFFFFFFFF },
        { "EFL"w, RegX86_EFLAGS, 32, 0, 0xFFFFFFFF },
    ];

    static  const  Reg     gX86SegmentsRegList[] = 
    [
        { "CS"w, RegX86_CS, 16, 0, 0xFFFF },
        { "DS"w, RegX86_DS, 16, 0, 0xFFFF },
        { "ES"w, RegX86_ES, 16, 0, 0xFFFF },
        { "FS"w, RegX86_FS, 16, 0, 0xFFFF },
        { "GS"w, RegX86_GS, 16, 0, 0xFFFF },
        { "SS"w, RegX86_SS, 16, 0, 0xFFFF },
    ];

    static  const  Reg     gX86FloatingRegList[] = 
    [
        { "ST0"w, RegX86_ST0, 0, 0, 0 },
        { "ST1"w, RegX86_ST1, 0, 0, 0 },
        { "ST2"w, RegX86_ST2, 0, 0, 0 },
        { "ST3"w, RegX86_ST3, 0, 0, 0 },
        { "ST4"w, RegX86_ST4, 0, 0, 0 },
        { "ST5"w, RegX86_ST5, 0, 0, 0 },
        { "ST6"w, RegX86_ST6, 0, 0, 0 },
        { "ST7"w, RegX86_ST7, 0, 0, 0 },
        { "STAT"w, RegX86_STAT, 16, 0, 0xFFFF },
        { "TAG"w, RegX86_TAG, 16, 0, 0xFFFF },
        { "CTRL"w, RegX86_CTRL, 16, 0, 0xFFFF },
        { "FPEDO"w, RegX86_FPEDO, 32, 0, 0xFFFFFFFF },
        { "FPEIP"w, RegX86_FPEIP, 32, 0, 0xFFFFFFFF },
    ];

    static  const  Reg     gX86FlagsRegList[] = 
    [
        { "OF"w, RegX86_EFLAGS, 1, 11, 1 },
        { "DF"w, RegX86_EFLAGS, 1, 10, 1 },
        { "IF"w, RegX86_EFLAGS, 1, 9, 1 },
        { "SF"w, RegX86_EFLAGS, 1, 7, 1 },
        { "ZF"w, RegX86_EFLAGS, 1, 6, 1 },
        { "AF"w, RegX86_EFLAGS, 1, 4, 1 },
        { "PF"w, RegX86_EFLAGS, 1, 2, 1 },
        { "CF"w, RegX86_EFLAGS, 1, 0, 1 },
    ];

    static  const  Reg     gX86MMXRegList[] = 
    [
        { "MM0"w, RegX86_MM0, 0, 0, 0 },
        { "MM1"w, RegX86_MM1, 0, 0, 0 },
        { "MM2"w, RegX86_MM2, 0, 0, 0 },
        { "MM3"w, RegX86_MM3, 0, 0, 0 },
        { "MM4"w, RegX86_MM4, 0, 0, 0 },
        { "MM5"w, RegX86_MM5, 0, 0, 0 },
        { "MM6"w, RegX86_MM6, 0, 0, 0 },
        { "MM7"w, RegX86_MM7, 0, 0, 0 },
    ];

    static  const  Reg     gX86SSERegList[] = 
    [
        { "XMM0"w, RegX86_XMM0, 0, 0, 0 },
        { "XMM1"w, RegX86_XMM1, 0, 0, 0 },
        { "XMM2"w, RegX86_XMM2, 0, 0, 0 },
        { "XMM3"w, RegX86_XMM3, 0, 0, 0 },
        { "XMM4"w, RegX86_XMM4, 0, 0, 0 },
        { "XMM5"w, RegX86_XMM5, 0, 0, 0 },
        { "XMM6"w, RegX86_XMM6, 0, 0, 0 },
        { "XMM7"w, RegX86_XMM7, 0, 0, 0 },

        { "XMM00"w, RegX86_XMM00, 0, 0, 0 },
        { "XMM01"w, RegX86_XMM01, 0, 0, 0 },
        { "XMM02"w, RegX86_XMM02, 0, 0, 0 },
        { "XMM03"w, RegX86_XMM03, 0, 0, 0 },

        { "XMM10"w, RegX86_XMM10, 0, 0, 0 },
        { "XMM11"w, RegX86_XMM11, 0, 0, 0 },
        { "XMM12"w, RegX86_XMM12, 0, 0, 0 },
        { "XMM13"w, RegX86_XMM13, 0, 0, 0 },

        { "XMM20"w, RegX86_XMM20, 0, 0, 0 },
        { "XMM21"w, RegX86_XMM21, 0, 0, 0 },
        { "XMM22"w, RegX86_XMM22, 0, 0, 0 },
        { "XMM23"w, RegX86_XMM23, 0, 0, 0 },

        { "XMM30"w, RegX86_XMM30, 0, 0, 0 },
        { "XMM31"w, RegX86_XMM31, 0, 0, 0 },
        { "XMM32"w, RegX86_XMM32, 0, 0, 0 },
        { "XMM33"w, RegX86_XMM33, 0, 0, 0 },

        { "XMM40"w, RegX86_XMM40, 0, 0, 0 },
        { "XMM41"w, RegX86_XMM41, 0, 0, 0 },
        { "XMM42"w, RegX86_XMM42, 0, 0, 0 },
        { "XMM43"w, RegX86_XMM43, 0, 0, 0 },

        { "XMM50"w, RegX86_XMM50, 0, 0, 0 },
        { "XMM51"w, RegX86_XMM51, 0, 0, 0 },
        { "XMM52"w, RegX86_XMM52, 0, 0, 0 },
        { "XMM53"w, RegX86_XMM53, 0, 0, 0 },

        { "XMM60"w, RegX86_XMM60, 0, 0, 0 },
        { "XMM61"w, RegX86_XMM61, 0, 0, 0 },
        { "XMM62"w, RegX86_XMM62, 0, 0, 0 },
        { "XMM63"w, RegX86_XMM63, 0, 0, 0 },

        { "XMM70"w, RegX86_XMM70, 0, 0, 0 },
        { "XMM71"w, RegX86_XMM71, 0, 0, 0 },
        { "XMM72"w, RegX86_XMM72, 0, 0, 0 },
        { "XMM73"w, RegX86_XMM73, 0, 0, 0 },

        { "MXCSR"w, RegX86_MXCSR, 0, 0, 0 },
    ];

    static  const  Reg     gX86SSE2RegList[] = 
    [
        { "XMM0DL"w, RegX86_XMM0L, 0, 0, 0 },
        { "XMM0DH"w, RegX86_XMM0H, 0, 0, 0 },
        { "XMM1DL"w, RegX86_XMM1L, 0, 0, 0 },
        { "XMM1DH"w, RegX86_XMM1H, 0, 0, 0 },
        { "XMM2DL"w, RegX86_XMM2L, 0, 0, 0 },
        { "XMM2DH"w, RegX86_XMM2H, 0, 0, 0 },
        { "XMM3DL"w, RegX86_XMM3L, 0, 0, 0 },
        { "XMM3DH"w, RegX86_XMM3H, 0, 0, 0 },
        { "XMM4DL"w, RegX86_XMM4L, 0, 0, 0 },
        { "XMM4DH"w, RegX86_XMM4H, 0, 0, 0 },
        { "XMM5DL"w, RegX86_XMM5L, 0, 0, 0 },
        { "XMM5DH"w, RegX86_XMM5H, 0, 0, 0 },
        { "XMM6DL"w, RegX86_XMM6L, 0, 0, 0 },
        { "XMM6DH"w, RegX86_XMM6H, 0, 0, 0 },
        { "XMM7DL"w, RegX86_XMM7L, 0, 0, 0 },
        { "XMM7DH"w, RegX86_XMM7H, 0, 0, 0 },
    ];

    static  const  RegGroupInternal   gX86RegGroups[] = 
    [
        { IDS_REGGROUP_CPU, gX86CpuRegList, _countof( gX86CpuRegList ), 0 },
        { IDS_REGGROUP_CPU_SEGMENTS, gX86SegmentsRegList, _countof( gX86SegmentsRegList ), 0 },
        { IDS_REGGROUP_FLOATING_POINT, gX86FloatingRegList, _countof( gX86FloatingRegList ), 0 },
        { IDS_REGGROUP_FLAGS, gX86FlagsRegList, _countof( gX86FlagsRegList ), 0 },
        { IDS_REGGROUP_MMX, gX86MMXRegList, _countof( gX86MMXRegList ), PF_X86_MMX },
        { IDS_REGGROUP_SSE, gX86SSERegList, _countof( gX86SSERegList ), PF_X86_SSE },
        { IDS_REGGROUP_SSE2, gX86SSE2RegList, _countof( gX86SSE2RegList ), PF_X86_SSE2 },
    ];


    void  GetX86RegisterGroups( ref const  RegGroupInternal*  groups, ref uint32_t  count )
    {
        groups = gX86RegGroups;
        count = _countof( gX86RegGroups );
    }
}
