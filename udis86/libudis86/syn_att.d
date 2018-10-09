module libudis86.syn_att;

/*decode.h
input.h
itab.h
syn.h
types.h
extern.h*/
/* -----------------------------------------------------------------------------
 * syn-att.c
 *
 * Copyright (c) 2004, 2005, 2006 Vivek Mohan <vivek@sig9.com>
 * All rights reserved. See (LICENSE)
 * -----------------------------------------------------------------------------
 */

//import libudis86.types;
//import libudis86.extern;
import libudis86.decode;
import libudis86.itab;
import libudis86.syn;

/**
 * -----------------------------------------------------------------------------
 * opr_cast() - Prints an operand cast.
 * -----------------------------------------------------------------------------
 */
static void opr_cast(ud* u, ud_operand* op)
{
  switch(op.size) {
	case  16 : case  32 :
		mkasm(u, "*");   break;
	default: break;
  }
}

/**
 * -----------------------------------------------------------------------------
 * gen_operand() - Generates assembly output for each operand.
 * -----------------------------------------------------------------------------
 */
static void gen_operand(ud* u, ud_operand* op)
{
  switch(op.type) {
	case  UD_OP_REG:
		mkasm(u, "%%%s", ud_reg_tab[op.base - UD_R_AL]);
		break;

	case  UD_OP_MEM:
		if (u.br_far) opr_cast(u, op);
		if (u.pfx_seg)
			mkasm(u, "%%%s:", ud_reg_tab[u.pfx_seg - UD_R_AL]);
		if (op.offset == 8) {
			if (op.lval.sbyte < 0)
				mkasm(u, "-0x%x", (-op.lval.sbyte) & 0xff);
			else	 mkasm(u, "0x%x", op.lval.sbyte);
		} 
		else  if (op.offset == 16) 
			mkasm(u, "0x%x", op.lval.uword);
		else  if (op.offset == 32) 
			mkasm(u, "0x%lx", op.lval.udword);
		else  if (op.offset == 64) 
			mkasm(u, "0x"  /* SYNTAX ERROR: (55): expected , instead of FMT64 */ FMT64 "x", op.lval.uqword);

		if (op.base)
			mkasm(u, "(%%%s", ud_reg_tab[op.base - UD_R_AL]);
		if (op.index) {
			if (op.base)
				mkasm(u, ",");
			else  mkasm(u, "(");
			mkasm(u, "%%%s", ud_reg_tab[op.index - UD_R_AL]);
		}
		if (op.scale)
			mkasm(u, ",%d", op.scale);
		if (op.base || op.index)
			mkasm(u, ")");
		break;

	case  UD_OP_IMM:
		switch (op.size) {
			case   8: mkasm(u, "$0x%x", op.lval.ubyte);    break;
			case  16: mkasm(u, "$0x%x", op.lval.uword);    break;
			case  32: mkasm(u, "$0x%lx", op.lval.udword);  break;
			case  64: mkasm(u, "$0x"  /* SYNTAX ERROR: (76): expected , instead of FMT64 */ FMT64 "x", op.lval.uqword); break;
			default: break;
		}
		break;

	case  UD_OP_JIMM:
		switch (op.size) {
			case   8:
				mkasm(u, "0x"  /* SYNTAX ERROR: (84): expected , instead of FMT64 */ FMT64 "x", u.pc + op.lval.sbyte); 
				break;
			case  16:
				mkasm(u, "0x"  /* SYNTAX ERROR: (87): expected , instead of FMT64 */ FMT64 "x", u.pc + op.lval.sword);
				break;
			case  32:
				mkasm(u, "0x"  /* SYNTAX ERROR: (90): expected , instead of FMT64 */ FMT64 "x", u.pc + op.lval.sdword);
				break;
			default:break;
		}
		break;

	case  UD_OP_PTR:
		switch (op.size) {
			case  32:
				mkasm(u, "$0x%x, $0x%x", op.lval.ptr.seg, 
					op.lval.ptr.off & 0xFFFF);
				break;
			case  48:
				mkasm(u, "$0x%x, $0x%lx", op.lval.ptr.seg, 
					op.lval.ptr.off);
				break;
		default: break;
		}
		break;
			
	default: return;
  }
}
