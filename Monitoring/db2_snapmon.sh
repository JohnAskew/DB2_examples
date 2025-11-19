#!/usr/bin/ksh
#################################################################################  
#  Utility name:   db2_snapmon.sh
#  Creator     :   John Askew 
#  Version     :   1.0          
#  Description :   Monitor database snapshots and generate alerts.  
#
#  Pre-requisites: All the monitor switches should be turned on in the database
#                  configuration.
#
#  Usage instructions: 
# 
#   Start the utility from the command line by typing the following command:
#       nohup db2_snapmon.sh > /dev/null &
#     Note:  The & sign in the end is very important as it runs the utility in 
#            background and frees up your terminal.  
#     After starting the utility you can either logout or continue with your
#     work.  When you get a log out you will get a message "There are running 
#     jobs" from AIX.  Ignore it and press <CTRL-D> once again to log out. 
#     The snapshot monitor program will run now at selected time intervals.
#
#
################################################################################ 
# Set up temporary file names to hold snapshot statistics
ALL_SNAP_FILE=getsnap.all.`date +%d%m%H%M%S'`; 
DB_SNAP_FILE=getsnap.db.`date +%d%m%H%M%S`; 
BP_SNAP_FILE=getsnap.bp.`date +%d%m%H%M%S`; 
TB_SNAP_FILE=getsnap.tb.`date +%d%m%H%M%S`; 
AP_SNAP_FILE=getsnap.ap.`date +%d%m%H%M%S`; 
TS_SNAP_FILE=getsnap.ts.`date +%d%m%H%M%S`;
DB_CONFIG_FILE=snapmon.dbcfg.`date +%d%m%H%M%S`;
DBM_CONFIG_FILE=snapmon.dbmcfg.`date +%d%m%H%M%S`;

# CUSTOMIZABLE VALUES  
# Thresholds and other constants
#
MAIL_TO=?????????                    # Change this to your email.
DB_NAME="LUCID";                     # Database name.  Change to your database name.
DB_SNAPSHOT_INTERVAL=60;             # Interval in seconds between each snapshot
DB_HWM_CONN_THRSH=95;                # DB High water mark connections threshold percent 
DB_APP_EX_CURR_THRSH=95;             # DB Application executing in db manager currently
                                     # threshold percent
DB_MAX_AGNTS_APPS_THRSH=95;          # Maximum agents associated with applications
                                     # threshold percent
DB_MAX_COORD_AGNTS_THRSH=95;         # Maximum coordinating agents threshold percent
DB_LCKS_CURR_THRSH=100;              # Locks held currently threshold percent
DB_LOCKLIST_THRSH=90;                # LOCKLIST threshold percent
DB_LCK_WT_THRSH=90000;               # Threshold for average lock wait in milliseconds
DB_DEAD_LCKS_THRSH=1;                # Threshold for number of deadlocks per minute.
DB_AGNT_LCK_WT_THRSH=2;              # Threshold for agents currently waiting on locks
DB_LCK_TMOUT_THRSH=1;                # Lock time outs per minute threshold
DB_SRT_OVFLW_THRSH=5;                # Sort overflow percentage threshold
DB_MAX_TOT_LOG_SPC_THRSH_WARN=75;    # Max total log space used warning 
                                     # threshold percent
DB_MAX_TOT_LOG_SPC_THRSH_CRIT=85;    # Max total space used critical 
                                     # threshold percent
DB_PKG_CACH_HIT_THRSH=05 ;            # Package cache hit ratio threshold percent
DB_CTLG_CACH_HIT_THRSH=80;           # Catalog cache hit ratio threshold percent
DB_NUM_SML_HASH_JOIN_OVFLW_THRSH=10; # Small hash join overflow threshold 
                                     # percent
DB_NUM_HASH_JOIN_OVFLW_THRSH=10;     # Hash join overflow threshold percent
DB_NUM_HASH_LOOP_THRSH=10;           # Hash loops threshold percent

