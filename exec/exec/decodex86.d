module exec.decodex86;

/*
   Copyright (c) 2010 Aldo J. Nunez

   Licensed under the Apache License, Version 2.0.
   See the LICENSE text file for details.
*/

import exec.common;
import std.bitmanip;

enum CpuSizeMode
{
    _32,
    _64,
}

// For drag and drop compatibility with the old code
// TODO: replace these with new references
enum Cpu_32 = CpuSizeMode._32;
enum Cpu_64 = CpuSizeMode._64;

enum InstructionType
{
    none,
    other,
    call,
    repString,
    jmp,
    breakpoint,
    syscall,
}
// For drag and drop compatibility with the old code
// TODO: replace these with new references
enum Inst_None = InstructionType.none;
enum Inst_Other = InstructionType.other;
enum Inst_Call = InstructionType.call;
enum Inst_RepString = InstructionType.repString;
enum Inst_Jmp = InstructionType.jmp;
enum Inst_Breakpoint = InstructionType.breakpoint;
enum Inst_Syscall = InstructionType.syscall;

// IA-32 Intel Architecture: Software Developer’s Manual
// Volume 2A: Instruction Set Reference, A-M
// 2.2.1 REX Prefixes (p. 2-9)
immutable int MAX_INSTRUCTION_SIZE = 15;

struct Prefixes32
{
    bool AddressSize; // 67
    bool OperandSize; // 66
    bool Lock; // F0
    bool RepF2; // F2
    bool RepF3; // F3
    bool Cs; // 2E
    bool Ds; // 3E
    bool Es; // 26
    bool Fs; // 64
    bool Gs; // 65
    bool Ss; // 36
}

union RexPrefix
{
    struct unnamed_30
    {
        /*bool     B : 1;
        bool     X : 1;
        bool     R : 1;
        bool     W : 1;
        uint8_t  RexConst : 4;*/
        mixin(bitfields!("bool", "B", 1, "bool", "X", 1, "bool", "R", 1,
                "bool", "W", 1, "ubyte", "RexConst", 4,));
    }

    unnamed_30 Bits;
    uint8_t Byte;
}

struct Prefixes64
{
    RexPrefix Rex;
}

struct Prefixes
{
    Prefixes32 Pre32;
    Prefixes64 Pre64;
}

static  int  GetModRmSize16( uint8_t  modRm )
{
    int      instSize = 1;       // already includes modRm byte
    BYTE     mod = (modRm >> 6) & 3;
    BYTE     rm = (modRm & 7);

    // mod == 3 is only for single direct register values
    if ( mod != 3 )
    {
        if ( mod == 2 )
            instSize += 2;      // disp16
        else  if ( mod == 1 )
            instSize += 1;      // disp8

        if ( (mod == 0) && (rm == 6) )
            instSize += 2;      // disp16
    }

    return  instSize;
}

static  int  GetModRmSize32( uint8_t  modRm )
{
    int      instSize = 1;       // already includes modRm byte
    BYTE     mod = (modRm >> 6) & 3;
    BYTE     rm = (modRm & 7);

    // mod == 3 is only for single direct register values
    if ( mod != 3 )
    {
        if ( rm == 4 )
            instSize += 1;      // SIB

        if ( mod == 2 )
            instSize += 4;      // disp32
        else  if ( mod == 1 )
            instSize += 1;      // disp8

        if ( (mod == 0) && (rm == 5) )
            instSize += 4;      // disp32
    }

    return  instSize;
}

InstructionType GetInstructionTypeAndSize(uint8_t* mem, int memLen, CpuSizeMode mode, ref int size)
{
    _ASSERT( (mode == Cpu_32) || (mode == Cpu_64) );

    InstructionType  type = Inst_Other;
    int              instSize = 0;
    int              remSize = 0;
    int              prefixSize = 0;
    Prefixes         prefixes = { 0 };

    if ( memLen > MAX_INSTRUCTION_SIZE )
        memLen = MAX_INSTRUCTION_SIZE;

    prefixSize = ReadPrefixes( mem, memLen, mode, prefixes );
    if ( prefixSize >= memLen )
        return  Inst_None;

    remSize = memLen - prefixSize;

    // now that we've considered prefixes, change the base to where the opcode begins
    mem = &mem[prefixSize];

    switch ( mem[0] )
    {
    case  0xCC:
        instSize = 1;
        type = Inst_Breakpoint;
        break;

        // call instructions
    case  0xE8:
        if ( prefixes.Pre32.OperandSize && (mode == Cpu_32) )
            instSize = 3;
        else
             instSize = 5;

        if ( instSize > 0 )
            type = Inst_Call;
        break;

    case  0x9A:
        if ( mode == Cpu_32 )
        {
            if ( prefixes.Pre32.OperandSize )
                instSize = 5;
            else
                 instSize = 7;
        }

        if ( instSize > 0 )
            type = Inst_Call;
        break;

        // call or jmp instructions
    case  0xFF:
        {
            if ( remSize < 2 )
                break;

            BYTE     regOp = (mem[1] >> 3) & 7;
            if ( (regOp == 2) || (regOp == 3) )
            {
                if ( (mode == Cpu_64) || !prefixes.Pre32.AddressSize )
                    instSize = 1 + GetModRmSize32( mem[1] );
                else
                     instSize = 1 + GetModRmSize16( mem[1] );

                if ( instSize > 0 )
                    type = Inst_Call;
            }
            else  if ( (regOp == 4) || (regOp == 5) )
            {
                if ( (mode == Cpu_64) || !prefixes.Pre32.AddressSize )
                    instSize = 1 + GetModRmSize32( mem[1] );
                else
                     instSize = 1 + GetModRmSize16( mem[1] );

                type = Inst_Jmp;
            }
        }
        break;

        // jmp instructions
    case  0xEB:
        instSize = 2;
        type = Inst_Jmp;
        break;

    case  0xE9:
        if ( prefixes.Pre32.OperandSize && (mode == Cpu_32) )
            instSize = 3;
        else
             instSize = 5;
        type = Inst_Jmp;
        break;

    case  0xEA:
        if ( mode == Cpu_32 )
        {
            if ( prefixes.Pre32.OperandSize )
                instSize = 5;
            else
                 instSize = 7;
            type = Inst_Jmp;
        }
        break;

        // system call instructions
    case  0x0F:
        if ( remSize < 2 )
            break;
        if ( (mem[1] == 0x05) || (mem[1] == 0x34) )
            instSize = 2;

        if ( instSize > 0 )
            type = Inst_Syscall;
        break;

    default:
        // rep prefixed instructions
        if ( remSize < 2 )
            break;

        if ( prefixes.Pre32.RepF2 )
        {
           if ( (mem[0] == 0xA6) || (mem[0] == 0xA7) || (mem[0] == 0xAE) || (mem[0] == 0xAF) )
                instSize = 1;
        }
        else  if ( prefixes.Pre32.RepF3 )
        {
            if (   ((mem[0] >= 0x6C) && (mem[0] <= 0x6F))
                || ((mem[0] >= 0xA4) && (mem[0] <= 0xA7))
                || ((mem[0] >= 0xAA) && (mem[0] <= 0xAF)) )
                instSize = 1;
        }

        if ( instSize > 0 )
            type = Inst_RepString;
        break;
    }

    // sanity check, is it longer than available memory?
    if ( instSize > memLen )
        return  Inst_None;

    size = instSize + prefixSize;

    return  type;
}
