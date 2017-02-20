# OpenShift Container Platform 3.4 with Username / Password authentication for OpenShift

This template deploys OpenShift Container Platform with basic username / password for authentication to OpenShift. It includes the following resources:

|Resource           	|Properties                                                                                                                          |
|-----------------------|------------------------------------------------------------------------------------------------------------------------------------|
|Virtual Network   		|**Address prefix:** 192.168.0.0/16<br />**Master subnet:** 192.168.1.0/24<br />**Node subnet:** 192.168.2.0/24                      |
|Master Load Balancer	|2 probes and 2 rules for TCP 8443 and TCP 9090 <br/> NAT rules for SSH on Ports 2200-220X                                           |
|Infra Load Balancer	|3 probes and 3 rules for TCP 80, TCP 443 and TCP 9090 									                                             |
|Public IP Addresses	|Bastion Public IP for Bastion Node<br />OpenShift Master public IP attached Master Load Balancer<br />OpenShift Router public IP attached to Infra Load Balancer            |
|Storage Accounts   	|1 Storage Account for Master, Infra, Bastion and Load Balancer VMs<br />2 Storage Accounts for Node VMs<br />1 Storage Account for Private Docker Registry                                                                                                                |
|Virtual Machines   	|1 Bastion Node - Used to Run Ansible Playbook for OpenShift deployment<br />1 Load Balancer Node to do internal load balancing to the masters<br />1 or 3 Masters. First Master is used to run a NFS server to provide persistent storage.<br />1, 2, or 3 Infra nodes<br />User-defined number of nodes (1 to 30)<br />All VMs include a single attached data disk for Docker thin pool logical volume|
## READ the instructions in its entirety before deploying!

This template deploys multiple VMs and requires some pre-work before you can successfully deploy the OpenShift Cluster.  If you don't get the pre-work done correctly, you will most likely fail to deploy the cluster using this template.  Please read the instructions completely before you proceed. 

This template allows you to choose between a custom VHD image in an existing Storage Account or the On-Demand Red Hat Enterprise Linux image from the Azure Gallery. 
>If you use the On-Demand image, there is an hourly charge for using this image.  At the same time, the instance will be registered to your Red Hat subscription so you will also be using one of your entitlements. This will lead to "double billing".

After successful deployment, the Bastion Node is no longer required.  You can turn it off and delete it or keep it around for running future playbooks.

## Prerequisites

### Generate SSH Keys

You'll need to generate an SSH key pair (Public / Private) in order to provision this template. Ensure that you do NOT include a passphrase with the private key. <br/><br/>
If you are using a Windows computer, you can download puttygen.exe.  You will need to export to OpenSSH (from Conversions menu) to get a valid Private Key for use in the Template.<br/><br/>
From a Linux or Mac, you can just use the ssh-keygen command.  Once you are finished deploying the cluster, you can always generate new keys that uses a passphrase and replace the original ones used during inital deployment.

### Create Key Vault to store SSH Private Key

You will need to create a Key Vault to store your SSH Private Key that will then be used as part of the deployment.  This extra work is to provide security around the Private Key - especially since it does not have a passphrase.  I recommend creating a Resource Group specifically to store the KeyVault.  This way, you can reuse the KeyVault for other deployments and you won't have to create this every time you chose to deploy another OpenShift cluster.

1. Create KeyVault using Powershell <br/>
  a.  Create new resource group: `New-AzureRMResourceGroup -Name 'ResourceGroupName' -Location 'West US'`<br/>
  b.  Create key vault: `New-AzureRmKeyVault -VaultName 'KeyVaultName' -ResourceGroup 'ResourceGroupName' -Location 'West US'`<br/>
  c.  Create variable with sshPrivateKey: `$securesecret = ConvertTo-SecureString -String '[copy ssh Private Key here - including line feeds]' -AsPlainText -Force`<br/>
  d.  Create Secret: `Set-AzureKeyVaultSecret -Name 'SecretName' -SecretValue $securesecret -VaultName 'KeyVaultName'`<br/>
  e.  Enable for Template Deployment: `Set-AzureRMKeyVaultAccessPolicy -VaultName 'KeyVaultName' -ResourceGroupName 'ResourceGroupName' -EnabledForTemplateDeployment`<br/>

