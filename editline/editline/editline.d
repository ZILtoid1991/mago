module editline.editline;

/*
ORIGINALLY FROM "readline.h":

readline.h

is part of:

WinEditLine (formerly MinGWEditLine)
Copyright 2010-2014 Paolo Tosco <paolo.tosco@unito.it>
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

    * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
    * Neither the name of WinEditLine (formerly MinGWEditLine) nor the
    name of its contributors may be used to endorse or promote products
    derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

import core.sys.windows.windows;
import core.sys.windows.wincon;

//import core.sys.windows.atl
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.stdc.ctype;
import core.stdc.wctype;
import core.stdc.wchar_;

import editline.fn_complete;
import editline.history;

/*
extern variables
*/
static char* rl_line_buffer;
static wchar_t* _el_line_buffer;
static wchar_t* _el_print;
static wchar_t* _el_temp_print;
static wchar_t* _el_next_compl;
static wchar_t* _el_file_name;
static wchar_t* _el_dir_name;
static wchar_t* _el_old_arg;
static wchar_t* _el_wide;
static wchar_t* _el_text;
static char* _el_text_mb;
static char* rl_prompt;
static wchar_t* _el_prompt;
static wchar_t** _el_compl_array;
static wchar_t* _el_basic_word_break_characters;
static wchar_t* _el_completer_word_break_characters;
static wchar_t[_EL_MAX_FILE_BREAK_CHARACTERS] _el_basic_file_break_characters;
static int _el_ctrl_c_pressed;
static int rl_point;
static int rl_attempted_completion_over;
static int rl_completion_append_character = ' ';
static const char[] rl_basic_word_break_characters = " \t\n\\'`@$><=;|&{(";
static char* rl_completer_word_break_characters;
static int _el_compl_index;
static int _el_n_compl;
static int _el_prompt_len;
static char* rl_readline_name;
static rl_completion_func_t* rl_attempted_completion_function;
static rl_compentry_func_t* rl_completion_entry_function;
static rl_compentryfree_func_t* rl_user_completion_entry_free_function;
static BOOL _el_prev_in_cm_saved;
static BOOL _el_prev_out_cm_saved;
static DWORD _el_prev_in_cm;
static DWORD _el_prev_out_cm;
static HANDLE _el_h_in;
static HANDLE _el_h_out;
static COORD _el_prev_size;

static size_t _el_temp_print_size;
static BOOL _el_prev_sbInfo_saved = FALSE;

/**
 * Emulates the wcsncpy_s function from the C standard library.
 * TODO: implement overlap detection.
 */
@nogc int wcsncpy_s(wchar_t* dest, size_t destsz, const wchar_t* src, size_t n)
{
  if (dest is null || src is null)
    return -1;
  if (!destsz || n >= destsz)
    return -1;
  int i;
  for (; i < n; i++)
  {
    dest[i] = src[i];
    if (!src[i])
    {
      return -1;
    }
  }
  dest[i] = '\0';
  return 0;
}
/**
 * Emulates wcscpy_s.
 */
@nogc int wcscpy_s(  
   wchar_t *strDestination,  
   size_t numberOfElements,  
   const wchar_t *strSource   
){
  return 0;
}
/*
these defines may be changed
*/
enum _EL_BUF_LEN = 32768; /* maximum line buffer size */
enum DEFAULT_HISTORY_SIZE = 200; /* default number of history entries */

/*
these defines should not be mangled
*/
enum
{
  _EL_CONSOLE_BUF_LEN = 8,
  _EL_MIN_HIST_SIZE = 1,
  _EL_ENV_BUF_LEN = 64,
  _EL_MAX_FILE_BREAK_CHARACTERS = 64, /* _EL_BASIC_FILE_BREAK_CHARACTERS  _T(" \"\t\n=><|")
 _EL_BASIC_FILE_QUOTE_CHARACTERS  _T(" $;=&")*/



}
enum _EL_BASIC_FILE_BREAK_CHARACTERS = " \"\t\n=><|"w;
enum _EL_BASIC_FILE_QUOTE_CHARACTERS = " $;=&"w;
/*
these are included because for some reason
they are missing from MinGW gcc 4.5.0
*/
/*#ifndef ENABLE_EXTENDED_FLAGS
#define ENABLE_EXTENDED_FLAGS    0x0080
#endif
#ifndef ENABLE_INSERT_MODE
#define ENABLE_INSERT_MODE    0x0020
#endif
#ifndef ENABLE_QUICK_EDIT_MODE
#define ENABLE_QUICK_EDIT_MODE    0x0040
#endif*/
enum
{
  ENABLE_EXTENDED_FLAGS = 0x0080,
  ENABLE_INSERT_MODE = 0x0020,
  ENABLE_QUICK_EDIT_MODE = 0x0040
}

alias rl_completion_func_t = char** function(const char*, int, int);
//typedef char **rl_completion_func_t(const char *, int, int);
alias rl_compentry_func_t = char* function(const char*, int);
//typedef char *rl_compentry_func_t(const char *, int);
alias rl_compentryfree_func_t = void function(void*);
//typedef void rl_compentryfree_func_t(void *);
/*
this is ignored by WinEditLine
*/
alias histdata_t = void*;
//typedef void *histdata_t;

struct _hist_entry
{
  char* line;
  char* timestamp;
  histdata_t data;
} //HIST_ENTRY;
alias HIST_ENTRY = _hist_entry;

struct _hist_state
{
  HIST_ENTRY** entries;
  int offset;
  int length;
  int size;
  int flags;
} //HISTORY_STATE;
alias HISTORY_STATE = _hist_state;

//#ifdef __cplusplus
//extern "C" {
//#endif
/*
prototypes of internal functions
*/

int _el_display_prev_hist()
{
  if (where_history() > 0)
  {
    if (!_el_w2mb(_el_line_buffer, &rl_line_buffer))
    {
      return -1;
    }
    replace_history_entry(where_history(), rl_line_buffer, null);
    previous_history();
    _el_display_history();
  }

  return 0;
}

int _el_display_next_hist()
{
  if (where_history() < (history_length() - 1))
  {
    if (!_el_w2mb(_el_line_buffer, &rl_line_buffer))
    {
      return -1;
    }
    replace_history_entry(where_history(), rl_line_buffer, null);
    next_history();
    _el_display_history();
  }

  return 0;
}

int _el_display_first_hist()
{
  if (where_history() > 0)
  {
    if (!_el_w2mb(_el_line_buffer, &rl_line_buffer))
    {
      return -1;
    }
    replace_history_entry(where_history(), rl_line_buffer, null);
    while (previous_history()){

    }
    _el_display_history();
  }

  return 0;
}

int _el_display_last_hist()
{
  if (where_history() < (history_length() - 1))
  {
    if (!_el_w2mb(_el_line_buffer, &rl_line_buffer))
    {
      return -1;
    }
    replace_history_entry(where_history(), rl_line_buffer, null);
    history_set_pos(history_length() - 1);
    _el_display_history();
  }

  return 0;
}

wchar_t* _el_mb2w(char* mb, wchar_t** w)
{
  int len_w;

  len_w = MultiByteToWideChar(CP_UTF8, 0, mb, -1, null, 0);
  *w = cast(wchar_t*)realloc(*w, len_w * wchar_t.sizeof);
  if (*w)
  {
    MultiByteToWideChar(CP_UTF8, 0, mb, -1, *w, len_w);
  }

  return *w;
}

char* _el_w2mb(wchar_t* w, char** mb)
{
  int len_mb;

  len_mb = WideCharToMultiByte(CP_UTF8, 0, w, -1, null, 0, null, null);
  *mb = cast(char*) realloc(*mb, len_mb);
  if (*mb)
  {
    WideCharToMultiByte(CP_UTF8, 0, w, -1, *mb, len_mb, null, null);
  }

  return *mb;
}

char** _el_alloc_array(int n, int size)
{
  char** array;
  int i;
  array = cast(char**) malloc((n + 1) * (char*).sizeof);
  if (!array)
  {
    return null;
  }
  memset(array, 0, (n + 1) * (char*).sizeof);
  for (i = 0; i < n; ++i)
  {
    (array[i] = cast(char*) malloc(size));
    if (!array[i])
    {
      _el_free_array(array);
      return NULL;
    }
    memset(array[i], 0, size);
  }

  return array;
}

@nogc void _el_free_array(void* array)
{
  int i = 0;

  if (array)
  {
    while ((cast(char**) array)[i])
    {
      free((cast(char**) array)[i]);
      (cast(char**) array)[i] = NULL;
      ++i;
    }
    free(array);
  }
}

