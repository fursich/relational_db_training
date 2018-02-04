-- ******************
-- テーブル
-- ******************
drop table if exists nodes;
create table nodes (
  node varchar(10) primary key
);

drop table if exists edges;
create table edges (
  start_node varchar(10),
  end_node varchar(10),
  weight int
);

-- ******************
-- 閉グラフ例
-- ******************
delete from nodes;
insert into nodes values
  ('a'), ('b'), ('c'), ('d'), ('z');

delete from edges;
insert into edges values
  ('a', 'b', 3), ('b', 'a', 3),
  ('b', 'c', 2), ('c', 'b', 2),
  ('c', 'a', 5), ('a', 'c', 5),
  ('a', 'd', 1), ('d', 'a', 1),
  ('d', 'b', 7), ('b', 'd', 7);

-- ******************
-- 開グラフ例
-- ******************
delete from nodes;
insert into nodes values
  ('a'), ('b'), ('c'), ('d');

delete from edges;
insert into edges values
  ('a', 'b', 3), ('b', 'a', 3),
  ('b', 'c', 1), ('c', 'b', 1),
  ('a', 'd', 4), ('d', 'a', 4);

-- ******************
-- プロシージャ呼び出し
-- ******************
call find_loop();
