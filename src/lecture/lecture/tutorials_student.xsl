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
<xsl:param name="map"/>
<xsl:param name="nav">none</xsl:param>
<xsl:param name="room"><xsl:value-of select="/Object/path/path"/></xsl:param>
<xsl:param name="no_objects">true</xsl:param>

<xsl:output method="html" encoding="iso-8859-1" indent="no"/>

<xsl:include href="steam://stylesheets/steam_header.xsl"/>
<xsl:include href="steam://stylesheets/browsercss2.xsl"/>
<xsl:include href="steam://stylesheets/footer.xsl"/>

<xsl:template match="Object">
<HEAD>
	<SCRIPT LANGUAGE="JavaScript" SRC="/gui_js/main.js" TYPE="text/javascript"/>
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

<FORM NAME="browser" ACTION="/home/eim03-admin/lecture/lecture" ENCTYPE="multipart/form-data" METHOD="POST" CLASS="nomargin">
<INPUT type="hidden" name="id" value="{id}"/>
<INPUT type="hidden" name="_action" value="upload"/>
<INPUT type="hidden" name="room" value="{$room}"/>
<INPUT type="hidden" name="room" value="name"/>
<INPUT type="hidden" name="objrating" value=""/>
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

&nbsp;&nbsp;<SPAN CLASS="text0sc"><A HREF="/scripts/navigate.pike?object={/Object/environment/object/id}">zur&#252;ck zum Environment</A></SPAN><BR/><BR/><BR/></TD></TR>
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
<xsl:call-template name="footer"/>
</BODY>
</xsl:template>


<xsl:template name="show_tutorialdocument">
<TR><TD><IMG SRC="/scripts/get.pike?object={icon/object/id}" WIDTH="32" HEIGHT="32" BORDER="0" VSPACE="2" HSPACE="4"/></TD><TD><a href="/scripts/get.pike?object={id}"><B><xsl:value-of select="name"/></B></a><BR/><SPAN CLASS="text0sc"><xsl:value-of select="description"/></SPAN></TD><TD><SPAN CLASS="text0sc"><xsl:value-of select="content/size"/> bytes</SPAN></TD><TD>
<xsl:choose>
<xsl:when test="assess/object/object/id > 0 ">
<a href="/scripts/get.pike?object={assess/object/object/id}">bewertet</a> von <a href="#" onClick="open_userdetails('{assess/creator/object/id}');"><xsl:value-of select="assess/creator/object/name"/></a>
</xsl:when>
<xsl:otherwise><I>Abgegeben am <xsl:value-of select="created/date"/></I></xsl:otherwise></xsl:choose></TD></TR>
</xsl:template>
 
<xsl:template name="show_container">
<TR><TD><A HREF="/scripts/navigate.pike?object={id}"><IMG SRC="/scripts/get.pike?object={icon/object/id}" WIDTH="32" HEIGHT="32" BORDER="0" VSPACE="2" HSPACE="4"/></A></TD><TD><A HREF="/scripts/navigate.pike?object={id}"><B><xsl:value-of select="name"/></B></A><BR/><SPAN CLASS="text0sc"><xsl:value-of select="description"/></SPAN></TD><TD><SPAN CLASS="text0sc"><xsl:value-of select="inventory/size"/></SPAN></TD><TD><SPAN CLASS="text0sc"><I><xsl:value-of select="created/date"/></I></SPAN></TD>
</TR>
</xsl:template>

<xsl:template name="show_mine">
<xsl:param name="user"/>
<xsl:call-template name="show_tutorialdocument"/>
</xsl:template>

<xsl:template name="inventory">
<TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0" WIDTH="785" CLASS="bgbrowser" ALIGN="CENTER">
<TR><TD COLSPAN="4"><IMG SRC="/images/nav_subline.gif" WIDTH="785" HEIGHT="2" BORDER="0"/></TD></TR>
<TR VALIGN="BOTTOM" CLASS="tabhead"><TD CLASS="header" WIDTH="36"><BR/><BR/></TD><TD
CLASS="header" WIDTH="400">Name</TD><TD CLASS="header"
WIDTH="85">Dateigr&#246;&#223;e</TD><TD CLASS="header" WIDTH="254">Abgabe-Status</TD></TR>
<xsl:for-each select="inventory/Object[@type='Container']">
<xsl:if test="abgabe>0">
<xsl:call-template name="show_container"/>
</xsl:if>
<xsl:if test="owner/object/id=/Object/user/id">
<xsl:call-template name="show_container"/>
</xsl:if>
</xsl:for-each>
<xsl:for-each select="inventory/Object[@type='Document']">
<xsl:sort select="*[local-name()=/Object/sort-objects]"/>
<xsl:if test="group!='0'">
<xsl:call-template name="show_mine">
<xsl:with-param name="user"><xsl:value-of select="/Object/user/id"/></xsl:with-param>
</xsl:call-template>
</xsl:if>
</xsl:for-each>
<xsl:if test="count(inventory/Object[@type='Document']) = 0">
<TR><TD COLSPAN="4"><BR/><BR/>
&nbsp;&nbsp;<B>... keine Dokumente vorhanden ...</B><BR/><BR/><BR/><BR/></TD></TR>
</xsl:if>
<TR><TD COLSPAN="4"><BR/><BR/><BR/></TD></TR>
<xsl:choose>
<xsl:when test="/Object/abgabe_ende/time=0">
<xsl:call-template name="upload_tutorialstuff"/>
</xsl:when>
<xsl:otherwise>
<TR><TD COLSPAN="4"><B>Abgabe endete am: <xsl:value-of select="/Object/abgabe_ende/date"/></B><br/><br/></TD></TR>
</xsl:otherwise>
</xsl:choose>
</TABLE>
</xsl:template>
 