/*
catch CTRL+C signals
*/
extern(Windows) @nogc BOOL _el_signal_handler(DWORD fdwCtrlType)
{
  _el_ctrl_c_pressed = FALSE;
  switch (fdwCtrlType)
  {
  case CTRL_C_EVENT:
  case CTRL_BREAK_EVENT:
    if (_el_line_buffer)
    { // && wcslen(_el_line_buffer)
      _el_ctrl_c_pressed = TRUE;
    }
    else
    {
      _el_clean_exit();
    }
    break;
  default:
    break;
  }
  return _el_ctrl_c_pressed;
}

/**
free memory buffers before exit
*/
@nogc void _el_clean_exit()
{
  if (rl_line_buffer)
  {
    free(rl_line_buffer);
    rl_line_buffer = null;
  }
  if (_el_line_buffer)
  {
    free(_el_line_buffer);
    _el_line_buffer = null;
  }
  if (_el_compl_array)
  {
    _el_free_array(_el_compl_array);
    _el_compl_array = null;
  }
  if (_el_print)
  {
    free(_el_print);
    _el_print = null;
  }
  if (_el_temp_print)
  {
    free(_el_temp_print);
    _el_temp_print = null;
  }
  if (_el_next_compl)
  {
    free(_el_next_compl);
    _el_next_compl = null;
  }
  if (_el_completer_word_break_characters)
  {
    free(_el_completer_word_break_characters);
    _el_completer_word_break_characters = null;
  }
  if (_el_basic_word_break_characters)
  {
    free(_el_basic_word_break_characters);
    _el_basic_word_break_characters = null;
  }
  if (rl_prompt)
  {
    free(rl_prompt);
    rl_prompt = null;
  }
  if (_el_old_arg)
  {
    free(_el_old_arg);
    _el_old_arg = null;
  }
  if (_el_wide)
  {
    free(_el_wide);
    _el_wide = null;
  }
  if (_el_text)
  {
    free(_el_text);
    _el_text = null;
  }
  if (_el_text_mb)
  {
    free(_el_text_mb);
    _el_text_mb = null;
  }
  if (_el_file_name)
  {
    free(_el_file_name);
    _el_file_name = null;
  }
  if (_el_dir_name)
  {
    free(_el_dir_name);
    _el_dir_name = null;
  }
  if (_el_prev_in_cm_saved)
  {
    SetConsoleMode(_el_h_in, _el_prev_in_cm | ENABLE_EXTENDED_FLAGS);
  }
  if (_el_prev_out_cm_saved)
  {
    SetConsoleMode(_el_h_out, _el_prev_out_cm);
  }
  SetConsoleCtrlHandler(cast(PHANDLER_ROUTINE)&_el_signal_handler, FALSE);
}

/**
insert character(s) on the command line
*/
int _el_insert_char(wchar_t* buf, int n)
{
  int c;
  int eff_n;
  int line_len;

  line_len = cast(int) wcslen(_el_line_buffer);
  /*
  get line length from the current
  logical cursor position
  to the end, including the terminal '\0'
  */
  c = cast(int) wcslen(&(_el_line_buffer[rl_point])) + 1;
  eff_n = n;
  /*
  if the buffer is not large enough, cut down
  the number of inserted chars
  */
  if ((line_len + n) >= _EL_BUF_LEN)
  {
    eff_n = _EL_BUF_LEN - line_len - 1;
  }
  /*
  make the insertion
  */
  memmove(&_el_line_buffer[rl_point + eff_n], &_el_line_buffer[rl_point], c * (wchar_t).sizeof);
  memcpy(&_el_line_buffer[rl_point], buf, eff_n * (wchar_t).sizeof);
  /*
  copy the inserted chars into the string
  for subsequent printing
  */
  memcpy(_el_print, &_el_line_buffer[rl_point], (c + eff_n) * (wchar_t).sizeof);
  _el_print[c + eff_n] = '\0';
  /*
  set the new logical cursor position
  */
  rl_point += eff_n;
  /*
  print the insertion
  */
  if (_el_print_string(_el_print))
  {
    return -1;
  }
  /*
  set the new cursor position
  */
  if (_el_set_cursor(eff_n))
  {
    return -1;
  }
  if (!_el_w2mb(_el_line_buffer, &rl_line_buffer))
  {
    return -1;
  }

  return 0;
}

/**
delete character(s) on the command line
*/
int _el_delete_char(UINT32 vk, int n)
{
  int c;
  int line_len;
  int eff_n;

  line_len = cast(int) wcslen(_el_line_buffer);
  eff_n = n;
  switch (vk)
  {
  case VK_DELETE:
    /*
    the character in correspondence
    of the cursor is to be deleted;
    check that we are not going to delete
    more characters than those which exist
    between the logical cursor position
    and the end of line
    */
    if ((line_len - rl_point) < n)
    {
      eff_n = line_len - rl_point;
    }

    break;

  case VK_BACK:
    /*
    the character before
    the cursor is to be deleted
    check that we are not going to delete
    more characters than those which exist
    between the logical cursor position
    and the beginning of line
    */
    if ((rl_point - n) >= 0)
    {
      rl_point -= n;
    }
    else
    {
      eff_n = rl_point;
      rl_point = 0;
    }
    /*
    with backspace we need to reposition
    the cursor as well
    */
    if (_el_set_cursor(-eff_n))
    {
      return -1;
    }
    break;

  default:
    return -1;
  }
  c = cast(int) wcslen(&_el_line_buffer[rl_point]) + 1;
  /*
  cut out deleted characters
  */
  memmove(&_el_line_buffer[rl_point], &_el_line_buffer[rl_point + eff_n],
      (c - eff_n) * (wchar_t).sizeof);
  /*
  copy the characters from the current cursor
  position to end of line in a string
  */
  memcpy(_el_print, &_el_line_buffer[rl_point], (c - eff_n) * (wchar_t).sizeof);
  _el_print[c - eff_n] = '\0';
  /*
  add spaces to the string to be printed
  to clear out "tails" from the command line
  */
  _el_add_char(_el_print, ' ', n);
  if (!_el_w2mb(_el_line_buffer, &rl_line_buffer))
  {
    return -1;
  }

  /*
  print out and goodbye
  */
  return _el_print_string(_el_print);
}

/**
add n characters to a string
*/
void _el_add_char(wchar_t* str, wchar_t c, int n)
{
  int i;
  int len;

  len = cast(int) wcslen(str);
  for (i = 0; i < n; ++i)
  {
    str[len + i] = c;
  }
  str[len + n] = '\0';
}

int _el_pad(CONSOLE_SCREEN_BUFFER_INFO* sbInfo, wchar_t* strng)
{
  int i;

  i = cast(int) wcslen(strng);
  if (i)
  {
    while (i < (sbInfo.dwSize.X - sbInfo.dwCursorPosition.X))
    {
      strng[i] = (' ');
      ++i;
    }
    strng[i] = ('\0');
  }

  return i;
}

