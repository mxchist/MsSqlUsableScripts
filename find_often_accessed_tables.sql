declare @sql_server_uptime datetime2 ;
declare @analyze_rate int; 

declare @object_id bigint, @object_name varchar(255), @operations_qty bigint;

SELECT @sql_server_uptime = login_time
FROM sys.dm_exec_sessions
WHERE session_id =1;

-- suppose critical tables those who reads often than the 1 time per hour
select @analyze_rate = DATEDIFF(day, @sql_server_uptime, sysdatetime()) * 24 ;

if @analyze_rate is null
-- Common stats by all user requests
select distinct
	upt.index_id
	, upt.object_id
	, OBJECT_NAME (upt.object_id) as table_name
	, sum(upt.operations_qty) over (partition by index_id, object_id) as operations_qty
from (
	select
	us.index_id
	, us.object_id
	, us.user_scans
	, us.user_seeks
	from sys.dm_db_index_usage_stats as us
	inner join sys.indexes as si on us.object_id = si.object_id and si.index_id = us.index_id
	where us.database_id = 5
		and si.type = 1
) as ius
	unpivot (operations_qty
	for operation_type in (user_scans, user_seeks)
) as upt
order by operations_qty desc

else
-- Common stats by all user requests

declare often_accessed_tables cursor fast_forward local for
select distinct
	 ius.object_id
	 , object_name(object_id)
	, operations_qty
from (
	select
	us.index_id
	, us.object_id
	, us.user_scans
	, us.user_seeks
	, sum (isnull (us.user_scans, 0) + isnull (us.user_seeks, 0)) 
		over (partition by us.index_id, us.object_id) as operations_qty
	from sys.dm_db_index_usage_stats as us
	inner join sys.indexes as si on us.object_id = si.object_id and si.index_id = us.index_id
	where us.database_id = 5
		and si.type = 1
) as ius
where ius.operations_qty > @analyze_rate
order by operations_qty desc

open often_accessed_tables;

fetch next from often_accessed_tables into @object_id, @object_name, @operations_qty;

while (@@FETCH_STATUS = 0)
begin
	raiserror ('|%-30s|%12I64d|', 10, 1, @object_name, @operations_qty)
	fetch next from often_accessed_tables into @object_id, @object_name, @operations_qty;
end

close often_accessed_tables;
deallocate often_accessed_tables;