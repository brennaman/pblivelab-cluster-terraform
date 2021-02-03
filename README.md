# pblivelab-cluster-terraform

The Terraform code in the core folder provisions an AKS cluster using Azure CNI (Azure Container Networking Interface Kubernetes Plugin) networking.  

With Azure CNI networking, the cluster deploys into an existing virtual network, and Azure does not manage virtual network resource as part of the AKS deployment. Pods receive individual IPs that can route to other network services or on-premises resources, and pods can be accessed directly. **Best practice guidance** - For integration with existing virtual networks or on-premises networks, use Azure CNI networking in AKS. This network model also allows greater separation of resources and controls in an enterprise environment.

For production scenarios, both Azure CNI and kubenet (the default model) are valid options. A notable benefit of Azure CNI networking for production is the network model allows for separation of control and management of resources. From a security perspective, you often want different teams to manage and secure those resources. Azure CNI networking lets you connect to existing Azure resources, on-premises resources, or other services directly via IP addresses assigned to each pod.
