mapping(object:mapping(int:object)) sessions;
mapping(object:int) currUserSession =([]);

#include <attributes.h>
#include <database.h>

private int new_session_id()
{
    return hash(this_user()->query_attribute(OBJ_NAME)+(string)time());
}

object new_user_session()
{
    mapping usersessions;

    if (!mappingp(sessions))
        sessions=([]);
    
    usersessions = sessions[this_user()];
    if (!mappingp(usersessions))
    {
        int id = new_session_id();
        object oSession = Session.Session(id);
        usersessions=([]);
        usersessions[id]=oSession;
        sessions[this_user()]=usersessions;
        currUserSession[this_user()] = id;
        return oSession;
    }
    
    array(int) aSIDs = indices(usersessions);
    if (sizeof(aSIDs) > 10)
        m_delete(usersessions,aSIDs[sizeof(aSIDs)-1]);
    
    currUserSession[this_user()] = new_session_id();
 
    object oSession = Session.Session(currUserSession[this_user()]);
    usersessions[currUserSession[this_user()]]= oSession;
    sessions[this_user()]=usersessions;
    return oSession;
}

object get_user_session_by_id(int sid)
{
    if (!sid)
        throw( ({"Illegal to access Session by ID without ID",
                 backtrace() }));

    if (!sessions)
        sessions = ([]);

    mapping usersessions = sessions[this_user()];
    object session;
    
    if (!mappingp(usersessions))
        usersessions=([]);
    
    if (!(session=usersessions[sid]))
    {
        werror("asking guest ...");
        object guest = MODULE_USERS->lookup("guest");
        
        mapping guestsessions = sessions[guest];
        if (session = guestsessions[sid])
        {
            // most probably a login during session - ok we will
            // continue to use this.
            werror("found guest session ... borrowing\n");
            m_delete(guestsessions, sid);
            usersessions[sid]= session;
            currUserSession[this_user()]= sid;
            sessions[this_user()]=usersessions;
            werror(sprintf("New Usersessions for %s are %O\n",
                           this_user()->get_identifier(),
                           sessions[this_user()]));
        }
    }

    if (session)
        currUserSession[this_user()] = sid;
    
    return session;
}

object get_user_session()
{
    object o= get_user_session_by_id(currUserSession[this_user()]);
    return o;
}

void set_user_session(int sid)
{
    currUserSession[this_user()]=sid;
}
