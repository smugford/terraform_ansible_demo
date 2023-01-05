# A Terraform/Ansible Integration Demo

## Assumptions 
* You have the AWS CLI Installed and a Default Profile Created [Docs](https://docs.aws.amazon.com/cli/latest/userguide/welcome-examples.html)
* We use the default profile for the Demo but you can change to whatever profile you wish.
## Quick Start
* Login to AWS Console
* Change Region to us-east-1
* Create a SSH Key and Save it Locally
* ```chmod 400 the-key-i-created.pem```
* The Default Security Group needs SSH Access to port 22 at least to your own ip 0.0.0.0/0 can be used for the demo but is NOT recommended for production
* Update private_key_file in ansible.cfg to the key you created and changed permissions on
* Update 'key_name' with your key_name in the aws instance creation block of ansi_terraform.tf
* in the "null_resource" blocks change "private_key" to the location of the key you downloaded (there are currently two null_resource blocks)
* from a local terminal window run ```terraform apply``` ... accept with "yes" - wait till this completes
* Copy the public ip output and paste it into a browser to confirm the content was provisioned

## Quick Tear Down
Make sure you tear this down so you are not paying for or using some of your free tier resources

```terraform destroy```
## Beyond the Quick Start

Demonstration on how to integrate Terraform with Ansible

Modified from https://medium.com/geekculture/the-most-simplified-integration-of-ansible-and-terraform-49f130b9fc8

My Modifications to the Original DEMO
* Remove the Variables File variable.tf because it is no longer required for this version of the demo
* Modified instance.yml (the ansible playbook) to use https://github.com/smugford/index_files.git as the default content
* Replaced References to User/Password login Method with SSH Key Access Method

This demo shows a simple way to integrate Terraform and Ansible at the same time.

There are probably some improvements that can be made. If you can think of any i'd be happy to review them in a Pull Request.

We modified it to get it to work as one step to create the instance and provision it with the same terraform apply command instead of running it twice like I think the original demo was doing.

![Infrastructure Diagram](/infra_diagram.webp?raw=true "Infrastructure Diagram")


Let's look at the code and see how it all works.

We start with the ansi_terraform.tf file

### The AWS Provider Block
We use us-east-1 as the default region
If you choose a different region you will need to update the AMI Id to match the region you choose

```
#defining the provider block
provider "aws" {
  region = "us-east-1"
  profile = "default"	
}
```

### Creating the EC2 Instance

> if you change the region you will need to change the AMI ID for this demo

> The 'key_name' variable is a key pair that you have already created please create a key and update the variable before running ```terraform apply```


```#aws instance creation
resource "aws_instance" "os1" {
  ami           = "ami-0b5eea76982371e91"
  instance_type = "t2.micro"
  key_name = "change-me-to-your-keyname"
  tags = {
    Name = "TerraformOS"
  }
}
```

### Getting the Pulbic IP and Storing it Locally

```
#IP of aws instance retrieved
output "op1" {
  value = aws_instance.os1.public_ip
}

#IP of aws instance copied to a file ip.txt in local system
resource "local_file" "ip" {
  content  = aws_instance.os1.public_ip
  filename = "ip.txt"
}
```

### Create and Attach and EBS Volume

```
#ebs volume created
resource "aws_ebs_volume" "ebs" {
  availability_zone = aws_instance.os1.availability_zone
  size              = 1
  tags = {
    Name = "myterraebs"
  }
}


#ebs volume attached
resource "aws_volume_attachment" "ebs_att" {
  device_name  = "/dev/sdh"
  volume_id    = aws_ebs_volume.ebs.id
  instance_id  = aws_instance.os1.id
  force_detach = true
}


#device name of ebs volume retrieved
output "op2" {
  value = aws_volume_attachment.ebs_att.device_name
}
```
> I am not sure why there is a EBS Volume Being Attached as part of this demo it does not seem to be required to get this to work. 

### Connecting to the Instance and Copying Files

```
#connecting to the Ansible control node using SSH connection

# Make sure that you update the variable to the key you created and stored locally

resource "null_resource" "nullremote1" {
  depends_on = [aws_instance.os1]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("change-me-to-your-key.pem")
    host        = aws_instance.os1.public_ip
  }
  #copying the ip.txt file to the Ansible control node from local system

  provisioner "file" {
    source      = "ip.txt"
    destination = "/tmp/ip.txt"
  }

}
```

### connecting to the Linux OS having the Ansible playbook
```
resource "null_resource" "nullremote2" {
  depends_on = [aws_instance.os1]
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/Downloads/tutorials/test-key.pem")
    host        = aws_instance.os1.public_ip
  }

  provisioner "file" {
    source      = "instance.yml"
    destination = "/tmp/instance.yml"
  }

  #command to run ansible playbook on remote Linux OS
  provisioner "remote-exec" {

    inline = [
      "cd /tmp",
      "ls -la",
      "sudo yum update -y",
      "sudo amazon-linux-extras enable ansible2 -y",
      "sudo yum install -y ansible",
      "ansible-playbook /tmp/instance.yml -i /tmp/ip.txt"
    ]
  }
}
```

# The ansible Playbook
instance.yml is pretty straight forward if you have the basics of ansible.

The playbook does the following steps:
* Installs Apache (httpd)
* Installs PHP
* Starts the Apache Server
* Installs GIT
* Formats the Storage
* Creates a "web" folder
* Mounts the Storage (EBS Volume)
* Clones Default Content into web directory

Once it has run succesfully check the ip in the browser to ensure that the content was provisioned

* http://theipaddressfromoutput/web

This should show a web page with:

"The Cloud Brothers Default Content" and some simple php content showing the date and day of the week.

## Sample of Successful Output
```
> terraform apply

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated
with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_ebs_volume.ebs will be created
  + resource "aws_ebs_volume" "ebs" {
      + arn               = (known after apply)
      + availability_zone = (known after apply)
      + encrypted         = (known after apply)
      + final_snapshot    = false
      + id                = (known after apply)
      + iops              = (known after apply)
      + kms_key_id        = (known after apply)
      + size              = 1
      + snapshot_id       = (known after apply)
      + tags              = {
          + "Name" = "myterraebs"
        }
      + tags_all          = {
          + "Name" = "myterraebs"
        }
      + throughput        = (known after apply)
      + type              = (known after apply)
    }

  # aws_instance.os1 will be created
  + resource "aws_instance" "os1" {
      + ami                                  = "ami-0b5eea76982371e91"
      + arn                                  = (known after apply)
      + associate_public_ip_address          = (known after apply)
      + availability_zone                    = (known after apply)
      + cpu_core_count                       = (known after apply)
      + cpu_threads_per_core                 = (known after apply)
      + disable_api_stop                     = (known after apply)
      + disable_api_termination              = (known after apply)
      + ebs_optimized                        = (known after apply)
      + get_password_data                    = false
      + host_id                              = (known after apply)
      + host_resource_group_arn              = (known after apply)
      + iam_instance_profile                 = (known after apply)
      + id                                   = (known after apply)
      + instance_initiated_shutdown_behavior = (known after apply)
      + instance_state                       = (known after apply)
      + instance_type                        = "t2.micro"
      + ipv6_address_count                   = (known after apply)
      + ipv6_addresses                       = (known after apply)
      + key_name                             = "test-key"
      + monitoring                           = (known after apply)
      + outpost_arn                          = (known after apply)
      + password_data                        = (known after apply)
      + placement_group                      = (known after apply)
      + placement_partition_number           = (known after apply)
      + primary_network_interface_id         = (known after apply)
      + private_dns                          = (known after apply)
      + private_ip                           = (known after apply)
      + public_dns                           = (known after apply)
      + public_ip                            = (known after apply)
      + secondary_private_ips                = (known after apply)
      + security_groups                      = (known after apply)
      + source_dest_check                    = true
      + subnet_id                            = (known after apply)
      + tags                                 = {
          + "Name" = "TerraformOS"
        }
      + tags_all                             = {
          + "Name" = "TerraformOS"
        }
      + tenancy                              = (known after apply)
      + user_data                            = (known after apply)
      + user_data_base64                     = (known after apply)
      + user_data_replace_on_change          = false
      + vpc_security_group_ids               = (known after apply)

      + capacity_reservation_specification {
          + capacity_reservation_preference = (known after apply)

          + capacity_reservation_target {
              + capacity_reservation_id                 = (known after apply)
              + capacity_reservation_resource_group_arn = (known after apply)
            }
        }

      + ebs_block_device {
          + delete_on_termination = (known after apply)
          + device_name           = (known after apply)
          + encrypted             = (known after apply)
          + iops                  = (known after apply)
          + kms_key_id            = (known after apply)
          + snapshot_id           = (known after apply)
          + tags                  = (known after apply)
          + throughput            = (known after apply)
          + volume_id             = (known after apply)
          + volume_size           = (known after apply)
          + volume_type           = (known after apply)
        }

      + enclave_options {
          + enabled = (known after apply)
        }

      + ephemeral_block_device {
          + device_name  = (known after apply)
          + no_device    = (known after apply)
          + virtual_name = (known after apply)
        }

      + maintenance_options {
          + auto_recovery = (known after apply)
        }

      + metadata_options {
          + http_endpoint               = (known after apply)
          + http_put_response_hop_limit = (known after apply)
          + http_tokens                 = (known after apply)
          + instance_metadata_tags      = (known after apply)
        }

      + network_interface {
          + delete_on_termination = (known after apply)
          + device_index          = (known after apply)
          + network_card_index    = (known after apply)
          + network_interface_id  = (known after apply)
        }

      + private_dns_name_options {
          + enable_resource_name_dns_a_record    = (known after apply)
          + enable_resource_name_dns_aaaa_record = (known after apply)
          + hostname_type                        = (known after apply)
        }

      + root_block_device {
          + delete_on_termination = (known after apply)
          + device_name           = (known after apply)
          + encrypted             = (known after apply)
          + iops                  = (known after apply)
          + kms_key_id            = (known after apply)
          + tags                  = (known after apply)
          + throughput            = (known after apply)
          + volume_id             = (known after apply)
          + volume_size           = (known after apply)
          + volume_type           = (known after apply)
        }
    }

  # aws_volume_attachment.ebs_att will be created
  + resource "aws_volume_attachment" "ebs_att" {
      + device_name  = "/dev/sdh"
      + force_detach = true
      + id           = (known after apply)
      + instance_id  = (known after apply)
      + volume_id    = (known after apply)
    }

  # local_file.ip will be created
  + resource "local_file" "ip" {
      + content              = (known after apply)
      + directory_permission = "0777"
      + file_permission      = "0777"
      + filename             = "ip.txt"
      + id                   = (known after apply)
    }

  # null_resource.nullremote1 will be created
  + resource "null_resource" "nullremote1" {
      + id = (known after apply)
    }

  # null_resource.nullremote2 will be created
  + resource "null_resource" "nullremote2" {
      + id = (known after apply)
    }

Plan: 6 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + op1 = (known after apply)
  + op2 = "/dev/sdh"

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

aws_instance.os1: Creating...
aws_instance.os1: Still creating... [10s elapsed]
aws_instance.os1: Still creating... [20s elapsed]
aws_instance.os1: Still creating... [30s elapsed]
aws_instance.os1: Still creating... [40s elapsed]
aws_instance.os1: Creation complete after 44s [id=i-0e505de41e82fc323]
aws_ebs_volume.ebs: Creating...
local_file.ip: Creating...
null_resource.nullremote1: Creating...
null_resource.nullremote2: Creating...
null_resource.nullremote2: Provisioning with 'file'...
null_resource.nullremote1: Provisioning with 'file'...
local_file.ip: Creation complete after 0s [id=81cd3ac2ced3505c52b999bfa0f4a333f5436b6c]
null_resource.nullremote1: Creation complete after 6s [id=821434618308427021]
null_resource.nullremote2: Provisioning with 'remote-exec'...
null_resource.nullremote2 (remote-exec): Connecting to remote host via SSH...
null_resource.nullremote2 (remote-exec):   Host: 54.172.18.56
null_resource.nullremote2 (remote-exec):   User: ec2-user
null_resource.nullremote2 (remote-exec):   Password: false
null_resource.nullremote2 (remote-exec):   Private key: true
null_resource.nullremote2 (remote-exec):   Certificate: false
null_resource.nullremote2 (remote-exec):   SSH Agent: true
null_resource.nullremote2 (remote-exec):   Checking Host Key: false
null_resource.nullremote2 (remote-exec):   Target Platform: unix
null_resource.nullremote2 (remote-exec): Connected!
null_resource.nullremote2 (remote-exec): total 20
null_resource.nullremote2 (remote-exec): drwxrwxrwt 12 root     root     4096 Jan  2 23:49 .
null_resource.nullremote2 (remote-exec): dr-xr-xr-x 18 root     root      257 Jan  2 23:49 ..
null_resource.nullremote2 (remote-exec): drwxrwxrwt  2 root     root        6 Jan  2 23:49 .font-unix
null_resource.nullremote2 (remote-exec): drwxrwxrwt  2 root     root        6 Jan  2 23:49 .ICE-unix
null_resource.nullremote2 (remote-exec): -rw-r--r--  1 ec2-user ec2-user  904 Jan  2 23:49 instance.yml
null_resource.nullremote2 (remote-exec): -rw-r--r--  1 ec2-user ec2-user   12 Jan  2 23:49 ip.txt
null_resource.nullremote2 (remote-exec): -rw-------  1 root     root        0 Jan  2 23:49 motd.partdhr4E
null_resource.nullremote2 (remote-exec): -rw-------  1 root     root      121 Jan  2 23:49 motd.yR6S2
null_resource.nullremote2 (remote-exec): drwx------  2 ec2-user ec2-user   24 Jan  2 23:49 ssh-4YaKgIspEt
null_resource.nullremote2 (remote-exec): drwx------  2 ec2-user ec2-user   24 Jan  2 23:49 ssh-OGAKnvSnNE
null_resource.nullremote2 (remote-exec): drwx------  2 ec2-user ec2-user   24 Jan  2 23:49 ssh-Tj4xnJGb61
null_resource.nullremote2 (remote-exec): drwx------  3 root     root       17 Jan  2 23:49 systemd-private-45ff90c0f2ef4b3d8a30c8e21731e27b-chronyd.service-dShqwu
null_resource.nullremote2 (remote-exec): drwx------  3 root     root       17 Jan  2 23:49 systemd-private-45ff90c0f2ef4b3d8a30c8e21731e27b-systemd-hostnamed.service-1CY5Dt
null_resource.nullremote2 (remote-exec): -rwxrwxrwx  1 ec2-user ec2-user  166 Jan  2 23:49 terraform_1662884219.sh
null_resource.nullremote2 (remote-exec): drwxrwxrwt  2 root     root        6 Jan  2 23:49 .Test-unix
null_resource.nullremote2 (remote-exec): drwxrwxrwt  2 root     root        6 Jan  2 23:49 .X11-unix
null_resource.nullremote2 (remote-exec): drwxrwxrwt  2 root     root        6 Jan  2 23:49 .XIM-unix
null_resource.nullremote2 (remote-exec): Loaded plugins: extras_suggestions,
null_resource.nullremote2 (remote-exec):               : langpacks, priorities,
null_resource.nullremote2 (remote-exec):               : update-motd
null_resource.nullremote2 (remote-exec): Existing lock /var/run/yum.pid: another copy is running as pid 3202.
null_resource.nullremote2 (remote-exec): Another app is currently holding the yum lock; waiting for it to exit...
null_resource.nullremote2 (remote-exec):   The other application is: yum
null_resource.nullremote2 (remote-exec):     Memory :  89 M RSS (381 MB VSZ)
null_resource.nullremote2 (remote-exec):     Started: Mon Jan  2 23:49:27 2023 - 00:06 ago
null_resource.nullremote2 (remote-exec):     State  : Running, pid: 3202
aws_ebs_volume.ebs: Still creating... [10s elapsed]
null_resource.nullremote2: Still creating... [10s elapsed]
aws_ebs_volume.ebs: Creation complete after 11s [id=vol-0464550ee71382d09]
aws_volume_attachment.ebs_att: Creating...
null_resource.nullremote2 (remote-exec): Another app is currently holding the yum lock; waiting for it to exit...
null_resource.nullremote2 (remote-exec):   The other application is: yum
null_resource.nullremote2 (remote-exec):     Memory : 150 M RSS (442 MB VSZ)
null_resource.nullremote2 (remote-exec):     Started: Mon Jan  2 23:49:27 2023 - 00:08 ago
null_resource.nullremote2 (remote-exec):     State  : Running, pid: 3202
null_resource.nullremote2 (remote-exec): Another app is currently holding the yum lock; waiting for it to exit...
null_resource.nullremote2 (remote-exec):   The other application is: yum
null_resource.nullremote2 (remote-exec):     Memory : 174 M RSS (466 MB VSZ)
null_resource.nullremote2 (remote-exec):     Started: Mon Jan  2 23:49:27 2023 - 00:10 ago
null_resource.nullremote2 (remote-exec):     State  : Running, pid: 3202
null_resource.nullremote2 (remote-exec): Existing lock /var/run/yum.pid: another copy is running as pid 3217.
null_resource.nullremote2 (remote-exec): Another app is currently holding the yum lock; waiting for it to exit...
null_resource.nullremote2 (remote-exec):   The other application is: yum
null_resource.nullremote2 (remote-exec):     Memory :  57 M RSS (276 MB VSZ)
null_resource.nullremote2 (remote-exec):     Started: Mon Jan  2 23:49:27 2023 - 00:12 ago
null_resource.nullremote2 (remote-exec):     State  : Running, pid: 3217
null_resource.nullremote2 (remote-exec): No packages marked for update
null_resource.nullremote2 (remote-exec):   0  ansible2=latest          enabled      \
null_resource.nullremote2 (remote-exec):         [ =2.4.2  =2.4.6  =2.8  =stable ]
null_resource.nullremote2 (remote-exec):   2  httpd_modules            available    [ =1.0  =stable ]
null_resource.nullremote2 (remote-exec):   3  memcached1.5             available    \
null_resource.nullremote2 (remote-exec):         [ =1.5.1  =1.5.16  =1.5.17 ]
null_resource.nullremote2 (remote-exec):   6  postgresql10             available    [ =10  =stable ]
null_resource.nullremote2 (remote-exec):   9  R3.4                     available    [ =3.4.3  =stable ]
null_resource.nullremote2 (remote-exec):  10  rust1                    available    \
null_resource.nullremote2 (remote-exec):         [ =1.22.1  =1.26.0  =1.26.1  =1.27.2  =1.31.0  =1.38.0
null_resource.nullremote2 (remote-exec):           =stable ]
null_resource.nullremote2 (remote-exec):  18  libreoffice              available    \
null_resource.nullremote2 (remote-exec):         [ =5.0.6.2_15  =5.3.6.1  =stable ]
null_resource.nullremote2 (remote-exec):  19  gimp                     available    [ =2.8.22 ]
null_resource.nullremote2 (remote-exec):  20  docker=latest            enabled      \
null_resource.nullremote2 (remote-exec):         [ =17.12.1  =18.03.1  =18.06.1  =18.09.9  =stable ]
null_resource.nullremote2 (remote-exec):  21  mate-desktop1.x          available    \
null_resource.nullremote2 (remote-exec):         [ =1.19.0  =1.20.0  =stable ]
null_resource.nullremote2 (remote-exec):  22  GraphicsMagick1.3        available    \
null_resource.nullremote2 (remote-exec):         [ =1.3.29  =1.3.32  =1.3.34  =stable ]
null_resource.nullremote2 (remote-exec):  23  tomcat8.5                available    \
null_resource.nullremote2 (remote-exec):         [ =8.5.31  =8.5.32  =8.5.38  =8.5.40  =8.5.42  =8.5.50
null_resource.nullremote2 (remote-exec):           =stable ]
null_resource.nullremote2 (remote-exec):  24  epel                     available    [ =7.11  =stable ]
null_resource.nullremote2 (remote-exec):  25  testing                  available    [ =1.0  =stable ]
null_resource.nullremote2 (remote-exec):  26  ecs                      available    [ =stable ]
null_resource.nullremote2 (remote-exec):  27  corretto8                available    \
null_resource.nullremote2 (remote-exec):         [ =1.8.0_192  =1.8.0_202  =1.8.0_212  =1.8.0_222  =1.8.0_232
null_resource.nullremote2 (remote-exec):           =1.8.0_242  =stable ]
null_resource.nullremote2 (remote-exec):  29  golang1.11               available    \
null_resource.nullremote2 (remote-exec):         [ =1.11.3  =1.11.11  =1.11.13  =stable ]
null_resource.nullremote2 (remote-exec):  30  squid4                   available    [ =4  =stable ]
null_resource.nullremote2 (remote-exec):  32  lustre2.10               available    \
null_resource.nullremote2 (remote-exec):         [ =2.10.5  =2.10.8  =stable ]
null_resource.nullremote2 (remote-exec):  33  java-openjdk11           available    [ =11  =stable ]
null_resource.nullremote2 (remote-exec):  34  lynis                    available    [ =stable ]
null_resource.nullremote2 (remote-exec):  36  BCC                      available    [ =0.x  =stable ]
null_resource.nullremote2 (remote-exec):  37  mono                     available    [ =5.x  =stable ]
null_resource.nullremote2 (remote-exec):  38  nginx1                   available    [ =stable ]
null_resource.nullremote2 (remote-exec):  39  ruby2.6                  available    [ =2.6  =stable ]
null_resource.nullremote2 (remote-exec):  40  mock                     available    [ =stable ]
null_resource.nullremote2 (remote-exec):  41  postgresql11             available    [ =11  =stable ]
null_resource.nullremote2 (remote-exec):  42  php7.4                   available    [ =stable ]
null_resource.nullremote2 (remote-exec):  43  livepatch                available    [ =stable ]
null_resource.nullremote2 (remote-exec):  44  python3.8                available    [ =stable ]
null_resource.nullremote2 (remote-exec):  45  haproxy2                 available    [ =stable ]
null_resource.nullremote2 (remote-exec):  46  collectd                 available    [ =stable ]
null_resource.nullremote2 (remote-exec):  47  aws-nitro-enclaves-cli   available    [ =stable ]
null_resource.nullremote2 (remote-exec):  48  R4                       available    [ =stable ]
null_resource.nullremote2 (remote-exec):   _  kernel-5.4               available    [ =stable ]
null_resource.nullremote2 (remote-exec):  50  selinux-ng               available    [ =stable ]
null_resource.nullremote2 (remote-exec):  51  php8.0                   available    [ =stable ]
null_resource.nullremote2 (remote-exec):  52  tomcat9                  available    [ =stable ]
null_resource.nullremote2 (remote-exec):  53  unbound1.13              available    [ =stable ]
null_resource.nullremote2 (remote-exec):  54  mariadb10.5              available    [ =stable ]
null_resource.nullremote2 (remote-exec):  55  kernel-5.10=latest       enabled      [ =stable ]
null_resource.nullremote2 (remote-exec):  56  redis6                   available    [ =stable ]
null_resource.nullremote2 (remote-exec):  57  ruby3.0                  available    [ =stable ]
null_resource.nullremote2 (remote-exec):  58  postgresql12             available    [ =stable ]
null_resource.nullremote2 (remote-exec):  59  postgresql13             available    [ =stable ]
null_resource.nullremote2 (remote-exec):  60  mock2                    available    [ =stable ]
null_resource.nullremote2 (remote-exec):  61  dnsmasq2.85              available    [ =stable ]
null_resource.nullremote2 (remote-exec):  62  kernel-5.15              available    [ =stable ]
null_resource.nullremote2 (remote-exec):  63  postgresql14             available    [ =stable ]
null_resource.nullremote2 (remote-exec):  64  firefox                  available    [ =stable ]
null_resource.nullremote2 (remote-exec):  65  lustre                   available    [ =stable ]
null_resource.nullremote2 (remote-exec):  66  php8.1                   available    [ =stable ]
null_resource.nullremote2 (remote-exec):  67  awscli1                  available    [ =stable ]

null_resource.nullremote2 (remote-exec): Now you can install:
null_resource.nullremote2 (remote-exec):  # yum clean metadata
null_resource.nullremote2 (remote-exec):  # yum install ansible
null_resource.nullremote2 (remote-exec): Loaded plugins: extras_suggestions,
null_resource.nullremote2 (remote-exec):               : langpacks, priorities,
null_resource.nullremote2 (remote-exec):               : update-motd
null_resource.nullremote2 (remote-exec): amzn2extra-ansib | 3.0 kB     00:00
null_resource.nullremote2 (remote-exec): amzn2extra-docke | 3.0 kB     00:00
null_resource.nullremote2 (remote-exec): amzn2extra-kerne | 3.0 kB     00:00
null_resource.nullremote2 (remote-exec): (1/2): amzn2extra- |   76 B   00:00
null_resource.nullremote2 (remote-exec): (2/2): amzn2extra- |  39 kB   00:00
null_resource.nullremote2 (remote-exec): Resolving Dependencies
null_resource.nullremote2 (remote-exec): --> Running transaction check
null_resource.nullremote2 (remote-exec): ---> Package ansible.noarch 0:2.9.23-1.amzn2 will be installed
null_resource.nullremote2 (remote-exec): --> Processing Dependency: sshpass for package: ansible-2.9.23-1.amzn2.noarch
null_resource.nullremote2 (remote-exec): --> Processing Dependency: python-paramiko for package: ansible-2.9.23-1.amzn2.noarch
null_resource.nullremote2 (remote-exec): --> Processing Dependency: python-keyczar for package: ansible-2.9.23-1.amzn2.noarch
null_resource.nullremote2 (remote-exec): --> Processing Dependency: python-httplib2 for package: ansible-2.9.23-1.amzn2.noarch
null_resource.nullremote2 (remote-exec): --> Processing Dependency: python-crypto for package: ansible-2.9.23-1.amzn2.noarch
null_resource.nullremote2 (remote-exec): --> Running transaction check
null_resource.nullremote2 (remote-exec): ---> Package python-keyczar.noarch 0:0.71c-2.amzn2 will be installed
null_resource.nullremote2 (remote-exec): ---> Package python2-crypto.x86_64 0:2.6.1-13.amzn2.0.3 will be installed
null_resource.nullremote2 (remote-exec): --> Processing Dependency: libtomcrypt.so.1()(64bit) for package: python2-crypto-2.6.1-13.amzn2.0.3.x86_64
null_resource.nullremote2 (remote-exec): ---> Package python2-httplib2.noarch 0:0.18.1-3.amzn2 will be installed
null_resource.nullremote2 (remote-exec): ---> Package python2-paramiko.noarch 0:1.16.1-3.amzn2.0.2 will be installed
null_resource.nullremote2 (remote-exec): --> Processing Dependency: python2-ecdsa for package: python2-paramiko-1.16.1-3.amzn2.0.2.noarch
null_resource.nullremote2 (remote-exec): ---> Package sshpass.x86_64 0:1.06-1.amzn2.0.1 will be installed
null_resource.nullremote2 (remote-exec): --> Running transaction check
null_resource.nullremote2 (remote-exec): ---> Package libtomcrypt.x86_64 0:1.18.2-1.amzn2.0.1 will be installed
null_resource.nullremote2 (remote-exec): --> Processing Dependency: libtommath >= 1.0 for package: libtomcrypt-1.18.2-1.amzn2.0.1.x86_64
null_resource.nullremote2 (remote-exec): --> Processing Dependency: libtommath.so.1()(64bit) for package: libtomcrypt-1.18.2-1.amzn2.0.1.x86_64
null_resource.nullremote2 (remote-exec): ---> Package python2-ecdsa.noarch 0:0.13.3-1.amzn2.0.1 will be installed
null_resource.nullremote2 (remote-exec): --> Running transaction check
null_resource.nullremote2 (remote-exec): ---> Package libtommath.x86_64 0:1.0.1-4.amzn2.0.1 will be installed
null_resource.nullremote2: Still creating... [20s elapsed]
null_resource.nullremote2 (remote-exec): --> Finished Dependency Resolution

null_resource.nullremote2 (remote-exec): Dependencies Resolved

null_resource.nullremote2 (remote-exec): ========================================
null_resource.nullremote2 (remote-exec):  Package
null_resource.nullremote2 (remote-exec):     Arch   Version
null_resource.nullremote2 (remote-exec):               Repository           Size
null_resource.nullremote2 (remote-exec): ========================================
null_resource.nullremote2 (remote-exec): Installing:
null_resource.nullremote2 (remote-exec):  ansible
null_resource.nullremote2 (remote-exec):     noarch 2.9.23-1.amzn2
null_resource.nullremote2 (remote-exec):               amzn2extra-ansible2  17 M
null_resource.nullremote2 (remote-exec): Installing for dependencies:
null_resource.nullremote2 (remote-exec):  libtomcrypt
null_resource.nullremote2 (remote-exec):     x86_64 1.18.2-1.amzn2.0.1
null_resource.nullremote2 (remote-exec):               amzn2extra-ansible2 409 k
null_resource.nullremote2 (remote-exec):  libtommath
null_resource.nullremote2 (remote-exec):     x86_64 1.0.1-4.amzn2.0.1
null_resource.nullremote2 (remote-exec):               amzn2extra-ansible2  36 k
null_resource.nullremote2 (remote-exec):  python-keyczar
null_resource.nullremote2 (remote-exec):     noarch 0.71c-2.amzn2
null_resource.nullremote2 (remote-exec):               amzn2extra-ansible2 218 k
null_resource.nullremote2 (remote-exec):  python2-crypto
null_resource.nullremote2 (remote-exec):     x86_64 2.6.1-13.amzn2.0.3
null_resource.nullremote2 (remote-exec):               amzn2extra-ansible2 476 k
null_resource.nullremote2 (remote-exec):  python2-ecdsa
null_resource.nullremote2 (remote-exec):     noarch 0.13.3-1.amzn2.0.1
null_resource.nullremote2 (remote-exec):               amzn2extra-ansible2  94 k
null_resource.nullremote2 (remote-exec):  python2-httplib2
null_resource.nullremote2 (remote-exec):     noarch 0.18.1-3.amzn2
null_resource.nullremote2 (remote-exec):               amzn2extra-ansible2 125 k
null_resource.nullremote2 (remote-exec):  python2-paramiko
null_resource.nullremote2 (remote-exec):     noarch 1.16.1-3.amzn2.0.2
null_resource.nullremote2 (remote-exec):               amzn2extra-ansible2 259 k
null_resource.nullremote2 (remote-exec):  sshpass
null_resource.nullremote2 (remote-exec):     x86_64 1.06-1.amzn2.0.1
null_resource.nullremote2 (remote-exec):               amzn2extra-ansible2  22 k

null_resource.nullremote2 (remote-exec): Transaction Summary
null_resource.nullremote2 (remote-exec): ========================================
null_resource.nullremote2 (remote-exec): Install  1 Package (+8 Dependent packages)

null_resource.nullremote2 (remote-exec): Total download size: 19 M
null_resource.nullremote2 (remote-exec): Installed size: 110 M
null_resource.nullremote2 (remote-exec): Downloading packages:
null_resource.nullremote2 (remote-exec): (1/9): libtomcrypt | 409 kB   00:00
null_resource.nullremote2 (remote-exec): (2/9): libtommath- |  36 kB   00:00
null_resource.nullremote2 (remote-exec): (3/9): python-keyc | 218 kB   00:00
null_resource.nullremote2 (remote-exec): (4/9): python2-cry | 476 kB   00:00
null_resource.nullremote2 (remote-exec): (5/9): python2-ecd |  94 kB   00:00
null_resource.nullremote2 (remote-exec): (6/9): ansible-2.9 |  17 MB   00:00
null_resource.nullremote2 (remote-exec): (7/9): python2-htt | 125 kB   00:00
null_resource.nullremote2 (remote-exec): (8/9): sshpass-1.0 |  22 kB   00:00
null_resource.nullremote2 (remote-exec): (9/9): python2-par | 259 kB   00:00
null_resource.nullremote2 (remote-exec): ----------------------------------------
null_resource.nullremote2 (remote-exec): Total       42 MB/s |  19 MB  00:00
aws_volume_attachment.ebs_att: Still creating... [10s elapsed]
null_resource.nullremote2 (remote-exec): Running transaction check
null_resource.nullremote2 (remote-exec): Running transaction test
null_resource.nullremote2 (remote-exec): Transaction test succeeded
null_resource.nullremote2 (remote-exec): Running transaction
null_resource.nullremote2 (remote-exec):   Installing : sshpass- [         ] 1/9
null_resource.nullremote2 (remote-exec):   Installing : sshpass- [###      ] 1/9
null_resource.nullremote2 (remote-exec):   Installing : sshpass- [#######  ] 1/9
null_resource.nullremote2 (remote-exec):   Installing : sshpass- [######## ] 1/9
null_resource.nullremote2 (remote-exec):   Installing : sshpass-1.06-1.amz   1/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [         ] 2/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [#        ] 2/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [##       ] 2/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [####     ] 2/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [#####    ] 2/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [######   ] 2/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [######## ] 2/9
null_resource.nullremote2 (remote-exec):   Installing : python2-httplib2-0   2/9
null_resource.nullremote2 (remote-exec):   Installing : libtomma [         ] 3/9
null_resource.nullremote2 (remote-exec):   Installing : libtomma [#######  ] 3/9
null_resource.nullremote2 (remote-exec):   Installing : libtomma [######## ] 3/9
null_resource.nullremote2 (remote-exec):   Installing : libtommath-1.0.1-4   3/9
null_resource.nullremote2 (remote-exec):   Installing : libtomcr [         ] 4/9
null_resource.nullremote2 (remote-exec):   Installing : libtomcr [#        ] 4/9
null_resource.nullremote2 (remote-exec):   Installing : libtomcr [##       ] 4/9
null_resource.nullremote2 (remote-exec):   Installing : libtomcr [###      ] 4/9
null_resource.nullremote2 (remote-exec):   Installing : libtomcr [####     ] 4/9
null_resource.nullremote2 (remote-exec):   Installing : libtomcr [#####    ] 4/9
null_resource.nullremote2 (remote-exec):   Installing : libtomcr [######   ] 4/9
null_resource.nullremote2 (remote-exec):   Installing : libtomcr [#######  ] 4/9
null_resource.nullremote2 (remote-exec):   Installing : libtomcr [######## ] 4/9
null_resource.nullremote2 (remote-exec):   Installing : libtomcrypt-1.18.2   4/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [         ] 5/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [#        ] 5/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [##       ] 5/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [###      ] 5/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [####     ] 5/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [#####    ] 5/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [######   ] 5/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [#######  ] 5/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [######## ] 5/9
null_resource.nullremote2 (remote-exec):   Installing : python2-crypto-2.6   5/9
null_resource.nullremote2 (remote-exec):   Installing : python-k [         ] 6/9
null_resource.nullremote2 (remote-exec):   Installing : python-k [#        ] 6/9
null_resource.nullremote2 (remote-exec):   Installing : python-k [##       ] 6/9
null_resource.nullremote2 (remote-exec):   Installing : python-k [###      ] 6/9
null_resource.nullremote2 (remote-exec):   Installing : python-k [####     ] 6/9
null_resource.nullremote2 (remote-exec):   Installing : python-k [#####    ] 6/9
null_resource.nullremote2 (remote-exec):   Installing : python-k [######   ] 6/9
null_resource.nullremote2 (remote-exec):   Installing : python-k [#######  ] 6/9
null_resource.nullremote2 (remote-exec):   Installing : python-k [######## ] 6/9
null_resource.nullremote2 (remote-exec):   Installing : python-keyczar-0.7   6/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [         ] 7/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [#        ] 7/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [##       ] 7/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [###      ] 7/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [####     ] 7/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [#####    ] 7/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [######   ] 7/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [#######  ] 7/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [######## ] 7/9
null_resource.nullremote2 (remote-exec):   Installing : python2-ecdsa-0.13   7/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [         ] 8/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [#        ] 8/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [##       ] 8/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [###      ] 8/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [####     ] 8/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [#####    ] 8/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [######   ] 8/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [#######  ] 8/9
null_resource.nullremote2 (remote-exec):   Installing : python2- [######## ] 8/9
null_resource.nullremote2 (remote-exec):   Installing : python2-paramiko-1   8/9
null_resource.nullremote2 (remote-exec):   Installing : ansible- [         ] 9/9
null_resource.nullremote2 (remote-exec):   Installing : ansible- [#        ] 9/9
null_resource.nullremote2 (remote-exec):   Installing : ansible- [##       ] 9/9
null_resource.nullremote2 (remote-exec):   Installing : ansible- [###      ] 9/9
null_resource.nullremote2 (remote-exec):   Installing : ansible- [####     ] 9/9
null_resource.nullremote2 (remote-exec):   Installing : ansible- [#####    ] 9/9
null_resource.nullremote2 (remote-exec):   Installing : ansible- [######   ] 9/9
null_resource.nullremote2 (remote-exec):   Installing : ansible- [#######  ] 9/9
null_resource.nullremote2 (remote-exec):   Installing : ansible- [######## ] 9/9
null_resource.nullremote2: Still creating... [30s elapsed]
aws_volume_attachment.ebs_att: Still creating... [20s elapsed]
null_resource.nullremote2 (remote-exec):   Installing : ansible-2.9.23-1.a   9/9
null_resource.nullremote2 (remote-exec):   Verifying  : python2-ecdsa-0.13   1/9
null_resource.nullremote2 (remote-exec):   Verifying  : libtommath-1.0.1-4   2/9
null_resource.nullremote2 (remote-exec):   Verifying  : python2-crypto-2.6   3/9
null_resource.nullremote2 (remote-exec):   Verifying  : ansible-2.9.23-1.a   4/9
null_resource.nullremote2 (remote-exec):   Verifying  : python-keyczar-0.7   5/9
null_resource.nullremote2 (remote-exec):   Verifying  : libtomcrypt-1.18.2   6/9
null_resource.nullremote2 (remote-exec):   Verifying  : python2-paramiko-1   7/9
null_resource.nullremote2 (remote-exec):   Verifying  : python2-httplib2-0   8/9
null_resource.nullremote2 (remote-exec):   Verifying  : sshpass-1.06-1.amz   9/9

null_resource.nullremote2 (remote-exec): Installed:
null_resource.nullremote2 (remote-exec):   ansible.noarch 0:2.9.23-1.amzn2

null_resource.nullremote2 (remote-exec): Dependency Installed:
null_resource.nullremote2 (remote-exec):   libtomcrypt.x86_64 0:1.18.2-1.amzn2.0.1
null_resource.nullremote2 (remote-exec):   libtommath.x86_64 0:1.0.1-4.amzn2.0.1
null_resource.nullremote2 (remote-exec):   python-keyczar.noarch 0:0.71c-2.amzn2
null_resource.nullremote2 (remote-exec):   python2-crypto.x86_64 0:2.6.1-13.amzn2.0.3
null_resource.nullremote2 (remote-exec):   python2-ecdsa.noarch 0:0.13.3-1.amzn2.0.1
null_resource.nullremote2 (remote-exec):   python2-httplib2.noarch 0:0.18.1-3.amzn2
null_resource.nullremote2 (remote-exec):   python2-paramiko.noarch 0:1.16.1-3.amzn2.0.2
null_resource.nullremote2 (remote-exec):   sshpass.x86_64 0:1.06-1.amzn2.0.1

null_resource.nullremote2 (remote-exec): Complete!
aws_volume_attachment.ebs_att: Creation complete after 21s [id=vai-1679515188]

null_resource.nullremote2 (remote-exec): PLAY [integration of terraform and ansible] ************************************

null_resource.nullremote2 (remote-exec): TASK [Gathering Facts] *********************************************************
null_resource.nullremote2 (remote-exec): ok: [localhost]

null_resource.nullremote2 (remote-exec): TASK [installing httpd] ********************************************************
null_resource.nullremote2: Still creating... [40s elapsed]
null_resource.nullremote2 (remote-exec): changed: [localhost]

null_resource.nullremote2 (remote-exec): TASK [installing php] **********************************************************
null_resource.nullremote2: Still creating... [50s elapsed]
null_resource.nullremote2 (remote-exec): changed: [localhost]

null_resource.nullremote2 (remote-exec): TASK [starting httpd service] **************************************************
null_resource.nullremote2 (remote-exec): changed: [localhost]

null_resource.nullremote2 (remote-exec): TASK [installing git] **********************************************************
null_resource.nullremote2: Still creating... [1m0s elapsed]
null_resource.nullremote2: Still creating... [1m10s elapsed]
null_resource.nullremote2 (remote-exec): changed: [localhost]

null_resource.nullremote2 (remote-exec): TASK [formatting storage] ******************************************************
null_resource.nullremote2 (remote-exec): changed: [localhost]

null_resource.nullremote2 (remote-exec): TASK [making folder] ***********************************************************
null_resource.nullremote2 (remote-exec): changed: [localhost]

null_resource.nullremote2 (remote-exec): TASK [mounting storage] ********************************************************
null_resource.nullremote2 (remote-exec): changed: [localhost]

null_resource.nullremote2 (remote-exec): TASK [cloning git repo] ********************************************************
null_resource.nullremote2 (remote-exec): changed: [localhost]

null_resource.nullremote2 (remote-exec): PLAY RECAP *********************************************************************
null_resource.nullremote2 (remote-exec): localhost                  : ok=9    changed=8    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

null_resource.nullremote2: Creation complete after 1m15s [id=7018039037638858104]

Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

Outputs:

op1 = "54.172.18.56"
op2 = "/dev/sdh"
```

## Skill Required to complete this demo

* Create and Use and AWS Profile
* Create and Use IAM User Programatic Credentials
* AWS Configure
* terraform plan
* terraform apply 

## Nice to Have
* A little ansible knowledge is useful but not required to get the demo working