/**
print a string to the Windows Console
*/
int _el_print_string(wchar_t* strng)
{
  int i;
  int len;
  int tail_lines;
  int padded_len;
  int c_first_line;
  int c_last_line;
  int dy;
  DWORD n_chars;
  SHORT x_initial;
  COORD temp_coord;
  CONSOLE_SCREEN_BUFFER_INFO sbInfo;
  int width;

  len = cast(int) wcslen(strng);
  /*
  get screen buffer info from the current console
  */
  if (!GetConsoleScreenBufferInfo(_el_h_out, &sbInfo))
  {
    return -1;
  }
  /*
  record the initial x coordinate of the cursor
  */
  x_initial = sbInfo.dwCursorPosition.X;
  /*
  compute the current visible console width
  */
  width = sbInfo.srWindow.Right - sbInfo.srWindow.Left + 1;
  /*
  count how many characters will fit from the current
  cursor position to the right console margin
  */
  c_first_line = sbInfo.srWindow.Right - sbInfo.dwCursorPosition.X + 1;
  tail_lines = cast(int) wcslen(&_el_line_buffer[rl_point]) / width;
  /*
  if the visible console width is not enough,
  we will write dy full lines
  */
  if (len > c_first_line)
  {
    dy = (len - c_first_line) / width;
    /*
    these are the residual characters which will
    be printed on the last line
    */
    c_last_line = len - c_first_line - dy * width;
    /*
    if the string will not fit on the first line
    pad with spaces then print it
    */
    wcsncpy_s(_el_temp_print, _el_temp_print_size, strng, c_first_line);
    _el_temp_print[c_first_line] = ('\0');
    padded_len = _el_pad(&sbInfo, _el_temp_print);
    if ((sbInfo.dwCursorPosition.Y - tail_lines) >= sbInfo.dwSize.Y)
    {
      printf("\n");
      --(sbInfo.dwCursorPosition.Y);
      if (!SetConsoleCursorPosition(_el_h_out, sbInfo.dwCursorPosition))
      {
        return -1;
      }
    }
    if (!WriteConsole(_el_h_out, _el_temp_print, padded_len, &n_chars, null))
    {
      return -1;
    }
    printf("\n");
    for (i = 0; i < dy; ++i)
    {
      wcsncpy_s(_el_temp_print, _el_temp_print_size, &strng[c_first_line + i * width], width);
      _el_temp_print[width] = ('\0');
      padded_len = _el_pad(&sbInfo, _el_temp_print);
      if ((sbInfo.dwCursorPosition.Y - tail_lines) >= sbInfo.dwSize.Y)
      {
        printf("\n");
        --(sbInfo.dwCursorPosition.Y);
        if (!SetConsoleCursorPosition(_el_h_out, sbInfo.dwCursorPosition))
        {
          return -1;
        }
      }
      if (!WriteConsole(_el_h_out, _el_temp_print, padded_len, &n_chars, null))
      {
        return -1;
      }
      printf("\n");
    }
    /*
    if there are residual characters on the last line
    */
    if (c_last_line >= 0)
    {
      /*
      get the current cursor position
      */
      if (!GetConsoleScreenBufferInfo(_el_h_out, &sbInfo))
      {
        return -1;
      }
      /*
      record the current cursor position
      */
      memcpy(&temp_coord, &(sbInfo.dwCursorPosition), COORD.sizeof);
      /*
      set the cursor to the beginning of the line
      */
      sbInfo.dwCursorPosition.X = 0;
      if (!SetConsoleCursorPosition(_el_h_out, sbInfo.dwCursorPosition))
      {
        return -1;
      }
      /*
      write the residual characters
      */
      wcsncpy_s(_el_temp_print, _el_temp_print_size,
          &strng[c_first_line + dy * width], c_last_line);
      _el_temp_print[c_last_line] = '\0';
      padded_len = _el_pad(&sbInfo, _el_temp_print);
      if ((sbInfo.dwCursorPosition.Y - tail_lines) >= sbInfo.dwSize.Y)
      {
        printf("\n");
        --(sbInfo.dwCursorPosition.Y);
        --(temp_coord.Y);
        if (!SetConsoleCursorPosition(_el_h_out, sbInfo.dwCursorPosition))
        {
          return -1;
        }
      }
      if (!WriteConsole(_el_h_out, _el_temp_print, padded_len, &n_chars, NULL))
      {
        return -1;
      }
      /*
      put the cursor back into the position
      it occupied before printing
      */
      memcpy(&(sbInfo.dwCursorPosition), &temp_coord, COORD.sizeof);
      if (!SetConsoleCursorPosition(_el_h_out, sbInfo.dwCursorPosition))
      {
        return -1;
      }
    }
    /*
    put the cursor back into the position
    it occupied before printing
    */
    sbInfo.dwCursorPosition.Y -= cast(SHORT)(dy + 1);
    sbInfo.dwCursorPosition.X = x_initial;
    if (!SetConsoleCursorPosition(_el_h_out, sbInfo.dwCursorPosition))
    {
      return -1;
    }
  }
  else
  {
    /*
    if the whole string will fit on the first line
    without need to wrap, record current
    cursor coordinates
    */
    memcpy(&temp_coord, &(sbInfo.dwCursorPosition), (COORD).sizeof);
    /*
    write out the string
    */
    wcscpy_s(_el_temp_print, _el_temp_print_size, strng);
    padded_len = _el_pad(&sbInfo, _el_temp_print);
    if (!WriteConsoleW(_el_h_out, _el_temp_print, padded_len, &n_chars, null))
    {
      return -1;
    }
    /*
    put the cursor back into the position
    it occupied before printing
    */
    memcpy(&(sbInfo.dwCursorPosition), &temp_coord, (COORD).sizeof);
    if (!SetConsoleCursorPosition(_el_h_out, sbInfo.dwCursorPosition))
    {
      return -1;
    }
  }

  return 0;
}

/*
move the cursor
*/
int _el_move_cursor(UINT32 vk, UINT32 ctrl)
{
  int len;
  int offset = 0;
  int first = 0;

  len = cast(int) wcslen(_el_line_buffer);
  switch (vk)
  {
  case VK_LEFT:
    /*
    if the user wants to go left
    and we are already at the beginning
    of the line, then do nothing
    */
    if (!rl_point)
    {
      return 0;
    }
    /*
    if the user wants to move left
    characterwise, go back one character
    with both the physical and the logical
    cursors
    */
    if (!ctrl)
    {
      offset = -1;
      --rl_point;
    }
    else
    {
      /*
      if the user wants to move left
      wordwise, first move left to the first
      alphanumeric character, checking if
      beginning of line has been reached
      */
      while (rl_point && (!iswalnum(_el_line_buffer[rl_point])))
      {
        --rl_point;
        --offset;
      }
      /*
      move to the beginning of the word
      */
      first = 0;
      while (rl_point && (iswalnum(_el_line_buffer[rl_point - 1]) || (!first)))
      {
        ++first;
        --rl_point;
        --offset;
      }
    }
    break;

  case VK_RIGHT:
    /*
    if the user wants to go right
    and we are already at the end
    of the line, then do nothing
    */
    if (rl_point == len)
    {
      return 0;
    }
    /*
    if the user wants to move right
    characterwise, go ahead one character
    with both the physical and the logical
    cursors
    */
    if (!ctrl)
    {
      offset = 1;
      ++rl_point;
    }
    else
    {
      /*
      if the user wants to move right
      wordwise, first move right to the first
      alphanumeric character, checking if
      end of line has been reached
      */
      while ((rl_point < len) && (!iswalnum(_el_line_buffer[rl_point])))
      {
        ++rl_point;
        ++offset;
      }
      /*
      move to the end of the word
      */
      first = 0;
      while ((rl_point < len) && (iswalnum(_el_line_buffer[rl_point]) || (!first)))
      {
        ++first;
        ++rl_point;
        ++offset;
      }
    }
    break;

  case VK_HOME:
    /*
    move to the beginning of line
    */
    offset = (rl_point ? -rl_point : 0);
    rl_point = 0;
    break;

  case VK_END:
    /*
    move to the end of line
    */
    offset = len - rl_point;
    rl_point = len;
    break;

  default:
    return -1;
  }

  /*
  set the physical cursor position
  */
  return (offset ? _el_set_cursor(offset) : 0);
}

/*
set the physical cursor position
*/
int _el_set_cursor(int offset)
{
  if (!offset)
    return 0;
  CONSOLE_SCREEN_BUFFER_INFO sbInfo;
  int width;
  int old_x;
  int dx;
  int dy = 0;
  int c_first_line;

  /*
  get screen buffer info from the current console
  */
  if (!GetConsoleScreenBufferInfo(_el_h_out, &sbInfo))
  {
    return -1;
  }
  /*
  compute the current visible console width
  */
  width = sbInfo.srWindow.Right - sbInfo.srWindow.Left + 1;
  dx = offset;
  /*
  if the cursor has to be moved rightwards
  */
  if (offset > 0)
  {
    /*
    count how many characters exist
    before the right margin
    */
    c_first_line = sbInfo.srWindow.Right + 1 - sbInfo.dwCursorPosition.X;

    /*
    if the cursor needs to be moved further,
    move to the next line(s)
    */
    if (offset >= c_first_line)
    {
      dy = (offset - c_first_line) / width + 1;
    }
    dx = offset - dy * width;
  }
  else if (offset < 0)
  {
    /*
    count how many characters exist
    before the left margin
    */
    c_first_line = sbInfo.dwCursorPosition.X - sbInfo.srWindow.Left + 1;
    /*
    if the cursor needs to be moved further,
    move to the previous line(s)
    */
    if (-offset >= c_first_line)
    {
      dy = (offset + c_first_line) / width - 1;
    }
    dx = offset - dy * width;
  }
  /*
  set the new physical cursor position
  */
  if ((sbInfo.dwCursorPosition.Y + dy - (
      cast(int) wcslen( & _el_line_buffer[rl_point]) / width)) >= sbInfo.dwSize.Y)
  {
    printf("\n");
    --dy;
    old_x = sbInfo.dwCursorPosition.X;
    if (!GetConsoleScreenBufferInfo(_el_h_out, &sbInfo))
    {
      return -1;
    }
    sbInfo.dwCursorPosition.X = cast(SHORT) old_x;
  }
  sbInfo.dwCursorPosition.X += cast(SHORT) dx;
  sbInfo.dwCursorPosition.Y += cast(SHORT) dy;

  return (SetConsoleCursorPosition(_el_h_out, sbInfo.dwCursorPosition) ? 0 : 1);
}

