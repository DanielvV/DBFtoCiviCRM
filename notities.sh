#!/bin/bash
function main {
  notities 2>&1 | grep -v 'Using a password on the command line interface can be insecure.'
}
function mysqlin () {
  echo mysqlin...
  echo "$1" | \
  mysql -u civicrm \
        -D \
        dbasetocivicrm
}
function notities () {
  echo notities...
  dir=/opt/SoL/
  zip=VNB
  unzip -q $dir$zip.zip \
        -d $dir
  rm       $dir$zip/NT005126.VNB
  for i in $dir$zip/*
  do echo -n "\"\"\");
  INSERT INTO notities VALUES
  (${i:${#i}-8:4}, \"\"\"" > ${i/.VNB/.0}
  done
  echo -n "
  DROP TABLE IF EXISTS notities;
  CREATE TABLE notities (
    id      int(10) UNSIGNED NOT NULL        COMMENT \"\"\"ID notities\"\"\",
    notitie text    COLLATE  utf8_unicode_ci COMMENT \"\"\"Note and/or Comment.\"\"\"
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
  INSERT INTO notities VALUES
  (0, \"\"\"eerste notitie" > $dir$zip/0first
  echo "\"\"\");" > $dir$zip/Zlast
  mysqlin "$(cat $dir$zip/* | iconv -f $(cat $HOME/GIT/DBFToMySQL/config.php | grep from_encoding | cut -d "'" -f 2) -t UTF-8 | sed "s/\\\\'/'/g; s/'/\\\\'/g; s/ *\"\"\")/')/g; s/\"\"\"/'/g")"
  rm -r $dir$zip
}
main
