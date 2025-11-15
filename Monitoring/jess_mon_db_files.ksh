#!/bin/ksh
# name: jess_mon_db_files.ksh
# desc: monitor file system capacity
#       for db. Uses thresholds to 
#       notify dba before file system
#       fills up.
# 
#-----------#
# Directions:
#-----------#
# set my_mail_notify to whom gets the error email
# set my_files_to_watch		include all file systems
#				you wish to monitor
#				separated by "|"
#
# set THRESHOLDS
#	my_capacity_threshold	set to % full before 
#				notification is emailed.
#				Remember, DBA needs time
#				to get mail and respond.
#
#===========================================#
# Change Log                                #
#===========================================#
# Date       Who             Did What?
# ---------- -------     --------------------
# 2011-06-01 J.Askew     Initial Rollout
#===========================================#
# Housekeeping                              #
#-------------------------------------------#
my_files_to_watch="/dbspace|/dblogs|/home/db2inst1"
my_mail_notify=`cat /home/db2inst1/TOOLZ/admin/.DBA_oncall`
my_mail_prog=`which mail`
my_host=`hostname`
my_email_heading="File System Capacity over threshold";
my_capacity_threshold=90
#--------------------------------#
# Start Processing Here          #
#--------------------------------#
df -k|egrep ${my_files_to_watch}|grep %|sed 's/%//g'|awk '{print $NF, $4}'|while read filesystem filecap
	do
		if [[ ${filecap} -ge ${my_capacity_threshold} ]];
			then
				echo ${filesystem} " at " ${filecap}"%"|${my_mail_prog} -s "${my_host}...${my_email_heading}" ${my_mail_notify};
                fi
	done
return;
