--
-- ORCA tests
--

-- show version
SELECT gp_opt_version();

-- master only tables

create schema orca;

create table orca.r();
alter table orca.r add column a int;
alter table orca.r add column b int;

insert into orca.r select i, i/3 from generate_series(1,20) i;

create table orca.s();
alter table orca.s add column c int;
alter table orca.s add column d int;

insert into orca.s select i, i/2 from generate_series(1,30) i;

set gp_log_optimizer=on;
set gp_optimizer=on;
----------------------------------------------------------------------

select * from orca.r;
select * from orca.r, orca.s where r.a=s.c;
select * from orca.r, orca.s where r.a<s.c+1 or r.a>s.c;
select sum(r.a) from orca.r;
select count(*) from orca.r;
select a, b from orca.r, orca.s group by a,b;
select r.a+1 from orca.r;
select * from orca.r, orca.s where r.a<s.c or (r.b<s.d and r.b>s.c);
select case when r.a<s.c then r.a<s.c else r.a<s.c end from orca.r, orca.s;
select case r.b<s.c when true then r.b else s.c end from orca.r, orca.s where r.a = s.d;
select * from orca.r limit 100;
select * from orca.r limit 10 offset 9;
select * from orca.r offset 10;
select sqrt(r.a) from orca.r;
select pow(r.b,r.a) from orca.r;
select b from orca.r group by b having  count(*) > 2;
select b from orca.r group by b having  count(*) <= avg(a) + (select count(*) from orca.s where s.c = r.b);
select sum(a) from orca.r group by b having count(*) > 2 order by b+1;
select sum(a) from orca.r group by b having count(*) > 2 order by b+1;

-- constants

select 0.001::numeric from orca.r;
select NULL::text, NULL::int from orca.r;
select 'helloworld'::text, 'helloworld2'::varchar from orca.r;
select 129::bigint, 5623::int, 45::smallint from orca.r;

select 0.001::numeric from orca.r;
select NULL::text, NULL::int from orca.r;
select 'helloworld'::text, 'helloworld2'::varchar from orca.r;
select 129::bigint, 5623::int, 45::smallint from orca.r;

--  distributed tables

----------------------------------------------------------------------
set gp_optimizer=off;

create table orca.foo (x1 int, x2 int, x3 int);
create table orca.bar1 (x1 int, x2 int, x3 int) distributed randomly;
create table orca.bar2 (x1 int, x2 int, x3 int) distributed randomly;

insert into orca.foo select i,i+1,i+2 from generate_series(1,10) i;

insert into orca.bar1 select i,i+1,i+2 from generate_series(1,20) i;
insert into orca.bar2 select i,i+1,i+2 from generate_series(1,30) i;

set gp_optimizer=on;
----------------------------------------------------------------------

-- produces result node

select x2 from orca.foo where x1 in (select x2 from orca.bar1);
select 1;
SELECT 1 AS one FROM orca.foo having 1 < 2;
SELECT generate_series(1,5) AS one FROM orca.foo having 1 < 2;
SELECT 1 AS one FROM orca.foo group by x1 having 1 < 2;
SELECT x1 AS one FROM orca.foo having 1 < 2;
----------------------------------------------------------------------
set gp_optimizer=off;

drop table orca.r cascade;
create table orca.r(a int, b int);
create unique index r_a on orca.r(a);
create index r_b on orca.r(b);

insert into orca.r select i, i%3 from generate_series(1,20) i;

drop table orca.s;
create table orca.s(c int, d int);

insert into orca.s select i%7, i%2 from generate_series(1,30) i;

analyze orca.r;
analyze orca.s;

set gp_optimizer=on;
----------------------------------------------------------------------

select * from orca.r, orca.s where r.a=s.c;

-- Materialize node
select * from orca.r, orca.s where r.a<s.c+1 or r.a>s.c;

-- empty target list
select r.* from orca.r, orca.s where s.c=2;

----------------------------------------------------------------------
set gp_optimizer=off;

create table orca.m();
alter table orca.m add column a int;
alter table orca.m add column b int;

create table orca.m1();
alter table orca.m1 add column a int;
alter table orca.m1 add column b int;

insert into orca.m select i-1, i%2 from generate_series(1,35) i;
insert into orca.m1 select i-2, i%3 from generate_series(1,25) i;

insert into orca.r values (null, 1);

set gp_optimizer=on;
----------------------------------------------------------------------

