# Test with ADG

## Introduction

Now we can run some testing with the ADG. We will test the transaction replication, check the log lag, test DML redirection, and  switchover to the cloud.

Estimated Lab Time: 30 minutes

### Prerequisites

This lab assumes you have already completed the following labs:

- Deploy Active Data Guard with LVM

## **Step 1:** Test transaction replication

1. From on-premise side, create a test user in orclpdb, and grant privileges to the user. You need  to check if the pdb is open.

```
[oracle@primary ~]$ <copy>sqlplus / as sysdba</copy>

SQL*Plus: Release 19.0.0.0.0 - Production on Sat Feb 1 06:52:50 2020
Version 19.9.0.0.0

Copyright (c) 1982, 2019, Oracle.  All rights reserved.


Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.9.0.0.0

SQL> <copy>show pdbs</copy>

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 ORCLPDB			  READ WRITE

SQL> <copy>alter session set container=orclpdb;</copy>

Session altered.

SQL> <copy>create user testuser identified by testuser;</copy>

User created.

SQL> <copy>grant connect,resource to testuser;</copy>

Grant succeeded.

SQL> <copy>alter user testuser quota unlimited on users;</copy>

User altered.

SQL> <copy>exit;</copy>
```

2. Connect with testuser using the on-premise host ip address or hostname, create test table and insert a test record.

```
[oracle@primary ~]$ <copy>sqlplus testuser/testuser@xxx.xxx.xxx.xxx:1521/orclpdb</copy>

SQL*Plus: Release 19.0.0.0.0 - Production on Sat Feb 1 06:59:56 2020
Version 19.9.0.0.0

Copyright (c) 1982, 2019, Oracle.  All rights reserved.


Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.9.0.0.0

SQL> <copy>create table test(a number,b varchar2(20));</copy>

Table created.
SQL> <copy>insert into test values(1,'line1');</copy>

1 row created.

SQL> <copy>commit;</copy>

Commit complete.

SQL>  
```

3. From cloud side, open the standby database as read only.

```
[oracle@dbcs ~]$ <copy>sqlplus / as sysdba</copy>

SQL*Plus: Release 19.0.0.0.0 - Production on Sat Feb 1 07:04:39 2020
Version 19.9.0.0.0

Copyright (c) 1982, 2019, Oracle.  All rights reserved.


Connected to:
Oracle Database 19c EE Extreme Perf Release 19.0.0.0.0 - Production
Version 19.9.0.0.0

SQL> <copy>select open_mode,database_role from v$database;</copy>

OPEN_MODE	     DATABASE_ROLE
-------------------- ----------------
MOUNTED 	     PHYSICAL STANDBY

SQL> <copy>alter database open;</copy>

Database altered.

SQL> <copy>alter pluggable database orclpdb open;</copy>

Pluggable database altered.

SQL> <copy>show pdbs</copy>

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 ORCLPDB			  READ ONLY  NO
	 
SQL> <copy>select open_mode,database_role from v$database;</copy>

OPEN_MODE	     DATABASE_ROLE
-------------------- ----------------
READ ONLY WITH APPLY PHYSICAL STANDBY

SQL> <copy>exit</copy>
Disconnected from Oracle Database 19c EE Extreme Perf Release 19.0.0.0.0 - Production
Version 19.9.0.0.0
[oracle@dbcs ~]$ 
```
If the `OPEN_MODE` is **READ ONLY**, you can run the following command in sqlplus as sysdba, then check the `open_mode` again, you can see the `OPEN_MODE` is **READ ONLY WITH APPLY** now.
```
SQL> <copy>alter database recover managed standby database cancel;</copy>

Database altered.

SQL> <copy>alter database recover managed standby database using current logfile disconnect;</copy>

Database altered.

SQL> <copy>select open_mode,database_role from v$database;</copy>

OPEN_MODE	     DATABASE_ROLE
-------------------- ----------------
READ ONLY WITH APPLY PHYSICAL STANDBY
```

If you encounter an error message: `ORA-01153: an incompatible media recovery is active`. This means the media recovery process doesn't stop before you try to start it. Try to run the commands again: `alter database recover managed standby database cancel;` and `alter database recover managed standby database using current logfile disconnect;`

4. From cloud side, connect as testuser to orclpdb using DBCS host ip address or hostname. Check if the test table and record has replicated to the standby.