#######
### Start of program logic
#######
while (( 1 == 1 ))
do
db2 "CONNECT TO" $DB_NAME;
db2 "GET DBM CFG" > $DBM_CONFIG_FILE;
db2 "GET DB CFG FOR " $DB_NAME > $DB_CONFIG_FILE;
# Get DBM config parameters into individual variables 
MON_HEAP_SZ=`grep MON_HEAP_SZ $DBM_CONFIG_FILE | awk '{print $8}'`;
UDF_MEM_SZ=`grep UDF_MEM_SZ $DBM_CONFIG_FILE | awk '{print $9}'`;
JAVA_HEAP_SZ=`grep JAVA_HEAP_SZ $DBM_CONFIG_FILE | awk '{print $9}'`;
SHEAPTHRES=`grep SHEAPTHRES $DBM_CONFIG_FILE | awk '{print $7}'`;
ASLHEAPSZ=`grep ASLHEAPSZ $DBM_CONFIG_FILE | awk '{print $9}'`;
RQRIOBLK=`grep RQRIOBLK $DBM_CONFIG_FILE | awk '{print $9}'`;
QUERY_HEAP_SZ=`grep QUERY_HEAP_SZ $DBM_CONFIG_FILE | awk '{print $7}'`;
DRDA_HEAP_SZ=`grep DRDA_HEAP_SZ $DBM_CONFIG_FILE | awk '{print $8}'`;
MAXAGENTS=`grep 'Max number of existing agents' $DBM_CONFIG_FILE | awk '{print $8}'`;
NUM_POOLAGENTS=`grep NUM_POOLAGENTS $DBM_CONFIG_FILE | awk '{print $6}'`;
NUM_INITAGENTS=`grep 'Initial number of agents in pool' $DBM_CONFIG_FILE | awk '{print $9}'`;
MAX_COORDAGENTS=`grep 'Max number of coordinating agents'  $DBM_CONFIG_FILE | awk '{print $8}'`;
if [[ "$MAX_COORDAGENTS" =  "MAXAGENTS" ]]
 then
   MAX_COORDAGENTS=$MAXAGENTS
elif [[ "$MAX_COORDAGENTS" = "(MAXAGENTS" ]]
 then
   let MAX_COORDAGENTS=$MAXAGENTS-$NUM_INITAGENTS
fi
MAXCAGENTS=`grep 'Max no. of concurrent coordinating agents' $DBM_CONFIG_FILE | awk '{print $9}'`;
if [ "$MAXCAGENTS" -eq "MAX_COORDAGENTS" ]
then
  MAXCAGENTS=$MAX_COORDAGENTS
fi
MAXDARI=`grep MAXDARI $DBM_CONFIG_FILE | awk '{print $8}'`;
if [ "$MAXDARI" -eq "MAX_COORDAGENTS" ]
then
  MAXDARI=$MAX_COORDAGENTS
fi 
MAX_QUERYDEGREE=`grep MAX_QUERYDEGREE $DBM_CONFIG_FILE | awk '{print $8}'`;
INTRA_PARALLEL=`grep INTRA_PARALLEL $DBM_CONFIG_FILE | awk '{print $6}'`;
#Get DB config parameters into individual variables
BACKUP_PENDING=`grep 'Backup pending' $DB_CONFIG_FILE | awk '{print $4}'`;
ROLLFORWARD_PENDING=`grep 'Rollforward pending' $DB_CONFIG_FILE | awk '{print $4}'`;
RESTORE_PENDING=`grep 'Restore pending' $DB_CONFIG_FILE | awk '{print $4}'`;
DBHEAP=`grep DBHEAP $DB_CONFIG_FILE | awk '{print $6}'`;
CATALOGCACHE_SZ=`grep CATALOGCACHE_SZ $DB_CONFIG_FILE | awk '{print $7}'`;
LOGBUFSZ=`grep LOGBUFSZ $DB_CONFIG_FILE | awk '{print $7}'`;
UTIL_HEAP_SZ=`grep UTIL_HEAP_SZ $DB_CONFIG_FILE | awk '{print $7}'`;
BUFFPAGE=`grep BUFFPAGE $DB_CONFIG_FILE | awk '{print $7}'`;
ESTORE_SEG_SZ=`grep ESTORE_SEG_SZ $DB_CONFIG_FILE | awk '{print $8}'`;
NUM_ESTORE_SEGS=`grep NUM_ESTORE_SEGS $DB_CONFIG_FILE | awk '{print $8}'`;
LOCKLIST=`grep LOCKLIST $DB_CONFIG_FILE | awk '{print $9}'`;
APP_CTL_HEAP_SZ=`grep APP_CTL_HEAP_SZ $DB_CONFIG_FILE | awk '{print $9}'`;
SORTHEAP=`grep SORTHEAP $DB_CONFIG_FILE | awk '{print $7}'`;
STMTHEAP=`grep STMTHEAP $DB_CONFIG_FILE | awk '{print $7}'`;
APPLHEAPSZ=`grep APPLHEAPSZ $DB_CONFIG_FILE | awk '{print $7}'`;
PCKCACHESZ=`grep PCKCACHESZ $DB_CONFIG_FILE | awk '{print $7}'`;
STAT_HEAP_SZ=`grep STAT_HEAP_SZ $DB_CONFIG_FILE | awk '{print $7}'`;
MAXLOCKS=`grep MAXLOCKS $DB_CONFIG_FILE | awk '{print $9}'`;
LOCKTIMEOUT=`grep LOCKTIMEOUT $DB_CONFIG_FILE | awk '{print $6}'`;
CHNGPGS_THRESH=`grep CHNGPGS_THRESH $DB_CONFIG_FILE | awk '{print $6}'`;
NUM_IOCLEANERS=`grep NUM_IOCLEANERS $DB_CONFIG_FILE | awk '{print $8}'`;
NUM_IOSERVERS=`grep NUM_IOSERVERS $DB_CONFIG_FILE | awk '{print $7}'`;
MAXAPPLS=`grep 'Max number of active applications' $DB_CONFIG_FILE | awk '{print $8}'`;
if [ "$PCKCACHESZ" -eq "(MAXAPPLS*8)" ] 
then
  let PCKCACHESZ=$MAXAPPLS*8 
