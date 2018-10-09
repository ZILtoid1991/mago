module libudis86.input;

/*decode.h
input.h
itab.h
syn.h
types.h
extern.h*/
/* -----------------------------------------------------------------------------
 * input.c
 *
 * Copyright (c) 2004, 2005, 2006, Vivek Mohan <vivek@sig9.com>
 * All rights reserved. See LICENSE
 * -----------------------------------------------------------------------------
 */
import libudis86.extern;
import libudis86.types;
import libudis86.itab;

//import input;

/** inp_init() - Initializes the input system. */
mixin template inp_init(alias u)
{
  do
  {
    u.inp_curr = 0;
    u.inp_fill = 0;
    u.inp_ctr = 0;
    u.inp_end = 0;
  }

  while (0)



}

/** inp_start() - Should be called before each de-code operation. */
mixin template inp_start(alias u)
{
  u.inp_ctr = 0;
}

/**
 * inp_back() - Resets the current pointer to its position before the current
 * instruction disassembly was started.
 */
mixin template inp_reset(alias u)
{
  do
  {
    u.inp_curr -= u.inp_ctr;
    u.inp_ctr = 0;
  }

  while (0)

}

/** inp_sess() - Returns the pointer to current session. */
mixin template inp_sess(alias u)
{
  (u.inp_sess)
}

/** inp_cur() - Returns the current input byte. */
mixin template inp_curr(alias u)
{
  ((u.inp_cache[(u.inp_curr])
}

/**
 * -----------------------------------------------------------------------------
 * inp_buff_hook() - Hook for buffered inputs.
 * -----------------------------------------------------------------------------
 */
static int inp_buff_hook(ud* u)
{
  if (u.inp_buff < u.inp_buff_end)
    return *u.inp_buff++; else
    return -1;}

  static if (!__UD_STANDALONE__)
  {
    /**
 * -----------------------------------------------------------------------------
 * inp_file_hook() - Hook for FILE inputs.
 * -----------------------------------------------------------------------------
 */
    static int inp_file_hook(ud* u)
    {
      return fgetc(u.inp_file);}
    }
