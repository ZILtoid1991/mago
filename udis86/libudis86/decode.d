module libudis86.decode;

/*decode.h
input.h
itab.h
syn.h
types.h
extern.h*/
/* -----------------------------------------------------------------------------
 * decode.c
 *
 * Copyright (c) 2005, 2006, Vivek Mohan <vivek@sig9.com>
 * All rights reserved. See LICENSE
 * -----------------------------------------------------------------------------
 */

// #include <assert.h>
// #include <string.h>

import libudis86.types;
import libudis86.itab;
import libudis86.input;
import libudis86.decode;
public import libudis86.decodeConsts;

/* The max number of prefixes to an instruction */
enum MAX_PREFIXES = 15;

static ud_itab_entry ie_invalid = {UD_Iinvalid, O_NONE, O_NONE, O_NONE, P_none};
static ud_itab_entry ie_pause = {UD_Ipause, O_NONE, O_NONE, O_NONE, P_none};
static ud_itab_entry ie_nop = {UD_Inop, O_NONE, O_NONE, O_NONE, P_none};

/** register classes */
enum RegisterClass
{
    T_NONE = 0,
    T_GPR = 1,
    T_MMX = 2,
    T_CRG = 3,
    T_DBG = 4,
    T_SEG = 5,
    T_XMM = 6,
}

/* itab prefix bits */
@nogc int P_none()
{
    return (0);
}

@nogc int P_c1()
{
    return (1 << 0);
}

@nogc int P_C1(int n)
{
    return ((n >> 0) & 1);
}

@nogc int P_rexb()
{
    return (1 << 1);
}

@nogc int P_REXB(int n)
{
    return ((n >> 1) & 1);
}

@nogc int P_depM()
{
    return (1 << 2);
}

@nogc int P_DEPM(int n)
{
    return ((n >> 2) & 1);
}

@nogc int P_c3()
{
    return (1 << 3);
}

@nogc int P_C3(int n)
{
    return ((n >> 3) & 1);
}

@nogc int P_inv64()
{
    return (1 << 4);
}

@nogc int P_INV64(int n)
{
    return ((n >> 4) & 1);
}

@nogc int P_rexw()
{
    return (1 << 5);
}

@nogc int P_REXW(int n)
{
    return ((n >> 5) & 1);
}

@nogc int P_c2()
{
    return (1 << 6);
}

@nogc int P_C2(int n)
{
    return ((n >> 6) & 1);
}

@nogc int P_def64()
{
    return (1 << 7);
}

@nogc int P_DEF64(int n)
{
    return ((n >> 7) & 1);
}

@nogc int P_rexr()
{
    return (1 << 8);
}

@nogc int P_REXR(int n)
{
    return ((n >> 8) & 1);
}

@nogc int P_oso()
{
    return (1 << 9);
}

@nogc int P_OSO(int n)
{
    return ((n >> 9) & 1);
}

@nogc int P_aso()
{
    return (1 << 10);
}

@nogc int P_ASO(int n)
{
    return ((n >> 10) & 1);
}

@nogc int P_rexx()
{
    return (1 << 11);
}

@nogc int P_REXX(int n)
{
    return ((n >> 11) & 1);
}

@nogc int P_ImpAddr()
{
    return (1 << 12);
}

@nogc int P_IMPADDR(int n)
{
    return ((n >> 12) & 1);
}
/* rex prefix bits */
@nogc int REX_W(int r)
{
    return ((0xF & (r)) >> 3);
}

@nogc int REX_R(int r)
{
    return ((0x7 & (r)) >> 2);
}

@nogc int REX_X(int r)
{
    return ((0x3 & (r)) >> 1);
}

@nogc int REX_B(int r)
{
    return ((0x1 & (r)) >> 0);
}

@nogc int REX_PFX_MASK(int n)
{
    return ((P_REXW(n) << 3) | (P_REXR(n) << 2) | (
            P_REXX(n) << 1) | (P_REXB(n) << 0));
}

/** scable-index-base bits */
@nogc int SIB_S(int b)
{
    return ((b) >> 6);
}

@nogc int SIB_I(int b)
{
    return (((b) >> 3) & 7);
}

@nogc int SIB_B(int b)
{
    return ((b) & 7);
}

/** modrm bits */
@nogc int MODRM_REG(int b)
{
    return (((b) >> 3) & 7);
}

@nogc int MODRM_NNN(int b)
{
    return (((b) >> 3) & 7);
}

@nogc int MODRM_MOD(int b)
{
    return (((b) >> 6) & 3);
}

@nogc int MODRM_RM(int b)
{
    return ((b) & 7);
}
/** operand type constants -- order is important! */

enum ud_operand_code
{
    OP_NONE,

    OP_A,
    OP_E,
    OP_M,
    OP_G,
    OP_I,

    OP_AL,
    OP_CL,
    OP_DL,
    OP_BL,
    OP_AH,
    OP_CH,
    OP_DH,
    OP_BH,

    OP_ALr8b,
    OP_CLr9b,
    OP_DLr10b,
    OP_BLr11b,
    OP_AHr12b,
    OP_CHr13b,
    OP_DHr14b,
    OP_BHr15b,

    OP_AX,
    OP_CX,
    OP_DX,
    OP_BX,
    OP_SI,
    OP_DI,
    OP_SP,
    OP_BP,

    OP_rAX,
    OP_rCX,
    OP_rDX,
    OP_rBX,
    OP_rSP,
    OP_rBP,
    OP_rSI,
    OP_rDI,

    OP_rAXr8,
    OP_rCXr9,
    OP_rDXr10,
    OP_rBXr11,
    OP_rSPr12,
    OP_rBPr13,
    OP_rSIr14,
    OP_rDIr15,

    OP_eAX,
    OP_eCX,
    OP_eDX,
    OP_eBX,
    OP_eSP,
    OP_eBP,
    OP_eSI,
    OP_eDI,

    OP_ES,
    OP_CS,
    OP_SS,
    OP_DS,
    OP_FS,
    OP_GS,

    OP_ST0,
    OP_ST1,
    OP_ST2,
    OP_ST3,
    OP_ST4,
    OP_ST5,
    OP_ST6,
    OP_ST7,

    OP_J,
    OP_S,
    OP_O,
    OP_I1,
    OP_I3,

    OP_V,
    OP_W,
    OP_Q,
    OP_P,

    OP_R,
    OP_C,
    OP_D,
    OP_VR,
    OP_PR
}