fi
AVG_APPLS=`grep AVG_APPLS $DB_CONFIG_FILE | awk '{print $8}'`;
MAXFILOP=`grep MAXFILOP $DB_CONFIG_FILE | awk '{print $9}'`;
LOGFILSIZ=`grep LOGFILSIZ $DB_CONFIG_FILE | awk '{print $7}'`;
LOGPRIMARY=`grep LOGPRIMARY $DB_CONFIG_FILE | awk '{print $8}'`;
LOGSECOND=`grep LOGSECOND $DB_CONFIG_FILE | awk '{print $8}'`;
LOGPATH=`grep 'Path to log files' $DB_CONFIG_FILE | awk '{print $6}'`;
FIRST_LOG_FILE=`grep 'First active log file' $DB_CONFIG_FILE | awk '{print $6}'`;
LOGRETAIN=`grep LOGRETAIN $DB_CONFIG_FILE | awk '{print $8}'`;
USEREXIT=`grep USEREXIT $DB_CONFIG_FILE | awk '{print $8}'`;
# Split the snapshot file into multiple files
db2 "get snapshot for all on " $DB_NAME > $ALL_SNAP_FILE;
while read x1 
do
  if echo $x1 | grep 'Database Snapshot' 
    then
     OUT_FILE=$DB_SNAP_FILE  
  elif echo $x1 | grep 'Bufferpool Snapshot' 
  then
#     OUT_FILE=$BP_SNAP_FILE 
    break;
  elif echo $x1 | grep 'Application Snapshot'
  then
     OUT_FILE=$AP_SNAP_FILE
  elif echo $x1 | grep 'Tablespace Snapshot'
  then
     OUT_FILE=$TS_SNAP_FILE
  elif echo $x1 | grep 'Table Snapshot'
  then
     OUT_FILE=$TB_SNAP_FILE 
  fi
  echo $x1 >> $OUT_FILE
