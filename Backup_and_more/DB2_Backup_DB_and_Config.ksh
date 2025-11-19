#!/bin/ksh
# name: DB2_Backup_DB_and_Config.ksh
# desc: Backup db, logs and config files to tar file
#
#=====================================================#
# CHANGES
#=====================================================#
# Askew 20110907	Initial Rollout for testing
# Askew20110121         Bug - old files not aging off
#
#=====================================================#
. ~/.bash_profile
. ~/sqllib/db2profile
export INSTANCE=$1                                                                  #Askew20111021
export DB_NAME=$2                                                                   #Askew20111021
export TMP_DIR=/tmp                                                                 #Askew20111021
export myDate=`date +%y%m%d%H%M%S`                                                  #Askew20111021
echo ${0} ' STARTING AT TIMESTAMP ' ${myDate}                                       #Askew20111021 
echo '----------------------'                                                       #Askew20111021
echo ' Extract DB info before doing any processing '                                #Askew20111021
echo '----------------------'                                                       #Askew20111021
db2 get dbm cfg                     > $TMP_DIR/$DB_NAME.dbmcfg                      #Askew20111021
db2 get db cfg for $DB_NAME         > $TMP_DIR/$DB_NAME.dbcfg                       #Askew20111021
export myREMOTE_SERVER='xdmsdb01'
export myHost=`uname -a|awk '{print $2}'`
export TOOLZ_DIR=TOOLZ
export DB_NAME_CAPS=`echo $DB_NAME|tr '[a-z]' '[A-Z]'`
export DB2_USER=`whoami`
export SQLLIB=sqllib
export SCRIPT_DIR=scripts
export SQL_DIR=sql
export BACKUP_DIR=/opt/Xxxxxx/Backup/db/$DB_NAME
export BACKUP_SCRIPT_DIR=${TOOLZ_DIR}/${SCRIPT_DIR}
export EXPORT_DIR=export
export ARCHIVE_DIR=${BACKUP_DIR}/archive
export TAR_DIR=${ARCHIVE_DIR}
myARCDIR1=`db2 get db cfg for $DB_NAME|grep LOGARCHMETH1|cut -d":" -f2|awk '{print $1}'`
myARCDIR2=`echo $DB2INSTANCE`
myARCDIR3=`echo $DB_NAME|tr 'a-z' 'A-Z'`
myARCDIRALL=$myARCDIR1$myARCDIR2/$myARCDIR3/NODE0000/C0*
export DB2_ARCH_DIR=$myARCDIRALL
export DB2_HOME=`cat $TMP_DIR/$DB_NAME.dbmcfg|grep DFTDBPATH|awk '{print $NF}'`     #Askew20111021
export DB2_DIR=$DB2_HOME/sqllib                                                     #Askew20111021
export LOG_DIR=`cat ${TMP_DIR}/${DB_NAME}.dbcfg|grep "Path to log files"|cut -d"=" -f2` #Askew20111021
echo '#----------------------#'                                                     #Askew20111021
echo ${0} ' # Report Info    #'                                                     #Askew20111021
echo '#----------------------#'                                                     #Askew20111021
echo 'INSTANCE          = ' $INSTANCE                                               #Askew20111021
echo 'DB_NAME           = ' $DB_NAME                                                #Askew20111021
echo 'DB_NAME_CAPS      = ' $DB_NAME_CAPS                                           #Askew20111021
echo 'DB2_USER          = ' $DB2_USER                                               #Askew20111021
echo 'DB2_HOME          = ' $DB2_HOME                                               #Askew20111021
echo 'DB2_DIR           = ' $DB2_DIR                                                #Askew20111021
echo 'SQLLIB            = ' $DB2_HOME/$SQLLIB                                       #Askew20111021
echo 'SCRIPT_DIR        = ' $DB2_HOME/$SCRIPT_DIR                                   #Askew20111021
echo 'SQL_DIR           = ' $DB2_HOME/$SQL_DIR                                      #Askew20111021
echo 'BACKUP_SCRIPT_DIR = ' $DB2_HOME/$BACKUP_SCRIPT_DIR                            #Askew20111021
echo 'BACKUP_DIR        = ' ${BACKUP_DIR}                                           #Askew20111021
echo 'EXPORT_DIR        = ' ${BACKUP_DIR}/$EXPORT_DIR                               #Askew20111021
echo 'LOG_DIR           = ' $LOG_DIR                                                #Askew20111021
echo 'DB2_ARCH_DIR      = ' $DB2_ARCH_DIR                                           #Askew20111021
echo 'TAR_DIR           = ' $TAR_DIR                                                #Askew20111021
echo 'TMP_DIR           = ' $TMP_DIR                                                #Askew20111021
echo 'TOOLZ_DIR         = ' $DB2_HOME/$TOOLZ_DIR                                    #Askew20111021
echo 'myDate            = ' $myDate                                                 #Askew20111021
echo '#-----------------------------------------#'                                  #Askew20111021
echo ${0} ' --> Remove old backups and logs'                                        #Askew20111021
echo '#-----------------------------------------#'                                  #Askew20111021
find ${BACKUP_DIR}/. -type f -mtime +6  -exec rm -f {} \;                           #Askew20111021
find ${ARCHIVE_DIR}/. -type f -mtime +6  -exec rm -f {} \;                          #Askew20111021
find $DB2_ARCH_DIR/. -type f -mtime +6  -name '*.gz' -exec rm -f {} \;              #Askew20111021
find $LOG_DIR/. -type f -mtime +6  -name '*LOG*' -exec rm -f {} \;                  #Askew20110121
echo '----------------------'                                                       #Askew20111021
echo ' DB Available?        '                                                       #Askew20111021
echo '----------------------'                                                       #Askew20111021
 if [ `db2 connect to ${DB_NAME}|egrep "SQL1013N|SQL1776N|SQL1117N"|wc -l` -gt 0 ]
	then
	    echo "Aborting DB2_Backup_DB_and_Config.ksh"
		echo " DB not available; NOT found, HADR or PENDING State"
		exit
 fi