/** operand size constants */
enum ud_operand_size
{
    SZ_NA = 0,
    SZ_Z = 1,
    SZ_V = 2,
    SZ_P = 3,
    SZ_WP = 4,
    SZ_DP = 5,
    SZ_MDQ = 6,
    SZ_RDQ = 7,

    /* the following values are used as is,
     * and thus hard-coded. changing them 
     * will break internals 
     */
    SZ_B = 8,
    SZ_W = 16,
    SZ_D = 32,
    SZ_Q = 64,
    SZ_T = 80,
}

/**
 * A single operand of an entry in the instruction table. 
 * (internal use only)
 */
@nogc struct ud_itab_entry_operand
{
    ud_operand_code type;
    ud_operand_size size;
    /**
   * Ctor.
   */
    @nogc this(ud_operand_code type, ud_operand_size size)
    {
        this.size = size;
        this.type = type;
    }
}

/**
 * A single entry in an instruction table. 
 *(internal use only)
 */
struct ud_itab_entry
{
    ud_mnemonic_code mnemonic;
    ud_itab_entry_operand operand1;
    ud_itab_entry_operand operand2;
    ud_itab_entry_operand operand3;
    uint32_t prefix;
    @nogc this(ud_mnemonic_code mnemonic, ud_itab_entry_operand operand1,
            ud_itab_entry_operand operand2, ud_itab_entry_operand operand3, uint32_t prefix)
    {
        this.mnemonic = mnemonic;
        this.operand1 = operand1;
        this.operand2 = operand2;
        this.operand3 = operand3;
        this.prefix = prefix;
    }
}

/** Looks up mnemonic code in the mnemonic string table
 * Returns NULL if the mnemonic code is invalid
 */
@nogc char* ud_lookup_mnemonic(ud_mnemonic_code c) const
{
    if (c < UD_Id3vil)
        return ud_mnemonics_str[c];
    return null;
}

/**
 * Extracts instruction prefixes.
 */
static @nogc int get_prefixes(ud* u)
{
    uint have_pfx = 1;
    uint i;
    uint8_t curr;

    /* if in error state, bail out */
    if (u.error)
        return -1;

    /* keep going as long as there are prefixes available */
    for (i = 0; have_pfx; ++i)
    {

        /* Get next byte. */
        inp_next(u);
        if (u.error)
            return -1;
        curr = inp_curr(u);

        /* rex prefixes in 64bit mode */
        if (u.dis_mode == 64 && (curr & 0xF0) == 0x40)
        {
            u.pfx_rex = curr;
        }
        else
        {
            switch (curr)
            {
            case 0x2E:
                u.pfx_seg = UD_R_CS;
                u.pfx_rex = 0;
                break;
            case 0x36:
                u.pfx_seg = UD_R_SS;
                u.pfx_rex = 0;
                break;
            case 0x3E:
                u.pfx_seg = UD_R_DS;
                u.pfx_rex = 0;
                break;
            case 0x26:
                u.pfx_seg = UD_R_ES;
                u.pfx_rex = 0;
                break;
            case 0x64:
                u.pfx_seg = UD_R_FS;
                u.pfx_rex = 0;
                break;
            case 0x65:
                u.pfx_seg = UD_R_GS;
                u.pfx_rex = 0;
                break;
            case 0x67: /* adress-size override prefix */
                u.pfx_adr = 0x67;
                u.pfx_rex = 0;
                break;
            case 0xF0:
                u.pfx_lock = 0xF0;
                u.pfx_rex = 0;
                break;
            case 0x66:
                /* the 0x66 sse prefix is only effective if no other sse prefix
                 * has already been specified.
                 */
                if (!u.pfx_insn)
                    u.pfx_insn = 0x66;
                u.pfx_opr = 0x66;
                u.pfx_rex = 0;
                break;
            case 0xF2:
                u.pfx_insn = 0xF2;
                u.pfx_repne = 0xF2;
                u.pfx_rex = 0;
                break;
            case 0xF3:
                u.pfx_insn = 0xF3;
                u.pfx_rep = 0xF3;
                u.pfx_repe = 0xF3;
                u.pfx_rex = 0;
                break;
            default:
                /* No more prefixes */
                have_pfx = 0;
                break;
            }
        }

        /* check if we reached max instruction length */
        if (i + 1 == MAX_INSN_LENGTH)
        {
            u.error = 1;
            break;
        }
    }

    /* return status */
    if (u.error)
        return -1;

    /* rewind back one byte in stream, since the above loop 
     * stops with a non-prefix byte. 
     */
    inp_back(u);

    /* speculatively determine the effective operand mode,
     * based on the prefixes and the current disassembly
     * mode. This may be inaccurate, but useful for mode
     * dependent decoding.
     */
    if (u.dis_mode == 64)
    {
        u.opr_mode = REX_W(u.pfx_rex) ? 64 : ((u.pfx_opr) ? 16 : 32);
        u.adr_mode = (u.pfx_adr) ? 32 : 64;
    }
    else if (u.dis_mode == 32)
    {
        u.opr_mode = (u.pfx_opr) ? 16 : 32;
        u.adr_mode = (u.pfx_adr) ? 16 : 32;
    }
    else if (u.dis_mode == 16)
    {
        u.opr_mode = (u.pfx_opr) ? 32 : 16;
        u.adr_mode = (u.pfx_adr) ? 32 : 16;
    }

    return 0;
}

/**
 * Searches the instruction tables for the right entry.
 */