```
[oracle@dbcs ~]$ <copy>sqlplus testuser/testuser@xxx.xxx.xxx.xxx:1521/orclpdb</copy>

SQL*Plus: Release 19.0.0.0.0 - Production on Sat Feb 1 07:09:27 2020
Version 19.9.0.0.0

Copyright (c) 1982, 2019, Oracle.  All rights reserved.

Last Successful login time: Sat Feb 01 2020 06:59:56 +00:00

Connected to:
Oracle Database 19c EE Extreme Perf Release 19.0.0.0.0 - Production
Version 19.9.0.0.0

SQL> <copy>select * from test;</copy>

	 A B
---------- --------------------
	 1 line1

SQL> 
```



## **Step 2:** Check lag between the primary and standby

There are several ways to check the lag between the primary and standby.

1. First let's prepare a sample workload in the primary side. Copy the following command:

   ```
   <copy>
   wget https://raw.githubusercontent.com/minqiaowang/pts-hybrid-adg/main/test-with-adg/workload.sh
   wget https://raw.githubusercontent.com/minqiaowang/pts-hybrid-adg/main/test-with-adg/scn.sql
   </copy>
   ```

   

2. From on-premise side, run as **oracle** user, download scripts using the command you copied.

   ```
   [oracle@primary ~]$ wget https://raw.githubusercontent.com/minqiaowang/pts-hybrid-adg/main/test-with-adg/workload.sh
   --2021-03-11 07:04:12--  https://raw.githubusercontent.com/minqiaowang/pts-hybrid-adg/main/test-with-adg/workload.sh
   Resolving raw.githubusercontent.com (raw.githubusercontent.com)... 185.199.111.133, 185.199.110.133, 185.199.108.133, ...
   Connecting to raw.githubusercontent.com (raw.githubusercontent.com)|185.199.111.133|:443... connected.
   HTTP request sent, awaiting response... 200 OK
   Length: 1442 (1.4K) [text/plain]
   Saving to: ‘workload.sh’
   
   100%[=================================================>] 1,442       --.-K/s   in 0s      
   
   2021-03-11 07:04:12 (11.7 MB/s) - ‘workload.sh’ saved [1442/1442]
   
   [oracle@primary ~]$ wget https://raw.githubusercontent.com/minqiaowang/pts-hybrid-adg/main/test-with-adg/scn.sql
   --2021-03-11 07:07:43--  https://raw.githubusercontent.com/minqiaowang/pts-hybrid-adg/main/test-with-adg/scn.sql
   Resolving raw.githubusercontent.com (raw.githubusercontent.com)... 185.199.110.133, 185.199.108.133, 185.199.109.133, ...
   Connecting to raw.githubusercontent.com (raw.githubusercontent.com)|185.199.110.133|:443... connected.
   HTTP request sent, awaiting response... 200 OK
   Length: 108 [text/plain]
   Saving to: ‘scn.sql’
   
   100%[=================================================>] 108         --.-K/s   in 0s      
   
   2021-03-11 07:07:43 (2.89 MB/s) - ‘scn.sql’ saved [108/108]
   
   [oracle@primary ~]$ 
   ```
   
   
   
3. Change mode of the `workload.sh` file and run the workload. Ignore the error message of drop table. Keep this window open and running for the next few steps in this lab.

   ```
   [oracle@primary ~]$ <copy>chmod a+x workload.sh</copy> 
   [oracle@primary ~]$ <copy>. ./workload.sh</copy> 
   
     NOTE:
     To break out of this batch
     job, please issue CTL-C 
   
   ...sleeping 5 seconds
   
     drop table sale_orders
                *
   ERROR at line 1:
   ORA-00942: table or view does not exist
   
   
   
   Table created.
   
   
   10 rows created.
   
   
   Commit complete.
   
   
     COUNT(*)
   ----------
   	10
   
   
   CURRENT_SCN TIME
   ----------- ---------------
       2814533 20200905-092831
   
   
   10 rows created.
   
   
   Commit complete.
   
   
     COUNT(*)
   ----------
   	20
   
   
   CURRENT_SCN TIME
   ----------- ---------------
       2814548 20200905-092833
       
   ```

   

4. From the standby side, connect as **testuser** to orclpdb,  count the records in the sample table several times. Replace the `xxx.xxx.xxx.xxx` to the standby database hostname or public ip address. Compare the record number with the primary side.

   ```
   [oracle@dbcs ~]$ <copy>sqlplus testuser/testuser@xxx.xxx.xxx.xxx:1521/orclpdb</copy>
   
   SQL*Plus: Release 19.0.0.0.0 - Production on Sat Sep 5 09:41:29 2020
   Version 19.9.0.0.0
   
   Copyright (c) 1982, 2020, Oracle.  All rights reserved.
   
   Last Successful login time: Sat Sep 05 2020 02:09:45 +00:00
   
   Connected to:
   Oracle Database 19c EE Extreme Perf Release 19.0.0.0.0 - Production
   Version 19.9.0.0.0
   
   SQL> <copy>select count(*) from sale_orders;</copy>
   
     COUNT(*)
   ----------
   	390
   
   SQL> 
   ```

    