done < $ALL_SNAP_FILE; 
# Analyze DB Snapshot and raise alarms
SNAPSHOT_TIME=`grep 'Snapshot timestamp' $DB_SNAP_FILE | awk '{print $5}'`;
SNAPSHOT_DATE=`grep 'Snapshot timestamp' $DB_SNAP_FILE | awk '{print $4}'`; 
SNAPSHOT_RESET_TIME=`grep 'Last reset timestamp' $DB_SNAP_FILE | awk '{print  $6}'`;
DB_HWM_CONN=`grep 'High water mark for connections' $DB_SNAP_FILE | awk '{print $7}'`;
DB_APP_CONN=`grep 'Application connects' $DB_SNAP_FILE | awk '{print $4}'`;
DB_APP_CONN_CURR=`grep 'Applications connected currently' $DB_SNAP_FILE | awk '{print $5}'`;
DB_APP_EX_CURR=`grep 'Appls. executing in db manager currently' $DB_SNAP_FILE | awk '{print $8}'`;
DB_AGNTS_APPS=`grep 'Agents associated with applications' $DB_SNAP_FILE | awk '{print $6}'`;
DB_MAX_AGNTS_APPS=`grep 'Maximum agents associated with applications' $DB_SNAP_FILE | awk '{print $6}'`;
DB_MAX_COORD_AGNTS=`grep 'Maximum coordinating agents' $DB_SNAP_FILE | awk '{print $5}'`;
DB_LCKS_CURR=`grep 'Locks held currently' $DB_SNAP_FILE | awk '{print $5}'`;
DB_LCK_WT=`grep 'Lock waits' $DB_SNAP_FILE | awk '{print $4}'`;
DB_LCK_WT_TM=`grep 'Time database waited on locks (ms)' $DB_SNAP_FILE | awk '{print $8}'`;  
DB_LCK_LST_USE=`grep 'Lock list memory in use' $DB_SNAP_FILE | awk '{print $8}'`;
DB_DEAD_LCKS=`grep 'Deadlocks detected' $DB_SNAP_FILE | awk '{print $4}'`;
DB_LCK_ESC=`grep 'Lock escalations' $DB_SNAP_FILE | awk '{print $4}'`;
DB_EX_LCK_ESC=`grep 'Exclusive lock escalations' $DB_SNAP_FILE | awk '{print $5}'`;
DB_AGNT_LCK_WT=`grep 'Agents currently waiting on locks' $DB_SNAP_FILE | awk '{print $7}'`;
DB_LCK_TMOUT=`grep 'Lock Timeouts' $DB_SNAP_FILE | awk '{print $4}'`;
DB_SRT_HEAP_ALL=`grep 'Total sort heap allocated' $DB_SNAP_FILE | awk '{print $6}'`;
DB_SRTS=`grep 'Total sorts' $DB_SNAP_FILE | awk '{print $4}'`;
DB_SRT_TM=`grep 'Total sort time' $DB_SNAP_FILE | awk '{print $6}'`;
DB_SRT_OVFLW=`grep 'Sort overflows' $DB_SNAP_FILE | awk '{print $4}'`;
DB_ACTV_SRTS=`grep 'Active sorts' $DB_SNAP_FILE | awk '{print $4}'`;
DB_DBHEAP_HWM=`grep 'High water mark for database heap' $DB_SNAP_FILE | awk '{print $8}'`;
DB_DL_INT_RL_BCK=`grep 'Internal rollbacks due to deadlock' $DB_SNAP_FILE | awk '{print $7}'`;
DB_MAX_SEC_LOG_SPC=`grep 'Maximum secondary log space used' $DB_SNAP_FILE | awk '{print $8}'`;
DB_MAX_TOT_LOG_SPC=`grep 'Maximum total log space used' $DB_SNAP_FILE | awk '{print $8}'`;
DB_SEC_LOG_ALL=`grep 'Secondary logs allocated currently' $DB_SNAP_FILE | awk '{print $6}'`;
DB_PKG_CACH_LKUP=`grep 'Package cache lookups' $DB_SNAP_FILE | awk '{print $5}'`;
DB_PKG_CACH_INSRT=`grep 'Package cache inserts' $DB_SNAP_FILE | awk '{print $5}'`;
DB_APP_SECT_LKUP=`grep 'Application section lookups' $DB_SNAP_FILE | awk '{print$5}'`;
DB_APP_SECT_INSRT=`grep 'Application section inserts' $DB_SNAP_FILE | awk '{print $5}'`;
DB_CTLG_CACH_LKUP=`grep 'Catalog cache lookups' $DB_SNAP_FILE | awk '{print $5}'`;
DB_CTLG_CACH_INSRT=`grep 'Catalog cache inserts' $DB_SNAP_FILE | awk '{print $5}'`;
DB_CTLG_CACH_OVFLW=`grep 'Catalog cache overflows' $DB_SNAP_FILE | awk '{print $5}'`;
DB_CTLG_CACH_HP_FULL=`grep 'Catalog cache heap full' $DB_SNAP_FILE | awk '{print $6}'`;
DB_NUM_HASH_JOIN=`grep 'Number of hash joins' $DB_SNAP_FILE | awk '{print $6}'`;
DB_NUM_HASH_LOOP=`grep 'Number of hash loops' $DB_SNAP_FILE | awk '{print $6}'`;
DB_NUM_HASH_JOIN_OVFLW=`grep 'Number of hash join overflows' $DB_SNAP_FILE | awk '{print $7}'`;
DB_NUM_SML_HASH_JOIN_OVFLW=`grep 'Number of small hash join overflows' $DB_SNAP_FILE | awk '{print $8}'`;
#  Code to monitor and trigger alarms
# Check 1:
typeset -i ratio
ratio=`echo $DB_HWM_CONN $MAXAPPLS | awk '{printf "%3d", ($1/$2) * 100}'`;
if [ $ratio -gt $DB_HWM_CONN_THRSH ] 
then
  MAIL_SUB="WARNING: DB Connections High Water Mark exceeds threshold: $DB_NAME";
  MAIL_LINE1="DB Connections HWM =  $DB_HWM_CONN \n";
  MAIL_LINE2="MAXAPPLS config    =  $MAXAPPLS \n";
  MAIL_LINE3="Threshold          =  $DB_HWM_CONN_THRSH %\n";
  echo $MAIL_LINE1 $MAIL_LINE2 $MAIL_LINE3  | mail -s "$MAIL_SUB" $MAIL_TO;