static @nogc int search_itab(ud* u)
{
    ud_itab_entry* e = null;
    ud_itab_index table;
    uint8_t peek;
    uint8_t did_peek = 0;
    uint8_t curr;
    uint8_t index;

    /* if in state of error, return */
    if (u.error)
        return -1;

    /* get first byte of opcode. */
    inp_next(u);
    if (u.error)
        return -1;
    curr = inp_curr(u);

    /* resolve xchg, nop, pause crazyness */
    if (0x90 == curr)
    {
        if (!(u.dis_mode == 64 && REX_B(u.pfx_rex)))
        {
            if (u.pfx_rep)
            {
                u.pfx_rep = 0;
                e = &ie_pause;
            }
            else
            {
                e = &ie_nop;
            }
            goto found_entry;
        }
    }

    /* get top-level table */
    if (0x0F == curr)
    {
        table = ITAB__0F;
        curr = inp_next(u);
        if (u.error)
            return -1;

        /* 2byte opcodes can be modified by 0x66, F3, and F2 prefixes */
        if (0x66 == u.pfx_insn)
        {
            if (ud_itab_list[ITAB__PFX_SSE66__0F][curr].mnemonic != UD_Iinvalid)
            {
                table = ITAB__PFX_SSE66__0F;
                u.pfx_opr = 0;
            }
        }
        else if (0xF2 == u.pfx_insn)
        {
            if (ud_itab_list[ITAB__PFX_SSEF2__0F][curr].mnemonic != UD_Iinvalid)
            {
                table = ITAB__PFX_SSEF2__0F;
                u.pfx_repne = 0;
            }
        }
        else if (0xF3 == u.pfx_insn)
        {
            if (ud_itab_list[ITAB__PFX_SSEF3__0F][curr].mnemonic != UD_Iinvalid)
            {
                table = ITAB__PFX_SSEF3__0F;
                u.pfx_repe = 0;
                u.pfx_rep = 0;
            }
        }
        /* pick an instruction from the 1byte table */
    }
    else
    {
        table = ITAB__1BYTE;
    }

    index = curr;

search:

    e = &ud_itab_list[table][index];

    /* if mnemonic constant is a standard instruction constant
     * our search is over.
     */

    if (e.mnemonic < UD_Id3vil)
    {
        if (e.mnemonic == UD_Iinvalid)
        {
            if (did_peek)
            {
                inp_next(u);
                if (u.error)
                    return -1;
            }
            goto found_entry;
        }
        goto found_entry;
    }

    table = e.prefix;

    switch (e.mnemonic)
    {
    case UD_Igrp_reg:
        peek = inp_peek(u);
        did_peek = 1;
        index = MODRM_REG(peek);
        break;

    case UD_Igrp_mod:
        peek = inp_peek(u);
        did_peek = 1;
        index = MODRM_MOD(peek);
        if (index == 3)
            index = ITAB__MOD_INDX__11;
        else
            index = ITAB__MOD_INDX__NOT_11;
        break;

    case UD_Igrp_rm:
        curr = inp_next(u);
        did_peek = 0;
        if (u.error)
            return -1;
        index = MODRM_RM(curr);
        break;

    case UD_Igrp_x87:
        curr = inp_next(u);
        did_peek = 0;
        if (u.error)
            return -1;
        index = curr - 0xC0;
        break;

    case UD_Igrp_osize:
        if (u.opr_mode == 64)
            index = ITAB__MODE_INDX__64;
        else if (u.opr_mode == 32)
            index = ITAB__MODE_INDX__32;
        else
            index = ITAB__MODE_INDX__16;
        break;

    case UD_Igrp_asize:
        if (u.adr_mode == 64)
            index = ITAB__MODE_INDX__64;
        else if (u.adr_mode == 32)
            index = ITAB__MODE_INDX__32;
        else
            index = ITAB__MODE_INDX__16;
        break;

    case UD_Igrp_mode:
        if (u.dis_mode == 64)
            index = ITAB__MODE_INDX__64;
        else if (u.dis_mode == 32)
            index = ITAB__MODE_INDX__32;
        else
            index = ITAB__MODE_INDX__16;
        break;

    case UD_Igrp_vendor:
        if (u.vendor == UD_VENDOR_INTEL)
            index = ITAB__VENDOR_INDX__INTEL;
        else if (u.vendor == UD_VENDOR_AMD)
            index = ITAB__VENDOR_INDX__AMD;
        else
            assert(!"unrecognized vendor id");
        break;

    case UD_Id3vil:
        assert(!"invalid instruction mnemonic constant Id3vil");
        break;

    default:
        assert(!"invalid instruction mnemonic constant");
        break;
    }

    goto search;

found_entry:

    u.itab_entry = e;
    u.mnemonic = u.itab_entry.mnemonic;

    return 0;
}

static @nogc uint resolve_operand_size(const ud* u, uint s)
{
    switch (s)
    {
    case SZ_V:
        return (u.opr_mode);
    case SZ_Z:
        return (u.opr_mode == 16) ? 16 : 32;
    case SZ_P:
        return (u.opr_mode == 16) ? SZ_WP : SZ_DP;
    case SZ_MDQ:
        return (u.opr_mode == 16) ? 32 : u.opr_mode;
    case SZ_RDQ:
        return (u.dis_mode == 64) ? 64 : 32;
    default:
        return s;
    }
}

static @nogc int resolve_mnemonic(ud* u)
{
    /* far/near flags */
    u.br_far = 0;
    u.br_near = 0;
    /* readjust operand sizes for call/jmp instrcutions */
    if (u.mnemonic == UD_Icall || u.mnemonic == UD_Ijmp)
    {
        /* WP: 16bit pointer */
        if (u.operand[0].size == SZ_WP)
        {
            u.operand[0].size = 16;
            u.br_far = 1;
            u.br_near = 0;
            /* DP: 32bit pointer */
        }
        else if (u.operand[0].size == SZ_DP)
        {
            u.operand[0].size = 32;
            u.br_far = 1;
            u.br_near = 0;
        }
        else
        {
            u.br_far = 0;
            u.br_near = 1;
        }
        /* resolve 3dnow weirdness. */
    }
    else if (u.mnemonic == UD_I3dnow)
    {
        u.mnemonic = ud_itab_list[ITAB__3DNOW][inp_curr(u)].mnemonic;
    }
    /* SWAPGS is only valid in 64bits mode */
    if (u.mnemonic == UD_Iswapgs && u.dis_mode != 64)
    {
        u.error = 1;
        return -1;
    }

    return 0;
}

/**
 * -----------------------------------------------------------------------------
 * decode_a()- Decodes operands of the type seg:offset
 * -----------------------------------------------------------------------------
 */
static @nogc void decode_a(ud* u, ud_operand* op)
{
    if (u.opr_mode == 16)
    {
        /* seg16:off16 */
        op.type = UD_OP_PTR;
        op.size = 32;
        op.lval.ptr.off = inp_uint16(u);
        op.lval.ptr.seg = inp_uint16(u);
    }
    else
    {
        /* seg16:off32 */
        op.type = UD_OP_PTR;
        op.size = 48;
        op.lval.ptr.off = inp_uint32(u);
        op.lval.ptr.seg = inp_uint16(u);
    }
}

/**
 * -----------------------------------------------------------------------------
 * decode_gpr() - Returns decoded General Purpose Register 
 * -----------------------------------------------------------------------------
 */
