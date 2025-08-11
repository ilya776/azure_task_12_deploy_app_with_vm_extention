$location = "uksouth"
$resourceGroupName = "mate-resources"     # Змінено
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "~/.ssh/id_rsa.pub"

$publicIpAddressNamePrefix = "linuxboxpip"
$vmNamePrefix = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"
$dnsLabelPrefix = "matetask"

$vmCount = 3                          # Кількість віртуалок, які хочемо створити
$githubUsername = "Kagerou4649"      # Змінна для GitHub username

# Налаштування мережі та NSG (їх можна залишити поза циклом, якщо всі ВМ будуть в одній мережі)
Write-Host "Creating network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet

# Створення SSH ключа (якщо треба, і якщо його ще нема)
New-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -PublicKey $sshKeyPublicKey

for ($i=1; $i -le $vmCount; $i++) {
    $vmName = "$vmNamePrefix$i"
    $publicIpAddressName = "$publicIpAddressNamePrefix$i"
    $dnsLabel = "$dnsLabelPrefix$i$(Get-Random -Maximum 9999)"

    Write-Host "Creating public IP $publicIpAddressName with DNS label $dnsLabel ..."
    New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -Location $location -Sku Basic -AllocationMethod Dynamic -DomainNameLabel $dnsLabel

    Write-Host "Creating VM $vmName ..."
    New-AzVm `
        -ResourceGroupName $resourceGroupName `
        -Name $vmName `
        -Location $location `
        -Image $vmImage `
        -Size $vmSize `
        -SubnetName $subnetName `
        -VirtualNetworkName $virtualNetworkName `
        -SecurityGroupName $networkSecurityGroupName `
        -SshKeyName $sshKeyName `
        -PublicIpAddressName $publicIpAddressName

    $scriptUri = "https://raw.githubusercontent.com/$githubUsername/azure_task_12_deploy_app_with_vm_extention/main/install-app.sh"

    $Params = @{
        ResourceGroupName = $resourceGroupName
        VMName = $vmName
        Name = 'CustomScript'
        Publisher = 'Microsoft.Azure.Extensions'
        ExtensionType = 'CustomScript'
        TypeHandlerVersion = '2.1'
        Settings = @{
            fileUris = @($scriptUri);
            commandToExecute = './install-app.sh'
        }
    }
    Write-Host "Setting VM extension CustomScript on $vmName ..."
    Set-AzVMExtension @Params
}
