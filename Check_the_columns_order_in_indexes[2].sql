set nocount on;
set quoted_identifier on;
go

declare @object_id int = ( select OBJECT_ID('dbo.ORDERS', 'U') ), @index_name nvarchar(255), @index_id int;
declare @statement nvarchar(4000), @column_name nvarchar(255), @column_list nvarchar(4000);
declare @enter nvarchar(1) = '
';

print @object_id
print object_name(@object_id)
print schema_name(@object_id)

begin try
	drop table #distinct_values;
end try
begin catch
end catch;

create table #distinct_values (id int primary key identity (1,1), column_name nvarchar(255), qty int
,  unique (column_name, qty));

declare find_distinct_values cursor fast_forward local for
select distinct
	concat('', sc.name, '')
from sys.index_columns as ic
inner join sys.indexes as si on si.index_id = ic.index_id and si.object_id = ic.object_id
inner join sys.columns as sc on sc.column_id = ic.column_id and sc.object_id = si.object_id
where  ic.is_included_column = 0
	and si.object_id = @object_id
	and si.type <> 1
;

open find_distinct_values;
fetch next from find_distinct_values into @column_name;

if @@FETCH_STATUS = 0
	set @statement = 'select' + @enter + 'count(distinct ' + @column_name + ')' + ' as ' + @column_name + @enter;
if @@FETCH_STATUS = 0
	set @column_list = @column_name;
fetch next from find_distinct_values into @column_name

while (@@FETCH_STATUS = 0)
begin
	set @statement += ', count(distinct ' + @column_name + ')' + ' as ' + @column_name + @enter;
	set @column_list += ', ' + @column_name;
	fetch next from find_distinct_values into @column_name
end

set @statement += 'from ' + 'dbo.' + QUOTENAME (OBJECT_NAME(@object_id)) + @enter;
print @statement;

execute ( 'insert into #distinct_values (column_name, qty)
select column_name, qty
from (' + @statement + ') as t
unpivot
(
qty for column_name in (' + @column_list + ')
) as l;
'
)

close find_distinct_values;
deallocate find_distinct_values;

-- ===================

declare check_indexes cursor fast_forward local for
select
si.name, si.index_id
from sys.indexes as si 
where   si.object_id = ( select OBJECT_ID('dbo.ORDERS', 'U') )
	and si.type <> 1
order by si.index_id;

open check_indexes;

fetch next from check_indexes into @index_name, @index_id;

while @@FETCH_STATUS = 0
begin

	select
		sc.name
		, dv.qty
	from sys.index_columns as ic
	inner join sys.indexes as si on si.index_id = ic.index_id and si.object_id = ic.object_id
	inner join sys.columns as sc on sc.column_id = ic.column_id and sc.object_id = si.object_id
	inner join #distinct_values as dv on dv.column_name = sc.name
	where  ic.is_included_column = 0
		and si.object_id = @object_id
		and si.index_id = @index_id
	order by ic.index_column_id;

	fetch next from check_indexes into @index_name, @index_id;
end

close check_indexes;
deallocate check_indexes;

select 
*
from #distinct_values