static @nogc ud_type decode_gpr(ud* u, uint s, ubyte rm)
{
    s = resolve_operand_size(u, s);

    switch (s)
    {
    case 64:
        return UD_R_RAX + rm;
    case SZ_DP:
    case 32:
        return UD_R_EAX + rm;
    case SZ_WP:
    case 16:
        return UD_R_AX + rm;
    case 8:
        if (u.dis_mode == 64 && u.pfx_rex)
        {
            if (rm >= 4)
                return UD_R_SPL + (rm - 4);
            return UD_R_AL + rm;
        }
        else
            return UD_R_AL + rm;
    default:
        return 0;
    }
}

/**
 * -----------------------------------------------------------------------------
 * resolve_gpr64() - 64bit General Purpose Register-Selection. 
 * -----------------------------------------------------------------------------
 */
static @nogc ud_type resolve_gpr64(ud* u, ud_operand_code gpr_op)
{
    if (gpr_op >= OP_rAXr8 && gpr_op <= OP_rDIr15)
        gpr_op = (gpr_op - OP_rAXr8) | (REX_B(u.pfx_rex) << 3);
    else
        gpr_op = (gpr_op - OP_rAX);

    if (u.opr_mode == 16)
        return gpr_op + UD_R_AX;
    if (u.dis_mode == 32 || (u.opr_mode == 32 && !(REX_W(u.pfx_rex) || u.default64)))
    {
        return gpr_op + UD_R_EAX;
    }

    return gpr_op + UD_R_RAX;
}

/**
 * -----------------------------------------------------------------------------
 * resolve_gpr32 () - 32bit General Purpose Register-Selection. 
 * -----------------------------------------------------------------------------
 */
static @nogc ud_type resolve_gpr32(ud* u, ud_operand_code gpr_op)
{
    gpr_op = gpr_op - OP_eAX;

    if (u.opr_mode == 16)
        return gpr_op + UD_R_AX;

    return gpr_op + UD_R_EAX;
}

/**
 * -----------------------------------------------------------------------------
 * resolve_reg() - Resolves the register type 
 * -----------------------------------------------------------------------------
 */
static @nogc ud_type resolve_reg(ud* u, uint type, ubyte i)
{
    switch (type)
    {
    case T_MMX:
        return UD_R_MM0 + (i & 7);
    case T_XMM:
        return UD_R_XMM0 + i;
    case T_CRG:
        return UD_R_CR0 + i;
    case T_DBG:
        return UD_R_DR0 + i;
    case T_SEG:
        return UD_R_ES + (i & 7);
    case T_NONE:
    default:
        return UD_NONE;
    }
}

/**
 * -----------------------------------------------------------------------------
 * decode_imm() - Decodes Immediate values.
 * -----------------------------------------------------------------------------
 */
static @nogc void decode_imm(ud* u, uint s, ud_operand* op)
{
    op.size = resolve_operand_size(u, s);
    op.type = UD_OP_IMM;

    switch (op.size)
    {
    case 8:
        op.lval.sbyte = inp_uint8(u);
        break;
    case 16:
        op.lval.uword = inp_uint16(u);
        break;
    case 32:
        op.lval.udword = inp_uint32(u);
        break;
    case 64:
        op.lval.uqword = inp_uint64(u);
        break;
    default:
        return;
    }
}

/**
 * -----------------------------------------------------------------------------
 * decode_modrm() - Decodes ModRM Byte
 * -----------------------------------------------------------------------------
 */
static @nogc void decode_modrm(ud* u, ud_operand* op, uint s, ubyte rm_type,
        ud_operand* opreg, ubyte reg_size, ubyte reg_type)
{
    ubyte mod, rm, reg;

    inp_next(u);

    /* get mod, r/m and reg fields */
    mod = MODRM_MOD(inp_curr(u));
    rm = (REX_B(u.pfx_rex) << 3) | MODRM_RM(inp_curr(u));
    reg = (REX_R(u.pfx_rex) << 3) | MODRM_REG(inp_curr(u));

    op.size = resolve_operand_size(u, s);

    /* if mod is 11b, then the UD_R_m specifies a gpr/mmx/sse/control/debug */
    if (mod == 3)
    {
        op.type = ud_type.UD_OP_REG;
        if (rm_type == T_GPR)
            op.base = decode_gpr(u, op.size, rm);
        else
            op.base = resolve_reg(u, rm_type, (REX_B(u.pfx_rex) << 3) | (rm & 7));
    }
    /* else its memory addressing */
    else
    {
        op.type = ud_type.UD_OP_MEM;

        /* 64bit addressing */
        if (u.adr_mode == 64)
        {

            op.base = ud_type.UD_R_RAX + rm;

            /* get offset type */
            if (mod == 1)
                op.offset = 8;
            else if (mod == 2)
                op.offset = 32;
            else if (mod == 0 && (rm & 7) == 5)
            {
                op.base = ud_type.UD_R_RIP;
                op.offset = 32;
            }
            else
                op.offset = 0;

            /* Scale-Index-Base (SIB) */
            if ((rm & 7) == 4)
            {
                inp_next(u);

                op.scale = (1 << SIB_S(inp_curr(u))) & ~1;
                op.index = ud_type.UD_R_RAX + (SIB_I(inp_curr(u)) | (REX_X(u.pfx_rex) << 3));
                op.base = ud_type.UD_R_RAX + (SIB_B(inp_curr(u)) | (REX_B(u.pfx_rex) << 3));

                /* special conditions for base reference */
                if (op.index == ud_type.UD_R_RSP)
                {
                    op.index = ud_type.UD_NONE;
                    op.scale = ud_type.UD_NONE;
                }

                if (op.base == ud_type.UD_R_RBP || op.base == ud_type.UD_R_R13)
                {
                    if (mod == 0)
                        op.base = ud_type.UD_NONE;
                    if (mod == 1)
                        op.offset = 8;
                    else
                        op.offset = 32;
                }
            }
        }

        /* 32-Bit addressing mode */
        else if (u.adr_mode == 32)
        {

            /* get base */
            op.base = ud_type.UD_R_EAX + rm;

            /* get offset type */
            if (mod == 1)
                op.offset = 8;
            else if (mod == 2)
                op.offset = 32;
            else if (mod == 0 && rm == 5)
            {
                op.base = ud_type.UD_NONE;
                op.offset = 32;
            }
            else
                op.offset = 0;

            /* Scale-Index-Base (SIB) */
            if ((rm & 7) == 4)
            {
                inp_next(u);

                op.scale = (1 << SIB_S(inp_curr(u))) & ~1;
                op.index = ud_type.UD_R_EAX + (SIB_I(inp_curr(u)) | (REX_X(u.pfx_rex) << 3));
                op.base = ud_type.UD_R_EAX + (SIB_B(inp_curr(u)) | (REX_B(u.pfx_rex) << 3));

                if (op.index == ud_type.UD_R_ESP)
                {
                    op.index = ud_type.UD_NONE;
                    op.scale = ud_type.UD_NONE;
                }

                /* special condition for base reference */
                if (op.base == ud_type.UD_R_EBP)
                {
                    if (mod == 0)
                        op.base = ud_type.UD_NONE;
                    if (mod == 1)
                        op.offset = 8;
                    else
                        op.offset = 32;
                }
            }
        }

        /* 16bit addressing mode */
        else
        {
            switch (rm)
            {
            case 0:
                op.base = ud_type.UD_R_BX;
                op.index = ud_type.UD_R_SI;
                break;
            case 1:
                op.base = ud_type.UD_R_BX;
                op.index = ud_type.UD_R_DI;
                break;
            case 2:
                op.base = ud_type.UD_R_BP;
                op.index = ud_type.UD_R_SI;
                break;
            case 3:
                op.base = ud_type.UD_R_BP;
                op.index = ud_type.UD_R_DI;
                break;
            case 4:
                op.base = ud_type.UD_R_SI;
                break;
            case 5:
                op.base = ud_type.UD_R_DI;
                break;
            case 6:
                op.base = ud_type.UD_R_BP;
                break;
            case 7:
                op.base = ud_type.UD_R_BX;
                break;
            default:
                break;
            }

            if (mod == 0 && rm == 6)
            {
                op.offset = 16;
                op.base = ud_type.UD_NONE;
            }
            else if (mod == 1)
                op.offset = 8;
            else if (mod == 2)
                op.offset = 16;
        }
    }

    /* extract offset, if any */
    switch (op.offset)
    {
    case 8:
        op.lval._ubyte = inp_uint8(u);
        break;
    case 16:
        op.lval.uword = inp_uint16(u);
        break;
    case 32:
        op.lval.udword = inp_uint32(u);
        break;
    case 64:
        op.lval.uqword = inp_uint64(u);
        break;
    default:
        break;
    }

    /* resolve register encoded in reg field */
    if (opreg)
    {
        opreg.type = ud_type.UD_OP_REG;
        opreg.size = resolve_operand_size(u, reg_size);
        if (reg_type == T_GPR)
            opreg.base = decode_gpr(u, opreg.size, reg);
        else
            opreg.base = resolve_reg(u, reg_type, reg);
    }
}