fi
ratio=`echo $DB_APP_EX_CURR $MAXCAGENTS | awk '{printf "%3d", ($1/$2)*100}'`;
if [ $ratio -gt $DB_MAX_AGNTS_APPS_THRSH ]
then
  MAIL_SUB="WARNING: No. of concurrent agents exceeds threshold: $DB_NAME";
  MAIL_LINE1="No. of applications executing concurrently =  $DB_APP_EX_CURR \n";
  MAIL_LINE2="MAXCAGENTS config                          =  $MAXCAGENTS \n";
  MAIL_LINE3="Threshold                                  =  $DB_MAX_AGNTS_APPS_THRSH  %\n";
  echo $MAIL_LINE1 $MAIL_LINE2 $MAIL_LINE3  | mail -s "$MAIL_SUB" $MAIL_TO;
fi  
ratio=`echo $DB_MAX_AGNTS_APPS $MAXAGENTS | awk '{printf "%3d", ($1/$2)*100}'`;
if [ $ratio -gt $DB_MAX_AGNTS_APPS_THRSH ]
then
  MAIL_SUB="WARNING: Max. agents associated with applications exceeding threshold: $DB_NAME";
  MAIL_LINE1="Maximum agents associated with applications = $DB_MAX_AGNTS_APPS  \n"; 
  MAIL_LINE2="MAXAGENTS config parameter                  = $MAXAGENTS\n";
  MAIL_LINE3="Threshold                                   = $DB_MAX_AGNTS_APPS_THRSH %\n";
  echo $MAIL_LINE1 $MAIL_LINE2 $MAIL_LINE3 | mail -s "$MAIL_SUB" $MAIL_TO;
fi
ratio=`echo $DB_MAX_COORD_AGNTS $MAX_COORDAGENTS | awk '{printf "%3d",($1/$2)*100}'`;
if [ $ratio -gt $DB_MAX_COORD_AGNTS_THRSH ]
then
  MAIL_SUB="WARNING: Max. coord agents exceeding threshold: $DB_NAME";
  MAIL_LINE1="Maximum coordinating agents      = $DB_MAX_COORD_AGNTS\n";
  MAIL_LINE2="MAX_COORDAGENTS config parameter = $MAX_COORDAGENTS\n";
  MAIL_LINE3="Threshold                        = $DB_MAX_COORD_AGNTS_THRSH  %\n";
  echo $MAIL_LINE1 $MAIL_LINE2 $MAIL_LINE3 | mail -s "$MAIL_SUB" $MAIL_TO;
fi 
ratio=`echo $DB_LCKS_CURR $DB_APP_CONN_CURR | awk '{printf "%6d",($1/$2)}'`;
if [ $ratio -gt $DB_LCKS_CURR_THRSH ]
then
  MAIL_SUB="WARNING: No. of locks per application exceeds threshold: $DB_NAME";
  MAIL_LINE1="Locks held currently             = $DB_LCKS_CURR\n";
  MAIL_LINE2="Applications connected currently = $DB_APP_CONN_CURR\n";
  MAIL_LINE3="Threshold                        = $DB_LCKS_CURR_THRSH \n";
  echo $MAIL_LINE1 $MAIL_LINE2 $MAIL_LINE3 | mail -s "$MAIL_SUB" $MAIL_TO;
