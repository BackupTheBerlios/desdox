private Slotter.Insert oInsert; // the Insert that will generate the content

/**
 * set the insert to this slot
 * @param Slotter.Insert Insert - the Insert to insert
 * @authot Ludger Merkens
 */
void set_insert(Slotter.Insert Insert)
{
    oInsert = Insert;
}

/**
 * get the current insert
 * @return 0| Slotter.Insert - the current insert
 */
Slotter.Insert get_insert()
{
    return oInsert;
}

/**
 * @return the complete identifier treated as a tree separated with "."
 */
// string get_path_slot_name()
// {
//     return (oParent ? oParent->get_path_slot_name()+"." :"/")+ sSlotName;
// }

/**
 * set the local name according to the generating insert
 * @param string name - the local name to set
 * @see create - you can also set the name during creation
 */
// string set_slot_name(string name)
// {
//     sSlotName = name;
// }

/**
 * return the local name on this level of hierarchy
 * @return string - the name set to this slot (local)
 */
// string get_slot_name()
// {
//     return sSlotName;
// }

int is_slot() {
    return 1;
}