/**
 * -----------------------------------------------------------------------------
 * decode_o() - Decodes offset
 * -----------------------------------------------------------------------------
 */
static @nogc void decode_o(ud* u, uint s, ud_operand* op)
{
    switch (u.adr_mode)
    {
    case 64:
        op.offset = 64;
        op.lval.uqword = inp_uint64(u);
        break;
    case 32:
        op.offset = 32;
        op.lval.udword = inp_uint32(u);
        break;
    case 16:
        op.offset = 16;
        op.lval.uword = inp_uint16(u);
        break;
    default:
        return;
    }
    op.type = ud_type.UD_OP_MEM;
    op.size = resolve_operand_size(u, s);
}

/**
 * -----------------------------------------------------------------------------
 * disasm_operands() - Disassembles Operands.
 * -----------------------------------------------------------------------------
 */
static @nogc int disasm_operands(ud* u)
{

    /* mopXt = map entry, operand X, type; */
    ud_operand_code mop1t = u.itab_entry.operand1.type;
    ud_operand_code mop2t = u.itab_entry.operand2.type;
    ud_operand_code mop3t = u.itab_entry.operand3.type;

    /* mopXs = map entry, operand X, size */
    uint mop1s = u.itab_entry.operand1.size;
    uint mop2s = u.itab_entry.operand2.size;
    uint mop3s = u.itab_entry.operand3.size;

    /* iop = instruction operand */
    /* SYNTAX ERROR: (711): expected ; instead of struct */ /*struct*/
    ud_operand* iop = u.operand;

    switch (mop1t)
    {

    case ud_operand_code.OP_A:
        decode_a(u, &(iop[0]));
        break;

        /* M[b] ... */
    case ud_operand_code.OP_M:
        if (MODRM_MOD(inp_peek(u)) == 3)
            u.error = 1;
        /* E, G/P/V/I/CL/1/S */
    case ud_operand_code.OP_E:
        if (mop2t == OP_G)
        {
            decode_modrm(u, &(iop[0]), mop1s, T_GPR, &(iop[1]), mop2s, T_GPR);
            if (mop3t == OP_I)
                decode_imm(u, mop3s, &(iop[2]));
            else if (mop3t == OP_CL)
            {
                iop[2].type = UD_OP_REG;
                iop[2].base = UD_R_CL;
                iop[2].size = 8;
            }
        }
        else if (mop2t == OP_P)
            decode_modrm(u, &(iop[0]), mop1s, T_GPR, &(iop[1]), mop2s, T_MMX);
        else if (mop2t == OP_V)
            decode_modrm(u, &(iop[0]), mop1s, T_GPR, &(iop[1]), mop2s, T_XMM);
        else if (mop2t == OP_S)
            decode_modrm(u, &(iop[0]), mop1s, T_GPR, &(iop[1]), mop2s, T_SEG);
        else
        {
            decode_modrm(u, &(iop[0]), mop1s, T_GPR, null, 0, T_NONE);
            if (mop2t == OP_CL)
            {
                iop[1].type = ud_type.UD_OP_REG;
                iop[1].base = ud_type.UD_R_CL;
                iop[1].size = 8;
            }
            else if (mop2t == OP_I1)
            {
                iop[1].type = ud_type.UD_OP_CONST;
                u.operand[1].lval.udword = 1;
            }
            else if (mop2t == OP_I)
            {
                decode_imm(u, mop2s, &(iop[1]));
            }
        }
        break;

        /* G, E/PR[,I]/VR */
    case ud_operand_code.OP_G:
        if (mop2t == OP_M)
        {
            if (MODRM_MOD(inp_peek(u)) == 3)
                u.error = 1;
            decode_modrm(u, &(iop[1]), mop2s, T_GPR, &(iop[0]), mop1s, T_GPR);
        }
        else if (mop2t == OP_E)
        {
            decode_modrm(u, &(iop[1]), mop2s, T_GPR, &(iop[0]), mop1s, T_GPR);
            if (mop3t == OP_I)
                decode_imm(u, mop3s, &(iop[2]));
        }
        else if (mop2t == OP_PR)
        {
            decode_modrm(u, &(iop[1]), mop2s, T_MMX, &(iop[0]), mop1s, T_GPR);
            if (mop3t == OP_I)
                decode_imm(u, mop3s, &(iop[2]));
        }
        else if (mop2t == OP_VR)
        {
            if (MODRM_MOD(inp_peek(u)) != 3)
                u.error = 1;
            decode_modrm(u, &(iop[1]), mop2s, T_XMM, &(iop[0]), mop1s, T_GPR);
        }
        else if (mop2t == OP_W)
            decode_modrm(u, &(iop[1]), mop2s, T_XMM, &(iop[0]), mop1s, T_GPR);
        break;

        /* AL..BH, I/O/DX */
        /*case OP_AL:
    case OP_CL:
    case OP_DL:
    case OP_BL:
    case OP_AH:
    case OP_CH:
    case OP_DH:
    case OP_BH:*/
    case ud_operand_code.OP_AL: .. case ud_operand_code.OP_BH:
    case iop[0].type = ud_type.UD_OP_REG;
        iop[0].base = UD_R_AL + (mop1t - OP_AL);
        iop[0].size = 8;

        if (mop2t == OP_I)
            decode_imm(u, mop2s, &(iop[1]));
        else if (mop2t == OP_DX)
        {
            iop[1].type = ud_type.UD_OP_REG;
            iop[1].base = ud_type.UD_R_DX;
            iop[1].size = 16;
        }
        else if (mop2t == OP_O)
            decode_o(u, mop2s, &(iop[1]));
        break;

        /* rAX[r8]..rDI[r15], I/rAX..rDI/O */
        /*case OP_rAXr8:
    case OP_rCXr9:
    case OP_rDXr10:
    case OP_rBXr11:
    case OP_rSPr12:
    case OP_rBPr13:
    case OP_rSIr14:
    case OP_rDIr15:
    case OP_rAX:
    case OP_rCX:
    case OP_rDX:
    case OP_rBX:
    case OP_rSP:
    case OP_rBP:
    case OP_rSI:
    case OP_rDI:*/
    case ud_operand_code.OP_rAXr8: .. ud_operand_code.case OP_rDI : iop[0].type = ud_type.UD_OP_REG;
        iop[0].base = resolve_gpr64(u, mop1t);

        if (mop2t == OP_I)
            decode_imm(u, mop2s, &(iop[1]));
        else if (mop2t >= OP_rAX && mop2t <= OP_rDI)
        {
            iop[1].type = ud_type.UD_OP_REG;
            iop[1].base = resolve_gpr64(u, mop2t);
        }
        else if (mop2t == OP_O)
        {
            decode_o(u, mop2s, &(iop[1]));
            iop[0].size = resolve_operand_size(u, mop2s);
        }
        break;

        /* AL[r8b]..BH[r15b], I */
        /*case OP_ALr8b:
    case OP_CLr9b:
    case OP_DLr10b:
    case OP_BLr11b:
    case OP_AHr12b:
    case OP_CHr13b:
    case OP_DHr14b:
    case OP_BHr15b:*/
    case ud_operand_code.OP_ALr8b: .. ud_operand_code.case OP_BHr15b : 
        {
            ud_type_t gpr = (mop1t - OP_ALr8b) + UD_R_AL + (REX_B(u.pfx_rex) << 3);
            if (UD_R_AH <= gpr && u.pfx_rex)
                gpr = gpr + 4;
            iop[0].type = UD_OP_REG;
            iop[0].base = gpr;
            if (mop2t == OP_I)
                decode_imm(u, mop2s, &(iop[1]));
            break;
        }

        /* eAX..eDX, DX/I */
        /*case OP_eAX:
    case OP_eCX:
    case OP_eDX:
    case OP_eBX:
    case OP_eSP:
    case OP_eBP:
    case OP_eSI:
    case OP_eDI:*/
    case ud_operand_code.OP_eAX: .. case ud_operand_code.OP_eDI:
        iop[0].type = ud_type.UD_OP_REG;
        iop[0].base = resolve_gpr32(u, mop1t);
        if (mop2t == OP_DX)
        {
            iop[1].type = ud_type.UD_OP_REG;
            iop[1].base = ud_type.UD_R_DX;
            iop[1].size = 16;
        }
        else if (mop2t == OP_I)
            decode_imm(u, mop2s, &(iop[1]));
        break;

        /* ES..GS */
        /*case ud_operand_code.OP_ES:
    case OP_CS:
    case OP_DS:
    case OP_SS:
    case OP_FS:
    case ud_operand_code.OP_GS:*/
    case ud_operand_code.OP_ES: .. case ud_operand_code.OP_GS:
        /* in 64bits mode, only fs and gs are allowed */
        if (u.dis_mode == 64)
            if (mop1t != ud_operand_code.OP_FS && mop1t != ud_operand_code.OP_GS)
                u.error = 1;
        iop[0].type = ud_type.UD_OP_REG;
        iop[0].base = (mop1t - ud_operand_code.OP_ES) + UD_R_ES;
        iop[0].size = 16;

        break;

        /* J */
    case ud_operand_code.OP_J:
        decode_imm(u, mop1s, &(iop[0]));
        iop[0].type = ud_type.UD_OP_JIMM;
        break;

        /* PR, I */
    case ud_operand_code.OP_PR:
        if (MODRM_MOD(inp_peek(u)) != 3)
            u.error = 1;
        decode_modrm(u, &(iop[0]), mop1s, RegisterClass.T_MMX, null, 0, RegisterClass.T_NONE);
        if (mop2t == ud_operand_code.OP_I)
            decode_imm(u, mop2s, &(iop[1]));
        break;

        /* VR, I */
    case ud_operand_code.OP_VR:
        if (MODRM_MOD(inp_peek(u)) != 3)
            u.error = 1;
        decode_modrm(u, &(iop[0]), mop1s, RegisterClass.T_XMM, null, 0, RegisterClass.T_NONE);
        if (mop2t == ud_operand_code.OP_I)
            decode_imm(u, mop2s, &(iop[1]));
        break;

        /* P, Q[,I]/W/E[,I],VR */
    case ud_operand_code.OP_P:
        if (mop2t == ud_operand_code.OP_Q)
        {
            decode_modrm(u, &(iop[1]), mop2s, RegisterClass.T_MMX, &(iop[0]),
                    mop1s, RegisterClass.T_MMX);
            if (mop3t == ud_operand_code.OP_I)
                decode_imm(u, mop3s, &(iop[2]));
        }
        else if (mop2t == ud_operand_code.OP_W)
        {
            decode_modrm(u, &(iop[1]), mop2s, RegisterClass.T_XMM, &(iop[0]),
                    mop1s, RegisterClass.T_MMX);
        }
        else if (mop2t == ud_operand_code.OP_VR)
        {
            if (MODRM_MOD(inp_peek(u)) != 3)
                u.error = 1;
            decode_modrm(u, &(iop[1]), mop2s, RegisterClass.T_XMM, &(iop[0]),
                    mop1s, RegisterClass.T_MMX);
        }
        else if (mop2t == ud_operand_code.OP_E)
        {
            decode_modrm(u, &(iop[1]), mop2s, RegisterClass.T_GPR, &(iop[0]),
                    mop1s, RegisterClass.T_MMX);
            if (mop3t == ud_operand_code.OP_I)
                decode_imm(u, mop3s, &(iop[2]));
        }
        break;

        /* R, C/D */
    case ud_operand_code.OP_R:
        if (mop2t == OP_C)
            decode_modrm(u, &(iop[0]),
                    mop1s, RegisterClass.T_GPR, &(iop[1]), mop2s, RegisterClass.T_CRG);
        else if (mop2t == OP_D)
            decode_modrm(u, &(iop[0]), mop1s, RegisterClass.T_GPR, &(iop[1]),
                    mop2s, RegisterClass.T_DBG);
        break;

        /* C, R */
    case ud_operand_code.OP_C:
        decode_modrm(u, &(iop[1]), mop2s,
                RegisterClass.T_GPR, &(iop[0]), mop1s, RegisterClass.T_CRG);
        break;

        /* D, R */
    case ud_operand_code.OP_D:
        decode_modrm(u, &(iop[1]), mop2s,
                RegisterClass.T_GPR, &(iop[0]), mop1s, RegisterClass.T_DBG);
        break;

        /* Q, P */
    case ud_operand_code.OP_Q:
        decode_modrm(u, &(iop[0]), mop1s,
                RegisterClass.T_MMX, &(iop[1]), mop2s, RegisterClass.T_MMX);
        break;

        /* S, E */
    case ud_operand_code.OP_S:
        decode_modrm(u, &(iop[1]), mop2s,
                RegisterClass.T_GPR, &(iop[0]), mop1s, RegisterClass.T_SEG);
        break;

        /* W, V */
    case ud_operand_code.OP_W:
        decode_modrm(u, &(iop[0]), mop1s,
                RegisterClass.T_XMM, &(iop[1]), mop2s, RegisterClass.T_XMM);
        break;

        /* V, W[,I]/Q/M/E */
    case ud_operand_code.OP_V:
        if (mop2t == OP_W)
        {
            /* special cases for movlps and movhps */
            if (MODRM_MOD(inp_peek(u)) == 3)
            {
                if (u.mnemonic == UD_Imovlps)
                    u.mnemonic = UD_Imovhlps;
                else if (u.mnemonic == UD_Imovhps)
                    u.mnemonic = UD_Imovlhps;
            }
            decode_modrm(u, &(iop[1]), mop2s, RegisterClass.T_XMM, &(iop[0]),
                    mop1s, RegisterClass.T_XMM);
            if (mop3t == OP_I)
                decode_imm(u, mop3s, &(iop[2]));
        }
        else if (mop2t == OP_Q)
            decode_modrm(u, &(iop[1]), mop2s, RegisterClass.T_MMX, &(iop[0]),
                    mop1s, RegisterClass.T_XMM);
        else if (mop2t == OP_M)
        {
            if (MODRM_MOD(inp_peek(u)) == 3)
                u.error = 1;
            decode_modrm(u, &(iop[1]), mop2s, RegisterClass.T_GPR, &(iop[0]),
                    mop1s, RegisterClass.T_XMM);
        }
        else if (mop2t == OP_E)
        {
            decode_modrm(u, &(iop[1]), mop2s, RegisterClass.T_GPR, &(iop[0]),
                    mop1s, RegisterClass.T_XMM);
        }
        else if (mop2t == OP_PR)
        {
            decode_modrm(u, &(iop[1]), mop2s, RegisterClass.T_MMX, &(iop[0]),
                    mop1s, RegisterClass.T_XMM);
        }
        break;

        /* DX, eAX/AL */
    case ud_operand_code.OP_DX:
        iop[0].type = ud_type.UD_OP_REG;
        iop[0].base = ud_type.UD_R_DX;
        iop[0].size = 16;

        if (mop2t == OP_eAX)
        {
            iop[1].type = ud_type.UD_OP_REG;
            iop[1].base = resolve_gpr32(u, mop2t);
        }
        else if (mop2t == OP_AL)
        {
            iop[1].type = UD_OP_REG;
            iop[1].base = ud_type.UD_R_AL;
            iop[1].size = 8;
        }

        break;

        /* I, I/AL/eAX */
    case ud_operand_code.OP_I:
        decode_imm(u, mop1s, &(iop[0]));
        if (mop2t == OP_I)
            decode_imm(u, mop2s, &(iop[1]));
        else if (mop2t == OP_AL)
        {
            iop[1].type = ud_type.UD_OP_REG;
            iop[1].base = ud_type.UD_R_AL;
            iop[1].size = 16;
        }
        else if (mop2t == OP_eAX)
        {
            iop[1].type = ud_type.UD_OP_REG;
            iop[1].base = resolve_gpr32(u, mop2t);
        }
        break;

        /* O, AL/eAX */
    case ud_operand_code.OP_O:
        decode_o(u, mop1s, &(iop[0]));
        iop[1].type = ud_type.UD_OP_REG;
        iop[1].size = resolve_operand_size(u, mop1s);
        if (mop2t == OP_AL)
            iop[1].base = ud_type.UD_R_AL;
        else if (mop2t == OP_eAX)
            iop[1].base = resolve_gpr32(u, mop2t);
        else if (mop2t == OP_rAX)
            iop[1].base = resolve_gpr64(u, mop2t);
        break;

        /* 3 */
    case ud_operand_code.OP_I3:
        iop[0].type = ud_type.UD_OP_CONST;
        iop[0].lval.sbyte = 3;
        break;

        /* ST(n), ST(n) */
        /*case OP_ST0:
    case OP_ST1:
    case OP_ST2:
    case OP_ST3:
    case OP_ST4:
    case OP_ST5:
    case OP_ST6:
    case OP_ST7:*/
    case ud_operand_code.OP_ST0: .. case ud_operand_code.OP_ST7:
        iop[0].type = ud_type.UD_OP_REG;
        iop[0].base = (mop1t - ud_operand_code.OP_ST0) + ud_type.UD_R_ST0;
        iop[0].size = 0;

        if (mop2t >= ud_operand_code.OP_ST0 && mop2t <= ud_operand_code.OP_ST7)
        {
            iop[1].type = UD_OP_REG;
            iop[1].base = (mop2t - ud_operand_code.OP_ST0) + ud_type.UD_R_ST0;
            iop[1].size = 0;
        }
        break;

        /* AX */
    case ud_operand_code.OP_AX:
        iop[0].type = ud_type.UD_OP_REG;
        iop[0].base = ud_type.UD_R_AX;
        iop[0].size = 16;
        break;

        /* none */
    default:
        iop[0].type = iop[1].type = iop[2].type = ud_type.UD_NONE;
    }

    return 0;
}

