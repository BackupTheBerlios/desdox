/* Copyright (C) 2000-2003  Thomas Bopp, Thorsten Hampel, Ludger Merkens
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

//! This class simulates a mapping inside the database.
//! Call get_value() and set_value() functions.

#include <macros.h>

private static Sql.sql_result oDbResult;
private static string          sDbTable;
//private static mapping            mData;
private static function             fDb;

int get_object_id();

string tablename()
{
    return copy_value(sDbTable);
}

/**
 * connect a db_mapping with database.pike
 */
static final void load_db_mapping()
{
    // get database access function and tablename
    //    mData = ([]);
    [fDb , sDbTable]= _Database->connect_db_mapping();

    // we are in secure code, so create table according to
    // values from database.
    if( search(fDb()->list_tables(), "i_"+sDbTable ) == -1 )
    {
	fDb()->big_query("create table i_"+sDbTable+
			"(k char(255) not null, v text,"+
			"UNIQUE(k))");
    }
}
    
/**
 * Index Operator for mapping emulation
 * @param   string key  - the key to access
 * @result  mixed value - the datastructure set with `[]= if any
 */
static mixed get_value(string|int key) {
    mixed d;
    mixed row;

    //    if (d = mData[key])
    //	return d;

    //    LOG("db_mapping.get_value("+key+")");
    Sql.sql_result res =
	fDb()->big_query("select v from i_"+sDbTable+
			 " where k = '"+fDb()->quote((string)key)+"'");
    if (!objectp(res) )
	return 0;
    else if ( !(row=res->fetch_row())) {
	destruct(res);
	return 0;
    }
    //    mData[key] = unserialize(row[0]);
    destruct(res);
    //    return mData[key];
    return unserialize(row[0]);
}
    
/**
 * Write Index Operator for mapping emulation
 * The serialization of the given value will be stored to the database
 * @param   string key  - the key to access
 * @param   mixed value - the value
 * @return  value| throw
 */
static mixed set_value(string|int key, mixed value) {
    //    mData[key]=value;
    //write("setting:"+serialize(value)+"\n");
    if(sizeof(fDb()->query("SELECT k FROM i_"+sDbTable+
                           " WHERE k='"+fDb()->quote((string)key)+"'")))
    {
      fDb()->big_query("UPDATE i_"+sDbTable+
                       " SET v='"+ fDb()->quote(serialize(value))+ "'"
                       " WHERE k='"+ fDb()->quote((string)key)+"'");
    }
    else
    {
      fDb()->big_query("INSERT INTO i_" + sDbTable +
		       " VALUES('" + fDb()->quote((string)key) + "', '" +
		       fDb()->quote(serialize(value)) + "')");
    }
    return value;
}

/**
 * delete a key from the database mapping emulation.
 * @param   string|int key
 * @result  int (0|1) - Number of deleted entries
 */
static int delete(string|int key) {
    fDb()->big_query("delete from i_"+ sDbTable+" where k like '"+key+"'");
    //    m_delete(mData, (string) key);
    return fDb()->master_sql->affected_rows();
}

/**
 * select keys from the database like the given expression.
 * @param   string|int keyexpression
 * @result  array(int|string)  
 */
static array report_delete(string|int key) {
    mixed aResult = ({});
    int i, sz;
    
    object handle = fDb();
    Sql.sql_result res = handle->big_query("select k from i_"+ sDbTable +
                                           " where k like '"+ key+"'");
    if (!res || !res->num_rows())
        return ({ });
          
    aResult = allocate(sz=res->num_rows());
    for (i=0;i<sz;i++)
        aResult[i] = res->fetch_row()[0];

    fDb()->big_query("delete from i_"+ sDbTable+" where k like '"+key+"'");
    //    m_delete(mData, (string) key);

    return aResult;
}

/**
 * give a list of all indices (keys) of the database table
 * @param   none
 * @return  an array containing the keys
 * @see     maapping.indices
 */
array(string) index()
{
    //    LOG("getting index()\n");
    
    Sql.sql_result res = fDb()->big_query("select k from i_"+sDbTable);
    //    LOG("done...");
#if 1
    int sz = res->num_rows();
    array(string) sIndices = allocate(sz);
    int i;
    for ( i = 0; i < sz; i++ )
    {
        string sres = copy_value(res->fetch_row()[0]);
	sIndices[i] = sres;
    }
#else
    array(string) sIndices = ({}); 
    array mres;
    while (mres = res->fetch_row())
        sIndices+=mres;
#endif
    destruct(res);
    return sIndices;
}

string get_table_name() { return (string)get_object_id(); }
