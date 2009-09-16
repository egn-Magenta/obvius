delimiter $$

drop procedure if exists stupid $$
create procedure stupid(n integer unsigned)
begin
        while n > 0 do
              set n = n - 1;
              select true;
        end while;
end $$

delimiter ;
