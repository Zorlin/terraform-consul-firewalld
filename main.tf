data "http" "agent_self" {
  url = "http://localhost:8500/v1/agent/self"
}

locals {
  parsed_agent_data = jsondecode(data.http.agent_self.response_body)
  local_node_name = local.parsed_agent_data.Config.NodeName
  current_env = local.parsed_agent_data.DebugConfig.NodeMeta.env
  current_stage = local.parsed_agent_data.DebugConfig.NodeMeta.stage
}

output "parsed_agent_data" {
  value = local.parsed_agent_data
}

provider "consul" {
  address = "localhost:8500"
}

data "consul_nodes" "all" {}

locals {
  all_hosts = [for node in data.consul_nodes.all.nodes : node.address if try(node.meta["env"], null) != null && try(node.meta["stage"], "unknown") == local.current_stage]
  metrics_hosts = [for node in data.consul_nodes.all.nodes : node.address if try(node.meta["env"], null) != null && try(node.meta["env"], "unknown") == "metrics" && try(node.meta["stage"], "unknown") == local.current_stage]
  backups_hosts = [for node in data.consul_nodes.all.nodes : node.address if try(node.meta["env"], null) != null && try(node.meta["env"], "unknown") == "backups" && try(node.meta["stage"], "unknown") == local.current_stage]
}

resource "null_resource" "firewall_rules" {
  provisioner "local-exec" {
    command = <<-EOT
      #set -x
      if [ "$${current_env}" = "logs" ]; then
        firewall-cmd --permanent --delete-ipset=all_hosts || true
        firewall-cmd --permanent --new-ipset=all_hosts --type=hash:ip
        echo '${join("\n", local.all_hosts)}' > /tmp/all_hosts_ips
        firewall-cmd --permanent --ipset=all_hosts --add-entries-from-file=/tmp/all_hosts_ips
        rm /tmp/all_hosts_ips
        firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source ipset=all_hosts port port="5141" protocol="tcp" accept'
      fi

      firewall-cmd --permanent --delete-ipset=metrics_hosts || true
      firewall-cmd --permanent --new-ipset=metrics_hosts --type=hash:ip
      echo '${join("\n", local.metrics_hosts)}' > /tmp/metrics_hosts_ips
      firewall-cmd --permanent --ipset=metrics_hosts --add-entries-from-file=/tmp/metrics_hosts_ips
      rm /tmp/metrics_hosts_ips
      firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source ipset=metrics_hosts port port="9100" protocol="tcp" accept'

      if [ "$${current_env}" = "app" ]; then
        firewall-cmd --permanent --delete-ipset=backups_hosts || true
        firewall-cmd --permanent --new-ipset=backups_hosts --type=hash:ip
        echo '${join("\n", local.backups_hosts)}' > /tmp/backups_hosts_ips
        firewall-cmd --permanent --ipset=backups_hosts --add-entries-from-file=/tmp/backups_hosts_ips
        rm /tmp/backups_hosts_ips
        firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source ipset=metrics_hosts port port="9104" protocol="tcp" accept'
        firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source ipset=backups_hosts port port="3306" protocol="tcp" accept'
      fi

      firewall-cmd --reload
    EOT
    environment = {
      current_env = local.current_env
    }
  }
  triggers = {
    all_hosts      = join(",", local.all_hosts)
    metrics_hosts  = join(",", local.metrics_hosts)
    backups_hosts  = join(",", local.backups_hosts)
  }
}