-- join types
select r.a, s.c from orca.r left outer join orca.s on(r.a=s.c);
select r.a, s.c from orca.r left outer join orca.s on(r.a=s.c and r.a=r.b and s.c=s.d) order by r.a,s.c;
select r.a, s.c from orca.r left outer join orca.s on(r.a=s.c) where s.d > 2 or s.d is null order by r.a;
select r.a, s.c from orca.r right outer join orca.s on(r.a=s.c);
select * from orca.r where exists (select * from orca.s where s.c=r.a + 2);
select * from orca.r where exists (select * from orca.s where s.c=r.b);
select * from orca.m where m.a not in (select a from orca.m1 where a=5);
select * from orca.m where m.a not in (select a from orca.m1);
select * from orca.m where m.a in (select a from orca.m1 where m1.a-1 = m.b);

-- enable_hashjoin=off; enable_mergejoin=on
select 1 from orca.m, orca.m1 where m.a = m1.a and m.b!=m1.b;

-- plan.qual vs hashclauses/join quals:
select * from orca.r left outer join orca.s on (r.a=s.c and r.b<s.d) where s.d is null;
-- select * from orca.r m full outer join orca.r m1 on (m.a=m1.a) where m.a is null;

-- sort
select * from orca.r join orca.s on(r.a=s.c) order by r.a, s.d;
select * from orca.r join orca.s on(r.a=s.c) order by r.a, s.d limit 10;
select * from orca.r join orca.s on(r.a=s.c) order by r.a + 5, s.d limit 10;

-- group by
select 1 from orca.m group by a+b;

-- join with const table
select * from orca.r where a = (select 1);

-- union with const table
select * from ((select a as x from orca.r) union (select 1 as x )) as foo order by x;

----------------------------------------------------------------------
set gp_optimizer=off;

insert into orca.m values (1,-1), (1,2), (1,1);

set gp_optimizer=on;
----------------------------------------------------------------------

-- computed columns
select a,a,a+b from orca.m;
select a,a+b,a+b from orca.m;

-- func expr
select * from orca.m where a=abs(b);

-- grouping sets

select a,b,count(*) from orca.m group by grouping sets ((a), (a,b));
select b,count(*) from orca.m group by grouping sets ((a), (a,b));
select a,count(*) from orca.m group by grouping sets ((a), (a,b));
select a,count(*) from orca.m group by grouping sets ((a), (b));
select a,b,count(*) from orca.m group by rollup(a, b);
select count(*) from orca.m group by ();
select a, count(*) from orca.r group by (), a;
select a, count(*) from orca.r group by grouping sets ((),(a));

select a, b, count(*) c from orca.r group by grouping sets ((),(a), (a,b)) order by b,a,c;
select a, count(*) c from orca.r group by grouping sets ((),(a), (a,b)) order by b,a,c;

-- arrays
select array[array[a,b]], array[b] from orca.r;

-- setops
select a, b from m union select b,a from orca.m;
SELECT a from m UNION ALL select b from orca.m UNION ALL select a+b from orca.m group by 1;

----------------------------------------------------------------------
set gp_optimizer=off;

drop table if exists orca.foo;
create table orca.foo(a int, b int, c int, d int);

drop table if exists orca.bar;
create table orca.bar(a int, b int, c int);

insert into orca.foo select i, i%2, i%4, i-1 from generate_series(1,40)i;
insert into orca.bar select i, i%3, i%2 from generate_series(1,30)i;

set gp_optimizer=on;
----------------------------------------------------------------------

--- distinct operation
SELECT distinct a, b from orca.foo;
SELECT distinct foo.a, bar.b from orca.foo, orca.bar where foo.b = bar.a;
SELECT distinct a, b from orca.foo;
SELECT distinct a, count(*) from orca.foo group by a;
SELECT distinct foo.a, bar.b, sum(bar.c+foo.c) from orca.foo, orca.bar where foo.b = bar.a group by foo.a, bar.b;
SELECT distinct a, count(*) from orca.foo group by a;
SELECT distinct foo.a, bar.b from orca.foo, orca.bar where foo.b = bar.a;
SELECT distinct foo.a, bar.b, sum(bar.c+foo.c) from orca.foo, orca.bar where foo.b = bar.a group by foo.a, bar.b;

SELECT distinct a, b from orca.foo;
SELECT distinct a, count(*) from orca.foo group by a;
SELECT distinct foo.a, bar.b from orca.foo, orca.bar where foo.b = bar.a;
SELECT distinct foo.a, bar.b, sum(bar.c+foo.c) from orca.foo, orca.bar where foo.b = bar.a group by foo.a, bar.b;