/*
check if characters already entered
by the user match the beginning of the
directory entry. If no characters have been
entered yet, then it is necessarily matching
*/
int _el_check_root_identity(wchar_t* root, wchar_t* entry_name)
{
  int len;
  int result = 1;
  int open_quote;
  int close_quote;

  if (root)
  {
    len = cast(int) wcslen(root);
    if (len)
    {
      open_quote = ((root[0] == '\"') ? 1 : 0);
      close_quote = ((root[len - 1] == '\"') ? 1 : 0);
      result = ((_wcsnicmp(&root[open_quote], entry_name, len - close_quote)) ? 0 : 1);
    }
  }

  return result;
}

/**
compare function for qsort
*/
int _el_fn_qsort_string_compare(const void* i1, const void* i2)
{
  const wchar_t * s1 = cast(const wchar_t * ) * cast(const wchar_t *  * ) i1;
  const wchar_t * s2 = cast(const wchar_t * ) * cast(const wchar_t *  * ) i2;

  return wcscmp(s1, s2);
}

/*
function to free memory allocated by readline()
this is to avoid problems using free() whenever
memory is not freed by the same module which
previously allocated it (especially when, e.g.,
the DLL was built with VS and the application with
GCC, or viceversa)
*/
void rl_free(void* mem)
{
  free(mem);
}

int isInConsole()
{
  _el_h_in = GetStdHandle(STD_INPUT_HANDLE);
  DWORD count = 0;
  INPUT_RECORD irBuffer;
  if (!PeekConsoleInput(_el_h_in, &irBuffer, 1, &count))
  {
    return 0;
  }
  return 1;
}

struct ReadlineState
{
  wchar_t[_EL_CONSOLE_BUF_LEN] buf;
  char** array;
  char* ret_string;
  int start;
  int end;
  int compl_pos;
  int index;
  int len;
  int line_len;
  int old_width;
  int width;
  UINT32 ctrl;
  UINT32 special;
  COORD coord;
  DWORD count;
  INPUT_RECORD irBuffer;

}


/* readline splitting : init part, returns nonzero if success */
void ReadlineState_init(ReadlineState* pthis)
{
  pthis.array = null;
  pthis.ret_string = null;
  pthis.start = 0;
  pthis.end = 0;
  pthis.compl_pos = -1;
  pthis.index = 0;
  pthis.len = 0;
  pthis.line_len = 0;
  pthis.old_width = 0;
  pthis.width = 0;
  pthis.ctrl = 0;
  pthis.special = 0;
  pthis.count = 0;

  /* init globals */
  _el_ctrl_c_pressed = FALSE;
  _el_line_buffer = null;
  _el_temp_print = null;
  _el_next_compl = null;
  rl_line_buffer = null;
  _el_file_name = null;
  _el_dir_name = null;
  _el_old_arg = null;
  _el_wide = null;
  _el_text = null;
  _el_text_mb = null;
  _el_compl_array = null;
  _el_completer_word_break_characters = null;
  rl_point = 0;
  rl_attempted_completion_over = 0;
  _el_compl_index = 0;
  _el_n_compl = 0;
  _el_h_in = null;
  _el_h_out = null;
  wcscpy_s(_el_basic_file_break_characters.ptr, _EL_MAX_FILE_BREAK_CHARACTERS,
      _EL_BASIC_FILE_BREAK_CHARACTERS.ptr);
  memset(&pthis.coord, 0, (COORD).sizeof);
  memset(pthis.buf.ptr, 0, _EL_CONSOLE_BUF_LEN * (wchar_t).sizeof);
  memset(&pthis.irBuffer, 0, (INPUT_RECORD).sizeof);
}

/** readline splitting : init part, returns nonzero if success */
int ReadlineState_prepare(ReadlineState* pthis, const char* prompt)
{
  /*
	allocate buffers
	*/
  _el_line_buffer_size = _EL_BUF_LEN + 1;
  _el_line_buffer = cast(wchar_t*) malloc(_el_line_buffer_size * (wchar_t).sizeof);
  if (!_el_mb2w(cast(char*) rl_basic_word_break_characters, &_el_basic_word_break_characters))
  {
    _el_clean_exit();
    return ReadLineResult.READLINE_ERROR;
  }
  if (rl_completer_word_break_characters)
  {
    if (!_el_mb2w(cast(char*) rl_completer_word_break_characters,
        &_el_completer_word_break_characters))
    {
      _el_clean_exit();
      return ReadLineResult.READLINE_ERROR;
    }
  }
  if (!(_el_line_buffer))
  {
    _el_clean_exit();
    return ReadLineResult.READLINE_ERROR;
  }
  memset(_el_line_buffer, 0, _el_line_buffer_size * (wchar_t).sizeof);
  rl_attempted_completion_over = 0;
  _el_print = cast(wchar_t*) malloc(_el_line_buffer_size * (wchar_t.sizeof));
  if (!(_el_print))
  {
    _el_clean_exit();
    return ReadLineResult.READLINE_ERROR;
  }
  memset(_el_print, 0, _el_line_buffer_size * (wchar_t.sizeof));
  rl_prompt = strdup(prompt);//modified from _strdup
  if (!(rl_prompt))
  {
    _el_clean_exit();
    return ReadLineResult.READLINE_ERROR;
  }
  if (!_el_mb2w(cast(char*) prompt, &_el_prompt))
  {
    _el_clean_exit();
    return ReadLineResult.READLINE_ERROR;
  }
  _el_prompt_len = cast(int) wcslen(_el_prompt);
  /*
	get I/O handles for current console
	*/
  _el_h_in = GetStdHandle(STD_INPUT_HANDLE);
  _el_h_out = GetStdHandle(STD_OUTPUT_HANDLE);
  if ((!(_el_h_in)) || (!(_el_h_out)))
  {
    _el_clean_exit();
    return ReadLineResult.READLINE_ERROR;
  }
  /*
	set console modes
	*/
  _el_prev_in_cm_saved = GetConsoleMode(_el_h_in, &_el_prev_in_cm);
  _el_prev_out_cm_saved = GetConsoleMode(_el_h_out, &_el_prev_out_cm);
  SetConsoleMode(_el_h_in,
      ENABLE_PROCESSED_INPUT | ENABLE_EXTENDED_FLAGS | ENABLE_INSERT_MODE | ENABLE_QUICK_EDIT_MODE);
  SetConsoleMode(_el_h_out, ENABLE_PROCESSED_OUTPUT);
  SetConsoleCtrlHandler(cast(PHANDLER_ROUTINE)&_el_signal_handler, TRUE);
  //_setmode(_fileno(stdout), _O_U16TEXT);
  rl_point = 0;

  //SetConsoleCP(CP_UTF8);
  //SetConsoleOutputCP(CP_UTF8);

  return 1;
}

