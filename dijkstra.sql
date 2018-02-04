drop procedure if exists dijkstra;
delimiter //
create procedure dijkstra (s char(10), g char(10))
begin
  declare current_node char(10) default null;
  declare total_weight int unsigned default null;
  
  if (select s in (select node from nodes)) = false
  then
    signal sqlstate 'HY000'
      set message_text = 'Invalid start node specified.', mysql_errno = 1000;
  end if;

  if (select g in (select node from nodes)) = false
  then
    signal sqlstate 'HY000'
      set message_text = 'Invalid goal node specified.', mysql_errno = 1000;
  end if;
  
  set current_node := s;
  set total_weight := 0;
  
  drop temporary table if exists nodes_data;
  create temporary table nodes_data (
    node varchar(10) primary key,
    minimal_weight int unsigned,
    from_node varchar(10)
  );
  
  drop temporary table if exists done_flags;
  create temporary table done_flags (
    node varchar(10) primary key
  );

  drop temporary table if exists path;
  create temporary table path (
    seq int unsigned not null primary key auto_increment,
    node varchar(10),
    weight int unsigned
  );
  
  start transaction;
  insert into nodes_data values(s, 0, null);
  
  main_loop: loop
    begin
      declare target_node char(10) default null;
      declare current_weight int unsigned default null;
      declare minimal_weight int unsigned default null;
      declare done int default false;
      declare cur1 cursor for
        select
            edges.end_node,
            edges.weight,
            nd.minimal_weight
          from
            edges
            left join nodes_data nd on end_node = nd.node
            left join done_flags df on end_node = df.node
          where
            start_node = current_node
            and df.node is null;
      declare continue handler for not found set done = true;
      
      open cur1;

      node_loop: loop
        fetch cur1 into target_node, current_weight, minimal_weight;
        
        if done then
          leave node_loop;
        end if;
        
        -- print debug lol
        -- select * from nodes_data;
        -- select current_node, total_weight, target_node, current_weight, minimal_weight;
                
        if minimal_weight is null
        then
          insert into nodes_data (node, minimal_weight, from_node)
            values(target_node, total_weight + current_weight, current_node);
        else
          update nodes_data set
              minimal_weight = case
              when total_weight + current_weight < minimal_weight then
                total_weight + current_weight
              else
                minimal_weight
              end,
              from_node = case
              when total_weight + current_weight < minimal_weight then
                current_node
              else
                from_node
              end
            where
              node = target_node;
        end if;
      end loop;
      
      close cur1;
    end;
    insert into done_flags values(current_node);

    set current_node := (
      select
          nd.node
        from
          nodes_data nd
          left join done_flags df using(node)
        where
          df.node is null
        order by
          nd.minimal_weight
        limit 1);
    if current_node is null
    then
      leave main_loop;
    end if;
    set total_weight := (select minimal_weight from nodes_data where node = current_node);
      
  end loop;
  
  if (select count(1) from nodes_data where node = g) = 0
  then
    rollback;
    drop temporary table nodes_data;
    drop temporary table done_flags;
    drop temporary table path;
    signal sqlstate 'HY000'
      set message_text = 'No path found between the nodes.', mysql_errno = 1000;
  end if;
    
  set current_node := g;
  insert into path (node, weight) values(g, 0);

  summary_loop: loop
    begin
      declare previous_node char(10) default null;
      declare current_weight int unsigned default null;
      select
          from_node,
          minimal_weight
        into
          previous_node,
          current_weight
        from
          nodes_data
        where
          node = current_node;
        insert into path (node, weight)
          values(previous_node, current_weight);
      if previous_node is null
      then
        leave summary_loop;
      end if;
      set current_node := previous_node;
    end;
  end loop;
  
  select
      group_concat(node order by seq desc separator ',') as path,
      max(weight) as cost
    from
      path;
  commit;
  
  drop temporary table nodes_data;
  drop temporary table done_flags;
  drop temporary table path;
  
end;//
delimiter ;