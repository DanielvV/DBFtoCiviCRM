#!/bin/bash
function mysqlquery () {
  echo mysqlquery...
#        -p$pass \
  mysql -h $(cat $HOME/GIT/DBFToMySQL/config.php \
             | grep host \
             | tail -n 1 \
             | cut -d "'" -f 2 \
           ) \
        -u civicrm \
        -p$( cat $HOME/GIT/DBFToMySQL/config.php \
             | grep passwd \
             | cut -d "'" -f 2 \
           ) \
        civicrm \
        -e "
          SET
          NAMES utf8
          ;
          $1
          ;
        " \
        2>&1 \
        | grep -v 'Using a password on the command line interface can be insecure.'
}

mysqlquery "
DROP TABLE IF EXISTS dbasetocivicrm.tempp01n
;
CREATE
TABLE   dbasetocivicrm.tempp01n ( old INT
                                , new VARCHAR(40)
                                )
;
INSERT
INTO    dbasetocivicrm.tempp01n
VALUES  ( 8080
        , '8080 Giften extra actie Ned'
        )
,       ( 8085
        , '8085 Giften Er is Hulp'
        )
,       ( 8090
        , '8090 Giften actie Buitenland'
        )
,       ( 8100
        , '8100 Giften algemeen'
        )
,       ( 8110
        , '8110 Door te betalen'
        )
,       ( 8200
        , '8200 Legaten'
        )
,       ( 8300
        , '8300 Sponsorplan'
        )
,       ( 8520
        , '8520 Giften Mars vh Leven'
        )
,       ( 8800
        , '8800 Inkomsten Conferentie'
        )
,       ( 8900
        , '8900 Diverse opbrengst'
        )
,       ( 8910
        , '8910 Cursusgelden'
        )
;
DELETE
FROM    sol_import_incasso
;
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
          , note
          )
SELECT  COALESCE(
          ( SELECT  tempp01n.new
            FROM    dbasetocivicrm.tempp01n tempp01n
            WHERE   tempp01n.old = pol.p01n
          )
        , '8100 Giften algemeen'
        )
,       TRIM(
          LEADING '0'
          FROM    pol.relatienr
        )
,       pol.p07
,       pol.p08
,       pol.p04
,       REPLACE(
          pol.tekendatum
        , '1970-01-01'
        , '2009-11-01'
        )
,       COALESCE(
          SUBSTR(
            ( SELECT  bhboekin.bankinfo
              FROM    dbasetocivicrm.BHBOEKIN bhboekin
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
        , ''
        )
,       DATE(
          CONCAT(
            '20'
          , SUBSTR(
              pol.vervalper
            , 1
            , 2
            )
          , '-'
          , SUBSTR(
              pol.vervalper
            , 3
            , 2
            )
          , '-26'
          )
        )
,       pol.banknummer
,       pol.omschrijv
FROM    dbasetocivicrm.POL pol
WHERE   pol.verwijderd = 0
AND NOT pol.vervalper = ''
;
DROP TABLE IF EXISTS dbasetocivicrm.tempp01n
;
"

exit

SELECT  *
FROM    sol_import_incasso
;