<xsl:template name="upload_tutorialstuff">
<TR VALIGN="BOTTOM" CLASS="tabhead"><TD COLSPAN="4" CLASS="header"><BR/>&#160;L&#246;sungen f&#252;r die &#220;bungsgruppe abgeben</TD></TR>
<TR><TD COLSPAN="4"><BR/><TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0">
<TR VALIGN="TOP"><TD><TABLE BORDER="0" CELLPADDING="2" CELLSPACING="0">
<TR><TD COLSPAN="2">&#160;<SPAN CLASS="text0sc">W&#228;hlen die Datei f&#252;r die elektronische Abgabe und den<BR/>&#160;&#220;bungsgruppenleiter aus der Liste. Zus&#228;tzlich kannst du<BR/>&#160;einen Kommentar zur Abgabe schreiben. Zul&#228;ssig sind nur<BR/>&nbsp;Dateien folgender Typen: .txt, .doc, .rtf, .pdf und .html/.htm</SPAN><BR/><BR/></TD></TR>
<TR VALIGN="TOP"><TD>&nbsp;<B>Dokument:</B>&nbsp;</TD><TD><INPUT TYPE="file" NAME="URL" MAXSIZE="20971520" SIZE="18" CLASS="formtext2" ACCEPT="text/*,application/pdf,application/msword"/></TD></TR>
<TR><TD COLSPAN="2"><BR/></TD></TR>
<TR><TD>&nbsp;<B>&#220;bungsgruppenleiter:</B>&nbsp;</TD><TD><SELECT NAME="tutorials_selecttutor" SIZE="1">
<OPTION VALUE="-1">Bitte w&#228;hlen</OPTION>
<xsl:for-each select="tutors/array/object">
<xsl:sort select="name"/>
<xsl:if test="name!='root' and name!='rks'">
<OPTION VALUE="{id}"><xsl:value-of select="name"/></OPTION>
</xsl:if>
</xsl:for-each>
</SELECT>
<BR/></TD></TR>
<TR><TD COLSPAN="2"><BR/></TD></TR>
<TR><TD>&#160;<B>Kommentar:</B></TD><TD><INPUT TYPE="TEXT" SIZE="22" MAXSIZE="255" NAME="objdesc" CLASS="formtext2"/></TD></TR>
</TABLE></TD><TD WIDTH="35">&#160;&#160;&#160;&#160;</TD><TD><TABLE BORDER="0" CELLPADDING="2" CELLSPACING="0" WIDTH="300">
<TR><TD COLSPAN="2"><B>Matrikelnummern</B><BR/><SPAN CLASS="text0sc">Es m&#252;ssen f&#252;r alle Teilnehmer (2-4) der Gruppe<BR/>die Matrikelnummern angegeben werden.</SPAN><BR/><BR/></TD></TR>
<TR><TD><B>1. Matrikelnummer:</B></TD><TD><INPUT TYPE="TEXT" NAME="tutorial_mno1tmp" SIZE="22" MAXSIZE="40" CLASS="formtext2" value="{/Object/user/matrikelnr}" DISABLED="TRUE"/></TD></TR>
<TR><TD><B>2. Matrikelnummer:</B></TD><TD><INPUT TYPE="TEXT" NAME="tutorial_mno2" SIZE="22" MAXSIZE="40" CLASS="formtext2" value=""/></TD></TR>
<TR><TD><B>3. Matrikelnummer:</B></TD><TD><INPUT TYPE="TEXT" NAME="tutorial_mno3" SIZE="22" MAXSIZE="40" CLASS="formtext2" value=""/></TD></TR>
<TR><TD><B>4. Matrikelnummer:</B></TD><TD><INPUT TYPE="TEXT" NAME="tutorial_mno4" SIZE="22" MAXSIZE="40" CLASS="formtext2" value=""/></TD></TR>
</TABLE></TD></TR>
</TABLE><BR/><BR/><BR/>
&nbsp;<INPUT type="hidden" name="tutorial_mno1" value="{/Object/user/matrikelnr}"/><INPUT TYPE="Button" VALUE="&nbsp;&nbsp;&nbsp;L&#246;sung uploaden und abgeben&nbsp;&nbsp;&nbsp;" CLASS="formbutton4" OnClick="submit();"/><BR/><BR/><BR/><BR/></TD>
</TR>
<TR><TD COLSPAN="5">Bisher erreichte Punkte: &#160;<xsl:for-each select="/Object/punkte/struct/member">
<xsl:sort select="key/int"/>
Aufgabe <xsl:value-of select="key/int"/>: <b><xsl:value-of select="substring-before(string(value/float),'.')"/></b>&#160;&#160;
</xsl:for-each>
</TD></TR>

</xsl:template>


</xsl:stylesheet>