5. From standby site, connect as sysdba. Check the Oracle System Change Number (SCN). Compare it with the primary side.

   ```
   SQL> <copy>connect / as sysdba</copy>
   Connected.
   SQL> <copy>SELECT current_scn FROM v$database;</copy>
   
   CURRENT_SCN
   -----------
       2784330
   ```
   
   
   
6. From standby site, query the `v$dataguard_stats` view to check the lag.

   ```
   SQL> <copy>set linesize 120;</copy>
   SQL> <copy>column name format a25;</copy>
   SQL> <copy>column value format a20;</copy>
   SQL> <copy>column time_computed format a20;</copy>
   SQL> <copy>column datum_time format a20;</copy>
   SQL> <copy>select name, value, time_computed, datum_time from v$dataguard_stats;</copy>
   
   NAME			                VALUE 	             TIME_COMPUTED	      DATUM_TIME
   ------------------------- -------------------- -------------------- --------------------
   transport lag		          +00 00:00:00	       09/05/2020 07:17:33  09/05/2020 07:17:30
   apply lag		              +00 00:00:00	       09/05/2020 07:17:33  09/05/2020 07:17:30
   apply finish time	        +00 00:00:00.000     09/05/2020 07:17:33
   estimated startup time	  9		                 09/05/2020 07:17:33
   
   SQL> 
   ```

   

7. Check lag using Data Guard Broker. Replace `ORCL_nrt1d4` with your standby database unique name.

   ```
   [oracle@dbcs ~]$ <copy>dgmgrl sys/Ora_DB4U@orcl</copy>
   DGMGRL for Linux: Release 19.0.0.0.0 - Production on Sat Sep 5 07:25:52 2020
   Version 19.9.0.0.0
   
   Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.
   
   Welcome to DGMGRL, type "help" for information.
   Connected to "ORCL"
   Connected as SYSDBA.
   DGMGRL> <copy>show database ORCL_nrt1d4</copy>
   
   Database - orcl_nrt1d4
   
     Role:               PHYSICAL STANDBY
     Intended State:     APPLY-ON
     Transport Lag:      0 seconds (computed 3 seconds ago)
     Apply Lag:          0 seconds (computed 3 seconds ago)
     Average Apply Rate: 6.00 KByte/s
     Real Time Query:    ON
     Instance(s):
       ORCL
   
   Database Status:
   SUCCESS
   
   DGMGRL> 
   ```

   

8. From the on-premise side, press `Ctrl-C` to terminate the running workload.

   

## **Step 3:** Test DML Redirection

Starting  with Oracle DB 19c, we can run DML operations on Active Data Guard standby databases. This enables you to occasionally execute DMLs on read-mostly applications on the standby database.

Automatic redirection of DML operations to the primary can be configured at the system level or the session level. The session level setting overrides the system level

1. From the standby side, connect to orclpdb as **testuser**. Test the DML before and after the DML Redirection is enabled.

```
[oracle@dbcs ~]$ <copy>sqlplus testuser/testuser@xxx.xxx.xxx.xxx:1521/orclpdb<copy>

SQL*Plus: Release 19.0.0.0.0 - Production on Sat Sep 5 10:04:04 2020
Version 19.9.0.0.0

Copyright (c) 1982, 2020, Oracle.  All rights reserved.

Last Successful login time: Sat Sep 05 2020 02:09:45 +00:00

Connected to:
Oracle Database 19c EE Extreme Perf Release 19.0.0.0.0 - Production
Version 19.9.0.0.0

SQL> <copy>set timing on</copy>
SQL> <copy>insert into test values(2,'line2');</copy>
insert into test values(2,'line2')
*
ERROR at line 1:
ORA-16000: database or pluggable database open for read-only access


Elapsed: 00:00:00.58
SQL> <copy>ALTER SESSION ENABLE ADG_REDIRECT_DML;</copy>

Session altered.

Elapsed: 00:00:00.00
SQL> <copy>insert into test values(2,'line2');</copy>

1 row created.

Elapsed: 00:00:26.13
SQL> <copy>commit;</copy>

Commit complete.

Elapsed: 00:00:21.12
SQL> <copy>select * from test;</copy>

	 A B
---------- --------------------
	 2 line2
	 1 line1

Elapsed: 00:00:00.03
SQL> 
```

