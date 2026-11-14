# Network infrastructure

This Terraform root module creates the shared network infrastructure in the
selected AWS Region, `ap-southeast-2`.

## CIDR allocation

The VPC uses `10.20.0.0/16`. It has three subnet **tiers**: public, private
application, and database. Each tier is created in two Availability Zones, so
the design contains six physical subnets rather than only three physical
subnets.

| Tier | Availability Zone index | CIDR | Routing and purpose |
| --- | ---: | --- | --- |
| Private application (temporarily public-routed) | 0 | `10.20.0.0/20` | Direct route to the internet gateway; EKS worker nodes |
| Private application (temporarily public-routed) | 1 | `10.20.16.0/20` | Direct route to the internet gateway; EKS worker nodes |
| Public | 0 | `10.20.48.0/24` | Route to the internet gateway; public load balancers and NAT gateway |
| Public | 1 | `10.20.49.0/24` | Route to the internet gateway; public load balancers and NAT gateway |
| Database | 0 | `10.20.64.0/24` | No direct public route; RDS DB subnet group |
| Database | 1 | `10.20.65.0/24` | No direct public route; RDS DB subnet group |

The remaining addresses in `10.20.0.0/16` are reserved for future subnet
tiers and expansion.

## How the CIDRs are calculated

Terraform derives the subnet CIDRs from `var.vpc_cidr` with `cidrsubnet`:

- Private: two `/20` networks using indexes `0` and `1`.
- Public: two `/24` networks using indexes `48` and `49`.
- Database: two `/24` networks using indexes `64` and `65`.

Changing `vpc_cidr` recalculates every subnet. Treat that as a network
replacement, review the Terraform plan carefully, and avoid changing it after
the environment contains workloads.

## Database tier

Terraform creates an RDS DB subnet group from both database subnets. Keeping
the database tier separate prevents EKS workloads and public load balancers
from sharing the database address space. Access to a database should be granted
through security-group rules from the application security group, not by
making the database subnets public.

## NAT gateway setting

NAT Gateway creation is currently disabled in `main.tf` to avoid the NAT
Gateway hourly charge, data-processing charge, and Elastic IP charge. The
existing private-named application subnets temporarily use direct default
routes to the internet gateway instead. Their names are unchanged. A workload
in those subnets must have a public IPv4 address for internet connectivity;
the subnet route alone does not assign one.

When workloads require outbound internet access, set `enable_nat_gateway` to
`true` and uncomment `single_nat_gateway`. A value of `true` creates one shared
NAT gateway; `false` creates one per Availability Zone.
