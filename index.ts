import * as pulumi from "@pulumi/pulumi";
import * as azure from "@pulumi/azure-native";

// Config
const config = new pulumi.Config();
const adminUsername = config.get("adminUser");
const adminPassword = config.requireSecret("adminPassword");

// Resource Group
const resourceGroup = new azure.resources.ResourceGroup("rg-vm", {
    location: "westeurope",
});

export const rgName = resourceGroup.name

// Network
const vnet = new azure.network.VirtualNetwork("vnet", {
    resourceGroupName: resourceGroup.name,
    location: resourceGroup.location,
    addressSpace: { addressPrefixes: ["10.0.0.0/16"] },
});

const subnet = new azure.network.Subnet("subnet", {
    resourceGroupName: resourceGroup.name,
    virtualNetworkName: vnet.name,
    addressPrefix: "10.0.1.0/24",
});

// Public IP
const publicIp = new azure.network.PublicIPAddress("publicIp", {
    resourceGroupName: resourceGroup.name,
    location: resourceGroup.location,
    publicIPAllocationMethod: "Dynamic",
});

// Network Interface
const nic = new azure.network.NetworkInterface("nic", {
    resourceGroupName: resourceGroup.name,
    location: resourceGroup.location,
    ipConfigurations: [{
        name: "ipconfig",
        subnet: { id: subnet.id },
        privateIPAllocationMethod: "Dynamic",
        publicIPAddress: { id: publicIp.id },
    }],
});

// VM
const vm = new azure.compute.VirtualMachine("winvm", {
    resourceGroupName: resourceGroup.name,
    location: resourceGroup.location,
    hardwareProfile: {
        vmSize: "Standard_D4s_v5",
    },
    osProfile: {
        computerName: "winvm",
        adminUsername,
        adminPassword,
    },
    networkProfile: {
        networkInterfaces: [{
            id: nic.id,
            primary: true,
        }],
    },
    storageProfile: {
        imageReference: {
            publisher: "MicrosoftWindowsDesktop",
            offer: "windows-11",
            sku: "win11-24h2-pro",   // may need adjustment based on region
            version: "latest",
        },
        osDisk: {
            name: "osdisk",
            caching: "ReadWrite",
            createOption: "FromImage",
            managedDisk: {
                storageAccountType: "StandardSSD_LRS",
            },
        },
    },
});

const nsg = new azure.network.NetworkSecurityGroup("nsg", {
    resourceGroupName: resourceGroup.name,
    location: resourceGroup.location,
    securityRules: [{
        name: "RDP",
        access: "Allow",
        direction: "Inbound",
        priority: 1000,
        protocol: "Tcp",
        sourcePortRange: "*",
        destinationPortRange: "3389",
        sourceAddressPrefix: "*",
        destinationAddressPrefix: "*",
    }],
});

// Output public IP
export const ip = publicIp.ipAddress;