/* s - Bedingung   i - Fehlerinfo   */
//# define ASSERTINFO(s, i) if ( !s ) { object __o; werror("Assertion failed :" + i+"\n------------------------------------------------------------------------\n"); __o = 0; __o->test(); }
#define ASSERTINFO(s, i) if ( !(s) ) { throw(({"Assertion failed: " + i + "\n--------------------------------------------------------------------\n", backtrace() })); }
