#!/bin/bash
hostname=$(cat $HOME/GIT/DBFToMySQL/config.php \
          | grep host \
          | tail -n 1 \
          | cut -d "'" -f 2 \
        )
database=$(cat $HOME/GIT/DBFToMySQL/config.php \
          | grep db_name \
          | tail -n 1 \
          | cut -d "'" -f 2 \
        )
function main () {
  step$1
}
function step () {
  echo Please specify step number
}
function step1 () {
  echo
  prepare_sol_import_table 'Adresvan'
  run_sol_import_api 'adresvan'
}
function step2 () {
  echo
  prepare_sol_import_table 'Emailadressen'
  run_sol_import_api 'email'
}
function step3 () {
  echo
  prepare_sol_import_table 'cod'
  run_sol_import_api 'cod'
}
function step4 () {
  echo
  prepare_sol_import_incasso_table
  run_sol_import_api 'incasso'
}
function mysqlquery () {
  echo mysqlquery...
  ssh root@$hostname "mysql \
        -u root \
        civicrm \
        -e '
          SET
          NAMES utf8
          ;
          $1
          ;
        ' \
        2>&1 \
        | grep -v 'Using a password on the command line interface can be insecure.'"
}
function run_sol_import_api() {
  echo Run the solimport.$1 api
  ssh root@$hostname "cd /var/www/${hostname/.*}/; drush cvapi SolImport.$1 limit=100000000"
}
function prepare_sol_import_table() {
  echo Copy $1 to the civicrm.sol_import table
  mysqlquery "
  DELETE
  FROM    sol_import
  "
  mysqlquery "
  INSERT
  INTO    sol_import(
            Contactnummer, $1
          )
  SELECT  Contactnummer, $1
  FROM    $database.preparetable
  "
}
function prepare_sol_import_incasso_table() {
  echo Populate the civicrm.sol_import_incasso table
  mysqlquery "
  DELIMITER //
  CREATE FUNCTION SPLIT_STR ( x       VARCHAR(255)
                            , delim   VARCHAR(12)
                            , pos     INT
                            ) RETURNS VARCHAR(255) CHARSET utf8 DETERMINISTIC
  BEGIN 
      RETURN REPLACE(SUBSTRING(SUBSTRING_INDEX(x, delim, pos),
         LENGTH(SUBSTRING_INDEX(x, delim, pos -1)) + 1),
         delim, \"\");
  END
  //
  DELIMITER ;
  "
  mysqlquery "
  DROP TABLE IF EXISTS $database.tempp01n
  "
  mysqlquery "
  CREATE
  TABLE   $database.tempp01n ( old INT
                             , new VARCHAR(40)
                             )
  "
  mysqlquery "
  INSERT
  INTO    $database.tempp01n
  VALUES  ( 8080
          , \"8080 Giften extra actie Ned\"
          )
  ,       ( 8085
          , \"8085 Giften Er is Hulp\"
          )
  ,       ( 8090
          , \"8090 Giften actie Buitenland\"
          )
  ,       ( 8100
          , \"8100 Giften algemeen\"
          )
  ,       ( 8110
          , \"8110 Door te betalen\"
          )
  ,       ( 8200
          , \"8200 Legaten\"
          )
  ,       ( 8300
          , \"8300 Sponsorplan\"
          )
  ,       ( 8520
          , \"8520 Giften Mars vh Leven\"
          )
  ,       ( 8800
          , \"8800 Inkomsten Conferentie\"
          )
  ,       ( 8900
          , \"8900 Diverse opbrengst\"
          )
  ,       ( 8910
          , \"8910 Cursusgelden\"
          )
  "
  mysqlquery "
  DELETE
  FROM    sol_import_incasso
  "
  mysqlquery "
  INSERT
  INTO    sol_import_incasso
            ( financial_type_id
            , contact_id
            , frequency_interval
            , amount
            , start_date
            , DtOfSgntr
            , MndtId
            , next_sched_contribution_date
            , iban
            , account_holder
            , note
            )
  SELECT  COALESCE(
            ( SELECT  tempp01n.new
              FROM    $database.tempp01n tempp01n
              WHERE   tempp01n.old = pol.p01n
            )
          , \"8100 Giften algemeen\"
          )
  ,       TRIM(
            LEADING \"0\"
            FROM    pol.relatienr
          )
  ,       pol.p07
  ,       pol.p08
  ,       pol.p04
  ,       REPLACE(
            pol.tekendatum
          , \"1970-01-01\"
          , \"2009-11-01\"
          )
  ,       COALESCE(
            SUBSTR(
              ( SELECT  bhboekin.bankinfo
                FROM    $database.BHBOEKIN bhboekin
                WHERE   bhboekin.relatienr = pol.relatienr
                AND     SUBSTR(
                          bhboekin.bankinfo
                        , -15
                        , 4
                        ) = pol.p01n
                LIMIT   1
              )
            , -16
            )
          , \"\"
          )
  ,       DATE(
            CONCAT(
              \"20\"
            , SUBSTR(
                pol.vervalper
              , 1
              , 2
              )
            , \"-\"
            , SUBSTR(
                pol.vervalper
              , 3
              , 2
              )
            , \"-26\"
            )
          )
  ,       pol.banknummer
  ,       TRIM( TRAILING  \" \"
                FROM      SPLIT_STR ( name.informatie
                                    , \";\"
                                    , 1
                                    )
          )
  ,       pol.omschrijv
  FROM    $database.POL pol
  LEFT
  JOIN    $database.VMSLREL name
  ON      pol.banknummer = SUBSTR(
                             name.sleutelwrd
                           , 1
                           , 18
                           )
  WHERE   pol.verwijderd = 0
  AND NOT pol.vervalper = \"\"
  "
  mysqlquery "
  DROP FUNCTION IF EXISTS SPLIT_STR
  "
  mysqlquery "
  DROP TABLE IF EXISTS $database.tempp01n
  "
}
main $1
