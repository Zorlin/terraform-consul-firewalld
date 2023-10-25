# terraform-consul-firewalld
A Terraform module to configure firewalld. Currently not a generalised module, just an example.

## Requirements
* firewalld installed on each host you wish to manage

## Caveats/TODO
This module hardcodes the firewall rules and IPSets in question, which is not best practice. It'll need further development to fix that.

## Usage
This is a standard Terraform module, but it's designed only to be run locally on the machine it is managing.

You can run it with a standard Terraform apply:
```
terraform init
terraform apply
```

It is intended to be used with [cts-consul-firewalld](https://github.com/Zorlin/cts-consul-firewalld), which turns this module into a service that can run on a node and dynamically respond to Consul events such as nodes joining or leaving the cluster.
