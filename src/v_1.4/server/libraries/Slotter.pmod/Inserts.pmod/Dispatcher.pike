inherit Slotter.Insert;

array(StateData) states = ({});
string active;

class StateData {
    void create(string n, Slotter.Slot cell) {
        name = n;
        renderer = cell;
    }
    string name;
    Slotter.Slot renderer;
}


/**
 * add a state and its dedicated cellrenderer to the list of
 * alternatives.
 *
 * @param string state - the statename to add
 * @param Slotter.Slot cell - the Slot containing the cellrenderer
 *
 * @author Ludger Merkens
 */

int add_state(string state, Slotter.Slot cell)
{
    states += ({ StateData(state, cell) });
    return sizeof(states);
}

/**
 * get the current state of the Dispatcher
 * @return string - the state
 * @author Ludger Merkens
 */
string get_state()
{
    return active;
}

/**
 * set the current state of the Dispatcher
 * @param s    - the state to activate. This state has to be added before
 * @return 1|0 - 1 known state was activated
 *               0 state unknown, nothing changed
 * @see add_state
 * @author Ludger Merkens
 */
int set_state(string s)
{
    active = s;
    return 1;
}

array generate()
{
    array(Slotter.Slot) slots = allocate(sizeof(states));

    for (int i=0; i<sizeof(slots); i++)
        slots[i]=states[i]->renderer;
    return slots;
}

array preview()
{
    array(Slotter.Slot) slots = allocate(sizeof(states));

    for (int i=0; i<sizeof(slots); i++)
        slots[i]=states[i]->renderer;
    return slots;
}
