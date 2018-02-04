-- ******************
-- （データ例）
-- ******************
-- drop table if exists nodes;
-- create table nodes (
--   node varchar(10) primary key
-- );
-- drop table if exists edges;
-- create table edges (
--   start_node varchar(10),
--   end_node varchar(10),
--   weight int
-- );

-- ******************
-- 閉グラフ例
-- ******************
-- insert into nodes values
--   ('a'), ('b'), ('c'), ('d'), ('z');
--
-- insert into edges values
--   ('a', 'b', 3), ('b', 'a', 3),
--   ('b', 'c', 2), ('c', 'b', 2),
--   ('c', 'a', 5), ('a', 'c', 5),
--   ('a', 'd', 1), ('d', 'a', 1),
--   ('d', 'b', 7), ('b', 'd', 7);

-- ******************
-- 開グラフ例
-- ******************
-- insert into nodes values
--   ('a'), ('b'), ('c'), ('d');
--
-- insert into edges values
--   ('a', 'b', 3), ('b', 'a', 3),
--   ('b', 'c', 1), ('c', 'b', 1),
--   ('a', 'd', 4), ('d', 'a', 4);

-- ******************
-- 呼び出し
-- ******************
-- call find_loop();

-- ******************
-- プロシージャ
-- 始点sを固定した時、sの連結成分上に
-- 閉路があるかどうかを判定する
-- ******************
drop procedure if exists find_loop_from;
delimiter //
create procedure find_loop_from(IN s varchar(10), OUT is_loop boolean)
begin
  -- 始点が実際に存在するかを確認する
  if (select s in (select node from nodes)) = false then
    signal sqlstate 'HY000'
    set message_text = 'Invalid start node specified.', mysql_errno = 1000;
  end if;

  -- 確認済みの辺を保持する
  -- 通行した辺を逆方向に戻り、閉路判定されてしまうことを防ぐ
  drop temporary table if exists inspected_edges;
  create temporary table inspected_edges (
    start_node varchar(10),
    end_node   varchar(10)
  );

  -- 確認済みノードを一時的に保持するテーブル
  drop temporary table if exists visited_nodes;
  create temporary table visited_nodes (
    node varchar(10) primary key,
    active boolean default false
  );

  -- 頂点s（初期値）をactiveにする
  insert into visited_nodes values(s, true);

  main_loop: loop
    begin
      declare current_node varchar(10);
      declare not_found boolean default false;
      declare found boolean default false;
      declare next_node varchar(10);
      declare target_count int;

      declare end_node_pointer cursor for
        select ed.start_node, ed.end_node
          from edges ed
          inner join visited_nodes vn on
            ed.start_node = vn.node
          left join inspected_edges ie on
            ed.start_node = ie.start_node
            and ed.end_node   = ie.end_node
          where
            vn.active = true
            and ie.start_node is null;

      declare continue handler for not found set not_found = true;

      open end_node_pointer;

      set target_count := 0;
      node_loop: loop
        fetch end_node_pointer into current_node, next_node;

        if not_found then
          leave node_loop;
        end if;

        set target_count = target_count + 1;

        -- -- 現在のノードをinactiveに倒す
        update visited_nodes set active = false where node = current_node;

        -- 次のノードがすでに訪問済みなら他に経路があると判断（閉路が存在）
        if (select count(1) from visited_nodes where node = next_node) = 1 then
          set found = true;
          leave node_loop;
        else
          insert into visited_nodes values(next_node, true);
        end if;

        -- 調査済みの辺を対象から外す
        insert into inspected_edges values
          (current_node, next_node), (next_node, current_node);

      end loop;

      close end_node_pointer;

      if found then
        drop temporary table visited_nodes;
        set is_loop = true;
        leave main_loop;
      end if;

      if not_found and target_count = 0 then
        drop temporary table visited_nodes;
        set is_loop = false;
        leave main_loop;
      end if;

    end;
  end loop;

end;//
delimiter ;

-- ******************
-- プロシージャ
-- 閉路があるかどうかを判定する
-- ******************
drop procedure if exists find_loop;
delimiter //
create procedure find_loop()
begin
  declare start_node varchar(10);
  declare done boolean default false;
  declare msg varchar(256);

  declare node_cursor cursor for
    select node from nodes;
  declare continue handler for not found set done = true;

  open node_cursor;
  node_loop: loop
    fetch node_cursor into start_node;

    if done then
      leave node_loop;
    end if;

    -- 始点ごとに閉路を探索する
    -- 一つでも発見すると終了
    call find_loop_from(start_node, @found);

    if @found then
      leave node_loop;
    end if;

  end loop;
  close node_cursor;

  if @found then
    set msg = 'detected ** (closed graph)';
  else
    set msg = 'not detected ** (opened graph)';
  end if;
  select concat("** closed path(s) ", msg) AS 'GRAPH CLOSEDNESS:';

end;//
delimiter ;

-- デバッグ用
-- drop procedure if exists debug_msg;
-- create procedure debug_msg(msg varchar(255))
--   select concat("** ", msg) AS '** DEBUG:';
