# terraform_ansible_integration
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


#ebs volume attatched
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