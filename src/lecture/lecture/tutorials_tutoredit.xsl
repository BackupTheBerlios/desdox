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

<xsl:output method="html" encoding="iso-8859-1" indent="no"/>

<xsl:include href="steam://stylesheets/steam_header.xsl"/>
<xsl:include href="steam://stylesheets/browsercss2.xsl"/>
<xsl:include href="steam://stylesheets/inventory.xsl"/>
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

<FORM NAME="browser" ACTION="/scripts/lecture.pike" METHOD="POST" CLASS="nomargin">
<INPUT type="hidden" name="id" value="{id}"/>
<INPUT type="hidden" name="_action" value="set_documentstatus"/>
<INPUT type="hidden" name="room" value="{$room}"/>

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

&nbsp;&nbsp;<SPAN CLASS="text0sc">Pfad: 
<xsl:for-each select="path/object"><xsl:choose><xsl:when test="position()=last()"><xsl:value-of select="name"/>/</xsl:when><xsl:otherwise><xsl:choose><xsl:when test="name=''"><a href="navigate.pike?object={id}">/root-path/</a></xsl:when><xsl:otherwise><a href="navigate.pike?object={id}"><xsl:value-of select="name"/></a>/</xsl:otherwise></xsl:choose></xsl:otherwise></xsl:choose></xsl:for-each></SPAN><BR/><BR/><BR/></TD></TR>
</TABLE>

<xsl:call-template name="tutoredit"/>

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


<xsl:template name="tutoredit">
<TABLE BORDER="0" CELLPADDING="0" CELLSPACING="0" WIDTH="785" CLASS="bgbrowser" ALIGN="CENTER">
<TR><TD COLSPAN="3"><IMG SRC="/images/nav_subline.gif" WIDTH="785" HEIGHT="2" BORDER="0"/></TD></TR>
<TR VALIGN="BOTTOM" CLASS="tabhead"><TD
CLASS="header" WIDTH="430">Bemerkung zur Abgabe</TD><TD CLASS="header" WIDTH="20">&nbsp;</TD><TD CLASS="header" WIDTH="335">Status der Bearbeitung</TD></TR>
<TR VALIGN="TOP"><TD><BR/><SPAN CLASS="formtext"><TEXTAREA NAME="tutorialdescr" ROWS="9" COLS="38" WRAP="VIRTUAL" CLASS="formtext"/></SPAN><BR/><BR/><BR/><INPUT TYPE="BUTTON" VALUE="&#160;&#160;Bearbeitungsvermerk speichern&#160;&#160;" CLASS="formbutton4"/><BR/><BR/><BR/><BR/></TD><TD></TD><TD><BR/><INPUT TYPE="BUTTON" NAME="tutorialssendtogroup" VALUE="Bemerkung an die Gruppe versenden" CLASS="formbutton4"/></TD></TR>
</TABLE>
</xsl:template>


</xsl:stylesheet>
