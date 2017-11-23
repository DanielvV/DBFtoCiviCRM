#!/bin/bash
cd "$HOME/SoL"
echo "payment_instrument,receive_date,boekstuk,financial_type,kostenpl,deb_cred,currency,total_amount,bedragvv,note,document,doc_regel,periode,subadmin,verwerkt,autoboek,doc_totaal,tot_deb,tot_cre,opc,bdat,mutd,tijd,contribution_contact_id,project,aant_dr,fondsboek,banknummer,bankinfo,factuurgrp,bewerking,betaalwyze,bankcode,storno" > \
bhboekin.csv
ssh root@civicrm.kvm.schreeuwomleven.nl "
  echo '
    SELECT *
    FROM BHBOEKIN
    WHERE SUBSTRING(rekening FROM 1 FOR 1) = 8
    AND NOT ( dagboek = \"MEMO\")
    AND NOT ( dagboek = \"KAS\"
              AND deb_cred = \"D\"
            )
    AND NOT ( dagboek = \"INKOOP\"
              AND NOT ( (   INSTR(omschrijv, \"Teveel\")
                        OR  INSTR(omschrijv, \"Corr.\")
                        OR  INSTR(omschrijv, \"Coll.\")
                        OR  INSTR(omschrijv, \"corri\")
                        OR  INSTR(omschrijv, \"Ontv.\")
                        OR  INSTR(omschrijv, \"ontv.\")
                        OR  INSTR(omschrijv, \"erug\")
                        OR  INSTR(omschrijv, \"voetjes\")
                        OR  INSTR(omschrijv, \"Gift Bri\")
                        OR  INSTR(omschrijv, \"Overgem.\")
                        OR  INSTR(omschrijv, \"Onvoldoende\")
                        OR  INSTR(omschrijv, \"Acceptgiro\")
                        OR  INSTR(omschrijv, \"Dubbele\")
                        OR  INSTR(omschrijv, \"machtiging\")
                        OR  INSTR(omschrijv, \"Groep 2x\")
                        )
                      AND NOT (   INSTR(omschrijv, \"tbv\")
                              OR  INSTR(omschrijv, \"t.b.v.\")
                              OR  INSTR(omschrijv, \"Saldo ontv. giften\")
                              OR  INSTR(omschrijv, \"L voor E\")
                              )
                      )
            );
  ' | \
  mysql -u root \
        -N -B -D \
        dbasetocivicrm
" |
sed 's/,/;/g' |
sed 's/\t/,/g' |
sed 's/^POSTBK,\(.*,P,G01010\)/SEPA DD One-off Transaction,\1/g' |
sed 's/^POSTBK,/Bank,/g' |
sed 's/^ABN-AM,/Bank,/g' |
sed 's/^INKOOP,/Bank,/g' |
sed 's/^KAS,/Kas,/g' |
sed 's/,D,[A-Z]\{3\},/&-/g' |
sed 's/,0000001,/,2,/g' |
sed 's/,\(,,[0-9]{1,2},,,,,,,,\)/,2\1/g' |
sed 's/,80[1-7][0-9],/,8100,/g' |
sed 's/,8081,/,8080,/g' |
sed 's/,8092,/,8090,/g' |
sed 's/,811[1-5],/,8090,/g' |
sed 's/,811[67],/,8100,/g' |
sed 's/,8120,/,8100,/g' |
sed 's/,84[24]0,/,8100,/g' |
sed 's/,85[49]0,/,8100,/g' |
sed 's/,8700,/,8100,/g' |
sed 's/,\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\),\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\),\([0-9]\{2\}\:[0-9]\{2\}\:[0-9]\{2\}\),,/,\1,\2,\3,1,/g' |
sed 's/,\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\),\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\),,,/,\1,\2,,1,/g' |
sed 's/,8080,/,8080 Giften extra actie Ned,/g' |
sed 's/,8085,/,8085 Giften Er is Hulp,/g' |
sed 's/,8090,/,8090 Giften actie Buitenland,/g' |
sed 's/,8100,/,8100 Giften algemeen,/g' |
sed 's/,8110,/,8110 Door te betalen,/g' |
sed 's/,8200,/,8200 Legaten,/g' |
sed 's/,8300,/,8300 Sponsorplan,/g' |
sed 's/,8520,/,8520 Giften Mars vh Leven,/g' |
sed 's/,8800,/,8800 Inkomsten Conferentie,/g' |
sed 's/,8900,/,8900 Diverse opbrengst,/g' |
sed 's/,8910,/,8910 Cursusgelden,/g' >> \
bhboekin.csv
touch "bhboekin.csv $(date +"%y-%m-%d %H:%M") count: $(expr $(wc -l bhboekin.csv | cut -d ' ' -f 1) - 1)"
tail -n +2 bhboekin.csv | split --lines=20000 --filter='head -n 1 ${FILE/-*}.csv > ${FILE/-a/-}.csv; cat >> ${FILE/-a/-}.csv' - bhboekin-

exit



bdat, mutd en opc naar log?

"payment_instrument"
Betaalmethode
dagboek
1


"receive_date"
Ontvangstdatum
boekdatum
2

"financial_type"
Financieel type *
rekening
4

"total_amount"
Totaal bedrag *
bedrag
8


"note"
Notitie
10


"contribution_contact_id"
Contactnummer (koppel aan contact) *
relatienr
23


"cancel_date"
Annuleringsdatum

"tax_amount"
Bedrag belasting

"fee_amount"
Bedrag per eenheid


"contribution_page_id"
Bijdragepagina-ID

"contribution_status_id"
Bijdragestatus

"contribution_source"
Bron van bijdrage

"contribution_campaign_id"
Campagne


"contribution_check_number"
Controlegetal

"creditnote_id"
Creditnota ID

"thankyou_date"
Datum bedankbericht

"revenue_recognition_date"
Datum inkomsten-verantwoording

"receipt_date"
Datum ontvangstbewijs

"email"
E-mail (koppel aan contact) *

"external_identifier"
Externe Id (koppel aan contact) *

"invoice_id"
Factuur ID


"custom_6"
How long have you been a donor?

"custom_5"
Known areas of interest

"amount_level"
Label bedrag

"net_amount"
Netto bedrag

"non_deductible_amount"
Niet-aftrekbaar bedrag



"cancel_reason"
Reden voor opzegging

"is_test"
Test

"pledge_payment"
Toezegging betaling

"pledge_id"
Toezeggingsnummer


"trxn_id"
Transactie ID


