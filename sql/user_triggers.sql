delimiter $$
drop trigger post_user_delete $$
create trigger post_user_delete after delete on users
for each row
begin
	update documents set owner = 1 where owner = old.id;
	update versions set user = 1 where user = old.id;
	delete from grp_user where user=old.id;
end $$

drop trigger post_groups_delete $$
create trigger post_groups_delete after delete on groups
for each row
begin
	update documents set grp=1 where grp=old.id;
	delete g from grp_user g where g.grp=old.id; 
end $$


delimiter ;
