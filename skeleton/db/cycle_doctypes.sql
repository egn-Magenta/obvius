# $Id$
#define CYCLE
#include <db/structure.sql>

# # If the processed file is included file for cycle_doctypes, the
# resulting file is stripped from #ifndef CYCLE and is not valid anymore.
# Explicitly die in this case.
#ifndef HAS_STRUCTURE_SQL
#error Included db/structure.sql is wrong, check your Obvius installation
#endif

#include <db/perms.sql>
