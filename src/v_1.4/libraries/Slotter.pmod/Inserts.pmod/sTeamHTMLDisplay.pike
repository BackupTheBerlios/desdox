inherit Slotter.Insert;

#include <macros.h>

object sTeamObject;
string stylesheet;

void set_style_sheet(string style)
{
    stylesheet = style;
}

void set_steam_object(object o)
{
    sTeamObject = o;
}

array preview()
{
    if (sTeamObject)
        return ({ sTeamObject->get_identifier() });
    return ({ "empty sTeamHTMLDisplay" });
}

array generate()
{
    Session.Session oSession = Session.get_user_session();
    object oComposer = oSession->get_composer();

    if (!oComposer)
        return ({ sprintf("%s Session: %d Composer missing\n",
                          this_user()->get_identifier(),
                          oSession->get_SID()) });
    
    if (sTeamObject)
        return ({
            oComposer->read_content(sTeamObject)
        });
    return ({ "empty sTeamHTMLDisplay" });
}

array(string) need_style_sheets()
{
    if (stringp(stylesheet))
        return ({ stylesheet });
    else
        return ({});
}