fi
ratio=`echo $DB_LCK_LST_USE $LOCKLIST | awk '{printf "%3d", ($1/($2*4096)) * 100}'`;
if [ $ratio -gt $DB_LOCKLIST_THRSH ]
then
  MAIL_SUB="WARNING: Lock list memory usage exceeds threshold: $DB_NAME";
  MAIL_LINE1="Lock list memory in use          = $DB_LCK_LST_USE\n";
  MAIL_LINE2="LOCKLIST config parameter        = $LOCKLIST\n";
  MAIL_LINE3="Threshold                        = $DB_LOCKLIST_THRSH %\n";
  echo $MAIL_LINE1 $MAIL_LINE2 $MAIL_LINE3 | mail -s "$MAIL_SUB" $MAIL_TO;
fi
if [ $DB_LCK_WT -gt 0 ]
then
  ratio=`echo $DB_LCK_WT_TM $DB_LCK_WT | awk '{printf "%8d", ($1/$2)}'`;
  if [ $ratio -gt $DB_LCK_WT_THRSH ]
  then
    MAIL_SUB="WARNING: Average lock wait time exceeds threshold: $DB_NAME";
    MAIL_LINE1="Time database waited on locks      =  $DB_LCK_ST_TM\n";
    MAIL_LINE2="Lock waits                         =  $DB_LCK_WT\n";
    MAIL_LINE3="Threshold                          =  $DB_LCK_WT_THRSH milliseconds\n";
    echo $MAIL_LINE1 $MAIL_LINE2 $MAIL_LINE3 | mail -s "$MAIL_SUB" $MAIL_TO;
  fi      
fi
ratio=`echo $DB_DEAD_LCKS $DB_SNAPSHOT_INTERVAL | awk '{printf "%3d", ($1/$2)}'`;
if [ $ratio -gt $DB_DEAD_LCKS_THRSH ] 
then
  MAIL_SUB="WARNING: Average deadlocks per snapshot interval high: $DB_NAME";
  MAIL_LINE1="Deadlocks detected                  = $DB_DEAD_LOCKS\n";
  MAIL_LINE2="Snapshot interval                   = $DB_SNAPSHOT_INTERVAL\n";
  MAIL_LINE3="Threshold                           = $DB_DEAD_LCKS_THRSH \n";
  echo $MAIL_LINE1 $MAIL_LINE2 $MAIL_LINE3 | mail -s "$MAIL_SUB" $MAIL_TO;
fi
if [ $DB_APP_CONN_CURR -gt 0 ]
then
  ratio=`echo $DB_AGNT_LCK_WT $DB_APP_CONN_CURR | awk '{printf "%3d", ($1/$2)}'`;
  if [ $ratio -gt $DB_AGNT_LCK_WT_THRSH ] 
  then
    MAIL_SUB="WARNING: Average lock waits per application high: $DB_NAME";
    MAIL_LINE1="Agents currently waiting on locks = $DB_AGNT_LCK_WT\n";
    MAIL_LINE2="Applications connected currently  = $DB_APP_CONN_CURR\n";
    MAIL_LINE3="Threshold                         = $DB_AGNT_LCK_WT_THRSH \n";
    echo $MAIL_LINE1 $MAIL_LINE2 $MAIL_LINE3 | mail -s "$MAIL_SUB" $MAIL_TO;
  fi
fi
if [ $DB_APP_CONN -gt 0 ]
then
  ratio=`echo $DB_LCK_TMOUT $DB_APP_CONN | awk '{printf "%3d", ($1/$2)}'`;
  if [ $ratio -gt $DB_LCK_TMOUT_THRSH ]
  then
    MAIL_SUB="WARNING: Lock timeouts per application high $DB_NAME";
    MAIL_LINE1="Lock timouts                     = $DB_LCK_TMOUT\n";
    MAIL_LINE2="Application connects             = $DB_APP_CONN\n";
    MAIL_LINE3="Threshold                        = $DB_LCK_TMOUT_THRSH \n";
    echo $MAIL_LINE1 $MAIL_LINE2 $MAIL_LINE3 | mail -s "$MAIL_SUB" $MAIL_TO;
  fi
fi
if [ $DB_SRT_HEAP_ALL -ge $SHEAPTHRES ]
then
  MAIL_SUB="WARNING: Allocated sort heap nears or exceeds sort heap threshold: $DB_NAME";
  MAIL_LINE1="Allocated sort heap              : $DB_SRT_HEAP_ALL\n";
  MAIL_LINE2="SHEAPTHRES config parameter      : $SHEAPTHRES\n";
  echo $MAIL_LINE1 $MAIL_LINE2 | mail -s "$MAIL_SUB" $MAIL_TO;