/* -----------------------------------------------------------------------------
 * clear_insn() - clear instruction pointer 
 * -----------------------------------------------------------------------------
 */
static @nogc int clear_insn(ud* u)
{
    u.error = 0;
    u.pfx_seg = 0;
    u.pfx_opr = 0;
    u.pfx_adr = 0;
    u.pfx_lock = 0;
    u.pfx_repne = 0;
    u.pfx_rep = 0;
    u.pfx_repe = 0;
    u.pfx_seg = 0;
    u.pfx_rex = 0;
    u.pfx_insn = 0;
    u.mnemonic = ud_type.UD_Inone;
    u.itab_entry = null;

    memset(&u.operand[0], 0, (ud_operand).sizeof);
    memset(&u.operand[1], 0, (ud_operand).sizeof);
    memset(&u.operand[2], 0, (ud_operand).sizeof);

    return 0;
}

static @nogc int do_mode(ud* u)
{
    /* if in error state, bail out */
    if (u.error)
        return -1;

    /* propagate perfix effects */
    if (u.dis_mode == 64)
    { /* set 64bit-mode flags */

        /* Check validity of  instruction m64 */
        if (P_INV64(u.itab_entry.prefix))
        {
            u.error = 1;
            return -1;
        }

        /* effective rex prefix is the  effective mask for the 
     * instruction hard-coded in the opcode map.
     */
        u.pfx_rex = (u.pfx_rex & 0x40) | (u.pfx_rex & REX_PFX_MASK(u.itab_entry.prefix));

        /* whether this instruction has a default operand size of 
     * 64bit, also hardcoded into the opcode map.
     */
        u.default64 = P_DEF64(u.itab_entry.prefix);
        /* calculate effective operand size */
        if (REX_W(u.pfx_rex))
        {
            u.opr_mode = 64;
        }
        else if (u.pfx_opr)
        {
            u.opr_mode = 16;
        }
        else
        {
            /* unless the default opr size of instruction is 64,
         * the effective operand size in the absence of rex.w
         * prefix is 32.
         */
            u.opr_mode = (u.default64) ? 64 : 32;
        }

        /* calculate effective address size */
        u.adr_mode = (u.pfx_adr) ? 32 : 64;
    }
    else if (u.dis_mode == 32)
    { /* set 32bit-mode flags */
        u.opr_mode = (u.pfx_opr) ? 16 : 32;
        u.adr_mode = (u.pfx_adr) ? 16 : 32;
    }
    else if (u.dis_mode == 16)
    { /* set 16bit-mode flags */
        u.opr_mode = (u.pfx_opr) ? 32 : 16;
        u.adr_mode = (u.pfx_adr) ? 32 : 16;
    }

    /* These flags determine which operand to apply the operand size
   * cast to.
   */
    u.c1 = (P_C1(u.itab_entry.prefix)) ? 1 : 0;
    u.c2 = (P_C2(u.itab_entry.prefix)) ? 1 : 0;
    u.c3 = (P_C3(u.itab_entry.prefix)) ? 1 : 0;

    /* set flags for implicit addressing */
    u.implicit_addr = P_IMPADDR(u.itab_entry.prefix);

    return 0;
}

