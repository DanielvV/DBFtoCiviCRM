#!/bin/bash
ssh root@$(cat $HOME/GIT/DBFToMySQL/config.php | grep host | tail -n 1 | cut -d "'" -f 2) << 'CiviCRM_Remote_Server_ssh'

banking=$(mysql -u root civicrm -e "SELECT civicrm_option_group.id FROM civicrm_option_group WHERE civicrm_option_group.name=\"civicrm_banking.plugin_types\";" | tail -n 1)
import=$(mysql -u root civicrm -e "SELECT civicrm_option_value.id FROM civicrm_option_value, civicrm_option_group WHERE civicrm_option_group.name=\"civicrm_banking.plugin_classes\" AND civicrm_option_value.option_group_id=civicrm_option_group.id LIMIT 1;" | tail -n 1)
match=$(mysql -u root civicrm -e "SELECT civicrm_option_value.id FROM civicrm_option_value, civicrm_option_group WHERE civicrm_option_group.name=\"civicrm_banking.plugin_classes\" AND civicrm_option_value.option_group_id=civicrm_option_group.id LIMIT 1,1;" | tail -n 1)
create=$(mysql -u root civicrm -e "SELECT civicrm_option_value.id FROM civicrm_option_value, civicrm_option_group WHERE civicrm_option_group.name=\"civicrm_banking.plugin_types\" AND civicrm_option_value.option_group_id=civicrm_option_group.id LIMIT 4,1;" | tail -n 1)
default=$(mysql -u root civicrm -e "SELECT civicrm_option_value.id FROM civicrm_option_value, civicrm_option_group WHERE civicrm_option_group.name=\"civicrm_banking.plugin_types\" AND civicrm_option_value.option_group_id=civicrm_option_group.id LIMIT 8,1;" | tail -n 1)
ignore=$(mysql -u root civicrm -e "SELECT civicrm_option_value.id FROM civicrm_option_value, civicrm_option_group WHERE civicrm_option_group.name=\"civicrm_banking.plugin_types\" AND civicrm_option_value.option_group_id=civicrm_option_group.id LIMIT 9,1;" | tail -n 1)
analyse=$(mysql -u root civicrm -e "SELECT civicrm_option_value.id FROM civicrm_option_value, civicrm_option_group WHERE civicrm_option_group.name=\"civicrm_banking.plugin_types\" AND civicrm_option_value.option_group_id=civicrm_option_group.id LIMIT 13,1;" | tail -n 1)
eboekhouden=$(mysql -u root civicrm -e "SELECT civicrm_option_value.id FROM civicrm_option_value, civicrm_option_group WHERE civicrm_option_group.name=\"civicrm_banking.plugin_types\" AND civicrm_option_value.option_group_id=civicrm_option_group.id LIMIT 16,1;" | tail -n 1)
if [ -z "$eboekhouden" ]; then
  mysql -u root civicrm -e "INSERT INTO civicrm_option_value(option_group_id, label, value, name, description, is_active, weight) VALUES ($banking, 'Configurable E-boekhouden Importer', 'CRM_Eboekhouden_Banking_PluginImpl_Importer_Eboekhouden', 'importer_eboekhouden', 'Imports mutations from E-boekhouden via their SOAP api', 1, 0);"
  eboekhouden=$(mysql -u root civicrm -e "SELECT civicrm_option_value.id FROM civicrm_option_value, civicrm_option_group WHERE civicrm_option_group.name=\"civicrm_banking.plugin_types\" AND civicrm_option_value.option_group_id=civicrm_option_group.id LIMIT 16,1;" | tail -n 1)