/** readline splitting : init part, returns nonzero if success */
int ReadlineState_poll(ReadlineState* pthis, wchar_t** ret_string, int was_interrupted)
{
  int n;
  CONSOLE_SCREEN_BUFFER_INFO sbInfo;

  if (!_el_line_buffer)
  {
    return ReadLineResult.READLINE_ERROR;
  }
  *ret_string = NULL;
  while ((pthis.buf[0] != VK_RETURN) && (!_el_ctrl_c_pressed) && _el_line_buffer)
  {
    /*
		get screen buffer info from the current console
		*/
    if (!GetConsoleScreenBufferInfo(_el_h_out, &sbInfo))
    {
      _el_clean_exit();
      return ReadLineResult.READLINE_ERROR;
    }
    _el_temp_print_size = sbInfo.dwSize.X + 1;
    _el_temp_print = cast(wchar_t*) realloc(_el_temp_print,
        _el_temp_print_size * (wchar_t.sizeof));
    if (!_el_temp_print)
    {
      _el_clean_exit();
      return ReadLineResult.READLINE_ERROR;
    }
    _el_temp_print[0] = ('\0');
    /*
		compute the current visible console width
		*/
    pthis.width = sbInfo.srWindow.Right - sbInfo.srWindow.Left + 1;
    /*
		if the user has changed the window size
		update the view
		*/
    if (pthis.old_width != pthis.width || was_interrupted)
    {
      pthis.line_len = cast(int) wcslen(_el_line_buffer);
      sbInfo.dwCursorPosition.X = 0;
      if (pthis.old_width && !was_interrupted)
      {
        n = (_el_prompt_len + pthis.line_len - 1) / pthis.old_width;
        sbInfo.dwCursorPosition.Y -= cast(SHORT) n;
        pthis.coord.Y = sbInfo.dwCursorPosition.Y;
      }
      if (!SetConsoleCursorPosition(_el_h_out, sbInfo.dwCursorPosition))
      {
        _el_clean_exit();
        return ReadLineResult.READLINE_ERROR;
      }
      if (_el_print_string(_el_prompt))
      {
        _el_clean_exit();
        return ReadLineResult.READLINE_ERROR;
      }
      if (_el_set_cursor(_el_prompt_len))
      {
        _el_clean_exit();
        return ReadLineResult.READLINE_ERROR;
      }
      if (_el_print_string(_el_line_buffer))
      {
        _el_clean_exit();
        return ReadLineResult.READLINE_ERROR;
      }
      if (_el_set_cursor(pthis.line_len))
      {
        _el_clean_exit();
        return ReadLineResult.READLINE_ERROR;
      }
      if (pthis.old_width && (pthis.old_width < pthis.width))
      {
        pthis.coord.X = 0;
        pthis.coord.Y += cast(SHORT)((_el_prompt_len + pthis.line_len - 1) / pthis.width + 1);
        FillConsoleOutputCharacter(_el_h_out, (' '), sbInfo.dwSize.X * (n + 2),
            pthis.coord, &pthis.count);
      }
      if (_el_set_cursor(rl_point - pthis.line_len))
      { //  
        _el_clean_exit();
        return ReadLineResult.READLINE_ERROR;
      }
    }
    pthis.old_width = pthis.width;
    /*
		wait for console events
		*/

    if (!PeekConsoleInput(_el_h_in, &pthis.irBuffer, 1, &pthis.count))
    {
      _el_clean_exit();
      return ReadLineResult.READLINE_ERROR;
    }
    if (pthis.count)
    {
      if ((pthis.irBuffer.EventType == KEY_EVENT) && pthis.irBuffer.Event.KeyEvent.bKeyDown)
      {
        /*
				the user pressed a key
				*/
        pthis.ctrl = (pthis.irBuffer.Event.KeyEvent.dwControlKeyState & (
            LEFT_CTRL_PRESSED | RIGHT_CTRL_PRESSED));
        if (pthis.irBuffer.Event.KeyEvent.uChar.UnicodeChar == '\n')
        {
          if (!ReadConsoleInput(_el_h_in, &pthis.irBuffer, 1, &pthis.count))
          {
            _el_clean_exit();
            return ReadLineResult.READLINE_ERROR;
          }
          pthis.buf[0] = VK_RETURN;
          continue;
        }
        if (pthis.irBuffer.Event.KeyEvent.uChar.UnicodeChar == '\0')
        {
          /*
					if it is a special key, just remove it from the buffer
					*/
          if (!ReadConsoleInput(_el_h_in, &pthis.irBuffer, 1, &pthis.count))
          {
            _el_clean_exit();
            return ReadLineResult.READLINE_ERROR;
          }
          pthis.special = pthis.irBuffer.Event.KeyEvent.wVirtualKeyCode;
          /*
					parse the special key
					*/
          switch (pthis.special)
          {
            /*
						arrow left, arrow right
						HOME and END keys
						*/
          case VK_LEFT:
          case VK_RIGHT:
          case VK_HOME:
          case VK_END:
            if (_el_move_cursor(pthis.special, pthis.ctrl))
            {
              _el_clean_exit();
              return ReadLineResult.READLINE_ERROR;
            }
            break;

            /*
						arrow up: display previous history element (if any)
						after recording the current command line
						*/
          case VK_UP:
            if (_el_display_prev_hist())
            {
              _el_clean_exit();
              return ReadLineResult.READLINE_ERROR;
            }
            break;

            /*
						page up: display the first history element (if any)
						after recording the current command line
						*/
          case VK_PRIOR:
            if (_el_display_first_hist())
            {
              _el_clean_exit();
              return ReadLineResult.READLINE_ERROR;
            }
            break;

            /*
						arrow down: display next history element (if any)
						after recording the current command line
						*/
          case VK_DOWN:
            if (_el_display_next_hist())
            {
              _el_clean_exit();
              return ReadLineResult.READLINE_ERROR;
            }
            break;

          case VK_NEXT:
            /*
						page down: display last history element (if any)
						after recording the current command line
						*/
            if (_el_display_last_hist())
            {
              _el_clean_exit();
              return ReadLineResult.READLINE_ERROR;
            }
            break;

            /*
						delete char
						*/
          case VK_DELETE:
            if (rl_point != wcslen(_el_line_buffer))
            {
              if (_el_delete_char(VK_DELETE, 1))
              {
                _el_clean_exit();
                return ReadLineResult.READLINE_ERROR;
              }
              _el_compl_index = 0;
              pthis.compl_pos =  - 1;
            }
            break;
            default:
            break;
          }
        }
        else
        {
          /*
					if it is a normal key, remove it from the buffer
					*/
          memset(pthis.buf.ptr, 0, _EL_CONSOLE_BUF_LEN * (wchar_t.sizeof));
          if (!ReadConsole(_el_h_in, pthis, 1, &pthis.count, null))
          {
            _el_clean_exit();
            return ReadLineResult.READLINE_ERROR;
          }
          /*
					then parse it
					*/
          switch (pthis.buf[0])
          {
            /*
						backspace
						*/
          case VK_BACK:
            if (rl_point)
            {
              _el_compl_index = 0;
              pthis.compl_pos = -1;
              if (_el_delete_char(VK_BACK, 1))
              {
                _el_clean_exit();
                return ReadLineResult.READLINE_ERROR;
              }
            }
            break;

            /*
						TAB: do completion
						*/
          case VK_TAB:
            if ((!pthis.array) || (rl_point != pthis.compl_pos))
            {
              _el_free_array(pthis.array);
              pthis.index = 0;
              if (_el_text)
              {
                free(_el_text);
                _el_text = NULL;
              }
              _el_text = _el_get_compl_text(&pthis.start, &pthis.end);
              if (!_el_text)
              {
                _el_clean_exit();
                return ReadLineResult.READLINE_ERROR;
              }
              if (_el_old_arg)
              {
                _el_old_arg[0] = ('\0');
              }
              if (!_el_w2mb(_el_text, &_el_text_mb))
              {
                _el_clean_exit();
                return ReadLineResult.READLINE_ERROR;
              }
              if (!_el_w2mb(_el_line_buffer, &rl_line_buffer))
              {
                _el_clean_exit();
                return ReadLineResult.READLINE_ERROR;
              }
              /*pthis.array = (rl_attempted_completion_function !is null
                  ? rl_attempted_completion_function(_el_text_mb, pthis.start, pthis.end)
                  : rl_completion_matches(_el_text_mb,
                    (rl_completion_entry_function !is null ? &rl_completion_entry_function
                    : &rl_filename_completion_function)));*/
              if(rl_attempted_completion_function !is null){
                pthis.array = rl_attempted_completion_function(_el_text_mb, pthis.start, pthis.end);
              }else{
                if(rl_completion_entry_function !is null)
                  pthis.array = rl_completion_matches(_el_text_mb, rl_completion_entry_function);
                else
                  pthis.array = rl_completion_matches(_el_text_mb, rl_filename_completion_function);
              }
              if (!pthis.array)
              {
                _el_clean_exit();
                return ReadLineResult.READLINE_ERROR;
              }
            }
            if (!pthis.array[pthis.index])
            {
              pthis.index = 0;
            }
            if (pthis.array[pthis.index])
            {
              if (!_el_mb2w(pthis.array[pthis.index], &_el_next_compl))
              {
                _el_clean_exit();
                return ReadLineResult.READLINE_ERROR;
              }
              pthis.len = 0;
              if (_el_old_arg)
              {
                pthis.len = cast(int) wcslen(_el_old_arg);
                /*#if 0
								fwprintf(stderr, _T("VK_TAB) _el_old_arg = '%s', len = %d\n"), _el_old_arg, len);
								fflush(stderr);
#endif*/
              }
              if (!pthis.len)
              {
                pthis.len = cast(int) wcslen(_el_text);
              }
              if (pthis.len)
              {
                if (_el_delete_char(VK_BACK, pthis.len))
                {
                  _el_clean_exit();
                  return ReadLineResult.READLINE_ERROR;
                }
              }
              pthis.len = cast(int) wcslen(_el_next_compl);
              if (!(_el_old_arg = cast(wchar_t*) realloc(_el_old_arg,
                  (pthis.len + 1) * (wchar_t.sizeof))))
              {
                return ReadLineResult.READLINE_ERROR;
              }
              _el_old_arg[pthis.len] = _T('\0');
              memcpy(_el_old_arg, _el_next_compl, pthis.len * (wchar_t.sizeof));
              pthis.line_len = cast(int) wcslen(_el_line_buffer);
              if (_el_insert_char(_el_next_compl, pthis.len))
              {
                _el_clean_exit();
                return ReadLineResult.READLINE_ERROR;
              }
              free(_el_next_compl);
              _el_next_compl = null;
              pthis.compl_pos = ((rl_point && (!wcschr(_el_completer_word_break_characters
                  ? _el_completer_word_break_characters
                  : _el_basic_word_break_characters, _el_line_buffer[rl_point - 1]))) ? rl_point
                  : -1);
              ++pthis.index;
            }
            break;

            /*
						ENTER: move the cursor to end of line,
						then return to the caller program
						*/
          case VK_RETURN:
            if (_el_set_cursor(cast(int) wcslen(_el_line_buffer) - rl_point))
            {
              _el_clean_exit();
              return ReadLineResult.READLINE_ERROR;
            }
            break;

            /*
						delete word
						*/
          case 0x17: /* CTRL + W */
            if (pthis.ctrl)
            {
              if (!rl_point)
              {
                break;
              }
              n = 1;
              while (((rl_point - n) > 0) && (iswspace(_el_line_buffer[rl_point - n])))
              {
                ++n;
              }
              while ((rl_point - n) && (!iswspace(_el_line_buffer[rl_point - n])))
              {
                ++n;
              }
              if (rl_point - n)
              {
                --n;
              }
              _el_compl_index = 0;
              pthis.compl_pos =  - 1;
              if (_el_delete_char(VK_BACK, n))
              {
                _el_clean_exit();
                return ReadLineResult.READLINE_ERROR;
              }
              break;
            }

            /*
						delete until end of line
						*/
          case 0x0B: /* CTRL + K */
            if (pthis.ctrl)
            {
              pthis.line_len = cast(int) wcslen(_el_line_buffer);
              if (rl_point < pthis.line_len)
              {
                _el_compl_index = 0;
                pthis.compl_pos = -1;
                if (_el_delete_char(VK_DELETE, pthis.line_len - rl_point))
                {
                  _el_clean_exit();
                  return ReadLineResult.READLINE_ERROR;
                }
              }
              break;
            }

            /*
						beginning-of-line
						*/
          case 0x01: /* CTRL + A */
            if (_el_move_cursor(VK_HOME, 0))
            {
              _el_clean_exit();
              return ReadLineResult.READLINE_ERROR;
            }
            break;

            /*
						end-of-line
						*/
          case 0x05: /* CTRL + E */
            if (_el_move_cursor(VK_END, 0))
            {
              _el_clean_exit();
              return ReadLineResult.READLINE_ERROR;
            }
            break;

            /*
						forward-char
						*/
          case 0x06: /* CTRL + F */
            if (_el_move_cursor(VK_RIGHT, 0))
            {
              _el_clean_exit();
              return ReadLineResult.READLINE_ERROR;
            }
            break;

            /*
						backward-char
						*/
          case 0x02: /* CTRL + B */
            if (_el_move_cursor(VK_LEFT, 0))
            {
              _el_clean_exit();
              return ReadLineResult.READLINE_ERROR;
            }
            break;

            /*
						previous-line
						*/
          case 0x10: /* CTRL + P */
            if (_el_display_prev_hist())
            {
              _el_clean_exit();
              return ReadLineResult.READLINE_ERROR;
            }
            break;

            /*
						next-line
						*/
          case 0x0E: /* CTRL + N */
            if (_el_display_next_hist())
            {
              _el_clean_exit();
              return ReadLineResult.READLINE_ERROR;
            }
            break;

            /*
						delete char
						*/
          case 0x04: /* CTRL + D */
            if (rl_point != wcslen(_el_line_buffer))
            {
              if (_el_delete_char(VK_DELETE, 1))
              {
                _el_clean_exit();
                return ReadLineResult.READLINE_ERROR;
              }
              _el_compl_index = 0;
              pthis.compl_pos = -1;
            }
            break;

            /*
						if it is a printable character, print it
						NOTE: I have later commented out the
						iswprint() check since for instance it
						prevents the euro sign from being printed
						*/
          default:
            /*if (iswprint(buf[0])) {*/
            _el_compl_index = 0;
            pthis.compl_pos = -1;
            if (_el_insert_char(pthis.buf, 1))
            {
              _el_clean_exit();
              return ReadLineResult.READLINE_ERROR;
            }
            /*}*/
          }
        }
      }
      /*
			if it was not a keyboard event, just remove it from buffer
			*/
    else if (!ReadConsoleInput(_el_h_in, &pthis.irBuffer, 1, &pthis.count))
      {
        _el_clean_exit();
        return ReadLineResult.READLINE_ERROR;
      }
    }
    else
    {
      /*
			wait for console input
			*/
      WaitForSingleObject(_el_h_in, 2); //INFINITE
    }
    if (pthis.buf[0] == VK_RETURN || _el_ctrl_c_pressed)
      break;
    if (!_el_line_buffer)
    {
      return ReadLineResult.READLINE_ERROR;
    }
    //*ret_string = _wcsdup(_el_line_buffer);
    //_el_clean_exit();
    return ReadLineResult.READLINE_IN_PROGRESS;
  }

  printf("\n");
  while (next_history()){

  }
  previous_history();
  /*
	if CTRL+C has been pressed, return NULL
	*/
  if (_el_ctrl_c_pressed)
  {
    /*
		n = (int)wcslen(_el_line_buffer) - rl_point;
		if (n) {
			_el_set_cursor(n);
		}
		*/
  }
  else
  {
    if (_el_line_buffer)
    {
      //_el_w2mb(_el_line_buffer, &rl_line_buffer);
       * ret_string = _wcsdup(_el_line_buffer);
    }
  }
  _el_clean_exit();
  return _el_ctrl_c_pressed ? ReadLineResult.READLINE_CTRL_C : ReadLineResult.READLINE_READY; // pthis->ret_string;
}