You may encounter the performance issue when using the DML redirection. This is because each of the DML is issued on a standby database will be passed to the primary database where it is executed. The default Data Guard protection mode is Maximum Performance and the redo transport mode is ASYNC. The session waits until the corresponding changes are shipped to and applied to the standby. In order to improve performance of the DML redirection, you need to switch the redo logfile more frequently on the primary side, or you can change the protection mode to Maximum Availability and the redo transport mode to SYNC - This protection mode provides the highest level of data protection, but it's need the high throughput and low latency network, you can use FastConnect or deploy the Data Guard in different ADs within the same region.

2. From the primary side, connect with Data Guard Broker, check the current protection mode and redo transport mode. Replace the `orcl_nrt1d4` to your standby db unique name.

   ```
   [oracle@primary ~]$ <copy>dgmgrl sys/Ora_DB4U@orcl</copy>
   DGMGRL for Linux: Release 19.0.0.0.0 - Production on Sun Sep 6 05:09:28 2020
   Version 19.9.0.0.0
   
   Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.
   
   Welcome to DGMGRL, type "help" for information.
   Connected to "ORCL"
   Connected as SYSDBA.
   DGMGRL> <copy>show configuration</copy>
   
   Configuration - adgconfig
   
     Protection Mode: MaxPerformance
     Members:
     orcl        - Primary database
       orcl_nrt1d4 - Physical standby database 
   
   Fast-Start Failover:  Disabled
   
   Configuration Status:
   SUCCESS   (status updated 20 seconds ago)
   DGMGRL> <copy>show database orcl LogXptMode</copy>
     LogXptMode = 'ASYNC'
   DGMGRL> <copy>show database orcl_nrt1d4 LogXptMode</copy>
     LogXptMode = 'ASYNC'
   ```

   

3. Switch the redo transport mode and protection mode. Replace the `orcl_nrt1d4` to your standby db unique name.

   ```
   DGMGRL> <copy>EDIT DATABASE orcl SET PROPERTY LogXptMode='SYNC';</copy>
   Property "logxptmode" updated
   DGMGRL> <copy>EDIT DATABASE orcl_nrt1d4 SET PROPERTY LogXptMode='SYNC';</copy>
   Property "logxptmode" updated
   DGMGRL> <copy>EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;</copy>
   Succeeded.
   DGMGRL> <copy>show configuration</copy>
   
   Configuration - adgconfig
   
     Protection Mode: MaxAvailability
     Members:
     orcl        - Primary database
       orcl_nrt1d4 - Physical standby database 
   
   Fast-Start Failover:  Disabled
   
   Configuration Status:
   SUCCESS   (status updated 42 seconds ago)
   
   DGMGRL>
   ```

    

4. From the standby side, test the DML redirection again. You can see the performance improved.

   ```
   SQL> <copy>insert into test values(3,'line3');</copy>
   
   1 row created.
   
   Elapsed: 00:00:00.25
   SQL> <copy>commit;</copy>
   
   Commit complete.
   
   Elapsed: 00:00:01.07
   SQL> <copy>select * from test;</copy>
   
        A B
   ---------- --------------------
        1 line1
        2 line2
        3 line3
   Elapsed: 00:00:00.03
   SQL> <copy>exit</copy>
   Disconnected from Oracle Database 19c EE Extreme Perf Release 19.0.0.0.0 - Production
   Version 19.9.0.0.0
   [oracle@dbcs ~]$ 
   ```

   

5. From the primary side, in the Data Guard Broker, switch back the protection mode. Replace the `orcl_nrt1d4` to your standby db unique name.

   ```
   DGMGRL> <copy>EDIT CONFIGURATION SET PROTECTION MODE AS MAXPERFORMANCE;</copy>
   Succeeded.
   DGMGRL> <copy>EDIT DATABASE orcl_nrt1d4 SET PROPERTY LogXptMode='ASYNC';</copy>
   Property "logxptmode" updated
   DGMGRL> <copy>EDIT DATABASE orcl SET PROPERTY LogXptMode='ASYNC';</copy>
   Property "logxptmode" updated
   DGMGRL> <copy>show configuration</copy>
   
   Configuration - adgconfig
   
     Protection Mode: MaxPerformance
     Members:
     orcl        - Primary database
       orcl_nrt1d4 - Physical standby database 
   
   Fast-Start Failover:  Disabled
   
   Configuration Status:
   SUCCESS   (status updated 20 seconds ago)
   ```

   




