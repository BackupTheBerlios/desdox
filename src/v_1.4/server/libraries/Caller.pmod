object get_caller(object obj, mixed bt)
{
    int sz = sizeof(bt);
    object       caller;

    sz -= 2;
    for ( ; sz >= 0; sz-- ) {
	if ( functionp(bt[sz][2]) ) {
	    function f = bt[sz][2];
	    caller = function_object(f);
	    if ( caller != obj ) { 
		return caller;
	    }
	}
    }
    return 0;
	
}
