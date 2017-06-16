#!/bin/bash
# Code gebaseerd op:
# https://stackoverflow.com/a/14579117 (Coalesce equivalent for nth not null value - MySQL)
# https://www.experts-exchange.com/articles/1250/3-Ways-to-Speed-Up-MySQL.html
# https://stackoverflow.com/a/1671056 (Can MySQL replace multiple characters?)
# https://forum.civicrm.org/index.php?topic=7567.0 (Import date created and/or date modified?)
#SELECT * FROM dbasetocivicrm.testimport1
host='localhost'
user='root'
pass=''
database='dbasetocivicrm'
encoding='CP437'
from=10
till=100000000
function main () {
  step$1
}
function mysqlquery () {
  echo mysqlquery...
#        -p$pass \
  mysql -h $host \
        -u $user \
        $database \
        -e "$1;" \
        2>&1 | grep -v 'Using a password on the command line interface can be insecure.'
}
function step () {
  echo Please specify step number
}
function step1 () {
echo Create functions, procedures, tables and indexes
createfunctions
createprocedures
createtables
createindexes
echo
echo Delete nonfunctional rows
mysqlquery "
DELETE FROM dbasetocivicrm.ASS
WHERE       relatienr=''
"
echo
echo Do the first import query
mysqlquery "
SET @query1 = CONCAT(\"
CREATE TABLE dbasetocivicrm.tempimport AS
SELECT  TRIM(     LEADING '0'
                  FROM    ass.relatienr
        )             AS  'Contactnummer'
,       NULL          AS  'Overgezet'
,       ass.tit       AS  'Voorvoegsel Persoon'
,       ass.na2       AS  'Voornaam'
,       ass.hisn      AS  'Tussenvoegsel'
,       ass.na1       AS  'Achternaam'
,       ass.tav
,       ass.voornaam  AS  'Roepnaam'
,       ass.inforegel
,       CONCAT(   ass.ad1
        ,         ' '
        ,         ass.huisnr
        )             AS  'Straat en huisnummer'
,       ass.ad1       AS  'Straatnaam'
,       ass.huisnr    AS  'Huisnummer'
,       ass.pos       AS  'Postcode'
,       ass.pla       AS  'Plaats'
,       (         SELECT  SPLIT_STR(  omschrijv
                          ,           '  '
                          ,           1
                          )       AS  naam
                  FROM    dbasetocivicrm.AMCODE amcode
                  WHERE   amcode.tabelnr = '002'
                  AND     amcode.waarde  = ass.lan
        )             AS  'Land'
,       ass.cod
,       ass.bdat      AS  'Gemaakt'
,       IF( ass.mutd = '1970-01-01'
        ,   ass.bdat
        ,   ass.mutd
        )             AS  'Wijzigingsdatum'
,       COALESCE((SELECT  tempopc.new
                  FROM    dbasetocivicrm.tempopc tempopc
                  WHERE   tempopc.old = ass.opc
        ), 1)         AS  'Wijziger'
\",
tnSELECT(6)
,
eaSELECT(6)
,
ibSELECT(5)
,\"
FROM    dbasetocivicrm.ASS        ass
\",
tnJOIN(6)
,
eaJOIN(6)
,
ibJOIN(5)
,\"
WHERE   ass.verwijderd  = 0
AND     ass.relatienr BETWEEN $from AND $till
\"
)
;
PREPARE query1
FROM   @query1
;
EXECUTE query1
"
echo
echo Do the second import query
mysqlquery "
DROP TABLE IF EXISTS dbasetocivicrm.testimport1
"
mysqlquery "
SET @query2 = CONCAT(\"
CREATE TABLE testimport1 AS
SELECT *
\",
SELECTseparate(0, 6, 'tn')
,
SELECTseparate(0, 1, 'ea')
,\"
FROM dbasetocivicrm.tempimport importtable
\"
)
;
PREPARE query2
FROM   @query2
;
EXECUTE query2
"
echo
echo Delete contacts and create them again
mysqlquery "
DELETE
FROM  civicrm.civicrm_contact
WHERE id
        BETWEEN $from
        AND     $till
"
mysqlquery "
INSERT INTO civicrm.civicrm_contact(  id
            ,                         contact_type
            )
SELECT  Contactnummer
,       'Individual'
FROM  dbasetocivicrm.testimport1
WHERE Contactnummer BETWEEN $from AND $till
"
echo
echo
echo Drop indexes, tables, procedures and functions
dropindexes
droptables
dropprocedures
dropfunctions
}
function step2 () {
echo Create functions, procedures and indexes
createfunctions
createprocedures
createindexes
echo
echo Delete some rows from log
mysqlquery "
DELETE
FROM  civicrm.civicrm_log
WHERE entity_id
        BETWEEN $from
        AND     $till
"
echo
echo Update created_date and modified_date on all contacts
mysqlquery "
INSERT
INTO    civicrm.civicrm_contact ( id
        ,                         created_date
        ,                         modified_date
        )
SELECT  Contactnummer
,       Gemaakt
,       Wijzigingsdatum
FROM    dbasetocivicrm.testimport1
WHERE   Gemaakt != '1970-01-01'
ON      DUPLICATE KEY
UPDATE  created_date  = Gemaakt
,       modified_date = Wijzigingsdatum
"
echo
echo Insert modified_date for all contacts in log
mysqlquery "
INSERT
INTO    civicrm.civicrm_log(  entity_table
        ,                     entity_id
        ,                     data
        ,                     modified_id
        ,                     modified_date
        )
SELECT  'civicrm_contact'
,       Contactnummer
,       CONCAT( 'civicrm_contact,'
        ,       Contactnummer
        )
,       Wijziger
,       Wijzigingsdatum
FROM    dbasetocivicrm.testimport1
"
echo
echo Create tables
createtables
echo
echo Delete notes from note
mysqlquery "
DELETE
FROM  civicrm.civicrm_note
WHERE contact_id
"
echo
echo Create notes in note
mysqlquery "
INSERT INTO civicrm.civicrm_note(id, entity_table, entity_id, note, contact_id, modified_date, subject, privacy)
SELECT  TRIM( LEADING '0'
              FROM    hfnotie.bestnummer
        )                 AS f1
,       'civicrm_contact' AS f2
,       TRIM( LEADING '0'
              FROM    SUBSTR( hfnotie.sleutel
                      ,       4
                      )
        )                 AS f3
,       notities.notitie  AS f4
,       COALESCE( ( SELECT  tempopc.new
                    FROM  dbasetocivicrm.tempopc  tempopc
                    WHERE   tempopc.old = hfnotie.opc
                  )
        ,         1
        )                 AS f5
,       IF( hfnotie.mutd = '1970-01-01'
        ,   hfnotie.bdat
        ,   hfnotie.mutd
        )                 AS f6
,       NULL              AS f7
,       0                 AS f8
FROM      dbasetocivicrm.HFNOTIE  hfnotie
LEFT JOIN dbasetocivicrm.notities notities  ON  TRIM( LEADING '0'
                                                      FROM    hfnotie.bestnummer
                                                ) = notities.id
INNER JOIN  civicrm.civicrm_contact contact ON contact.id = TRIM( LEADING '0'
                                                                  FROM    SUBSTR( hfnotie.sleutel
                                                                          ,       4
                                                                          )
                                                            )
WHERE   SUBSTR( hfnotie.sleutel
        ,       1
        ,       3
        ) = 'ass'
"
echo
echo Insert modified_date for all notes in log
mysqlquery "
INSERT INTO civicrm.civicrm_log(entity_table, entity_id, data, modified_id, modified_date)
SELECT  f1
,       f2
,       f3
,       f4
,       bdat
FROM    dbasetocivicrm.tempnotitie
UNION ALL
SELECT  f1
,       f2
,       f3
,       f4
,       mutd
FROM    dbasetocivicrm.tempnotitie  tempnotitie
WHERE   tempnotitie.mutd != '1970-01-01'
"
echo
echo Delete bankaccounts
mysqlquery "
DELETE
FROM  civicrm.civicrm_bank_account
"
echo
echo Delete bankaccount references
mysqlquery "
DELETE
FROM  civicrm.civicrm_bank_account_reference
"
echo
echo Create bankaccounts
mysqlquery "
CALL INSERT_BANK_ACCOUNTS(5)
"
echo
echo Create bankaccount references
mysqlquery "
CALL INSERT_BANK_ACCOUNT_REFERENCES(5)
"
echo
echo Drop indexes, tables, procedures and functions
dropindexes
droptables
dropprocedures
dropfunctions
}
function dropindexes () {
  echo dropindexes...
  mysqlquery "
  CALL
  DROP_INDEX_IF_EXISTS( 'dbasetocivicrm'
  ,                     'ASS'
  ,                     'ASS_FIELD1'
  )
  "
  mysqlquery "
  CALL
  DROP_INDEX_IF_EXISTS( 'dbasetocivicrm'
  ,                     'VMSLREL'
  ,                     'VMSLREL_FIELD1'
  )
  "
  mysqlquery "
  CALL
  DROP_INDEX_IF_EXISTS( 'dbasetocivicrm'
  ,                     'VMSLREL'
  ,                     'VMSLREL_FIELD1_2_6'
  )
  "
  mysqlquery "
  CALL
  DROP_INDEX_IF_EXISTS( 'dbasetocivicrm'
  ,                     'testimport1'
  ,                     'testimport1_FIELD1'
  )
  "
}
function createindexes () {
  dropindexes
  echo createindexes...
  mysqlquery "
  ALTER
  TABLE dbasetocivicrm.ASS
  ADD
  INDEX ASS_FIELD1 (  relatienr
        )
  "
  mysqlquery "
  ALTER
  TABLE dbasetocivicrm.VMSLREL
  ADD
  INDEX VMSLREL_FIELD1 (  relatienr
        )
  "
  mysqlquery "
  ALTER
  TABLE dbasetocivicrm.VMSLREL
  ADD
  INDEX VMSLREL_FIELD1_2_6 (  relatienr
        ,                     sleutelcd
        ,                     volgnummer
        )
  "
  mysqlquery "
  ALTER
  TABLE dbasetocivicrm.testimport1
  ADD
  INDEX testimport1_FIELD1 (Contactnummer)
  "
}
function droptables () {
  echo droptables...
  mysqlquery "
  DROP TABLE IF EXISTS dbasetocivicrm.tempopc;
  DROP TABLE IF EXISTS dbasetocivicrm.tempnotitie;
  DROP TABLE IF EXISTS dbasetocivicrm.tempimport;
  "
}
function createtables () {
  droptables
  echo createtables...
  mysqlquery "
  CREATE
  TABLE   dbasetocivicrm.tempopc (old VARCHAR(3), new INT);
  INSERT
  INTO    dbasetocivicrm.tempopc
  VALUES  ( 'DAN'
          , 1
          )
  ,       ( 'JBU'
          , 1
          )
  "
  mysqlquery "
  CREATE
  TABLE   dbasetocivicrm.tempnotitie
  AS
  SELECT  'civicrm_contact' AS f1
  ,       TRIM( LEADING '0'
                FROM    SUBSTR( hfnotie.sleutel
                        ,       4
                        )
          )                 AS f2
  ,       CONCAT( 'civicrm_contact,'
          ,       TRIM( LEADING '0'
                        FROM    hfnotie.bestnummer
                  )
          )                 AS f3
  ,       COALESCE( ( SELECT  tempopc.new
                      FROM  dbasetocivicrm.tempopc  tempopc
                      WHERE   tempopc.old = hfnotie.opc
                    )
          ,         1
          )                 AS f4
  ,       hfnotie.bdat
  ,       hfnotie.mutd
  FROM    dbasetocivicrm.HFNOTIE  hfnotie
  INNER
  JOIN    civicrm.civicrm_contact contact
  ON      TRIM( LEADING '0'
                FROM    SUBSTR( hfnotie.sleutel
                        ,       4
                        )
          ) = contact.id
  WHERE   SUBSTR( hfnotie.sleutel
          ,       1
          ,       3
          ) = 'ass'
  "
}
function dropprocedures () {
  echo dropprocedures...
  mysqlquery "
  DROP PROCEDURE IF EXISTS DROP_INDEX_IF_EXISTS;
  DROP PROCEDURE IF EXISTS INSERT_BANK_ACCOUNTS;
  DROP PROCEDURE IF EXISTS INSERT_BANK_ACCOUNT_REFERENCES;
  "
}
function createprocedures () {
  dropprocedures
  echo createprocedures...
  mysqlquery "
  DELIMITER //
  CREATE PROCEDURE DROP_INDEX_IF_EXISTS (tblSchema VARCHAR(64),tblName VARCHAR(64),ndxName VARCHAR(64))
  BEGIN
      DECLARE IndexColumnCount INT;
      DECLARE SQLStatement VARCHAR(256);
      SELECT COUNT(1) INTO IndexColumnCount
      FROM information_schema.statistics
      WHERE table_schema = tblSchema
      AND table_name = tblName
      AND index_name = ndxName;
      IF IndexColumnCount > 0 THEN
          SET SQLStatement = CONCAT('ALTER TABLE ',tblSchema,'.',tblName,' DROP INDEX ',ndxName,'');
          SET @SQLStmt = SQLStatement;
          PREPARE s FROM @SQLStmt;
          EXECUTE s;
          DEALLOCATE PREPARE s;
      END IF;
  END
  //
  CREATE PROCEDURE INSERT_BANK_ACCOUNTS (x INT)
  BEGIN
      DECLARE i INT DEFAULT 0;
      DECLARE SQLStatement VARCHAR(8192);
      SET SQLStatement = '
        INSERT INTO civicrm.civicrm_bank_account (  id
        ,                                           created_date
        ,                                           modified_date
        ,                                           data_raw
        ,                                           data_parsed
        ,                                           contact_id
        )
      ';
      loop1: LOOP
        SET i := i + 1;
        SET SQLStatement = CONCAT(SQLStatement, \"
          SELECT    CONCAT( Contactnummer
                    ,       \",i,\"
                    )
          ,         Gemaakt
          ,         Wijzigingsdatum
          ,         '{}'
          ,         CONCAT( '{\\\"BIC\\\":\\\"'
                    ,       bic\",i,\"
                    ,       '\\\"}'
                    )
          ,         Contactnummer
          FROM      dbasetocivicrm.testimport1
          WHERE NOT (   iban\",i,\" IS  NULL
                    OR  iban\",i,\" =   ''
                    OR  bic\",i,\"  IS  NULL
                    OR  bic\",i,\"  =   ''
                    )
          UNION ALL
          SELECT    CONCAT( Contactnummer
                    ,       \",i,\"
                    )
          ,         Gemaakt
          ,         Wijzigingsdatum
          ,         '{}'
          ,         '{}'
          ,         Contactnummer
          FROM      dbasetocivicrm.testimport1
          WHERE     (   NOT (   iban\",i,\" IS  NULL
                            OR  iban\",i,\" =   ''
                            )
                    )
                    AND (   bic\",i,\"  IS  NULL
                        OR  bic\",i,\"  =   ''
                        )
        \");
        IF i < x THEN
          SET SQLStatement = CONCAT(SQLStatement, \"
            UNION ALL
          \");
          ITERATE loop1;
        END IF;
        LEAVE loop1;
      END LOOP loop1;
      SET @SQLStmt = SQLStatement;
      PREPARE s FROM @SQLStmt;
      EXECUTE s;
      DEALLOCATE PREPARE s;
  END
  //
  CREATE PROCEDURE INSERT_BANK_ACCOUNT_REFERENCES (x INT)
  BEGIN
      DECLARE i INT DEFAULT 0;
      DECLARE SQLStatement VARCHAR(8192);
      SET SQLStatement = '
        INSERT INTO civicrm.civicrm_bank_account_reference (  reference
        ,                                                     reference_type_id
        ,                                                     ba_id
        )
      ';
      loop1: LOOP
        SET i := i + 1;
        SET SQLStatement = CONCAT(SQLStatement, \"
          SELECT    iban\",i,\"
          ,         872
          ,         bank_account.id
          FROM      dbasetocivicrm.testimport1    testimport1
          INNER
          JOIN      civicrm.civicrm_bank_account  bank_account
          ON        CONCAT( testimport1.Contactnummer
                    ,       \",i,\"
                    ) = bank_account.id
          WHERE NOT (   iban\",i,\" IS  NULL
                    OR  iban\",i,\" =   ''
                    )
        \");
        IF i < x THEN
          SET SQLStatement = CONCAT(SQLStatement, \"
            UNION ALL
          \");
          ITERATE loop1;
        END IF;
        LEAVE loop1;
      END LOOP loop1;
      SET @SQLStmt = SQLStatement;
      PREPARE s FROM @SQLStmt;
      EXECUTE s;
      DEALLOCATE PREPARE s;
  END
  //
  DELIMITER ;
  "
}
function dropfunctions () {
  echo dropfunctions...
  mysqlquery "
  DROP FUNCTION IF EXISTS SPLIT_STR;
  DROP FUNCTION IF EXISTS SELECTseparate;
  DROP FUNCTION IF EXISTS tnSELECT;
  DROP FUNCTION IF EXISTS eaSELECT;
  DROP FUNCTION IF EXISTS ibSELECT;
  DROP FUNCTION IF EXISTS tnJOIN;
  DROP FUNCTION IF EXISTS eaJOIN;
  DROP FUNCTION IF EXISTS ibJOIN;
  "
}
function createfunctions () {
  dropfunctions
  echo createfunctions...
  mysqlquery "
  DELIMITER //
  CREATE FUNCTION SPLIT_STR(  x     VARCHAR(255)
                  ,           delim VARCHAR(12)
                  ,           pos   INT
                  )
  RETURNS VARCHAR(255) DETERMINISTIC
  BEGIN 
      RETURN REPLACE(SUBSTRING(SUBSTRING_INDEX(x, delim, pos),
         LENGTH(SUBSTRING_INDEX(x, delim, pos -1)) + 1),
         delim, '');
  END
  //
  CREATE FUNCTION SELECTseparate(z INT, x INT, y VARCHAR(12)) RETURNS VARCHAR(10000)
  BEGIN
    DECLARE i INT DEFAULT z;
    SET @r = '';
    loop1: LOOP
      SET i := i + 1;
      SET @r = CONCAT(@r,\"
        , SPLIT_STR( importtable.\",y,\", ',', \",i,\" ) AS \",y,i,\"
      \");
      IF i < x THEN
        ITERATE loop1;
      END IF;
      LEAVE loop1;
    END LOOP loop1;
    RETURN @r;
  END
  //
  CREATE FUNCTION tnSELECT(x INT) RETURNS VARCHAR(10000)
  BEGIN
    DECLARE i INT DEFAULT 0;
    SET @r = \"
      , CONCAT_WS( ','
    \";
    loop1: LOOP
      SET i := i + 1;
      SET @r = CONCAT(@r,\"
        , TRIM( LEADING ' ' FROM
                SPLIT_STR(  tn\",i,\".sleutelwrd
                ,           '         '
                ,           2
                )
          )
      \");
      IF i < x THEN
        ITERATE loop1;
      END IF;
      LEAVE loop1;
    END LOOP loop1;
    RETURN CONCAT(@r,\"
      , ',' ) AS tn
    \");
  END
  //
  CREATE FUNCTION eaSELECT(x INT) RETURNS VARCHAR(10000)
  BEGIN
    DECLARE i INT DEFAULT 0;
    SET @r = \"
      , CONCAT_WS( ','
    \";
    loop1: LOOP
      SET i := i + 1;
      SET @r = CONCAT(@r,\"
        , ea\",i,\".sleutelwrd
      \");
      IF i < x THEN
        ITERATE loop1;
      END IF;
      LEAVE loop1;
    END LOOP loop1;
    RETURN CONCAT(@r,\"
      , ',' ) AS ea
    \");
  END
  //
  CREATE FUNCTION ibSELECT(x INT) RETURNS VARCHAR(10000)
  BEGIN
    DECLARE i INT DEFAULT 0;
    SET @r = '';
    loop1: LOOP
      SET i := i + 1;
      SET @r = CONCAT(@r,\"
        , SPLIT_STR(ib\",i,\".sleutelwrd, ' ', 1 )  AS iban\",i,\"
        , SPLIT_STR(ib\",i,\".sleutelwrd, ' ', 18)  AS bic\",i,\"
        , TRIM(TRAILING ' ' FROM
          SPLIT_STR(ib\",i,\".informatie, ';', 1 )) AS naam\",i,\"
        , SPLIT_STR(ib\",i,\".informatie, ';', 2 )  AS plaats\",i,\"
      \");
      IF i < x THEN
        ITERATE loop1;
      END IF;
      LEAVE loop1;
    END LOOP loop1;
    RETURN @r;
  END
  //
  CREATE FUNCTION tnJOIN(x INT) RETURNS VARCHAR(10000)
  BEGIN
    DECLARE i INT DEFAULT 0;
    SET @r = '';
    loop1: LOOP
      SET i := i + 1;
      SET @r = CONCAT(@r,\"
        LEFT JOIN dbasetocivicrm.VMSLREL tn\",i,\" ON ass.relatienr  = tn\",i,\".relatienr
                                            AND tn\",i,\".sleutelcd  = 'TN'
                                            AND tn\",i,\".codebalk  != 'FAX'
                                            AND (   tn\",i,\".informatie  = '///'
                                                OR  tn\",i,\".informatie  = ''
                                                OR  tn\",i,\".codebalk    = 'TEL'
                                          ) AND tn\",i,\".generiek   = 0
                                            AND tn\",i,\".volgnummer = \",i);
      IF i <= x THEN
        ITERATE loop1;
      END IF;
      LEAVE loop1;
    END LOOP loop1;
    RETURN @r;
  END
  //
  CREATE FUNCTION eaJOIN(x INT) RETURNS VARCHAR(10000)
  BEGIN
    DECLARE i INT DEFAULT 0;
    SET @r = '';
    loop1: LOOP
      SET i := i + 1;
      SET @r = CONCAT(@r,\"
        LEFT JOIN dbasetocivicrm.VMSLREL ea\",i,\" ON ass.relatienr  = ea\",i,\".relatienr
                                            AND ea\",i,\".sleutelcd  = 'EA'
                                            AND (   ea\",i,\".informatie  = '///'
                                                OR  ea\",i,\".informatie  = ''
                                          ) AND ea\",i,\".generiek   = 0
                                            AND ea\",i,\".volgnummer = \",i);
      IF i <= x THEN
        ITERATE loop1;
      END IF;
      LEAVE loop1;
    END LOOP loop1;
    RETURN @r;
  END
  //
  CREATE FUNCTION ibJOIN(x INT) RETURNS VARCHAR(10000)
  BEGIN
    DECLARE i INT DEFAULT 0;
    SET @r = '';
    loop1: LOOP
      SET i := i + 1;
      SET @r = CONCAT(@r,\"
        LEFT JOIN dbasetocivicrm.VMSLREL ib\",i,\" ON ass.relatienr  = ib\",i,\".relatienr
                                            AND ib\",i,\".sleutelcd  = 'IB'
                                            AND ib\",i,\".generiek   = 0
                                            AND ib\",i,\".volgnummer = \",i);
      IF i <= x THEN
        ITERATE loop1;
      END IF;
      LEAVE loop1;
    END LOOP loop1;
    RETURN @r;
  END
  //
  DELIMITER ;
  "
}
main $1
