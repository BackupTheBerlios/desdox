<?xml version="1.0" encoding="ISO-8859-1"?>
<!DOCTYPE xsl:stylesheet [
   <!ENTITY nbsp " ">
]>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:param name="object">undefined</xsl:param>
  <xsl:param name="host">undefined</xsl:param>
  <xsl:param name="user_id">undefined</xsl:param>
  <xsl:param name="user_name">undefined</xsl:param>
  <xsl:param name="selection">undefined</xsl:param>
  <xsl:param name="port_http">undefined</xsl:param>
  <xsl:param name="port_ftp">undefined</xsl:param>
  <xsl:param name="message">no action</xsl:param>
  <xsl:param name="domain" />
  <xsl:param name="error">ok</xsl:param>
  <xsl:param name="client">undefined</xsl:param>
  <xsl:param name="browse">details</xsl:param>
<xsl:param name="back">no</xsl:param>
<xsl:param name="items">5</xsl:param>
<xsl:param name="room"/>
<xsl:param name="edit">false</xsl:param>

<xsl:output method="html" encoding="iso-8859-1" />

<xsl:include href="steam://stylesheets/public.xsl"/>

<xsl:template match="Object">
<html>
<head>
	<link rel="stylesheet" type="text/css" href="/wisn/upb.css" />
	<SCRIPT LANGUAGE="JavaScript" SRC="/gui_js/main.js" TYPE="text/javascript"/>
	<title>{text_veranstaltung_beschreibung}</title>
<style type="text/css">
a.button:link { color:#FFFFFF; text-decoration:none }
a.button:visited { color:#FFFFFF; text-decoration:none }
a.button:hover { color:#FFFFFF; text-decoration:none }
a.button:active { color:#FFFFFF; text-decoration:underline }
a.button:focus { color:#FFFFFF; text-decoration:underline }
</style>

</head>

<body bgcolor="#FFFAF6">
<form action="{veranstaltung_url}/xsl_config">
<table cellspacing="0" cellpadding="0" border="0">
<tr><td height="45" bgcolor="#19138c">&#160;</td>
<td></td></tr>
<tr><td bgcolor="#E6E2E2" align="center" valign="top" width="130">
<table bgcolor="#FFFAF6" width="145" cellspacing="0" cellpadding="0" border="0">
<tr><td align="center">
<br/><br/>
<a href="http://www.uni-paderborn.de"><img src="{veranstaltung_url}/images/kralle.gif" alt="Uni Paderborn" border="0"/></a><br/></td></tr>
<tr height="10"><td>&#160;</td></tr>
<tr>
<td bgcolor="#E6E2E2">

<p><center>Universit&#xe4;t Paderborn</center><center><font face="Arial,Helvetica,sans-serif" size="2">{text_fakultaet}</font></center></p>
<p><center>{text_Arbeitsgruppe}</center></p>
</td>
</tr>
</table>

<!-- Navigations Struktur Links -->
<br/><br/>

<a href="{veranstaltung_url}"><img src="{veranstaltung_url}/images/Home.gif" alt="Home" border="0"/></a><br/>
<a href="{veranstaltung_url}/Vorlesungen">{opt_nav_Vorlesungen}</a><br/>
<a href="{veranstaltung_url}/Uebungen">{opt_nav_Uebungen}</a><br/>
<br/><br/>
<a href="{veranstaltung_url}/anmeldung">{opt_nav_Anmeldung}</a><br/>
{opt_nav_generic1}<br/>
{opt_nav_generic2}<br/>
{opt_nav_generic3}<br/>
<br/><br/>
<a href="https://{$host}:{$port_http}/home/{veranstaltung_name}">{opt_nav_Login}</a><br/>

<br/></td>

<td valign="top">

<xsl:if test="$edit='true'">
{start_edit}
</xsl:if>

<xsl:if test="header!=''">
<xsl:value-of select="header" disable-output-escaping="yes"/>
</xsl:if>
<xsl:choose>
<xsl:when test="index!=''">
<xsl:value-of select="index" disable-output-escaping="yes"/>
</xsl:when>
<xsl:otherwise>
<xsl:apply-templates select="inventory">
	<xsl:with-param name="index">index.html</xsl:with-param>
	<xsl:with-param name="header">header.html</xsl:with-param>
</xsl:apply-templates>
<xsl:if test="/Object/useraccess/writeable[@user='true']">
		<TABLE BORDER="0" CELLPADDING="2" CELLSPACING="0">
		<TR>
			<TD ALIGN="CENTER">
				<A HREF="JavaScript:open_createmode('{$object}', 'Document')">
					<IMG SRC="/images/icon_createnew_generic.gif" WIDTH="32" HEIGHT="32" ALT="{NEW} {ODOCUMENT}" BORDER="0"/></A><BR/><A HREF="JavaScript:open_createmode('{$object}', 'Document')" CLASS="sub5url">
					{NEW}<BR/>{ODOCUMENT}
				</A>
			</TD>
		</TR>
	</TABLE>
<TABLE BORDER="0" CELLPADDING="2" CELLSPACING="0">
<TR><TD ALIGN="CENTER"><A HREF="JavaScript:open_createmode('{$object}', 'Container')"><IMG SRC="/images/icon_createnew_container.gif" WIDTH="32" HEIGHT="32" ALT="{NEW} {OCONTAINER}" BORDER="0"/></A><BR/><A HREF="JavaScript:open_createmode('{$object}', 'Container')" CLASS="sub5url">{NEW2}<BR/>{OCONTAINER}</A></TD></TR>
</TABLE>
</xsl:if>
</xsl:otherwise>
</xsl:choose>
</td></tr>

<!-- Impressum and Copyright -->
</table>

<xsl:if test="$edit='true'">
	<input type="hidden" name="_action" value="edit"/>
	<input type="submit" value="&gt;&gt; Aenderungen uebernehmen"/>
</xsl:if>

</form>
</body>
</html>
</xsl:template>

<xsl:template name="show_docextern">
<TR><TD ALIGN="RIGHT">&#160;</TD>
<TD><A HREF="{url}"><IMG SRC="/scripts/get.pike?object={icon/object/id}" WIDTH="32" HEIGHT="32" BORDER="0" VSPACE="2" HSPACE="2"/></A></TD><TD><B><A HREF="{url}" TITLE="(Browse/Show Object)"><xsl:value-of select="name"/></A></B><BR/><SPAN CLASS="text0sc"><xsl:value-of select="description"/></SPAN></TD></TR>
</xsl:template>

<xsl:template name="show_document">
<TR><TD ALIGN="RIGHT"> </TD>
<TD><A HREF="{url}"><IMG SRC="/scripts/get.pike?object={icon/object/id}" BORDER="0"/></A></TD><TD><B><A HREF="{URL}" TITLE="(Show Object)"><xsl:value-of select="name"/></A></B>
</TD>
</TR>
</xsl:template>

<xsl:template match="text() | @*">
<xsl:copy><xsl:apply-templates /></xsl:copy>
</xsl:template>

<xsl:template match="TABLE | TR | TD | SELECT | OPTION | MAP | AREA | A | a | BR">
  <xsl:copy><xsl:apply-templates select="@* | * | text()"/></xsl:copy>
</xsl:template>



</xsl:stylesheet>
