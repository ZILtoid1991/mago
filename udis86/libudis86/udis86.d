module libudis86.udis86;

/*decode.h
input.h
itab.h
syn.h
types.h
extern.h*/
/* -----------------------------------------------------------------------------
 * udis86.c
 *
 * Copyright (c) 2004, 2005, 2006, Vivek Mohan <vivek@sig9.com>
 * All rights reserved. See LICENSE
 * -----------------------------------------------------------------------------
 */

// #include <stdlib.h>
// #include <stdio.h>
// #include <string.h>
import core.stdc.stdlib;
import core.stdc.stdio;
import core.stdc.string;

import libudis86.input;
//import libudis86.extern;

/**
 * =============================================================================
 * ud_init() - Initializes ud_t object.
 * =============================================================================
 */
public @nogc void ud_init(ud* u)
{
	memset((void * ) u, 0, ud.sizeof);
	ud_set_mode(u, 16);
	u.mnemonic = UD_Iinvalid;
	ud_set_pc(u, 0);
	static if (!__UD_STANDALONE__)
		ud_set_input_file(u, stdin);
	//#endif /* __UD_STANDALONE__ */
}

/**
 * =============================================================================
 * ud_disassemble() - disassembles one instruction and returns the number of 
 * bytes disassembled. A zero means end of disassembly.
 * =============================================================================
 */
public @nogc int ud_disassemble(ud* u)
{
	if (ud_input_end(u))
		return 0;

	u.insn_buffer[0] = u.insn_hexcode[0] = 0;

	if (ud_decode(u) == 0)
		return 0;
	if (u.translator)
		u.translator(u);
	return ud_insn_len(u);
}

/**
 * =============================================================================
 * ud_set_mode() - Set Disassemly Mode.
 * =============================================================================
 */
public @nogc void ud_set_mode(ud* u, ubyte m)
{
	switch (m)
	{
	case 16, 32, 64:
		u.dis_mode = m;
		return;
	default:
		u.dis_mode = 16;
		return;
	}
}

/**
 * =============================================================================
 * ud_set_vendor() - Set vendor.
 * =============================================================================
 */
public @nogc void ud_set_vendor(ud* u, uint v)
{
	switch (v)
	{
	case UD_VENDOR_INTEL:
		u.vendor = v;
		break;
	default:
		u.vendor = UD_VENDOR_AMD;
	}
}

/**
 * =============================================================================
 * ud_set_pc() - Sets code origin. 
 * =============================================================================
 */
public @nogc void ud_set_pc(ud* u, uint64_t o)
{
	u.pc = o;
}

/**
 * =============================================================================
 * ud_set_syntax() - Sets the output syntax.
 * =============================================================================
 */
public @nogc void ud_set_syntax(ud* u, void* t)
{
	//ud_set_syntax(ud* u, void (*t)(struct ud*))
	u.translator = t;
}

/**
 * =============================================================================
 * ud_insn() - returns the disassembled instruction
 * =============================================================================
 */
public @nogc char* ud_insn_asm(ud* u)
{
	return u.insn_buffer;
}

/**
 * =============================================================================
 * ud_insn_offset() - Returns the offset.
 * =============================================================================
 */
public @nogc ulong ud_insn_off(ud* u)
{
	return u.insn_offset;
}

/**
 * =============================================================================
 * ud_insn_hex() - Returns hex form of disassembled instruction.
 * =============================================================================
 */
public @nogc char* ud_insn_hex(ud* u)
{
	return u.insn_hexcode;
}

/**
 * =============================================================================
 * ud_insn_ptr() - Returns code disassembled.
 * =============================================================================
 */
public @nogc ubyte * ud_insn_ptr(ud* u)
{
	return u.inp_sess;
}

/**
 * =============================================================================
 * ud_insn_len() - Returns the count of bytes disassembled.
 * =============================================================================
 */
public @nogc uint ud_insn_len(ud* u)
{
	return u.inp_ctr;
}