--- window operations
select row_number() over() from orca.foo order by 1;
select rank() over(partition by b order by count(*)/sum(a)) from orca.foo group by a, b order by 1;
select row_number() over(order by foo.a) from orca.foo inner join orca.bar using(b) group by foo.a, bar.b, bar.a;
select 1+row_number() over(order by foo.a+bar.a) from orca.foo inner join orca.bar using(b);
select row_number() over(order by foo.a+ bar.a)/count(*) from orca.foo inner join orca.bar using(b) group by foo.a, bar.a, bar.b;
select count(*) over(partition by b order by a range between 1 preceding and (select count(*) from orca.bar) following) from orca.foo;
select a+1, rank() over(partition by b+1 order by a+1) from orca.foo order by 1, 2;

--- cte 
with x as (select a, b from orca.r)
select rank() over(partition by a, case when b = 0 then a+b end order by b asc) as rank_within_parent from x order by a desc ,case when a+b = 0 then a end ,b;

----------------------------------------------------------------------
set gp_optimizer=off;

drop table if exists orca.rcte;
create table orca.rcte(a int, b int, c int);

insert into orca.rcte select i, i%2, i%3 from generate_series(1,40)i;

-- select disable_xform('CXformInlineCTEConsumer');
set gp_optimizer=on;
----------------------------------------------------------------------

with x as (select * from orca.rcte where a < 10) select * from x x1, x x2;
with x as (select * from orca.rcte where a < 10) select * from x x1, x x2 where x2.a = x1.b;
with x as (select * from orca.rcte where a < 10) select a from x union all select b from x;
with x as (select * from orca.rcte where a < 10) select * from x x1 where x1.b = any (select x2.a from x x2 group by x2.a);
with x as (select * from orca.rcte where a < 10) select * from x x1 where x1.b = all (select x2.a from x x2 group by x2.a);
with x as (select * from orca.rcte where a < 10) select * from x x1, x x2, x x3 where x2.a = x1.b and x3.b = x2.b                                                                                   ;
with x as (select * from orca.rcte where a < 10) select * from x x2 where x2.b < (select avg(b) from x x1);
with x as (select r.a from orca.r, orca.s  where r.a < 10 and s.d < 10 and r.a = s.d) select * from x x1, x x2;
with x as (select r.a from orca.r, orca.s  where r.a < 10 and s.c < 10 and r.a = s.c) select * from x x1, x x2;
with x as (select * from orca.rcte where a < 10) (select a from x x2) union all (select max(a) from x x1);
with x as (select * from orca.r) select * from x order by a;
-- with x as (select * from orca.rcte where a < 10) select * from x x1, x x2 where x2.a = x1.b limit 1;

----------------------------------------------------------------------
-- correlated execution
select (select 1 union select 2);
select (select generate_series(1,5));
select (select a from orca.foo inner1 where inner1.a=outer1.a  union select b from orca.foo inner2 where inner2.b=outer1.b) from orca.foo outer1;
select (select generate_series(1,1)) as series;
select generate_series(1,5);
select a, c from orca.r, orca.s where a = any (select c) order by a, c limit 10;
select a, c from orca.r, orca.s where a = (select c) order by a, c limit 10;
select a, c from orca.r, orca.s where a  not in  (select c) order by a, c limit 10;
select a, c from orca.r, orca.s where a  = any  (select c from orca.r) order by a, c limit 10;
select a, c from orca.r, orca.s where a  <> all (select c) order by a, c limit 10;
----------------------------------------------------------------------
set gp_optimizer=off;

CREATE TABLE orca.onek (
unique1 int4,
unique2 int4,
two int4,
four int4,
ten int4,
twenty int4,
hundred int4,
thousand int4,
twothousand int4,
fivethous int4,
tenthous int4,
odd int4,
even int4,
stringu1 name,
stringu2 name,
string4 name
);

insert into orca.onek values (931,1,1,3,1,11,1,31,131,431,931,2,3,'VJAAAA','BAAAAA','HHHHxx');
insert into orca.onek values (714,2,0,2,4,14,4,14,114,214,714,8,9,'MBAAAA','CAAAAA','OOOOxx');
insert into orca.onek values (711,3,1,3,1,11,1,11,111,211,711,2,3,'JBAAAA','DAAAAA','VVVVxx');
insert into orca.onek values (883,4,1,3,3,3,3,83,83,383,883,6,7,'ZHAAAA','EAAAAA','AAAAxx');
insert into orca.onek values (439,5,1,3,9,19,9,39,39,439,439,18,19,'XQAAAA','FAAAAA','HHHHxx');
insert into orca.onek values (670,6,0,2,0,10,0,70,70,170,670,0,1,'UZAAAA','GAAAAA','OOOOxx');
insert into orca.onek values (543,7,1,3,3,3,3,43,143,43,543,6,7,'XUAAAA','HAAAAA','VVVVxx');