static ReadlineState read_line_state;
enum ReadLineResult {
	READLINE_ERROR,
	READLINE_IN_PROGRESS,
	READLINE_READY,
	READLINE_CTRL_C
}
static int _readline_new_is_interrupted = 0;
static int _readline_new_last_state = ReadLineResult.READLINE_READY;

void readline_interrupt()
{
  if (!_el_line_buffer)
    return;
  CONSOLE_SCREEN_BUFFER_INFO sbInfo;
  int cursor_y_offset = 0;
  int editor_lines = 1;
  COORD coord;
  DWORD count;
  _readline_new_is_interrupted = 1;
  if (_el_line_buffer)
  {
    // input in progress
    if (!GetConsoleScreenBufferInfo(_el_h_out, &sbInfo))
    {
      return;
    }
    int width = sbInfo.srWindow.Right - sbInfo.srWindow.Left + 1;
    cursor_y_offset = (_el_prompt_len + rl_point) / width;
    editor_lines = (_el_prompt_len + read_line_state.line_len) / width;

    sbInfo.dwCursorPosition.X = 0;
    sbInfo.dwCursorPosition.Y -= cursor_y_offset;

    SetConsoleCursorPosition(_el_h_out, sbInfo.dwCursorPosition);
    FillConsoleOutputCharacter(_el_h_out, ' ', width * (editor_lines + 2),
        sbInfo.dwCursorPosition, &count);
  }
}

int readline_poll(const char* prompt, wchar_t** result_string)
{
  *result_string = NULL;
  if (_readline_new_last_state != ReadLineResult.READLINE_IN_PROGRESS)
  {
    ReadlineState_init(&read_line_state);
    if (ReadlineState_prepare(&read_line_state, prompt) == ReadLineResult.READLINE_ERROR)
    {
      _readline_new_last_state = ReadLineResult.READLINE_ERROR;
      return ReadLineResult.READLINE_ERROR;
    }
  }
  _readline_new_last_state = ReadlineState_poll(&read_line_state,
      result_string, _readline_new_is_interrupted);
  _el_ctrl_c_pressed = 0;
  _readline_new_is_interrupted = 0;
  return _readline_new_last_state;
}