fi
mysql -u root civicrm << RunSomeMySQL
  DELETE FROM civicrm_bank_plugin_instance;
  INSERT INTO civicrm_bank_plugin_instance (plugin_type_id, plugin_class_id, name, description, enabled, weight, config, state) VALUES
  ($import, $eboekhouden, 'E-boekhouden Importer', 'Default Options for E-boekhouden Importer', '1', '100', '{}', '{}'),
  ($match, $ignore, 'E-boekhouden Ignore', 'Ignore everything except purpose 8* E-boekhouden Importer', '1', '100', '{}', '{}'),
  ($match, $analyse, 'E-boekhouden Analyser', 'Analyse purpose from E-boekhouden Importer', '1', '100', '{}', '{}'),
  ($match, $create, 'E-boekhouden Contribution Creator', 'Match and create contributions for E-boekhouden Importer', '1', '100', '{}', '{}'),
  ($match, $default, 'E-boekhouden Default Matcher', 'Manual matcher for E-boekhouden Importer', '1', '100', '{}', '{}');
  update civicrm_bank_plugin_instance set config='{"defaults":{"payment_instrument_id":"5"},"rules":[{"from":"MutatieRegels","to":[{"from":"cMutatieListRegel","to":[{"from":"BedragInvoer","to":"amount","type":"amount"},{"from":"TegenrekeningCode","to":"purpose","type":"set"}],"type":"object"}],"type":"object"},{"if":"equalto:GeldUitgegeven","from":"Soort","to":"_tmp","type":"set"},{"from":"amount","to":"_tmp","type":"append:"},{"from":"_tmp","to":"amount","type":"replace:GeldUitgegeven:-"},{"from":"Datum","to":"booking_date","type":"strtotime:Y-m-d\\\\\\\\TH:i:s"},{"from":"Datum","to":"value_date","type":"strtotime:Y-m-d\\\\\\\\TH:i:s"},{"from":"Omschrijving","to":"description","type":"set"},{"from":"Omschrijving","to":"description","warn":0,"type":"regex:#(.*) NONREF\\\\\\\\z#"},{"comment":"extract IBAN","from":"description","to":"_party_IBAN","warn":0,"type":"regex:#([A-Z]{2}[0-9]{2}[A-Z0-9]*)\\\\\\\\b#"},{"comment":"extract BIC","from":"description","to":"_party_BIC","warn":0,"type":"regex:#\\\\\\\\b([A-Z]{6}[A-Z0-9]{2})\\\\\\\\b#"},{"comment":"extract Contact id","from":"description","to":"contact_id","warn":0,"type":"regex:#\\\\\\\\b[0-9]{1}8[0-1]{1}[0-9]{1}0000([0-9]{7})0#"},{"comment":"extract Name","from":"description","to":"name","warn":0,"type":"regex:#\\\\\\\\b[A-Z]{6}[A-Z0-9]{2} (.*)\\\\\\\\z#"},{"comment":"extract Name","from":"name","to":"name","warn":0,"type":"regex:#\\\\\\\\A(?P<name>.*)?\\\\\\\\b[0-9]{1}8[0-1]{1}[0-9]{1}0000([0-9]{7})0\\\\\\\\z#"}]}' WHERE plugin_class_id=$eboekhouden;
  update civicrm_bank_plugin_instance set config='{"generate":1,"auto_exec":true,"ignore":[{"field":"purpose","regex": "#^[^8]#","message": "Dit is geen 8... grootboekrekening"},{"field":"description","regex": "#TOTAAL [0-9]* POSTEN#","message": "Dit is een incasso"}]}' WHERE plugin_class_id=$ignore;
  update civicrm_bank_plugin_instance set config='{"rules":[{"fields":["purpose"],"pattern":"/(?P<grootboekrekening>8[0-9]{3})/","actions":[{"action":"map","from":"purpose","to":"purpose","mapping":{"8080":"8080 Giften extra actie Ned","8085":"8085 Giften Er is Hulp","8090":"8090 Giften actie Buitenland","8100":"8100 Giften algemeen","8110":"8110 Door te betalen","8200":"8200 Legaten","8300":"8300 Sponsorplan","8520":"8520 Giften Mars vh Leven","8800":"8800 Inkomsten Conferentie","8900":"8900 Diverse opbrengst","8910":"8910 Cursusgelden"}},{"action":"lookup:FinancialType,id,name","from":"purpose","to":"financial_type_id"}]},{"fields":["contact_id"],"pattern":"/(?P<contactnummer>^0[0-9]*)/","actions":[{"action":"copy_ltrim_zeros","from":"contactnummer","to":"contact_id"}]},{"fields":["_tmp"],"pattern":"/./","actions":[{"action":"unset","to":"_tmp"}]}]}' WHERE plugin_class_id=$analyse;
  update civicrm_bank_plugin_instance set config='{"auto_exec":true,"factor":1.0,"threshold":0.7,"required_values":[],"value_propagation":{"ba.name_id":"contribution.custom_14","btx.financial_type_id":"contribution.financial_type_id","btx.payment_instrument_id":"contribution.payment_instrument_id","btx.campaign_id":"contribution.campaign_id"},"lookup_contact_by_name":{"soft_cap_probability":1.0,"soft_cap_min":4,"hard_cap_probability":0.85,"ignore_contact_types":"Household"}}' WHERE plugin_class_id=$create;
  update civicrm_bank_plugin_instance set config='{"generate":1,"auto_exec":false,"manual_enabled":true,"manual_probability":"50%","manual_show_always":true,"manual_title":"Handmatig verwerken","manual_message":"Verwerk deze transactie handmatig en voeg daarna de contributie aan onderstaande lijst, <strong>voordat</strong> er bevestigd wordt.","manual_contribution":"Vul hier het contributie ID in (indien van toepassing):","manual_default_source":"","manual_default_financial_type_id":1,"ignore_enabled":true,"ignore_show_always":true,"ignore_probability":"0.1","ignore_title":"Negeren","ignore_message":"Kies hiervoor als het zeker is dat deze transactie niet in CiviCRM thuishoort.","value_propagation":{"ba.name_id":"contribution.custom_14","btx.financial_type_id":"contribution.financial_type_id","btx.payment_instrument_id":"contribution.payment_instrument_id","btx.campaign_id":"contribution.campaign_id"},"lookup_contact_by_name":{"soft_cap_probability":0.8,"soft_cap_min":10,"hard_cap_probability":0.4}}' WHERE plugin_class_id=$default;
RunSomeMySQL

CiviCRM_Remote_Server_ssh



