fi
if [ $DB_SRTS -gt 0 ]
then
  ratio=`echo $DB_SRT_OVFLW $DB_SRTS | awk '{printf "%3d", ($1/$2) * 100}'`;
  if [ $ratio -gt $DB_SRT_OVFLW_THRSH ]
  then
    MAIL_SUB="WARNING: Avg. sort overflows per sort exceeds threshold: $DB_NAME";
    MAIL_LINE1="Sort overflows                     : $DB_SRT_OVFLW\n";
    MAIL_LINE2="Total sorts                        : $DB_SRTS\n";
    MAIL_LINE3="Threshold                          : $DB_SRT_OVFLW_THRSH %\n";
    echo $MAIL_LINE1 $MAIL_LINE2 $MAIL_LINE3 | mail -s "$MAIL_SUB" $MAIL_TO;
  fi
fi
ratio=`echo $DB_DBHEAP_HWM | awk '{printf "%8d", $1/4096 }'`;
if [ $ratio -gt $DBHEAP ]
then
   MAIL_SUB="CRITICAL: Database heap utilization more than configured DBHEAP: $DB_NAME";
   MAIL_LINE1="High water mark for database heap  : $ratio 4K PAGES\n";
   MAIL_LINE2="DBHEAP config parameter            : $DBHEAP\n";
   echo $MAIL_LINE1 $MAIL_LINE2 | mail -s "$MAIL_SUB" $MAIL_TO;
fi
LOG_SPACE_ALL=`echo $LOGFILSIZ $LOGPRIMARY $LOGSECOND | awk '{print ($1 * ($2 + $3) * 4096)}'`;
ratio=`echo $DB_MAX_TOT_LOG_SPC $LOG_SPACE_ALL | awk '{printf "%3d", ($1/$2) * 100}'`;
if [ $ratio -gt $DB_MAX_TOT_LOG_SPC_THRSH_CRIT ]
then
  MAIL_SUB="CRITICAL: Total log space used exceeding threshold: $DB_NAME";
  MAIL_LINE1="Maximum total log space used     : $DB_MAX_TOT_LOG_SPC bytes\n";
  MAIL_LINE2="Allocated log space              : $LOG_SPACE_ALL  bytes   \n";
  MAIL_LINE3="Threshold                        : $DB_MAX_TOT_LOG_SPC_THRSH_CRIT %\n";
  echo $MAIL_LINE1 $MAIL_LINE2 $MAIL_LINE3 | mail -s "$MAIL_SUB" $MAIL_TO;
elif
   [ $ratio -gt $DB_MAX_TOT_LOG_SPC_THRSH_WARN ]
then
  MAIL_SUB="WARNING: Total log space used exceeding threshold: $DB_NAME";
  MAIL_LINE3="Threshold                        : $DB_MAX_TOT_LOG_SPC_THRSH_WARN %\n";
  echo $MAIL_LINE1 $MAIL_LINE2 $MAIL_LINE3 | mail -s "$MAIL_SUB" $MAIL_TO;
fi
if [ $DB_PKG_CACH_LKUP -gt 0 ]
then
  ratio=`echo $DB_PKG_CACH_INSRT $DB_PKG_CACH_LKUP | awk '{printf "%3d", ((1 - ($1/$2)) * 100)}'`;
  if [ $ratio -lt $DB_PKG_CACH_HIT_THRSH ]
  then
    MAIL_SUB="WARNING: Package Cache hit ratio low.  Suggest increasing PCKCACHESZ:  $DB_NAME";
    MAIL_LINE1="Package cache inserts                 : $DB_PKG_CACH_INSRT\n";
    MAIL_LINE2="Package cache lookups                 : $DB_PKG_CACH_LKUP\n";
    MAIL_LINE3="Threshold                             : $DB_PKG_CACH_HIT_THRSH %\n";
    echo $MAIL_LINE1 $MAIL_LINE2 $MAIL_LINE3 | mail -s "$MAIL_SUB" $MAIL_TO;
  fi
