module libudis86.syn_intel;

/*decode.h
input.h
itab.h
syn.h
types.h
extern.h*/
/* -----------------------------------------------------------------------------
 * syn-intel.c
 *
 * Copyright (c) 2002, 2003, 2004 Vivek Mohan <vivek@sig9.com>
 * All rights reserved. See (LICENSE)
 * -----------------------------------------------------------------------------
 */

//import libudis86.types;
//import libudis86.extern;
import libudis86.decode;
import libudis86.itab;
import libudis86.syn;

static void mksym(ud* u, const(char)* fmt, uint64_t addr)
{
	if (!u.symbolizer || !(*(u.symbolizer))(u, addr))
		mkasm(u, fmt, addr);
}

/**
 * -----------------------------------------------------------------------------
 * opr_cast() - Prints an operand cast.
 * -----------------------------------------------------------------------------
 */
static void opr_cast(ud* u, ud_operand* op)
{
	switch (op.size)
	{
	case 8:
		mkasm(u, "byte ");
		break;
	case 16:
		mkasm(u, "word ");
		break;
	case 32:
		mkasm(u, "dword ");
		break;
	case 64:
		mkasm(u, "qword ");
		break;
	case 80:
		mkasm(u, "tword ");
		break;
	default:
		break;
	}
	if (u.br_far)
		mkasm(u, "far ");
	else if (u.br_near)
		mkasm(u, "near ");
}

/**
 * -----------------------------------------------------------------------------
 * gen_operand() - Generates assembly output for each operand.
 * -----------------------------------------------------------------------------
 */
static void gen_operand(ud* u, ud_operand* op, int syn_cast)
{
	switch (op.type)
	{
	case UD_OP_REG:
		mkasm(u, ud_reg_tab[op.base - UD_R_AL]);
		break;

	case UD_OP_MEM:
		{

			int op_f = 0;

			int64_t off = 0;
			if (op.offset == 8)
			{
				off = op.lval.sbyte;
			}
			else if (op.offset == 16)
				off = op.lval.uword;
			else if (op.offset == 32)
			{
				if (u.adr_mode == 64)
					off = op.lval.sdword;
				else
					off = op.lval.udword;
			}
			else if (op.offset == 64)
				off = op.lval.uqword;

			if (syn_cast)
				opr_cast(u, op);

			mkasm(u, "[");

			if (op.base == UD_R_RIP && !op.index && !op.scale)
			{
				uint64_t addr = u.pc + off;
				if (u.symbolizer && (*(u.symbolizer))(u, addr))
					goto L_sym;
			}

			if (u.pfx_seg)
				mkasm(u, "%s:", ud_reg_tab[u.pfx_seg - UD_R_AL]);

			if (op.base)
			{
				mkasm(u, "%s", ud_reg_tab[op.base - UD_R_AL]);
				op_f = 1;
			}

			if (op.index)
			{
				if (op_f)
					mkasm(u, "+");
				mkasm(u, "%s", ud_reg_tab[op.index - UD_R_AL]);
				op_f = 1;
			}

			if (op.scale)
				mkasm(u, "*%d", op.scale);

			if (off)
			{
				if (off < 0)
					mkasm(u, "-0x" /* SYNTAX ERROR: (104): expected , instead of FMT64 */ FMT64"x",
							 - off);
				else
				{
					if (op_f)
						mkasm(u, "+");
					mksym(u, "0x" /* SYNTAX ERROR: (109): expected , instead of FMT64 */ FMT64"x",
							off);
				}
			}
	L_sym:
			mkasm(u, "]");
			break;
		}

	case UD_OP_IMM : 
		if (syn_cast){
			opr_cast(u, op);
		}
		switch (op.size)
		{
		case 8 : 
			mkasm(u, "0x%x", op.lval.ubyte);
			break;
		case 16 : 
			mkasm(u, "0x%x", op.lval.uword);
			break;
		case 32 : mksym(u, "0x" /* SYNTAX ERROR: (122): expected , instead of FMT64 */ FMT64"x",
					op.lval.udword);
			break;
		case 64 : mksym(u, "0x" /* SYNTAX ERROR: (123): expected , instead of FMT64 */ FMT64"x",
					op.lval.uqword);
			break;
		default : break;
		}
		break;

	case UD_OP_JIMM : if (syn_cast)
			opr_cast(u, op);
		switch (op.size)
		{
		case 8 : 
			mksym(u, "0x" /* SYNTAX ERROR: (132): expected , instead of FMT64 */ FMT64"x",
					u.pc + op.lval.sbyte);
			break;
		case 16 : 
			mksym(u, "0x" /* SYNTAX ERROR: (135): expected , instead of FMT64 */ FMT64"x",
					u.pc + op.lval.sword);
			break;
		case 32 : 
			mksym(u, "0x" /* SYNTAX ERROR: (138): expected , instead of FMT64 */ FMT64"x",
					u.pc + op.lval.sdword);
			break;
		default : break;
		}
		break;

	case UD_OP_PTR : switch (op.size)
		{
		case 32 : 
			mkasm(u, "word 0x%x:0x%x", op.lval.ptr.seg, op.lval.ptr.off & 0xFFFF);
			break;
		case 48 : 
			mkasm(u, "dword 0x%x:0x%lx", op.lval.ptr.seg, op.lval.ptr.off);
			break;
		default : break;
		}
		break;

	case UD_OP_CONST : 
		if (syn_cast)
			opr_cast(u, op);
		mksym(u, "%d", op.lval.udword);
		break;

	default : return;
	}
}
