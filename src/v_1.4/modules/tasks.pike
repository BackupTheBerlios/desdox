inherit "/kernel/module";

#include <macros.h>
#include <exception.h>
#include <attributes.h>
#include <classes.h>
#include <access.h>
#include <database.h>


static mapping mTasks = ([ ]);
static int tid = 0;

object log;

#define TASK_DEBUG(s) task_debug(s)


class task {
    mapping descriptions;
    object obj;
    array params;
    string func;
    int tid;
    string done_func = 0; // function to check if task is not req anymore
};

void task_debug(string s)
{
    if ( objectp(log) ) {
	string l = log->get_content();
	log->set_content(l+ "On "+ctime(time())+": &nbsp;&nbsp;"+ s+"<br/>");
    }
}


void init_module()
{
    add_data_storage(retrieve_tasks, restore_tasks);
}

void install_module()
{
#if 0
    log = find_object("/tasks.html");
    if ( !objectp(log) ) 
	log = get_factory(CLASS_DOCUMENT)->execute( 
	    ([ "name":"tasks.html",  ]));

    log->sanction_object(_STEAMUSER, SANCTION_ALL);
    log->move(find_object("/"));
#endif
}

mapping retrieve_tasks()
{
    if ( CALLER != _Database )
	THROW("Caller is not database !", E_ACCESS);
    mapping save = ([ ]);
    foreach ( indices(mTasks), mixed idx)
	if ( objectp(idx) ) {
	    save[idx] = ({});
	    foreach(mTasks[idx], object t )
		save[idx] += ({ mkmapping(indices(t), values(t)) });
	}
    return ([ "tasks": save, ]);
}

void restore_tasks(mapping data)
{
    if ( CALLER != _Database )
	THROW("Caller is not database !", E_ACCESS);
    foreach(indices(data["tasks"]), object o )
	foreach(data["tasks"][o], mapping m)
	{
	    LOG("Task="+sprintf("%O\n",m));
	    object t = add_task(o, m->obj, m->func, 
				m->params, m->descriptions);
	}
}

object add_task(object user, object obj, string func, array args,mapping desc)
{
    if ( !arrayp(mTasks[user]) )
	mTasks[user] = ({ });
    object t = task();
    t->obj = obj;
    t->func = func;
    t->params = args;
    t->descriptions = desc;
    t->tid = ++tid;
    mTasks[user] += ({ t });
    mTasks[tid] = t;

    TASK_DEBUG("added " + func + " for " + user->get_identifier() + 
	       " (id="+t->tid+")");
    
    require_save();
    return t;
}

array get_tasks(object user)
{
  return mTasks[user];
}


object get_task(int tid)
{
  return mTasks[tid];
}

mapping _get_tasks()
{
    return mTasks;
}

void tasks_done(object user)
{
    TASK_DEBUG("All Tasks done for "+ user->get_identifier());
    mTasks[user] = ({ });
    require_save();
}

void run_task(int tid)
{
    function f;
    object t = mTasks[tid];
    if ( !objectp(t) )
	return;
    
    TASK_DEBUG("Run Task " + t->func + " (id="+t->tid+")");
    f = t->obj->find_function(t->func);
    if ( !functionp(f) )
	THROW("Cannot find task '"+t->func+"' to execute !", E_ERROR);
    LOG("Running task " + tid + "\n");
    f(@t->params); 
    TASK_DEBUG("Task " + t->tid + " success !");
    mTasks[tid] = 0;
}

string get_identifier() { return "tasks"; }

void create_group_exit(object grp, object user)
{
    object dest = grp->query_attribute(GROUP_WORKROOM);
    object wr = user->query_attribute(USER_WORKROOM);
    array exits = wr->get_inventory_by_class(CLASS_EXIT);
    
    // check if exit already exists in workarea
    foreach ( exits, object ex )
	if ( ex->get_exit() == dest )
	    return;


    object factory = _Server->get_factory(CLASS_EXIT);
    object exit = factory->execute(
	([ "name": grp->parent_and_group_name() + " workarea", "exit_to": dest, ]) );
    exit->sanction_object(this(), SANCTION_ALL);
    exit->move(wr);
}

void join_invited_group(object grp, object user)
{
    grp->add_member(user);
    create_group_exit(grp, user);
}

void remove_group_exit(object grp, object user)
{
    object wr = user->query_attribute(USER_WORKROOM);
    if ( objectp(wr) ) {
	foreach(wr->get_inventory_by_class(CLASS_EXIT), object exit)
	    if ( exit->get_exit() == grp->query_attribute(GROUP_WORKROOM) )
	    {
		exit->delete();
		return;
	    }
    }
}
