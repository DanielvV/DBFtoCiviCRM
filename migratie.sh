#!/bin/bash
#SELECT * FROM dbasetocivicrm.testimport1 WHERE type='person'
# Code gebaseerd op:
# https://stackoverflow.com/a/14579117 (Coalesce equivalent for nth not null value - MySQL)
# https://www.experts-exchange.com/articles/1250/3-Ways-to-Speed-Up-MySQL.html
# https://stackoverflow.com/a/1671056 (Can MySQL replace multiple characters?)
# https://forum.civicrm.org/index.php?topic=7567.0 (Import date created and/or date modified?)
host='localhost'
user='root'
pass=''
database='dbasetocivicrm'
encoding='CP437'
  from=70
  till=100000
  cividatabase=civicrm
case $HOSTNAME in
civicrm)
  till=10000
  ;;
civicrm2)
  from=28
  till=100000000
  ;;
esac
function main () {
  step$1
}
function mysqlquery () {
  echo mysqlquery...
#        -p$pass \
  mysql -h $host \
        -u $user \
        $database \
        -e "
          SET
          NAMES utf8
          ;
          $1
          ;
        " \
        2>&1 \
        | grep -v 'Using a password on the command line interface can be insecure.' \
        | grep -v 'ERROR 1146 (42S02) at line 6: Table'
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
SELECT  ass.*
,       CONCAT( ass.tit
              , '/'
              , ass.na2
              , '/'
              , ass.hisn
              , '/'
              , ass.na1
              )       AS  'informatie'
,       ( SELECT  SPLIT_STR ( omschrijv
                            , '  '
                            , 1
                            ) AS  naam
          FROM    dbasetocivicrm.AMCODE amcode
          WHERE   amcode.tabelnr = '002'
          AND     amcode.waarde  = ass.lan
        )             AS  'lan2'
\",
tnSELECT(6)
,\"
FROM    dbasetocivicrm.ASS        ass
\",
tnJOIN(6)
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
createindexes
mysqlquery "
SET @query2 = CONCAT(\"
CREATE
TABLE   testimport1
AS
SELECT  TRIM(     LEADING '0'
                  FROM    importtable.relatienr
        )                     AS  'Contactnummer'
,       CAST(     'Vigilant'
                  AS CHAR(32)
        )                     AS  'Herkomst'
,       '00000000'            AS  'Adressfrom'
,       'N'                   AS  'status'
,       'person'              AS  'type'
,       importtable.tit       AS  'Voorvoegsel'
,       importtable.na2       AS  'Voornaam'
,       importtable.hisn      AS  'Tussenvoegsel'
,       importtable.na1       AS  'Achternaam'
,       importtable.tav
,       importtable.voornaam  AS  'Roepnaam'
,       importtable.inforegel
,       CONCAT(   importtable.ad1
        ,         ' '
        ,         importtable.huisnr
        )                     AS  'Straat en huisnummer'
,       importtable.ad1       AS  'Straatnaam'
,       importtable.huisnr    AS  'Huisnummer'
,       importtable.pos       AS  'Postcode'
,       importtable.pla       AS  'Plaats'
,       COALESCE((SELECT  templan.new
                  FROM    dbasetocivicrm.templan templan
                  WHERE   templan.old = importtable.lan2
        ), importtable.lan2)  AS  'Land'
,       importtable.cod
,       importtable.bdat      AS  'Gemaakt'
,       IF( importtable.mutd = '1970-01-01'
        ,   importtable.bdat
        ,   importtable.mutd
        )                     AS  'Wijzigingsdatum'
,       COALESCE((SELECT  tempopc.new
                  FROM    dbasetocivicrm.tempopc tempopc
                  WHERE   tempopc.old = importtable.opc
        ), 1)                 AS  'Wijziger'
\",
eaSELECT(6)
,
SELECTseparate(0, 6, 'tn')
,
ibSELECT(5)
,\"
FROM dbasetocivicrm.tempimport importtable
\",
eaJOIN(6)
,
ibJOIN(5)
)
;
PREPARE query2
FROM   @query2
;
EXECUTE query2
"
echo
echo Add primary key testimport1
mysqlquery "
ALTER
TABLE   dbasetocivicrm.testimport1
ADD
PRIMARY
KEY   ( Contactnummer )
"
echo
echo Autoincrement testimport1
mysqlquery "
ALTER
TABLE   dbasetocivicrm.testimport1
MODIFY
COLUMN  Contactnummer INT auto_increment
"
echo
echo Add extra contacts
mysqlquery "
INSERT
INTO    dbasetocivicrm.testimport1  ( Adressfrom
                                    , Herkomst
                                    , status
                                    , type
                                    , Voorvoegsel
                                    , Voornaam
                                    , Tussenvoegsel
                                    , Achternaam
                                    , tav
                                    , inforegel
                                    , cod
                                    , Gemaakt
                                    , Wijzigingsdatum
                                    , Wijziger
                                    , Emailadressen
                                    , tn1
                                    )
SELECT  TRIM( LEADING '0'
              FROM    importtable.relatienr
            )
,       'Vigilant extra'
,       'N'
,       'person'
,       vmslrel.titel
,       vmslrel.voornaam
,       IF  ( vmslrel.achternaam != ''
            , vmslrel.tussenvoegsel
            , importtable.hisn
            )
,       IF  ( vmslrel.achternaam != ''
            , vmslrel.achternaam
            , IF  ( vmslrel.titel = 'Mw.'
                  , importtable.na1
                  , SPLIT_STR ( importtable.na1
                              , '-'
                              , 1
                              )
                  )
            )
,       importtable.tav
,       importtable.inforegel
,       importtable.cod
,       importtable.bdat
,       importtable.mutd
,       COALESCE( ( SELECT  tempopc.new
                    FROM    dbasetocivicrm.tempopc tempopc
                    WHERE   tempopc.old = importtable.opc
                  )
                , 1
                )
,       IF  ( vmslrel.sleutelcd = 'EA'
            , vmslrel.sleutelwrd
            , ''
            )
,       vmslrel.telefoonnummer
FROM    dbasetocivicrm.tempimport importtable
INNER
JOIN    dbasetocivicrm.eatn       vmslrel
ON      importtable.relatienr       = vmslrel.relatienr
AND     vmslrel.generiek            = 0
AND     (   vmslrel.sleutelcd       = 'EA'
        OR  (   vmslrel.sleutelcd   = 'TN'
            AND vmslrel.codebalk    = 'MOB'
            )
        )
AND     vmslrel.informatie         != '///'
AND     vmslrel.informatie         != ''
AND     vmslrel.informatie         != importtable.informatie
AND     vmslrel.voornaam           != importtable.voornaam
"
echo
echo Update Voorvoegsel
mysqlquery "
UPDATE  dbasetocivicrm.testimport1
SET     Voorvoegsel='Stichting'
WHERE   Voorvoegsel='Stg.'
"
mysqlquery "
UPDATE  dbasetocivicrm.testimport1
SET     Voorvoegsel='Redactie'
WHERE   Voorvoegsel='Red.'
"
mysqlquery "
UPDATE  dbasetocivicrm.testimport1
SET     Voorvoegsel='Vereniging'
WHERE   Voorvoegsel='Ver.'
"
mysqlquery "
UPDATE  dbasetocivicrm.testimport1
SET     Voorvoegsel=''
WHERE   Voorvoegsel='Diaconie'
"
mysqlquery "
UPDATE  dbasetocivicrm.testimport1
SET     Voorvoegsel=''
WHERE   Voorvoegsel='Diakonie'
"
mysqlquery "
UPDATE  dbasetocivicrm.testimport1
SET     Voorvoegsel='Dhr./Mw.'
WHERE   Voorvoegsel='Dhr./mw.'
"
mysqlquery "
UPDATE  dbasetocivicrm.testimport1
SET     Voorvoegsel='Dhr./Mw.'
WHERE   Voorvoegsel='Dhr./mw'
"
echo
echo Update contact type of person or organization
mysqlquery "
UPDATE  dbasetocivicrm.testimport1
SET     type='org'
WHERE INSTR(cod, 'BED')
OR    INSTR(cod, 'CRE')
OR    INSTR(cod, 'KER')
OR    INSTR(cod, 'PRI')
OR    INSTR(cod, 'REL')
OR    INSTR(cod, 'TGN')
OR    Voorvoegsel='Stichting'
OR    Voorvoegsel='Redactie'
OR    Voorvoegsel='Vereniging'
"
echo
echo Add contact users for change history
mysqlquery "
INSERT
INTO dbasetocivicrm.testimport1 ( Contactnummer
                                , status
                                , type
                                , Voornaam
                                , Tussenvoegsel
                                , Achternaam
                                )
VALUES  ( 71
        , 'N'
        , 'person'
        , 'Joop'
        , ''
        , 'Buker'
        )
,       ( 72
        , 'N'
        , 'person'
        , 'Daniël'
        , 'van'
        , 'Vuuren'
        )
,       ( 73
        , 'N'
        , 'person'
        , 'Alex'
        , 'van'
        , 'Vuuren'
        )
,       ( 74
        , 'N'
        , 'person'
        , 'Wim'
        , ''
        , 'Nelisse'
        )
,       ( 75
        , 'N'
        , 'person'
        , 'Ariëtte'
        , ''
        , 'Westland'
        )
,       ( 76
        , 'N'
        , 'person'
        , 'Albert'
        , ''
        , 'Holtvluwer'
        )
,       ( 77
        , 'N'
        , 'person'
        , 'Bert'
        , ''
        , 'Keizer'
        )
,       ( 78
        , 'N'
        , 'person'
        , 'Joke'
        , ''
        , 'Keizer'
        )
"
echo
echo Add external id
mysqlquery "
ALTER
TABLE   dbasetocivicrm.testimport1
ADD     Externe_ID INT(12)
"
mysqlquery "
UPDATE  dbasetocivicrm.testimport1
SET     Externe_ID = Contactnummer
"
echo
echo Delete contacts and create them again
mysqlquery "
DELETE
FROM  $cividatabase.civicrm_contact
WHERE id
        BETWEEN $from
        AND     $till
"
mysqlquery "
INSERT INTO $cividatabase.civicrm_contact ( id
                                          , contact_type
                                          )
SELECT  Contactnummer
,       'Individual'
FROM  dbasetocivicrm.testimport1
WHERE Contactnummer
        BETWEEN $from
        AND     $till
"
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
FROM  $cividatabase.civicrm_log
WHERE entity_id
        BETWEEN $from
        AND     $till
"
echo
echo Update created_date and modified_date on all contacts
mysqlquery "
INSERT
INTO    $cividatabase.civicrm_contact ( id
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
INTO    $cividatabase.civicrm_log ( entity_table
                                  , entity_id
                                  , data
                                  , modified_id
                                  , modified_date
                                  )
SELECT  'civicrm_contact'
,       Contactnummer
,       CONCAT( 'civicrm_contact,'
        ,       Contactnummer
        )
,       Wijziger
,       Gemaakt
FROM    dbasetocivicrm.testimport1
WHERE   Gemaakt != '1970-01-01'
UNION ALL
SELECT  'civicrm_contact'
,       Contactnummer
,       CONCAT( 'civicrm_contact,'
        ,       Contactnummer
        )
,       Wijziger
,       Wijzigingsdatum
FROM    dbasetocivicrm.testimport1
WHERE   Wijzigingsdatum != '1970-01-01'
"
echo
echo Create tables
createtables
echo
echo Delete notes from note
mysqlquery "
DELETE
FROM  $cividatabase.civicrm_note
"
echo
echo Create notes in note
mysqlquery "
INSERT INTO $cividatabase.civicrm_note(id, entity_table, entity_id, note, contact_id, modified_date, subject, privacy)
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
INNER JOIN  $cividatabase.civicrm_contact contact ON contact.id = TRIM( LEADING '0'
                                                                  FROM    SUBSTR( hfnotie.sleutel
                                                                          ,       4
                                                                          )
                                                            )
WHERE   SUBSTR( hfnotie.sleutel
        ,       1
        ,       3
        ) = 'ass'
AND     contact.source = 'Vigilant'
"
echo
echo Insert modified_date for all notes in log
mysqlquery "
INSERT INTO $cividatabase.civicrm_log(entity_table, entity_id, data, modified_id, modified_date)
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
FROM  $cividatabase.civicrm_bank_account
"
echo
echo Delete bankaccount references
mysqlquery "
DELETE
FROM  $cividatabase.civicrm_bank_account_reference
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
  ,                     'eatn'
  ,                     'eatn_FIELD1'
  )
  "
  mysqlquery "
  CALL
  DROP_INDEX_IF_EXISTS( 'dbasetocivicrm'
  ,                     'eatn'
  ,                     'eatn_FIELD1_2_6'
  )
  "
  mysqlquery "
  CALL
  DROP_INDEX_IF_EXISTS( 'dbasetocivicrm'
  ,                     'tempimport'
  ,                     'tempimport_FIELD1'
  )
  "
  mysqlquery "
  CALL
  DROP_INDEX_IF_EXISTS( 'dbasetocivicrm'
  ,                     'tempimport'
  ,                     'tempimport_FIELD2'
  )
  "
  mysqlquery "
  CALL
  DROP_INDEX_IF_EXISTS( 'dbasetocivicrm'
  ,                     'tempimport'
  ,                     'tempimport_FIELD3'
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
  INDEX ASS_FIELD1  ( relatienr
                    )
  "
  mysqlquery "
  ALTER
  TABLE dbasetocivicrm.VMSLREL
  ADD
  INDEX VMSLREL_FIELD1  ( relatienr
                        )
  "
  mysqlquery "
  ALTER
  TABLE dbasetocivicrm.VMSLREL
  ADD
  INDEX VMSLREL_FIELD1_2_6  ( relatienr
                            , sleutelcd
                            , volgnummer
                            )
  "
  mysqlquery "
  ALTER
  TABLE dbasetocivicrm.eatn
  ADD
  INDEX eatn_FIELD1 ( relatienr
                    )
  "
  mysqlquery "
  ALTER
  TABLE dbasetocivicrm.eatn
  ADD
  INDEX eatn_FIELD1_2_6 ( relatienr
                        , sleutelcd
                        , volgnummer
                        )
  "
  mysqlquery "
  ALTER
  TABLE dbasetocivicrm.tempimport
  ADD
  INDEX tempimport_FIELD1 ( relatienr
                          )
  "
  mysqlquery "
  ALTER
  TABLE dbasetocivicrm.tempimport
  ADD
  INDEX tempimport_FIELD2 ( informatie
                          )
  "
  mysqlquery "
  ALTER
  TABLE dbasetocivicrm.tempimport
  ADD
  INDEX tempimport_FIELD3 ( voornaam
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
  DROP TABLE IF EXISTS dbasetocivicrm.templan;
  DROP TABLE IF EXISTS dbasetocivicrm.tempnotitie;
  DROP TABLE IF EXISTS dbasetocivicrm.tempimport;
  DROP TABLE IF EXISTS dbasetocivicrm.eatn;
  "
}
function createtables () {
  droptables
  echo createtables...
  mysqlquery "
  CREATE
  TABLE   dbasetocivicrm.tempopc  ( old VARCHAR(3)
                                  , new INT
                                  )
  ;
  INSERT
  INTO    dbasetocivicrm.tempopc
  VALUES  ( 'JBU'
          , 71
          )
  ,       ( 'DAN'
          , 72
          )
  ,       ( 'AVU'
          , 73
          )
  ,       ( 'NEL'
          , 74
          )
  ,       ( 'ARI'
          , 75
          )
  ,       ( 'SLI'
          , 75
          )
  ,       ( 'AH'
          , 76
          )
  ,       ( 'BEK'
          , 77
          )
  ,       ( 'JKE'
          , 78
          )
  "
  mysqlquery "
  CREATE
  TABLE   dbasetocivicrm.templan  ( old VARCHAR(64) CHARSET utf8
                                  , new VARCHAR(64) CHARSET utf8
                                  )
  ;
  INSERT
  INTO    dbasetocivicrm.templan
  VALUES  ( 'Onbekend land'
          , 'Nederland'
          )
  ,       ( 'Korea Zuid'
          , 'Zuid-Korea'
          )
  ,       ( 'Myanmar (Burma)'
          , 'Burma'
          )
  ,       ( 'Ned. Antillen'
          , 'Nederlandse Antillen'
          )
  ,       ( 'Ver. Staten van Amerika'
          , 'Verenigde Staten'
          )
  ,       ( 'Groot-Brittannië'
          , 'Verenigd Koninkrijk'
          )
  ,       ( 'Wit-Rusland'
          , 'Belarus'
          )
  ,       ( 'Centraal Afrikaanse Republiek 03FFF'
          , 'Centraal-Afrikaanse Republiek'
          )
  ,       ( 'Democratisch Rep. Congo'
          , 'Democratisch Republiek Congo (Congo-Kinshasa)'
          )
  ,       ( 'Faeröer Eilanden'
          , 'Faeröer'
          )
  ,       ( 'Hong Kong'
          , 'Hongkong'
          )
  ,       ( 'Kenya'
          , 'Kenia'
          )
  ,       ( 'Mauretanië'
          , 'Mauritanië'
          )
  ,       ( 'Burma'
          , 'Myanmar'
          )
  ,       ( 'Nederlandse Antillen'
          , 'Curaçao'
          )
  ,       ( 'Nieuw Zeeland'
          , 'Nieuw-Zeeland'
          )
  ,       ( 'Papua Nieuw Guinea'
          , 'Papua-Nieuw-Guinea'
          )
  ,       ( 'Filippijnen'
          , 'Filipijnen'
          )
  ,       ( 'St. Vincent'
          , 'Sint Vincent en de Grenadines'
          )
  ,       ( 'Slowakije'
          , 'Slovakije'
          )
  ,       ( 'Vaticaan'
          , 'Vaticaanstad'
          )
  ,       ( 'Viet Nam'
          , 'Vietnam'
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
  JOIN    $cividatabase.civicrm_contact contact
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
  mysqlquery "
  CREATE
  TABLE   dbasetocivicrm.eatn
  AS
  SELECT  vmslrel.*
  ,       SPLIT_STR ( vmslrel.informatie
                    , '/'
                    , 1
                    ) AS titel
  ,       SPLIT_STR ( vmslrel.informatie
                    , '/'
                    , 2
                    ) AS voornaam
  ,       SPLIT_STR ( vmslrel.informatie
                    , '/'
                    , 3
                    ) AS tussenvoegsel
  ,       SPLIT_STR ( vmslrel.informatie
                    , '/'
                    , 4
                    ) AS achternaam
  ,       IF  ( vmslrel.sleutelcd = 'TN'
              , TRIM( LEADING ' ' FROM
                      SPLIT_STR ( vmslrel.sleutelwrd
                                , '         '
                                , 2
                                )
                    )
              , ''
              )       AS telefoonnummer
  FROM    dbasetocivicrm.VMSLREL  vmslrel
  WHERE   vmslrel.relatienr
              BETWEEN $from
              AND     $till
  AND     vmslrel.generiek      = 0
  AND     (   vmslrel.sleutelcd = 'TN'
          OR  vmslrel.sleutelcd = 'EA'
          )
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
  CREATE PROCEDURE DROP_INDEX_IF_EXISTS ( tblSchema VARCHAR(64) CHARSET utf8
                                        , tblName   VARCHAR(64) CHARSET utf8
                                        , ndxName   VARCHAR(64) CHARSET utf8
                                        )
  BEGIN
      DECLARE IndexColumnCount INT;
      DECLARE SQLStatement VARCHAR(256);
      SELECT COUNT(1) INTO IndexColumnCount
      FROM information_schema.statistics
      WHERE table_schema = tblSchema
      AND table_name = tblName
      AND index_name = ndxName;
      IF IndexColumnCount > 0 THEN
          SET SQLStatement = CONCAT ( 'ALTER TABLE '
                                    , tblSchema
                                    , '.'
                                    , tblName
                                    , ' DROP INDEX '
                                    , ndxName
                                    , ''
                                    )
          ;
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
        INSERT INTO $cividatabase.civicrm_bank_account  ( id
                                                        , created_date
                                                        , modified_date
                                                        , data_raw
                                                        , data_parsed
                                                        , contact_id
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
        INSERT INTO $cividatabase.civicrm_bank_account_reference  ( reference
                                                            , reference_type_id
                                                            , ba_id
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
          JOIN      $cividatabase.civicrm_bank_account  bank_account
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
  CREATE FUNCTION SPLIT_STR ( x       VARCHAR(255)
                            , delim   VARCHAR(12)
                            , pos     INT
                            ) RETURNS VARCHAR(255) CHARSET utf8 DETERMINISTIC
  BEGIN 
      RETURN REPLACE(SUBSTRING(SUBSTRING_INDEX(x, delim, pos),
         LENGTH(SUBSTRING_INDEX(x, delim, pos -1)) + 1),
         delim, '');
  END
  //
  CREATE FUNCTION SELECTseparate  ( z       INT
                                  , x       INT
                                  , y       VARCHAR(12)
                                  ) RETURNS VARCHAR(10000) CHARSET utf8
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
  CREATE FUNCTION tnSELECT  ( x       INT
                            ) RETURNS VARCHAR(10000) CHARSET utf8
  BEGIN
    DECLARE i INT DEFAULT 0;
    SET @r = \"
      , CONCAT_WS( ','
    \";
    loop1: LOOP
      SET i := i + 1;
      SET @r = CONCAT(@r,\"
        , tn\",i,\".telefoonnummer
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
  CREATE FUNCTION eaSELECT  ( x       INT
                            ) RETURNS VARCHAR(10000) CHARSET utf8
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
      , ',' ) AS 'Emailadressen'
    \");
  END
  //
  CREATE FUNCTION ibSELECT  ( x       INT
                            ) RETURNS VARCHAR(10000) CHARSET utf8
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
  CREATE FUNCTION tnJOIN  ( x       INT
                          ) RETURNS VARCHAR(10000) CHARSET utf8
  BEGIN
    DECLARE i INT DEFAULT 0;
    SET @r = '';
    loop1: LOOP
      SET i := i + 1;
      SET @r = CONCAT(@r,\"
        LEFT
        JOIN  dbasetocivicrm.eatn tn\",i,\"
        ON    ass.relatienr             = tn\",i,\".relatienr
        AND   tn\",i,\".volgnummer      = \",i,\"
        AND   tn\",i,\".sleutelcd       = 'TN'
        AND   tn\",i,\".codebalk       != 'FAX'
        AND   (   tn\",i,\".codebalk    = 'TEL'
              OR  tn\",i,\".informatie  = '///'
              OR  tn\",i,\".informatie  = ''
              OR  tn\",i,\".informatie  = importtable.informatie
              OR  tn\",i,\".voornaam    = importtable.voornaam
              )
      \");
      IF i <= x THEN
        ITERATE loop1;
      END IF;
      LEAVE loop1;
    END LOOP loop1;
    RETURN @r;
  END
  //
  CREATE FUNCTION eaJOIN  ( x       INT
                          ) RETURNS VARCHAR(10000) CHARSET utf8
  BEGIN
    DECLARE i INT DEFAULT 0;
    SET @r = '';
    loop1: LOOP
      SET i := i + 1;
      SET @r = CONCAT(@r,\"
        LEFT
        JOIN  dbasetocivicrm.eatn ea\",i,\"
        ON    importtable.relatienr     = ea\",i,\".relatienr
        AND   ea\",i,\".volgnummer      = \",i,\"
        AND   ea\",i,\".sleutelcd       = 'EA'
        AND   (   ea\",i,\".informatie  = '///'
              OR  ea\",i,\".informatie  = ''
              OR  ea\",i,\".informatie  = importtable.informatie
              OR  ea\",i,\".voornaam    = importtable.voornaam
              )
      \");
      IF i <= x THEN
        ITERATE loop1;
      END IF;
      LEAVE loop1;
    END LOOP loop1;
    RETURN @r;
  END
  //
  CREATE FUNCTION ibJOIN  ( x       INT
                          ) RETURNS VARCHAR(10000) CHARSET utf8
  BEGIN
    DECLARE i INT DEFAULT 0;
    SET @r = '';
    loop1: LOOP
      SET i := i + 1;
      SET @r = CONCAT(@r,\"
        LEFT JOIN dbasetocivicrm.VMSLREL ib\",i,\" ON importtable.relatienr  = ib\",i,\".relatienr
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