fi
if [ $DB_CTLG_CACH_OVFLW -gt 0 ]
then
  ratio=`echo $DB_CTLG_CACH_LKUP $DB_CTLG_CACH_INSRT | awk '{printf "%3d", ((1 - ($1/$2)) * 100)}'`;
  if [ $ratio -lt $DB_CTLG_CACH_HIT_THRSH ]
  then
   MAIL_SUB="WARNING: Catalog cache hit ratio low.  Suggest increasing CATALOGCACHE_SZ:    $DB_NAME";
   MAIL_LINE1="Catalog cache lookups          : $DB_CTLG_CACH_LKUP\n";
   MAIL_LINE2="Catalog cache inserts          : $DB_CTLG_CACH_INSRT\n";
   MAIL_LINE3="Threshold                      : $DB_CTLG_CACH_HIT_THRSH %\n";
   echo $MAIL_LINE1 $MAIL_LINE2 $MAIL_LINE3 | mail -s "$MAIL_SUB" $MAIL_TO;
  fi
fi
if [ $DB_NUM_HASH_JOIN_OVFLW -gt 0 ] && [ $DB_NUM_HASH_JOIN -gt 0 ] 
then
  ratio1=`echo $DB_NUM_SML_HASH_JOIN_OVFLW $DB_NUM_HASH_JOIN_OVFLW | awk '{printf "%3d", ($1/$2) * 100}'`;
  ratio2=`echo $DB_NUM_HASH_JOIN_OVFLW $DB_NUM_HASH_JOIN | awk '{printf "%3d", ($1/$2) * 100}'`;
  ratio3=`echo $DB_NUM_HASH_LOOP $DB_NUM_HASH_JOIN | awk '{printf "%3d", ($1/$2) * 100}'`;
  if  [ $ratio1 -gt $DB_NUM_SML_HASH_JOIN_OVFLW_THRSH ] && [ $ratio2 -gt $DB_NUM_HASH_JOIN_OVFLW_THRSH ] && [ $ratio3 -gt $DB_NUM_HASH_LOOP_THRSH ] 
then
   MAIL_SUB="WARNING: Hash join overflows high.  Suggest increasing SORTHEAP: $DB_NAME";
   MAIL_LINE1="Number of small hash join overflows           : $DB_NUM_SML_HASH_JOIN_OVFLW\n";
   MAIL_LINE2="Number of hash join overflows                 : $DB_NUM_HASH_JOIN_OVFLW\n";
   MAIL_LINE3="Number of hash joins                          : $DB_NUM_HASH_JOIN\n";
   MAIL_LINE4="Number of hash join loops                     : $DB_NUM_HASH_LOOP\n";
   MAIL_LINE5="Small hash join overflow threshold            : $DB_NUM_SML_HASH_JOIN_OVFLW_THRSH %\n";
   MAIL_LINE6="Hash join overflow threshold                  : $DB_NUM_HASH_JOIN_OVFLW_THRSH %\n";
   MAIL_LINE7="Hash loop threshold                           : $DB_NUM_HASH_LOOP_THRSH %\n";
   echo $MAIL_LINE1 $MAIL_LINE2 $MAIL_LINE3 $MAIL_LINE4 $MAIL_LINE5 $MAIL_LINE6 $MAIL_LINE7 | mail -s "$MAIL_SUB" $MAIL_TO;
  fi
fi 
rm -f $ALL_SNAP_FILE;
rm -f $DB_CONFIG_FILE;
rm -f $DBM_CONFIG_FILE;
rm -f $DB_SNAP_FILE;
rm -f $BP_SNAP_FILE;
rm -f $TB_SNAP_FILE;
rm -f $AP_SNAP_FILE;
rm -f $TS_SNAP_FILE;
db2 "UPDATE MONITOR SWITCHES USING BUFFERPOOL OFF";
db2 "UPDATE MONITOR SWITCHES USING LOCK OFF";
db2 "UPDATE MONITOR SWITCHES USING SORT OFF";
db2 "UPDATE MONITOR SWITCHES USING STATEMENT OFF";
db2 "UPDATE MONITOR SWITCHES USING TABLE OFF";
db2 "UPDATE MONITOR SWITCHES USING UOW OFF";
db2 "UPDATE MONITOR SWITCHES USING BUFFERPOOL ON";
db2 "UPDATE MONITOR SWITCHES USING LOCK ON";
db2 "UPDATE MONITOR SWITCHES USING SORT ON";
db2 "UPDATE MONITOR SWITCHES USING STATEMENT ON";
db2 "UPDATE MONITOR SWITCHES USING TABLE ON";
db2 "UPDATE MONITOR SWITCHES USING UOW ON";
db2 "CONNECT RESET";
sleep $DB_SNAPSHOT_INTERVAL
done
