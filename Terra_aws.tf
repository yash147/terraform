provider "aws" {
    region ="ap-south-1"
    profile = "yash"
  
}

#Security group
resource "aws_security_group" "aws_sg" {
  name        = "aws_sg"
  vpc_id      = "vpc-e698858e"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aws_sg"
  }
}



#EC2 instance
resource "aws_instance" "Os1" {
    ami = "ami-0447a12f28fddb066"
    instance_type = "t2.micro"
    key_name = "Os1key"
    security_groups = [ "aws_sg"  ]
    connection {
        type = "ssh"
        user = "ec2-user"
        private_key = file("C:/Users/Nihal/Downloads/Os1key.pem")
        host = aws_instance.Os1.public_ip
    }
    provisioner "remote-exec" {
        inline = [
            "sudo yum install httpd  php git -y",
            "sudo systemctl restart httpd",
            "sudo systemctl enable httpd",
        ]
    }

    tags = {
        Name = "aws_os1"
    }
}
	resource "null_resource" "local1"{
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.Os1.public_ip} > publicip.txt"
  }
	
}
output "AZ" {
       value = aws_instance.Os1.availability_zone
}
output "Os1_ip" {
       value = aws_instance.Os1.public_ip
}


output "Os1_id" {
       value = aws_instance.Os1.id
}
#EBS volume
resource "aws_ebs_volume" "vol1" {
  availability_zone = "${aws_instance.Os1.availability_zone}"
  size = 1
  tags = {
    Name = "osvol1"
  }
}

resource "null_resource" "nullremote1"  {

depends_on = [
    aws_volume_attachment.Ebs_ec2,
]

connection {
    type = "ssh"
    user = "ec2-user"
    private_key = file("C:/Users/Nihal/Downloads/Os1key.pem")
    host = aws_instance.Os1.public_ip
}
provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/yash147/aws_auto.git /var/www/html/"
    ]
  }
}


#Attach EBS with EC2
resource "aws_volume_attachment" "Ebs_ec2" {
   device_name = "/dev/sdh"
   volume_id   =  "${aws_ebs_volume.vol1.id}"
   instance_id = "${aws_instance.Os1.id}"
    force_detach = true
   depends_on = [
       aws_ebs_volume.vol1,
       aws_instance.Os1
   ]
 }

#Creating S3 bucket
resource "aws_s3_bucket" "os1_bucket" {
  bucket = "ybbucket148"
  acl    = "public-read"
}

# image to S3 bucket
resource "aws_s3_bucket_object" "obj1" {
  bucket = "ybbucket148"
  key = "index.jpg"
        source = "C:/Users/Nihal/Desktop/index.jpg"
	etag = filemd5("C:/Users/Nihal/Desktop/index.jpg")
	acl = "public-read"
  content_type = "image/jpg"
  depends_on = [
      aws_s3_bucket.os1_bucket
  ]
}

# Cloud-front and attching S3 buccket to it

resource "aws_cloudfront_distribution" "os1_cloudFront" {
    origin {
        domain_name = "ybbucket148.s3.amazonaws.com"
        origin_id   = "S3-ybbucket148" 

        custom_origin_config {
            http_port = 80
            https_port = 80
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
        }
    }
       
    enabled = true

    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3-ybbucket148"

        forwarded_values {
            query_string = false
        
            cookies {
               forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    
}
connection {
        type    = "ssh"
        user    = "ec2-user"
        host    = aws_instance.Os1.public_ip
        port    = 22
        private_key = file("C:/Users/Nihal/Downloads/Os1key.pem")
    }
provisioner "remote-exec" {

        inline  = [

            "sudo su << EOF",
            "echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.obj1.key}'>\" > /var/www/html/index.html",
            "EOF"
        ]
    }
	restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }

viewer_certificate {
        cloudfront_default_certificate = true
    }
	depends_on = [
        aws_s3_bucket_object.obj1
    ]

}
resource "null_resource" "nulllocal1"  {


depends_on = [
    null_resource.nullremote1,
  ]

	
}