/*
main readline function
*/
char* readline(const char* prompt)
{
  wchar_t[_EL_CONSOLE_BUF_LEN] buf;
  char** array;
  char* ret_string;
  int start = 0;
  int end = 0;
  int compl_pos = -1;
  int n = 0;
  int index = 0;
  int len = 0;
  int line_len = 0;
  int old_width = 0;
  int width = 0;
  UINT32 ctrl = 0;
  UINT32 special = 0;
  COORD coord;
  DWORD count = 0;
  INPUT_RECORD irBuffer;
  CONSOLE_SCREEN_BUFFER_INFO sbInfo;

  _el_ctrl_c_pressed = FALSE;
  _el_line_buffer = NULL;
  _el_temp_print = NULL;
  _el_next_compl = NULL;
  rl_line_buffer = NULL;
  _el_file_name = NULL;
  _el_dir_name = NULL;
  _el_old_arg = NULL;
  _el_wide = NULL;
  _el_text = NULL;
  _el_text_mb = NULL;
  _el_compl_array = NULL;
  _el_completer_word_break_characters = NULL;
  rl_point = 0;
  rl_attempted_completion_over = 0;
  _el_compl_index = 0;
  _el_n_compl = 0;
  _el_h_in = NULL;
  _el_h_out = NULL;
  wcscpy_s(_el_basic_file_break_characters, _EL_MAX_FILE_BREAK_CHARACTERS,
      _EL_BASIC_FILE_BREAK_CHARACTERS);
  memset(&coord, 0, (COORD.sizeof));
  memset(buf, 0, _EL_CONSOLE_BUF_LEN * (wchar_t.sizeof));
  memset(&irBuffer, 0, (INPUT_RECORD.sizeof));
  /*
  allocate buffers
  */
  _el_line_buffer_size = _EL_BUF_LEN + 1;
  _el_line_buffer = cast(twchar_t*) malloc(_el_line_buffer_size * (wchar_t.sizeof));
  if (!_el_mb2w(cast(char*) rl_basic_word_break_characters,  & _el_basic_word_break_characters))
  {
    _el_clean_exit();
    return NULL;
  }
  if (rl_completer_word_break_characters)
  {
    if (!_el_mb2w(cast(char*) rl_completer_word_break_characters,
         & _el_completer_word_break_characters))
    {
      _el_clean_exit();
      return NULL;
    }
  }
  if (!(_el_line_buffer))
  {
    _el_clean_exit();
    return NULL;
  }
  memset(_el_line_buffer, 0, _el_line_buffer_size * (wchar_t.sizeof));
  rl_attempted_completion_over = 0;
  _el_print = cast(wchar_t*) malloc(_el_line_buffer_size * (wchar_t.sizeof));
  if (!(_el_print))
  {
    _el_clean_exit();
    return NULL;
  }
  memset(_el_print, 0, _el_line_buffer_size * (wchar_t.sizeof));
  rl_prompt = _strdup(prompt);
  if (!(rl_prompt))
  {
    _el_clean_exit();
    return NULL;
  }
  if (!_el_mb2w(cast(char*) prompt,  & _el_prompt))
  {
    _el_clean_exit();
    return NULL;
  }
  _el_prompt_len = cast(int)wcslen(_el_prompt);
  /*
  get I/O handles for current console
  */
  _el_h_in = GetStdHandle(STD_INPUT_HANDLE);
  _el_h_out = GetStdHandle(STD_OUTPUT_HANDLE);
  if ((!(_el_h_in)) || (!(_el_h_out)))
  {
    _el_clean_exit();
    return NULL;
  }
  /*
  set console modes
  */
  _el_prev_in_cm_saved = GetConsoleMode(_el_h_in, &_el_prev_in_cm);
  _el_prev_out_cm_saved = GetConsoleMode(_el_h_out, &_el_prev_out_cm);
  SetConsoleMode(_el_h_in,
      ENABLE_PROCESSED_INPUT | ENABLE_EXTENDED_FLAGS | ENABLE_INSERT_MODE | ENABLE_QUICK_EDIT_MODE);
  SetConsoleMode(_el_h_out, ENABLE_PROCESSED_OUTPUT);
  SetConsoleCtrlHandler(cast(PHANDLER_ROUTINE) _el_signal_handler, TRUE);
  rl_point = 0;
  while ((buf[0] != VK_RETURN) && (!_el_ctrl_c_pressed) && _el_line_buffer)
  {
    /*
    get screen buffer info from the current console
    */
    if (!GetConsoleScreenBufferInfo(_el_h_out, &sbInfo))
    {
      _el_clean_exit();
      return NULL;
    }
    _el_temp_print_size = sbInfo.dwSize.X + 1;
    if (!(_el_temp_print = cast(wchar_t*) realloc(_el_temp_print,
        _el_temp_print_size * (wchar_t.sizeof))))
    {
      _el_clean_exit();
      return NULL;
    }
    _el_temp_print[0] = ('\0');
    /*
    compute the current visible console width
    */
    width = sbInfo.srWindow.Right - sbInfo.srWindow.Left + 1;
    /*
    if the user has changed the window size
    update the view
    */
    if (old_width != width)
    {
      line_len = cast(int) wcslen(_el_line_buffer);
      sbInfo.dwCursorPosition.X = 0;
      if (old_width)
      {
        n = (_el_prompt_len + line_len - 1) / old_width;
        sbInfo.dwCursorPosition.Y -= cast(SHORT) n;
        coord.Y = sbInfo.dwCursorPosition.Y;
      }
      if (!SetConsoleCursorPosition(_el_h_out, sbInfo.dwCursorPosition))
      {
        _el_clean_exit();
        return NULL;
      }
      if (_el_print_string(_el_prompt))
      {
        _el_clean_exit();
        return NULL;
      }
      if (_el_set_cursor(_el_prompt_len))
      {
        _el_clean_exit();
        return NULL;
      }
      if (_el_print_string(_el_line_buffer))
      {
        _el_clean_exit();
        return NULL;
      }
      if (_el_set_cursor(line_len))
      {
        _el_clean_exit();
        return NULL;
      }
      if (old_width && (old_width < width))
      {
        coord.X = 0;
        coord.Y += cast(SHORT)((_el_prompt_len + line_len - 1) / width + 1);
        FillConsoleOutputCharacter(_el_h_out, (' '), sbInfo.dwSize.X * (n + 2), coord, &count);
      }
    }
    old_width = width;
    /*
    wait for console events
    */
    if (!PeekConsoleInput(_el_h_in, &irBuffer, 1, &count))
    {
      _el_clean_exit();
      return NULL;
    }
    if (count)
    {
      if ((irBuffer.EventType == KEY_EVENT) && irBuffer.Event.KeyEvent.bKeyDown)
      {
        /*
        the user pressed a key
        */
        ctrl = (irBuffer.Event.KeyEvent.dwControlKeyState & (LEFT_CTRL_PRESSED | RIGHT_CTRL_PRESSED));
        if (irBuffer.Event.KeyEvent.uChar.UnicodeChar == ('\n'))
        {
          if (!ReadConsoleInput(_el_h_in, &irBuffer, 1, &count))
          {
            _el_clean_exit();
            return NULL;
          }
          buf[0] = VK_RETURN;
          continue;
        }
        if (irBuffer.Event.KeyEvent.uChar.UnicodeChar == ('\0'))
        {
          /*
          if it is a special key, just remove it from the buffer
          */
          if (!ReadConsoleInput(_el_h_in, &irBuffer, 1, &count))
          {
            _el_clean_exit();
            return NULL;
          }
          special = irBuffer.Event.KeyEvent.wVirtualKeyCode;
          /*
          parse the special key
          */
          switch (special)
          {
            /*
            arrow left, arrow right 
            HOME and END keys
            */
          case VK_LEFT:
          case VK_RIGHT:
          case VK_HOME:
          case VK_END:
            if (_el_move_cursor(special, ctrl))
            {
              _el_clean_exit();
              return NULL;
            }
            break;

            /*
            arrow up: display previous history element (if any)
            after recording the current command line
            */
          case VK_UP:
            if (_el_display_prev_hist())
            {
              _el_clean_exit();
              return NULL;
            }
            break;

            /*
            page up: display the first history element (if any)
            after recording the current command line
            */
          case VK_PRIOR:
            if (_el_display_first_hist())
            {
              _el_clean_exit();
              return NULL;
            }
            break;

            /*
            arrow down: display next history element (if any)
            after recording the current command line
            */
          case VK_DOWN:
            if (_el_display_next_hist())
            {
              _el_clean_exit();
              return NULL;
            }
            break;

          case VK_NEXT:
            /*
            page down: display last history element (if any)
            after recording the current command line
            */
            if (_el_display_last_hist())
            {
              _el_clean_exit();
              return NULL;
            }
            break;

            /*
            delete char
            */
          case VK_DELETE:
            if (rl_point != wcslen(_el_line_buffer))
            {
              if (_el_delete_char(VK_DELETE, 1))
              {
                _el_clean_exit();
                return NULL;
              }
              _el_compl_index = 0;
              compl_pos = -1;
            }
            break;
          }
        }
        else
        {
          /*
          if it is a normal key, remove it from the buffer
          */
          memset(buf, 0, _EL_CONSOLE_BUF_LEN * sizeof(wchar_t));
          if (!ReadConsole(_el_h_in, buf, 1, &count, NULL))
          {
            _el_clean_exit();
            return NULL;
          }
          /*
          then parse it
          */
          switch (buf[0])
          {
            /*
            backspace
            */
          case VK_BACK:
            if (rl_point)
            {
              _el_compl_index = 0;
              compl_pos = -1;
              if (_el_delete_char(VK_BACK, 1))
              {
                _el_clean_exit();
                return NULL;
              }
            }
            break;

            /*
            TAB: do completion
            */
          case VK_TAB:
            if ((!array) || (rl_point != compl_pos))
            {
              _el_free_array(array);
              index = 0;
              if (_el_text)
              {
                free(_el_text);
                _el_text = NULL;
              }
              if (!(_el_text = _el_get_compl_text(&start, &end)))
              {
                _el_clean_exit();
                return NULL;
              }
              if (_el_old_arg)
              {
                _el_old_arg[0] = _T('\0');
              }
              if (!_el_w2mb(_el_text, &_el_text_mb))
              {
                _el_clean_exit();
                return NULL;
              }
              if (!_el_w2mb(_el_line_buffer, &rl_line_buffer))
              {
                _el_clean_exit();
                return NULL;
              }
              array = (rl_attempted_completion_function ? rl_attempted_completion_function(_el_text_mb,
                  start, end) : rl_completion_matches(_el_text_mb,
                  (rl_completion_entry_function ? rl_completion_entry_function
                  : rl_filename_completion_function)));
              if (!array)
              {
                _el_clean_exit();
                return NULL;
              }
            }
            if (!array[index])
            {
              index = 0;
            }
            if (array[index])
            {
              if (!_el_mb2w(array[index], &_el_next_compl))
              {
                _el_clean_exit();
                return NULL;
              }
              len = 0;
              if (_el_old_arg)
              {
                len = cast(int) wcslen(_el_old_arg);
                /*#if 0 fwprintf(stderr,
                    _T("VK_TAB) _el_old_arg = '%s', len = %d\n"), _el_old_arg, len);
                fflush(stderr);
                #endif*/
              }
              if (!len)
              {
                len = cast(int) wcslen(_el_text);
              }
              if (len)
              {
                if (_el_delete_char(VK_BACK, len))
                {
                  _el_clean_exit();
                  return NULL;
                }
              }
              len = cast(int) wcslen(_el_next_compl);
              if (!(_el_old_arg = cast(wchar_t*) realloc(_el_old_arg, (len + 1) * wchar_t.sizeof)))
              {
                return NULL;
              }
              _el_old_arg[len] = ('\0');
              memcpy(_el_old_arg, _el_next_compl, len * wchar_t.sizeof);
              line_len = cast(int) wcslen(_el_line_buffer);
              if (_el_insert_char(_el_next_compl, len))
              {
                _el_clean_exit();
                return NULL;
              }
              free(_el_next_compl);
              _el_next_compl = NULL;
              compl_pos = ((rl_point && (!wcschr(_el_completer_word_break_characters
                  ? _el_completer_word_break_characters
                  : _el_basic_word_break_characters, _el_line_buffer[rl_point - 1]))) ? rl_point
                  : -1);
              ++index;
            }
            break;

            /*
            ENTER: move the cursor to end of line,
            then return to the caller program
            */
          case VK_RETURN:
            if (_el_set_cursor(cast(int) wcslen(_el_line_buffer) - rl_point))
            {
              _el_clean_exit();
              return NULL;
            }
            break;

            /*
            delete word
            */
          case 0x17: /* CTRL + W */
            if (ctrl)
            {
              if (!rl_point)
              {
                break;
              }
              n = 1;
              while (((rl_point - n) > 0) && (iswspace(_el_line_buffer[rl_point - n])))
              {
                ++n;
              }
              while ((rl_point - n) && (!iswspace(_el_line_buffer[rl_point - n])))
              {
                ++n;
              }
              if (rl_point - n)
              {
                --n;
              }
              _el_compl_index = 0;
              compl_pos = -1;
              if (_el_delete_char(VK_BACK, n))
              {
                _el_clean_exit();
                return NULL;
              }
              break;
            }

            /*
            delete until end of line
            */
          case 0x0B: /* CTRL + K */
            if (ctrl)
            {
              line_len = cast(int) wcslen(_el_line_buffer);
              if (rl_point < line_len)
              {
                _el_compl_index = 0;
                compl_pos = -1;
                if (_el_delete_char(VK_DELETE, line_len - rl_point))
                {
                  _el_clean_exit();
                  return NULL;
                }
              }
              break;
            }

            /*
            beginning-of-line
            */
          case 0x01: /* CTRL + A */
            if (_el_move_cursor(VK_HOME, 0))
            {
              _el_clean_exit();
              return NULL;
            }
            break;

            /*
            end-of-line
            */
          case 0x05: /* CTRL + E */
            if (_el_move_cursor(VK_END, 0))
            {
              _el_clean_exit();
              return NULL;
            }
            break;

            /*
            forward-char
            */
          case 0x06: /* CTRL + F */
            if (_el_move_cursor(VK_RIGHT, 0))
            {
              _el_clean_exit();
              return NULL;
            }
            break;

            /*
            backward-char
            */
          case 0x02: /* CTRL + B */
            if (_el_move_cursor(VK_LEFT, 0))
            {
              _el_clean_exit();
              return NULL;
            }
            break;

            /*
            previous-line
            */
          case 0x10: /* CTRL + P */
            if (_el_display_prev_hist())
            {
              _el_clean_exit();
              return NULL;
            }
            break;

            /*
            next-line
            */
          case 0x0E: /* CTRL + N */
            if (_el_display_next_hist())
            {
              _el_clean_exit();
              return NULL;
            }
            break;

            /*
            delete char
            */
          case 0x04: /* CTRL + D */
            if (rl_point != wcslen(_el_line_buffer))
            {
              if (_el_delete_char(VK_DELETE, 1))
              {
                _el_clean_exit();
                return NULL;
              }
              _el_compl_index = 0;
              compl_pos = -1;
            }
            break;

            /*
            if it is a printable character, print it
            NOTE: I have later commented out the
            iswprint() check since for instance it
            prevents the euro sign from being printed
            */
          default:
            /*if (iswprint(buf[0])) {*/
            _el_compl_index = 0;
            compl_pos = -1;
            if (_el_insert_char(buf, 1))
            {
              _el_clean_exit();
              return NULL;
            }
            /*}*/
          }
        }
      }
      /*
      if it was not a keyboard event, just remove it from buffer
      */
    else if (!ReadConsoleInput(_el_h_in, &irBuffer, 1, &count))
      {
        _el_clean_exit();
        return NULL;
      }
    }
    else
    {
      /*
      wait for console input
      */
      WaitForSingleObject(_el_h_in, INFINITE);
    }
  }

  printf("\n");
  while (next_history()){

  }
  previous_history();
  /*
  if CTRL+C has been pressed, return an empty string
  */
  if (_el_line_buffer)
  {
    if (_el_ctrl_c_pressed)
    {
      n = cast(int) wcslen(_el_line_buffer) - rl_point;
      if (n)
      {
        _el_set_cursor(n);
      }
      _el_line_buffer[0] = ('\0');
    }
    _el_w2mb(_el_line_buffer,  & rl_line_buffer);
    ret_string = _strdup(rl_line_buffer);
  }
  _el_clean_exit();

  return ret_string;
}