set gp_optimizer=on;
----------------------------------------------------------------------

select ten, sum(distinct four) from orca.onek a
group by ten 
having exists (select 1 from orca.onek b where sum(distinct a.four) = b.four);

-- indexes on partitioned tables
create table orca.pp(a int) partition by range(a)(partition pp1 start(1) end(10));
create index pp_a on orca.pp(a);
explain select * from orca.pp where a=5;

----------------------------------------------------------------------

-- list partition tests 

-- test homogeneous partitions 
drop table if exists orca.t;

create table orca.t ( a int, b char(2), to_be_drop int, c int, d char(2), e int)
distributed by (a) 
partition by list(d) (partition part1 values('a'), partition part2 values('b'));

insert into orca.t 
	select i, i::char(2), i, i, case when i%2 = 0 then 'a' else 'b' end, i 
	from generate_series(1,100) i;

select * from orca.t order by 1, 2, 3, 4, 5, 6 limit 4;

alter table orca.t drop column to_be_drop;

select * from orca.t order by 1, 2, 3, 4, 5 limit 4;

insert into orca.t (d, a) values('a', 0);
insert into orca.t (a, d) values(0, 'b');

select * from orca.t order by 1, 2, 3, 4, 5 limit 4;


-- test appendonly
drop table if exists orca.t;

create table orca.t ( a int, b char(2), to_be_drop int, c int, d char(2), e int)
distributed by (a) 
partition by list(d) (partition part1 values('a') with (appendonly=true, compresslevel=5, orientation=column), partition part2 values('b') with (appendonly=true, compresslevel=5, orientation=column));

insert into orca.t 
	select i, i::char(2), i, i, case when i%2 = 0 then 'a' else 'b' end, i 
	from generate_series(1,100) i;

select * from orca.t order by 1, 2, 3, 4, 5, 6 limit 4;

alter table orca.t drop column to_be_drop;

select * from orca.t order by 1, 2, 3, 4, 5 limit 4;

insert into orca.t 
	select i, i::char(2), i, case when i%2 = 0 then 'a' else 'b' end, i 
	from generate_series(1,100) i;

select * from orca.t order by 1, 2, 3, 4, 5 limit 4;


-- test heterogeneous partitions
drop table if exists orca.t;

create table orca.t ( timest character varying(6), user_id numeric(16,0) not null, to_be_drop char(5), tag1 char(5), tag2 char(5)) 
distributed by (user_id) 
partition by list (timest) (partition part201203 values('201203') with (appendonly=true, compresslevel=5, orientation=column), partition part201204 values('201204') with (appendonly=true, compresslevel=5, orientation=row), partition part201205 values('201205'));

insert into orca.t values('201203',0,'drop', 'tag1','tag2');

alter table orca.t drop column to_be_drop;

alter table orca.t add partition part201206 values('201206') with (appendonly=true, compresslevel=5, orientation=column);
alter table orca.t add partition part201207 values('201207') with (appendonly=true, compresslevel=5, orientation=row);
alter table orca.t add partition part201208 values('201208');

insert into orca.t values('201203',1,'tag1','tag2');
insert into orca.t values('201204',2,'tag1','tag2');
insert into orca.t values('201205',1,'tag1','tag2');
insert into orca.t values('201206',2,'tag1','tag2');
insert into orca.t values('201207',1,'tag1','tag2');
insert into orca.t values('201208',2,'tag1','tag2');

-- test projections
select * from orca.t order by 1,2;

select tag2, tag1 from orca.t order by 1, 2;;

select tag1, user_id from orca.t order by 1, 2;

insert into orca.t(user_id, timest, tag2) values(3, '201208','tag2');

select * from orca.t order by 1, 2;

-- test project elements in TVF

CREATE FUNCTION orca.csq_f(a int) RETURNS int AS $$ select $1 $$ LANGUAGE SQL;

CREATE TABLE orca.csq_r(a int);

INSERT INTO orca.csq_r VALUES (1);

SELECT * FROM orca.csq_r WHERE a IN (SELECT * FROM orca.csq_f(orca.csq_r.a));

-- clean up
drop schema orca cascade;