<?xml version="1.0"?>
<!DOCTYPE xsl:stylesheet [
   <!ENTITY nbsp "&#160;">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

<xsl:param name="object">undefined</xsl:param>
<xsl:param name="host">undefined</xsl:param>
<xsl:param name="user_id">undefined</xsl:param>
<xsl:param name="user_name">undefined</xsl:param>
<xsl:param name="selection">undefined</xsl:param>
<xsl:param name="port_http">undefined</xsl:param>
<xsl:param name="port_ftp">undefined</xsl:param>
<xsl:param name="port_irc">undefined</xsl:param>
<xsl:param name="message">no action</xsl:param>
<xsl:param name="domain"/>
<xsl:param name="error">ok</xsl:param>
<xsl:param name="client">undefined</xsl:param>
<xsl:param name="nav"><xsl:choose><xsl:when test="/Object/id=/Object/user/id">inv</xsl:when><xsl:when test="/Object/@type='Container' or /Object/@type='Trashbin'">container</xsl:when><xsl:otherwise>area</xsl:otherwise></xsl:choose></xsl:param>
<xsl:param name="room"><xsl:choose><xsl:when test="$nav='area'"><xsl:value-of select="$object"/></xsl:when><xsl:otherwise>0</xsl:otherwise></xsl:choose></xsl:param>
<xsl:param name="no_objects">false</xsl:param>
<xsl:param name="map"/>

<xsl:output method="html" encoding="iso-8859-1" indent="no"/>

<xsl:include href="steam://stylesheets/steam_header.xsl"/>
<xsl:include href="steam://stylesheets/browsercss2.xsl"/>

<xsl:template match="Object">
<HEAD>
	<SCRIPT LANGUAGE="JavaScript" SRC="/gui_js/main.js" TYPE="text/javascript"/>
	<SCRIPT LANGUAGE="JavaScript">
		function finish_tutorial(id) {
		     var form = document.browser;
		     var finishcheck = confirm('Soll die Bewertung wirklich abgeschlossen werden?');
	        if(finishcheck) {
        	        form._action.value = 'finish';
               		form.object.value = id;
	                form.submit();
       		 } else return false;
	        }
	</SCRIPT>
    <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=iso-8859-1"/>
    <META http-equiv="expires" content="0"/>
	<TITLE>sTeam: <xsl:value-of select="name"/></TITLE>
    <xsl:call-template name="browsercss"/>
</HEAD>
<BODY BGCOLOR="#F5F5F5" LINK="#000000" VLINK="#000000" ALINK="#000000">

<xsl:call-template name="header"/>

<MAP NAME="subnav1">
<AREA SHAPE="poly" COORDS="666,2,729,2,715,20,652,20" HREF="navigate.pike?object={$room}" ALT="Users"/>
<AREA SHAPE="poly" COORDS="733,2,782,2,782,20,720,20" HREF="JavaScript:open_chat('{/Object/user/name}','{/Object/id}');" ALT="Chat"/>
</MAP>

<MAP NAME="subnav2">
<AREA SHAPE="poly" COORDS="257,2,390,2,375,20,245,20" HREF="navigate.pike?object={$object}&amp;room={$room}&amp;browse=details" ALT="Browse by List"/>
<AREA SHAPE="poly" COORDS="394,2,527,2,515,20,380,20" HREF="navigate.pike?object={$object}&amp;room={$room}&amp;browse=icons" ALT="Browser by Icons"/>
<AREA SHAPE="poly" COORDS="531,2,594,2,582,20,518,20" HREF="navigate.pike?object={$object}&amp;room={$room}&amp;browse=svg" ALT="Map"/>
<AREA SHAPE="poly" COORDS="597,2,648,2,648,20,585,20" HREF="JavaScript:open_ftp('{$user_name}@{$host}:{$port_ftp}{/Object/path/path}');" ALT="FTP"/>
</MAP>

<MAP NAME="subnav3">
<AREA SHAPE="poly" COORDS="392,2,525,2,510,20,380,20" HREF="navigate.pike?object={$object}&amp;room={$room}&amp;browse=details" ALT="Browse by List"/>
<AREA SHAPE="poly" COORDS="529,2,662,2,650,20,515,20" HREF="navigate.pike?object={$object}&amp;room={$room}&amp;browse=icons" ALT="Browse by Icons"/>
<AREA SHAPE="poly" COORDS="666,2,729,2,717,20,653,20" HREF="navigate.pike?object={$object}&amp;room={$room}&amp;browse=svg" ALT="Map"/>
<AREA SHAPE="poly" COORDS="732,2,783,2,783,20,720,20" HREF="JavaScript:open_ftp('{$user_name}@{$host}:{$port_ftp}{/Object/path/path}');" ALT="FTP"/>
</MAP>

<FORM NAME="browser" ACTION="/home/eim03-admin/lecture/lecture" METHOD="POST" CLASS="nomargin">
<INPUT type="hidden" name="id" value="{id}"/>
<INPUT type="hidden" name="_action" value="set_documentstatus"/>
<INPUT type="hidden" name="room" value="{$room}"/>
<INPUT type="hidden" name="object" value=""/>
<TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0" WIDTH="785" CLASS="bginfotext" ALIGN="CENTER">
<TR><TD><BR/><BR/>&nbsp;&nbsp;<SPAN CLASS="text2bb">
<xsl:choose>
<xsl:when test="name=''">
*No Description*
</xsl:when>
<xsl:otherwise>
<xsl:value-of select="name"/>
</xsl:otherwise>
</xsl:choose>
<BR/></SPAN>

&nbsp;&nbsp;<SPAN CLASS="text0sc"><A HREF="/scripts/navigate.pike?object={/Object/environment/object/id}">zur&#252;ck zum Environment</A></SPAN><BR/><BR/><BR/>&nbsp;<SPAN CLASS="text2bb">Hinweis: <xsl:choose><xsl:when test="/Object/abgabe_ende/time>0">die Abgabe ist beendet</xsl:when><xsl:otherwise>die Abgabe l&#228;uft seit <xsl:value-of select="start_date/date"/></xsl:otherwise></xsl:choose></SPAN><BR/><BR/></TD></TR>

</TABLE>

<xsl:call-template name="inventory"/>

<xsl:if test="types!=0">
<TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0" WIDTH="785" ALIGN="CENTER">
<TR VALIGN="TOP"><TD><BR/><SPAN CLASS="text0sc">You can show this page as:
<xsl:for-each select="types/struct/member">
<A href="navigate.pike?object={$object}&amp;room={$room}&amp;style={value/object/id}"><xsl:value-of select="key/object/name"/></A>&#160;|
</xsl:for-each>
</SPAN><BR/><BR/></TD></TR>
</TABLE>
</xsl:if>
</FORM>
</BODY>
</xsl:template>

<xsl:template name="show_container">
<TR><TD ALIGN="RIGHT">
<xsl:if test="@selected='false'">
<INPUT TYPE="CHECKBOX" NAME="objsel" VALUE="{id}"/>
</xsl:if>
<xsl:if test="@selected='true'">
<INPUT TYPE="CHECKBOX" NAME="objsel" VALUE="{id}" CHECKED="true" CLASS="bgcheckedobj"/>
</xsl:if>
</TD><TD><A HREF="/scripts/navigate.pike?object={id}"><IMG SRC="/scripts/get.pike?object={icon/object/id}" WIDTH="32" HEIGHT="32" BORDER="0" VSPACE="2" HSPACE="4"/></A></TD><TD><A HREF="/scripts/navigate.pike?object={id}"><B><xsl:value-of select="name"/></B></A><BR/><SPAN CLASS="text0sc"><xsl:value-of select="description"/></SPAN></TD><TD><SPAN CLASS="text0sc"><xsl:value-of select="inventory/size"/></SPAN></TD><TD><SPAN CLASS="text0sc"><I><xsl:value-of select="created/date"/></I></SPAN></TD>
</TR>
</xsl:template>

<xsl:template name="show_tutordocument">
<xsl:param name="group"/>
<TR><TD ALIGN="RIGHT">
<xsl:if test="@selected='false'">
<INPUT TYPE="CHECKBOX" NAME="objsel" VALUE="{id}"/>
</xsl:if>
<xsl:if test="@selected='true'">
<INPUT TYPE="CHECKBOX" NAME="objsel" VALUE="{id}" CHECKED="true" CLASS="bgcheckedobj"/>
</xsl:if>
</TD><TD><A HREF="/scripts/get.pike?object={id}"><IMG SRC="/scripts/get.pike?object={icon/object/id}" WIDTH="32" HEIGHT="32" BORDER="0" VSPACE="2" HSPACE="4"/></A></TD><TD><A HREF="/scripts/get.pike?object={id}"><B><xsl:value-of select="name"/></B></A><BR/><SPAN CLASS="text0sc"><xsl:value-of select="description"/></SPAN></TD><TD><SPAN CLASS="text0sc"><xsl:value-of select="content/size"/> bytes</SPAN></TD><TD><SPAN CLASS="text0sc"><I><xsl:value-of select="created/date"/> von 
<A HREF="#" onClick="open_userdetails('{owner/object/id}');"><xsl:value-of select="owner/object/name"/></A></I> - Bearbeitet:  <xsl:choose><xsl:when test="status='processed'">Ja</xsl:when><xsl:otherwise>Nein</xsl:otherwise></xsl:choose> [<A HREF="#" onClick="_action.value='rate';object.value='{id}';submit();"><B>Bewerten</B></A>]</SPAN></TD></TR>
</xsl:template>


<xsl:template name="taketutorial">
<BR/>&#160;<B>&gt;&gt;</B>&#160;&#160;
<SELECT name="user_action" CLASS="formtext2">
<OPTION value="select_objects">Alle Dokumente Selektieren</OPTION>
<OPTION value="unselect_objects">Alle Dokumente Deselektieren</OPTION>
<OPTION value="---">---------------------------</OPTION>
<OPTION value="get_objects">Dokumente aufnehmen</OPTION>
<OPTION value="copy_objects">Kopie erzeugen</OPTION>
<OPTION value="delete_objects">Dokumente l&#246;schen</OPTION>
<OPTION value="---">---------------------------</OPTION>
<OPTION value="show_annotations">Annotationen anzeigen</OPTION>
<OPTION value="show_access">Rechte anzeigen</OPTION>
<OPTION value="show_attributes">Attribute anzeigen</OPTION>
</SELECT>&#160;&#160;<INPUT type="button" value=" Ok " OnClick="commit_action(document.browser);" CLASS="formbutton4"/>
</xsl:template>


<xsl:template name="show_mine">
<xsl:param name="group"/>
<xsl:param name="no_objects">false</xsl:param>
<xsl:call-template name="show_tutordocument">
</xsl:call-template>
</xsl:template>


<xsl:template name="inventory">
<TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0" WIDTH="785" CLASS="bgbrowser" ALIGN="CENTER">
<TR><TD COLSPAN="5"><IMG SRC="/images/nav_subline.gif" WIDTH="785" HEIGHT="2" BORDER="0"/></TD></TR>
<TR VALIGN="BOTTOM" CLASS="tabhead"><TD CLASS="header" WIDTH="10"><BR/></TD><TD CLASS="header" WIDTH="36"><BR/><BR/></TD><TD
CLASS="header" WIDTH="225">Name</TD><TD CLASS="header"
WIDTH="85">Dateigr&#246;&#223;e</TD><TD CLASS="header" WIDTH="429">Status<BR/>Abgegeben am / von</TD></TR>

<xsl:for-each select="inventory/Object[@type='Container']">
<xsl:if test="number(abgabe)>0">
<xsl:call-template name="show_container"/>
</xsl:if>
<xsl:if test="lecture/object/id=/Object/user/id">
<xsl:call-template name="show_container"/>
</xsl:if>
</xsl:for-each>

<xsl:for-each select="inventory/Object[@type='Document' and created/time>/Object/start_date/time]">
<xsl:sort select="created/time" order="descending"/>
<xsl:call-template name="show_mine">
<xsl:with-param name="group"><xsl:value-of select="group/object/id"/></xsl:with-param>
</xsl:call-template>
</xsl:for-each>

<xsl:if test="$no_objects='true'">
<TR><TD COLSPAN="5"><BR/><BR/>
&nbsp;&nbsp;<B>... keine Dokumente vorhanden ...</B><BR/><BR/><BR/><BR/></TD></TR>
</xsl:if>
<xsl:if test="$no_objects!='true'">
<TR><TD COLSPAN="5"><BR/><BR/><BR/>&#160;<B>&gt;&gt;</B>&#160;&#160; Bearbeitet: <INPUT TYPE="RADIO" VALUE="1" NAME="tutorials_status" CHECKED="true"/> Ja <INPUT TYPE="RADIO" VALUE="0" NAME="tutorials_status"/> Nein 
&#160;&#160;<INPUT type="button" value=" Status setzen " OnClick="form.submit()" CLASS="formbutton4"/><BR/><BR/>&#160;<B>&gt;&gt;</B>&#160;<input type="button" value=" Bewertung abschliessen " OnClick="finish_tutorial({id});" CLASS="formbutton4"/><BR/><BR/>

<xsl:call-template name="taketutorial"/>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Letzte Aktion: &gt; <I>
<xsl:choose>
<xsl:when test="$error='ok'">
<xsl:value-of select="$message"/>
</xsl:when>
<xsl:otherwise>
<font color="#FF0000"><A href="#" onClick="show_error('{$error}');"><xsl:value-of select="$message"/></A></font>
</xsl:otherwise>
</xsl:choose>
</I> &lt;<BR/><BR/><BR/>
</TD></TR>
</xsl:if>
<TR><TD COLSPAN="5"><BR/><BR/><BR/><BR/></TD></TR>
</TABLE>
</xsl:template>

</xsl:stylesheet>
