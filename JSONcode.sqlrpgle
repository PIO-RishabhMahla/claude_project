**FREE

ctl-opt dftactgrp(*no) actgrp(*new);

dcl-s jsonData varchar(500);
dcl-s result   varchar(200);
dcl-s skill    varchar(50);
dcl-s debugValue varchar(1000);


//JSON_OBJECT

exec sql
  select cast(json_object('name' value 'Rishabh',
                     'age'  value 25) as varchar(500))
    into :jsonData
    from sysibm.sysdummy1;

debugValue = 'JSON_OBJECT: ' + jsonData;


//JSON_ARRAY

exec sql
  select cast(json_array('RPG','SQL','Java') as 
    varchar(500))
    into :jsonData
    from sysibm.sysdummy1;

debugValue = 'JSON_ARRAY: ' + jsonData;


jsonData = '{"name":"Rishabh","skills":["RPG","SQL","Java"]}';

//JSON_VALUE (single value)

exec sql
  select json_value(:jsonData, '$.name')
    into :result
    from sysibm.sysdummy1;

debugValue = 'JSON_VALUE name: ' + result;

//JSON_QUERY (array/object)

exec sql
  select json_query(:jsonData, '$.skills')
    into :result
    from sysibm.sysdummy1;

debugValue = 'JSON_QUERY skills: ' + result;


//JSON_TABLE Array Rows

exec sql
  declare c1 cursor for
    select skill
    from json_table(:jsonData,
                    '$.skills[*]'
                    columns (
                      skill varchar(20) path '$'
                    )) as jt;

exec sql open c1;

dow sqlcode = 0;
  exec sql fetch c1 into :skill;
  if sqlcode = 0;
    debugValue = 'Skill:'+ skill;
  endif;
enddo;

exec sql close c1;

*inlr = *on;
return;
