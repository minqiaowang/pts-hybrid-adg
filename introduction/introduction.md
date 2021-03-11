# Introduction

## About this Workshop

In this workshop, You will learn how to setup Oracle Database Active Data Guard from on-premise to Oracle Cloud. You will using a compute instance in OCI to simulate the on-premise database, which is deployed in one region (For example: Seoul). The standby cloud database service is deployed in another region (For example: Tokyo). The primary and the standby database communicate through public internet.

Estimated Workshop Time: 4 hours

### About ADG

Oracle’s Maximum Availability Architecture (Oracle MAA) is the best practices blueprint for data protection and availability for Oracle databases deployed on private, public or hybrid clouds. Data Guard and Active Data Guard provide disaster recovery (DR) for databases with recovery time objectives (RTO) that cannot be met by restoring from backup. Customers use these solutions to deploy one or more synchronized replicas (standby databases) of a production database (the primary database) in physically separate locations to provide high availability, comprehensive data protection, and disaster recovery for mission-critical data. 

An effective disaster recovery plan can be costly due to the need to establish, equip and manage a remote data center. The Oracle Cloud offers a great alternative for hosting standby databases for customers who do not have a DR site or who prefer not to deal with the cost or complexity of managing a remote data center. Existing production databases remain on-premises and standby databases used for DR are deployed on the Oracle Cloud. This mode of deployment is commonly referred to as a hybrid cloud implementation. 

##Benefits of Hybrid Standby in the Cloud 

1. Cloud data center and infrastructure is managed by Oracle 

2. Cloud provides basic system life cycle operations including bursting and shrinking resources 

3. Oracle Data Guard provides disaster recovery, data protection and ability to offload activity for higher utilization and return on investment. 

4. When configured with MAA practices, RTO of seconds with automatic failover when configured with Data Guard Fast-Start failover and RPO less than a second for Data Guard with ASYNC transport or RPO zero for Data Guard in SYNC or FAR SYNC configurations 

During this Lab, You will learn how to setup Hybrid Data Guard to Oracle Cloud Infrastructure. You will configure the Production Database on Premises and Disaster Recovery with DBaaS VM shapes in Oracle Cloud Infrastructure.

In a Data Guard configuration, the primary and standby must be able to communicate bi-directionally. This requires additional network configuration to allow access to ports between the hosts. 

##Secure Connectivity

There are two options to privately connect your cloud network to the on-premises network, IPSec VPN and FastConnect. Each of these methods require a Dynamic Routing Gateway (DRG) to connect to your Virtual Cloud Network (VCN). Details for creating a DRG can be found in the documentation at this link. 

- IPSec VPN 

IPSec stands for Internet Protocol Security or IP Security. IPSec is a protocol suite that encrypts the entire IP traffic before the packets are transferred from the source to the destination. 

- FastConnect 

Oracle Cloud Infrastructure FastConnect provides a method to create a dedicated, private connection between your data center and Oracle Cloud Infrastructure. FastConnect provides higher-bandwidth options and a more reliable and consistent networking experience compared to internet-based connections. 

## Public Internet Connectivity

Connectivity between OCI and on-premises can be achieved through the public internet as well. This method is not by default secure and additional steps must be taken to secure transmissions. The lab steps assumes public internet connectivity. 




## Acknowledgements

- **Authors/Contributors** - Minqiao Wang, DB Product Management
- **Last Updated By/Date** - Mar 2021
- **Workshop Expiration Date** - 