2. **Create Key Vault using Azure CLI**<br/>
  a.  Create new Resource Group: azure group create \<name\> \<location\> <br/>
         Ex: `azure group create ResourceGroupName 'East US'` <br/>
  b.  Create Key Vault: azure keyvault create -u \<vault-name\> -g \<resource-group\> -l \<location\><br/>
         Ex: `azure keyvault create -u KeyVaultName -g ResourceGroupName -l 'East US'`<br/>
  c.  Create Secret: azure keyvault secret set -u \<vault-name\> -s \<secret-name\> --file \<private-key-file-name\>`<br/>
         Ex: `azure keyvault secret set -u KeyVaultName -s SecretName --file ~/.ssh/id_rsa` <br/>
  d.  Enable the Keyvvault for Template Deployment: azure keyvault set-policy -u \<vault-name\> --enabled-for-template-deployment true <br/>
         Ex: `azure keyvault set-policy -u KeyVaultName --enabled-for-template-deployment true` <br/>

### Red Hat Subscription Access

For security reasons, the method for registering the RHEL system has been changed to allow the use of an Organization ID and Activation Key as well as a Username and Password. Please know that it is more secure to use the Organizatoin ID and Activation Key.

You can determine your Organization ID by running ```subscription-manager identity``` on a registered machine.  To create or find your Activation Key, please go here: https://access.redhat.com/management/activation_keys.

You will also need to get the Pool ID that contains your entitlements for OpenShift.  You can retrieve this from the Red Hat portal by examining the details of the subscription that has the OpenShift entitlements.  Or you can contact your Red Hat administrator to help you.

### azuredeploy.Parameters.json File Explained

1.  _artifactsLocation: URL for artifacts (json, scripts, etc.)
2.  customVhdOrGallery: Choose to use a custom VHD image or an image from the Azure Gallery. The valid inputs are "gallery" or "custom". The default is set to "gallery".
2.  customStorageAccount: The URL to the storage account that contains your custom VHD image. Include the ending '/'. Example: https://customstorageaccount.blob.core.windows.net/
2.  customOsDiskName: The folder and name of the custom VHD image. Example: images/customosdisk.vhd
2.  masterVmSize: Size of the Master VM. Select from one of the allowed VM sizes listed in the azuredeploy.json file
3.  nodeVmSize: Size of the Node VM. Select from one of the allowed VM sizes listed in the azuredeploy.json file
3.  infraVmSize: Size of the Infra VM. Select from one of the allowed VM sizes listed in the azuredeploy.json file
4.  openshiftClusterPrefix: Cluster Prefix used to configure hostnames for all nodes - bastion, master, infra and nodes (between 1 and 5 characters)
5.  openshiftMasterPublicIpDnsLabel: A unique Public DNS host name (not FQDN) to reference the Master Node by
6.  infraLbPublicIpDnsLabel: A unique Public DNS host name (not FQDN) to reference the Node Load Balancer by.  Used to access deployed applications
7.  masterInstanceCount: Number of Masters nodes to deploy
8.  nodeInstanceCount: Number of Nodes to deploy
8.  infraInstanceCount: Number of infra nodes to deploy
9.  dataDiskSize: Size of data disk to attach to nodes for Docker volume - valid sizes are 128 GB, 512 GB and 1023 GB
10. adminUsername: Admin username for both OS (VM) login and initial OpenShift user
11. openshiftPassword: Password for OpenShift user
12. rhsmUsernamePasswordOrActivationKey: Choose to use Username and Password or Organization ID and Activation Key for registration. Valid values are "usernamepassword" and "activationkey".
12. rhsmUsernameOrOrgId: Red Hat Subscription Manager Username or Organization ID. If usernamepassword selected in previous input, then use Username; otherwise entier Organization ID. To find your Organization ID, run on registered server: `subscription-manager identity`.
13. rhsmPasswordOrActivationKey: Red Hat Subscription Manager Password or Activation Key for your Cloud Access subscription. You can get this from [here](https://access.redhat.com/management/activation_keys).
14. rhsmPoolId: The Red Hat Subscription Manager Pool ID that contains your OpenShift entitlements
15. sshPublicKey: Copy your SSH Public Key here
16. keyVaultResourceGroup: The name of the Resource Group that contains the Key Vault
17. keyVaultName: The name of the Key Vault you created
18. keyVaultSecret: The Secret Name you used when creating the Secret (that contains the Private Key)
19. defaultSubDomainType: This will either be xipio (if you don't have your own domain) or custom if you have your own domain that you would like to use for routing
20. defaultSubDomain: The wildcard DNS name you would like to use for routing if you selected custom above.  If you selected xipio above, you must still enter something here but it will not be used

## Deploy Template

Deploy to Azure using Azure Portal: 
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fharoldwongms%2Fopenshift-containerplatform%2Fmaster%2Fazuredeploy.json" target="_blank"><img src="http://azuredeploy.net/deploybutton.png"/></a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fharoldwongms%2Fopenshift-containerplatform%2Fmaster%2Fazuredeploy.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a><br/>

Once you have collected all of the prerequisites for the template, you can deploy the template by clicking Deploy to Azure or populating the **azuredeploy.parameters.json** file and executing Resource Manager deployment commands with PowerShell or the Azure CLI.

### NOTE

The OpenShift Ansible playbook does take a while to run when using VMs backed by Standard Storage. VMs backed by Premium Storage are faster. If you want Premium Storage, select a DS or GS series VM.
<hr />
Be sure to follow the OpenShift instructions to create the necessary DNS entry for the OpenShift Router for access to applications. <br />

Currently there is a hickup in the deployment of metrics and logging that will cause the deployment to take a little longer than normal.  When you look at the stdout files on the Bastion host, you will see that the installation had numerous retries for certain playbook tasks.  This is normal.

### TROUBLESHOOTING

If you encounter an error during deployment of the cluster, please view the deployment status.  The following Error Codes will help to narrow things down.

1. Exit Code 3: Your Red Hat Subscription User Name and / or Password is incorrect
2. Exit Code 4: Your Red Hat Pool ID is incorrect or there are no entitlements available
3. Exit Code 5: Unable to provision Docker Thin Pool Volume
4. Exit Code 6: Unable to mount filesystem on Master zero node for NFS 

For further troubleshooting, please SSH into your Bastion node on port 22.  You will need to be root (sudo su -) and then navigate to the following directory: **/var/lib/waagent/custom-script/download**<br/><br/>
You should see a folder named '0' and '1'.  In each of these folders, you will see two files, stderr and stdout.  You can look through these files to determine where the failure occurred.

## Post-Deployment Operations

### Metrics and logging

To display metrics and logs, you need to logon to OpenShift ( https://publicDNSname:8443 ) go into the logging project, click on the Kubana route and accept the SSL exception in your brower, then do the same with the Hawkster metrics route in the openshift-infra project.

### Creation of additional users

To create additional (non-admin) users in your environment, login to your master server(s) via SSH and run:
<br><i>htpasswd /etc/origin/master/htpasswd mynewuser</i>

### Access to Cockpit

Use user 'root' and the same password as you assigned to your OpenShift admin to login to Cockpit ( https://publicDNSname:9090 ).
   
### Additional OpenShift Configuration Options
 
You can configure additional settings per the official (<a href="https://docs.openshift.com/container-platform/3.4/welcome/index.html" target="_blank">OpenShift Enterprise Documentation</a>).
