# XXX When Obvius starts to write on one handle as one user and read on
# another handle as another user, this needs adjustment:

use mysql;
#grant select on ${dbname}.* to ${dbname}_normal@localhost identified by 'default_normal';
grant select,insert,update,delete on ${dbname}.* to ${dbname}_normal@localhost identified by 'default_normal';
#grant insert,update on ${dbname}.subscribers to ${dbname}_normal@localhost;
#grant insert,update,delete on ${dbname}.subscriptions to ${dbname}_normal@localhost;


# Local Variables: ***
# mode:sql ***
# tab-width:2 ***
# End: ***