## **Step 4:** Switchover to the Cloud 

At any time, you can manually execute a Data Guard switchover (planned event) or failover (unplanned event). Customers may also choose to automate Data Guard failover by configuring Fast-Start failover. Switchover and failover reverse the roles of the databases in a Data Guard configuration – the standby in the cloud becomes primary and the original on-premise primary becomes a standby database. Refer to Oracle MAA Best Practices for additional information on Data Guard role transitions. 

Switchovers are always a planned event that guarantees no data is lost. To execute a switchover, perform the following in Data Guard Broker 

1. Connect DGMGRL from on-premise side, validate the standby database to see if Ready For Switchover is Yes. Replace `ORCL_nrt1d4` with your standby db unique name.

```
[oracle@primary ~]$ <copy>dgmgrl sys/Ora_DB4U@orcl</copy>
DGMGRL for Linux: Release 19.0.0.0.0 - Production on Sat Feb 1 07:21:55 2020
Version 19.9.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

Welcome to DGMGRL, type "help" for information.
Connected to "ORCL"
Connected as SYSDBA.
DGMGRL> <copy>validate database ORCL_nrt1d4</copy>

  Database Role:     Physical standby database
  Primary Database:  orcl

  Ready for Switchover:  Yes
  Ready for Failover:    Yes (Primary Running)

  Flashback Database Status:
    orcl       :  On
    orcl_nrt1d4:  Off

  Managed by Clusterware:
    orcl       :  NO             
    orcl_nrt1d4:  YES            
    Validating static connect identifier for the primary database orcl...
    The static connect identifier allows for a connection to database "orcl".

DGMGRL> 
```

2. Switch over to cloud standby database, replace `ORCL_nrt1d4` with your standby db unique name.

```
DGMGRL> <copy>switchover to orcl_nrt1d4</copy>
Performing switchover NOW, please wait...
Operation requires a connection to database "orcl_nrt1d4"
Connecting ...
Connected to "ORCL_nrt1d4"
Connected as SYSDBA.
New primary database "orcl_nrt1d4" is opening...
Operation requires start up of instance "ORCL" on database "orcl"
Starting instance "ORCL"...
Connected to an idle instance.
ORACLE instance started.
Connected to "ORCL"
Database mounted.
Database opened.
Connected to "ORCL"
Switchover succeeded, new primary is "orcl_nrt1d4"
DGMGRL> <copy>show configuration</copy>

Configuration - adgconfig

  Protection Mode: MaxPerformance
  Members:
  orcl_nrt1d4 - Primary database
    orcl        - Physical standby database 

Fast-Start Failover:  Disabled

Configuration Status:
SUCCESS   (status updated 104 seconds ago)

DGMGRL> 
```

3. Check from on-premise side. You can see the previous primary side becomes the new standby side.

```
[oracle@primary ~]$ <copy>sqlplus / as sysdba</copy>

SQL*Plus: Release 19.0.0.0.0 - Production on Sat Feb 1 10:16:54 2020
Version 19.9.0.0.0

Copyright (c) 1982, 2019, Oracle.  All rights reserved.


Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.9.0.0.0

SQL> <copy>show pdbs</copy>

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 ORCLPDB			  READ ONLY  NO
SQL> <copy>select open_mode,database_role from v$database;</copy>

OPEN_MODE	     DATABASE_ROLE
-------------------- ----------------
READ ONLY WITH APPLY PHYSICAL STANDBY

SQL> 
```

4. Check from cloud side. You can see it's becomes the new primary side.

```
[oracle@dbcs ~]$ <copy>sqlplus / as sysdba</copy>

SQL*Plus: Release 19.0.0.0.0 - Production on Sat Feb 1 10:20:06 2020
Version 19.9.0.0.0

Copyright (c) 1982, 2019, Oracle.  All rights reserved.


Connected to:
Oracle Database 19c EE Extreme Perf Release 19.0.0.0.0 - Production
Version 19.9.0.0.0

SQL> <copy>show pdbs</copy>

    CON_ID CON_NAME			  OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
	 2 PDB$SEED			  READ ONLY  NO
	 3 ORCLPDB			  READ WRITE NO
SQL> <copy>select open_mode,database_role from v$database;</copy>

OPEN_MODE	     DATABASE_ROLE
-------------------- ----------------
READ WRITE	     PRIMARY

SQL> 
```

You may proceed to the next lab.