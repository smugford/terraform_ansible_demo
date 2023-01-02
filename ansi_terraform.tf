#defining the provider block
provider "aws" {
  region  = "us-east-1"
  profile = "default"

}

#aws instance creation
resource "aws_instance" "os1" {
  ami           = "ami-0b5eea76982371e91"
  instance_type = "t2.micro"
  key_name = "test-key"
  tags = {
    Name = "TerraformOS"
  }
}

#IP of aws instance retrieved
output "op1" {
  value = aws_instance.os1.public_ip
}


#IP of aws instance copied to a file ip.txt in local system
resource "local_file" "ip" {
  content  = aws_instance.os1.public_ip
  filename = "ip.txt"
}


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

#connecting to the Ansible control node using SSH connection

# Make sure that you update the variable to the key you created and stored locally

resource "null_resource" "nullremote1" {
  depends_on = [aws_instance.os1]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/Downloads/tutorials/test-key.pem")
    host        = aws_instance.os1.public_ip
  }
  #copying the ip.txt file to the Ansible control node from local system

  provisioner "file" {
    source      = "ip.txt"
    destination = "/tmp/ip.txt"
  }

}

#connecting to the Linux OS having the Ansible playbook
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

  # # #command to run ansible playbook on remote Linux OS
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

# # to automatically open the webpage on local system
# resource "null_resource" "nullremote3" {
# depends_on = [null_resource.nullremote2]
# provisioner "local-exec" {
#   command = "echo 'hello world'"
#  }
# }
