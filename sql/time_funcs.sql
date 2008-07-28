delimiter $$

drop function if exists intervals_overlap $$
create function intervals_overlap(siv1 datetime, eiv1 datetime, siv2 datetime, eiv2 datetime) returns integer  deterministic
begin
	if eiv1 is null or eiv1 = '0000-00-00' then
	   set eiv1 = siv1;
	end if;

	if eiv2 is null or eiv2 = '0000-00-00' then
	   set eiv2 = siv2;
	end if;


	return not ((eiv2 < siv1 and eiv2 < eiv1) or (eiv1 < siv2 and eiv1 < eiv2));
end $$
delimiter ;
