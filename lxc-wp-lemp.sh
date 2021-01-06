#!/bin/bash
clear


   echo "# Enter the LXC container name please:"
   read -p "# Enter LXC name: " lxcname
   echo "# Generate the LXC container Ubuntu 18.04: $lxcname"
   echo "#"
   echo "#"

   echo "# update.. (apt install update)"
   echo "#"
   sudo apt -y update -qq
   
   
   if ! command -v ansible &> /dev/null
   then
      echo "# Ansible is not yet installed"
      echo "# Installing Ansible.."
      sudo apt -y update -qq
      sudo apt -y install ansible -qq
      
   else
      echo "# Ansible is here.."
   fi

      #  - START - HAPRoxy check
   ##
   ##
   if [[ $(lxc list | grep haproxy) ]];
   then
      echo "# HAProxy is found!"
   else
      echo "# HAProxy is not here. Installing HAProxy"
      lxc launch ubuntu:18.04 haproxy
      echo "#"
      echo "# Trying to get the HAProxy IP Address.."
      HAProxy_LXC_IP=$(lxc list | grep haproxy | awk '{print $6}')
      VALID_IP=^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$
      # START - SPINNER
      #
      sp="/-\|"
      sc=0
      spin() {
      printf "\b${sp:sc++:1}"
      ((sc==${#sp})) && sc=0
      }
      endspin() {
      printf "\r%s\n" "$@"
      }
      #
      # - END SPINNER
      # Getting the IP of LXC
      while ! [[ "${HAProxy_LXC_IP}" =~ ${VALID_IP} ]]; do
            HAProxy_LXC_IP=$(lxc list | grep haproxy | awk '{print $6}')
            spin
      done
      endspin
      echo "# "
      echo "# IP Address found! HAProxy LXC IP: ${HAProxy_LXC_IP}"

      echo "# "
      echo "# Updating HAProxy container"
      echo "# "
      lxc exec haproxy -- sh -c "apt update" --verbose
      echo "# "
      echo "# Downloading HAProxy (apt install haproxy))"
      lxc exec haproxy -- sh -c "apt -y install haproxy" --verbose
      echo "# "
      echo "# Download and transfer HAProxy config file"
      wget -q https://raw.githubusercontent.com/avinashkraghu-3/avi_files/main/haproxy.cfg
      lxc exec haproxy -- sh -c "rm /etc/haproxy/haproxy.cfg"
      lxc file push haproxy.cfg haproxy/etc/haproxy/haproxy.cfg --verbose
      echo "# "
      echo "# Testing and reloading HAProxy config"
      lxc exec haproxy -- sh -c "/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -c" --verbose
      lxc exec haproxy -- sh -c "sudo systemctl reload haproxy"   --verbose
      rm haproxy.cfg
      haproxyip=$(lxc exec haproxy -- sh -c "ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'")
      echo "# "
      echo "# HAProxy is now installed!"
      

            echo "#"
      echo "# Inserting new IP tables for HAProxy"
      sudo iptables -t nat -I PREROUTING -i eth0 -p TCP -d 95.216.204.31/32 --dport 80 -j DNAT --to-destination ${HAProxy_LXC_IP}:80
      sudo iptables -t nat -I PREROUTING -i eth0 -p TCP -d 95.216.204.31/32 --dport 443 -j DNAT --to-destination ${HAProxy_LXC_IP}:443
      # Reload and save IP Tables
      echo "#"
      echo "# Save IP tables"
      echo "#"
      sudo /sbin/iptables-save
   fi
   ##
   ##
   #  - END - HAPRoxy check
	

   echo "# Checking for apt update and upgrades.."
   if [[ $(sudo apt list --upgradeable | grep ubuntu) ]];
   then   
      echo "# There's an upgrade available."
      echo "# Updating and upgrading now.. - apt update && apt upgrade"
      sudo apt -y update -qq
      sudo apt -y upgrade -qq
   else
      echo "# No upgrades needed.."
   fi


   # 18.04
   lxc launch ubuntu:18.04 $lxcname

   # 16.04
   #lxc launch ubuntu:16.04 $lxcname

   #starting Container
   lxc start $lxcname

   cfdomain=$lxcname

   # Get the current external IP address
   ip=$(curl -s -X GET https://checkip.amazonaws.com)

   echo "# Current IP is $ip"


   if host $cfdomain 1.1.1.1 | grep "has address" | grep "$ip"; then
   echo "# $cfdomain is currently set to $ip; no changes needed"
   # exit
   fi
   
   
   echo "#"
   echo "# Let's generate SSH-KEY gen for this LXC"
   echo "#"
   ssh-keygen -f $HOME/.ssh/id_lxc_$lxcname -N '' -C 'key for local LXC'

   echo "#"
   echo "# - START - Details from ssh key gen"

   # ls $HOME/.ssh/
   # cat $HOME/.ssh/id_lxc_$lxcname.pub


   echo "#"
   echo "#"
   echo "# START - Info of LXC: ${lxcname}"


   echo "#"
   echo "# Trying to get the LXC IP Address.."


   LXC_IP=$(lxc list | grep ${lxcname} | awk '{print $6}')


   VALID_IP=^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$


   # START - SPINNER 
   #
   sp="/-\|"
   sc=0
   spin() {
      printf "\b${sp:sc++:1}"
      ((sc==${#sp})) && sc=0
   }
   endspin() {
      printf "\r%s\n" "$@"
   }
   #
   # - END SPINNER


   while ! [[ "${LXC_IP}" =~ ${VALID_IP} ]]; do
   # sleep 1
   #  echo "LXC ${lxcname} has still no IP "
   #  echo "Checking again.." 
   #  echo "#"
   #  echo "#"
   #  lxc list
      LXC_IP=$(lxc list | grep ${lxcname} | awk '{print $6}')
      spin
   #  echo "IP is: ${LXC_IP}"
   done
   endspin

   echo "# IP Address found!  ${lxcname} LXC IP: ${LXC_IP}"
   #lxc info $lxcname
   echo "# "

   echo "# Checking status of LXC list again.."
   lxc list

   echo "#Adding iptables ... for container"
   container_name=$(lxc exec ${lxcname} -- sh -c "ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'")
   sudo iptables -t nat -I PREROUTING -i eth0 -p TCP -d 95.216.204.31/32 --dport 80 -j DNAT --to-destination ${container_name}:80
   sudo iptables -t nat -I PREROUTING -i eth0 -p TCP -d 95.216.204.31/32 --dport 443 -j DNAT --to-destination ${container_name}:443

   echo "# Sending public key to target LXC: " ${lxcname}
   echo "#"
   #echo lxc file push $HOME/.ssh/id_lxc_${lxcname}.pub ${lxcname}/root/.ssh/authorized_keys

   #Pause for 2 seconds to make sure we get the IP and push the file.
   sleep 5

   # Send SSH key file from this those to the target LXC
   echo "######## lxc file push $HOME/.ssh/id_lxc_${lxcname}.pub ${lxcname}/root/.ssh/authorized_keys --verbose"
   lxc file push $HOME/.ssh/id_lxc_${lxcname}.pub ${lxcname}/root/.ssh/authorized_keys --verbose

   echo "#"
   echo "# Fixing root permission for authorized_keys file"
   echo "#"
   lxc exec ${lxcname} -- chmod 600 /root/.ssh/authorized_keys --verbose
   lxc exec ${lxcname} -- chown root:root /root/.ssh/authorized_keys --verbose
   lxc exec ${lxcname} -- apt-get update
   lxc exec ${lxcname} -- apt-get install -y python
   echo "#"
   echo "# Adding SSH-key for this host so we can SSH to the target LXC."
   echo "#"
   eval $(ssh-agent); 
   ssh-add $HOME/.ssh/id_lxc_$lxcname
   echo "#"
   echo "# Done! Ready to connect?"
   echo "#"
   echo "# Connect to this: ssh -i ~/.ssh/id_lxc_${lxcname} root@${LXC_IP}"
   echo "#"
   echo "#"

   # ssh key variable location
   SSHKEY=~/.ssh/id_lxc_${lxcname}

   echo "[lxc]
   ${LXC_IP} ansible_user=root "> ${lxcname}_hosts

   # Downloading ansible files 
   # Ansible playbook file check



   echo "#"
   echo "# Running playbook with this command:"
   echo "#"
   echo "# ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook lempws.yml -i ${lxcname}_hosts --private-key=${SSHKEY}"
   echo "#"

   time ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook lempws.yml -i ${lxcname}_hosts --private-key=~${SSHKEY} 


   
   # Configure HAProxy for this LXC_443
   #!/bin/bash
   echo "#"
   echo "# Let's configure HAPRoxy for this container so the world can see it!"

   lxc exec haproxy -- sh -c "sed -i  '/^    # Http Redirect /a\    acl host_lxd_${lxcname} hdr(host) -i ${cfdomain}.flexicloudhosting.com'  /etc/haproxy/haproxy.cfg" --verbose

 lxc exec haproxy -- sh -c "sed -i  '/^    # lxd backend /a\    use_backend farm_backend_lxd1 if host_lxd_${lxcname}'  /etc/haproxy/haproxy.cfg" --verbose


lxc exec haproxy -- sh -c "sed -i -e  '/ # It matches /a\        server ${lxcname} ${LXC_IP}:443 \n'  /etc/haproxy/haproxy.cfg" --verbose

   lxc exec haproxy -- sh -c "/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -c"

   lxc exec haproxy -- sh -c "sudo systemctl reload haproxy"

   lxc exec haproxy cat /etc/haproxy/haproxy.cfg | grep ${lxcname}_
      
   
   
  echo "Iptables Remove Container ip"
  sudo iptables -t nat -D PREROUTING -i eth0 -p TCP -d 95.216.204.31/32 --dport 80 -j DNAT --to-destination ${container_name}:80
  sudo iptables -t nat -D PREROUTING -i eth0 -p TCP -d 95.216.204.31/32 --dport 443 -j DNAT --to-destination ${container_name}:443


   echo "#"
   echo "#"
   echo "# Insert nginx config client_max_body_size 100M;"
   lxc exec ${lxcname} -- sh -c "sed -i  '/^http {/a\        client_max_body_size 100M;'  /etc/nginx/nginx.conf"

   echo "#"
   echo "#"
   echo "# Test and reload nginx;"
   lxc exec ${lxcname} -- sh -c "nginx -t;sudo systemctl restart nginx" 




