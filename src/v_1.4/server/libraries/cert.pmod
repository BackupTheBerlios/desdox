/* Copyright (C) 2000 - 2003  Thomas Bopp, Thorsten Hampel, Ludger Merkens
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 */
import Standards.ASN1.Types;

#if !constant(PrintableString) 
class PrintableString {
    inherit asn1_printable_string;
}
#endif

/**
 * Read a certificate file 'path' which has to be encoded
 * appropriately (base64).
 *  
 * @param string path - the path of the filename
 * @return mapping of certificate components
 */
mapping read_certificate(string path)
{
    mapping result = ([ ]);
    
    string cert;
    string f = Stdio.read_file("config/steam.cer");
    if ( !stringp(f) ) 
	error("Failed to read certificate file " + path);
    object msg = Tools.PEM.pem_msg()->init(f);
    object part = msg->parts["CERTIFICATE"] || msg->parts["X509 CERTIFICATE"];
    if ( !objectp(part) )
	error("Failed to parse certificate in file 'steam.cer'.");
    cert = part->decoded_body();
    result->cert = cert;
    
    part = msg->parts["RSA PRIVATE KEY"];
    string key = part->decoded_body();
    if ( !objectp(part) )
	error("Failed to find RSA private key in certificate");
    result->key = key;
    result->rsa = Standards.PKCS.RSA.parse_private_key(key);
    result->random = Crypto.randomness.reasonably_random()->read;

    return result;

}