static @nogc int gen_hex(ud* u)
{
    uint i;
    ubyte* src_ptr = inp_sess(u);
    char* src_hex;

    /* bail out if in error stat. */
    if (u.error)
        return -1;
    /* output buffer pointe */
    src_hex = cast(char*) u.insn_hexcode;
    /* for each byte used to decode instruction */
    for (i = 0; i < u.inp_ctr; ++i, ++src_ptr)
    {
        sprintf(src_hex, "%02x", *src_ptr & 0xFF);
        src_hex += 2;
    }
    return 0;
}

/**
 * =============================================================================
 * ud_decode() - Instruction decoder. Returns the number of bytes decoded.
 * =============================================================================
 */
@nogc uint ud_decode(ud* u)
{
    inp_start(u);

    if (clear_insn(u))
    {
        {
        } /* error */
    }
    else if (get_prefixes(u) != 0)
    {
        {
        } /* error */
    }
    else if (search_itab(u) != 0)
    {
        {
        } /* error */
    }
    else if (do_mode(u) != 0)
    {
        {
        } /* error */
    }
    else if (disasm_operands(u) != 0)
    {
        {
        } /* error */
    }
    else if (resolve_mnemonic(u) != 0)
    {
        {
        } /* error */
    }

    /* Handle decode error. */
    if (u.error)
    {
        /* clear out the decode data. */
        clear_insn(u);
        /* mark the sequence of bytes as invalid. */
        u.itab_entry = &ie_invalid;
        u.mnemonic = u.itab_entry.mnemonic;
    }

    u.insn_offset = u.pc; /* set offset of instruction */
    u.insn_fill = 0; /* set translation buffer index to 0 */
    u.pc += u.inp_ctr; /* move program counter by bytes decoded */
    gen_hex(u); /* generate hex code */

    /* return number of bytes disassembled. */
    return u.inp_ctr;
}

/* vim:cindent
 * vim:ts=4
 * vim:sw=4
 * vim:expandtab
 */