echo '##############################################################'               #Askew20111021
echo ${0} ' --> Prerequisites passed STARTING BACKUP for DB ' ${DB_NAME}            #Askew20111021
echo '##############################################################'               #Askew20111021
echo '----------------------'                                                       #Askew20111021
echo ' Extract DB info      '                                                       #Askew20111021
echo '----------------------'                                                       #Askew20111021
db2 get dbm cfg                     > $TMP_DIR/$DB_NAME.dbmcfg
db2 get db cfg for $DB_NAME         > $TMP_DIR/$DB_NAME.dbcfg
db2 get admin cfg                   > $TMP_DIR/$DB_NAME.admcfg
db2 get snapshot for all on $DB_NAME > $TMP_DIR/$DB_NAME.snapshot 
db2 get monitor switches            > $TMP_DIR/$DB_NAME.mon_sw
db2 get contacts                    > $TMP_DIR/$DB_NAME.contacts
db2look -d $DB_NAME -l -xd -f -e    > $TMP_DIR/$DB_NAME.db2look
db2mtrk -i -d -p -v                 > $TMP_DIR/$DB_NAME.mtrk
db2 get db cfg for $DB_NAME|grep \(|cut -d"(" -f2|sed 's/)//g'|sed 's/  / /g'|awk '$3 ~ /[A-Z0-9]/ {  print $0  }'|sed 's/=//'|awk '{print "update db cfg for $DB_NAME USING " $0, ";"}'|sort -u|tr [a-z] [A-Z]|egrep -i "on|off|auto|recover|_"|egrep -v "TSM|collate" > $TMP_DIR/$DB_NAME.setdbcfg 
db2 get snapshot for db on $DB_NAME|egrep "HADR|Role|State|Synchronization|Connection|Heart|Local host|Local service|Remote|timeout|position|Log gap" > $TMP_DIR/$DB_NAME.hadr_status
db2 connect reset;
db2licm -l show detail             > $TMP_DIR/$DB_NAME.install_info
echo '####################' 
echo '# Build Bkup SQL   #'
echo '####################' 
echo db2 connect to $DB_NAME\;                                      > ${BACKUP_DIR}/backup_$DB_NAME.sql
echo db2 BACKUP DATABASE  $DB_NAME ONLINE TO \"${BACKUP_DIR}\" WITH 3 BUFFERS BUFFER 1024 PARALLELISM 3 UTIL_IMPACT_PRIORITY 50 INCLUDE LOGS WITHOUT PROMPTING\;          >> ${BACKUP_DIR}/backup_$DB_NAME.sql
#cat  ${BACKUP_DIR}/backup_$DB_NAME.sql
chmod 700 ${BACKUP_DIR}/backup_$DB_NAME.sql
#-----------------------------------------#
# Move zip current backups and archive
#-----------------------------------------#
gzip -f ${BACKUP_DIR}/*.001
mv  ${BACKUP_DIR}/*.001.*  ${ARCHIVE_DIR}/.               #Askew20111021
mv  ${BACKUP_DIR}/*.LOG*   ${ARCHIVE_DIR}/.               #Askew20111021
gzip -f $DB2_ARCH_DIR/*.LOG
#
# AT THIS POINT, THE DB IMAGE COPYS ARE
# ARCHIVED and BACKUP_DIR should not have
# any backup images.
#   Any new logs are taken during backup.
#
#-----------------------------------------#
# Clean the current log file
#-----------------------------------------#
echo '####################' 
echo '# Switch logs       ' 
echo '####################' 
echo 'db2 archive log for database $DB_NAME;'
db2 archive log for database $DB_NAME > @tmp.3
cat  @tmp.3
myRC=`cat @tmp.3|grep -i "The ARCHIVE LOG command completed successfully"|wc -l`
if [ $myRC -ne 1 ]
   then
      echo $0 failed|mailx -s $myHost $DBA_oncall
   else
       cat @tmp.3
fi
rm  @tmp.3
#-----------------------------------------#
# copy current logs to archive dir
#-----------------------------------------#
###########################################
# TAKE BACKUP
###########################################
echo '####################' 
echo '# TAKE BACKUP'
echo '####################' 
. ${BACKUP_DIR}/backup_$DB_NAME.sql > @tmp.1
cat @tmp.1
#>>> END BACKUP
myTIMESTMP=`cat @tmp.1|grep timestamp|awk '{print $NF}'`
#>>> END BACKUP
echo '#>>> END BACKUP'
db2 archive log for database $DB_NAME > @tmp.4
echo '####################' 
echo '# Backup Info.     #'
echo '####################' 
#echo db2 db2 list history backup since $myTIMESTMP for db $DB_NAME 
db2 list history backup since $myTIMESTMP for db $DB_NAME > @tmp.2 
cat @tmp.2
echo '#------------------#'
echo '# End Backup Info. #'
echo '#------------------#'
###########################################
# Take Export
###########################################
cd ${BACKUP_DIR}/$EXPORT_DIR
db2move $DB_NAME_CAPS export

###########################################
# SAVE LOGS
###########################################
cp $DB2_ARCH_DIR/*.LOG ${BACKUP_DIR}
#-----------------------------------------#
# SAVE Supplementary INFO
#-----------------------------------------#
cp ~/.bash_profile                   ${BACKUP_DIR}/$DB2_USER.bash_profile
cp  $TMP_DIR/$DB_NAME.dbmcfg         ${BACKUP_DIR}
cp  $TMP_DIR/$DB_NAME.dbcfg          ${BACKUP_DIR}
cp  $TMP_DIR/$DB_NAME.admcfg         ${BACKUP_DIR}
cp  $TMP_DIR/$DB_NAME.snapshot       ${BACKUP_DIR}
cp  $TMP_DIR/$DB_NAME.mon_sw         ${BACKUP_DIR}
cp  $TMP_DIR/$DB_NAME.contacts       ${BACKUP_DIR}
cp  $TMP_DIR/$DB_NAME.db2look        ${BACKUP_DIR}
cp  $TMP_DIR/$DB_NAME.mtrk           ${BACKUP_DIR}
cp  $TMP_DIR/$DB_NAME.setdbcfg       ${BACKUP_DIR}
cp  $TMP_DIR/$DB_NAME.hadr_status    ${BACKUP_DIR}
cp  $TMP_DIR/$DB_NAME.install_info   ${BACKUP_DIR}
crontab -l >                         ${BACKUP_DIR}/crontab.sav
cp ~/sqllib/db2profile               ${BACKUP_DIR}
env >                                ${BACKUP_DIR}/$DB2_USER.env.sav
#-----------------------------------------#
# Create TAR of Backup Dir and 
# add SQLLIB to TAR
#-----------------------------------------#
echo '####################' 
echo '# TAR Inventory     ' 
echo '####################' 
cd ${BACKUP_DIR}                                              
tar  -cvf  ${DB_NAME_CAPS}_${myHost}_${myTIMESTMP}.tar  /dev/null 
tar  -uvf  ${BACKUP_DIR}/${DB_NAME_CAPS}_${myHost}_${myTIMESTMP}.tar $DB_NAME_CAPS.*
tar  -uvf  ${BACKUP_DIR}/${DB_NAME_CAPS}_${myHost}_${myTIMESTMP}.tar $DB_NAME.*
tar  -uvf  ${BACKUP_DIR}/${DB_NAME_CAPS}_${myHost}_${myTIMESTMP}.tar *.LOG
tar  -uvf  ${BACKUP_DIR}/${DB_NAME_CAPS}_${myHost}_${myTIMESTMP}.tar $DB2_USER.*
tar  -uvf  ${BACKUP_DIR}/${DB_NAME_CAPS}_${myHost}_${myTIMESTMP}.tar $TOOLZ_DIR 
tar  -uvf  ${BACKUP_DIR}/${DB_NAME_CAPS}_${myHost}_${myTIMESTMP}.tar $EXPORT_DIR
cd $DB2_HOME
tar  -uvf  ${BACKUP_DIR}/${DB_NAME_CAPS}_${myHost}_${myTIMESTMP}.tar $SQLLIB 
tar  -Xuvf $BACKUP_SCRIPT_DIR/scripts/exclude.txt ${BACKUP_DIR}/${DB_NAME_CAPS}_${myHost}_${myTIMESTMP}.tar $SCRIPT_DIR 
tar  -uvf  ${BACKUP_DIR}/${DB_NAME_CAPS}_${myHost}_${myTIMESTMP}.tar $SQL_DIR 
tar  -uvf  ${BACKUP_DIR}/${DB_NAME_CAPS}_${myHost}_${myTIMESTMP}.tar $BACKUP_SCRIPT_DIR 
tar  -uvf  ${BACKUP_DIR}/${DB_NAME_CAPS}_${myHost}_${myTIMESTMP}.tar $TOOLZ_DIR 
echo '##########################################'
echo '# FTP BACKUP TAR'
echo '##########################################'
cd ${BACKUP_DIR}
gzip ${BACKUP_DIR}/${DB_NAME_CAPS}_${myHost}_${myTIMESTMP}.tar
for i in $BACKUP_SCRIPT_DIR/scripts ${BACKUP_DIR} $DB2_HOME
{
     for j in 1 2 3 4 5 6 7 8 9 0
         {
            rm $i/@tmp.$j
         }
}
rm  $TMP_DIR/$DB_NAME.dbmcfg $TMP_DIR/$DB_NAME.dbcfg $TMP_DIR/$DB_NAME.admcfg $TMP_DIR/$DB_NAME.snapshot $TMP_DIR/$DB_NAME.mon_sw $TMP_DIR/$DB_NAME.contacts $TMP_DIR/$DB_NAME.db2look $TMP_DIR/$DB_NAME.mtrk $TMP_DIR/$DB_NAME.setdbcfg $TMP_DIR/$DB_NAME.hadr_status $TMP_DIR/$DB_NAME.install_info
echo '##########################################'
echo '# FTP BACKUP TAR'
echo '##########################################'
sftp ${myREMOTE_SERVER} << EOF
cd ${ARCHIVE_DIR}
put ${BACKUP_DIR}/${DB_NAME_CAPS}_${myHost}_${myTIMESTMP}.tar.gz
EOF
mv ${BACKUP_DIR}/${DB_NAME_CAPS}_${myHost}_${myTIMESTMP}.tar.gz ${TAR_DIR}/.   #Askew20111021
echo '#----------------------------------------#'
echo '# Completed ' ${TAR_DIR}/${DB_NAME_CAPS}_${myHost}_${myTIMESTMP}.tar.gz ' FTP to ' ${myREMOTE_SERVER}
echo '#----------------------------------------#'
exit
