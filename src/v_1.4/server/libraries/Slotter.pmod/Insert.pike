//private Slotter.Slot inSlot;
private mapping mCallbacks = ([]);

/*
 * This is the very basic html Slot, it is almost a virtual class
 * meant as parent for all more elaborate insert classes
 */


/**
 * return some useful html representation suitable for a rough preview
 * of the final result. Most times an empty table with a name will do
 *
 * @return array - a vector of slots and strings to be composed by the
 *                 Slotter main module
 * @author Ludger Merkens
 */ 
array preview()
{
    return ({"<td>empty slot</td>"});    
}

/**
 * return the final design, the html representation meant for application
 * purposes.
 *
 * @return array - a vector of slots and strings to be composed by the
 *                 Slotter main module
 * @author Ludger Merkens
 */
array generate()
{
    return ({"<td></td>"});
}

array(string) need_style_sheets() {
    return ({});
}

array(string) need_java_scripts() {
    return ({});
}

