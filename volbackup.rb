#!/usr/bin/env ruby
require 'optparse'
require 'ostruct'
require 'open-uri'

containers = []
host = ""
docker_sock = ""
rsync_user = ""
ssh_key_path = ""
ssh_port = ""
rsync_extra_opts = []
remote_path = ""

opts_parser = OptionParser.new do |opts|
  opts.banner = "Usage: rsync.rb [options]"

  opts.separator ""
  opts.separator "Sepcific options"

  opts.on("-c", "--container", "Name/ID of Container to backup volumes for") do |c|
    containers << c
  end

  opts.on("-h", "--host", "Remote host to sync backups to, format: <user@>host<:port>") do |h|
    host = h
  end

  opts.on("-s", "--sock", "Location of Docker socket") do |sock|
    if sock /^\//
      sock = "unix://#{sock}"
    end
    docker_sock = sock
  end

  opts.on("-u", "--user", "RSync/SSH user") do |u|
    rsync_user = u
  end

  opts.on("-k", "--key", "RSync/SSH key path") do |key|
    ssh_key_path = key
  end

  opts.on("-p", "--port", "RSync/SSH port") do |port|
    ssh_port = port
  end

  opts.on("-r", "--remote-path", "Path to store data on remote server") do |path|
    remote_path = path
  end

  opts.on("--rsync-opt", "Extra rsync options") do |opt|
    rsync_extra_opts << opt
  end
end
opts_parser.parse!(ARGV)

raise OptionParser::MissingArgument, "Must provide host" if host.empty?

ssh_port ||= 22
ssh_key_path ||= "/Backup/.ssh/id_rsa"
ssh_user ||= "backup"
docker_sock ||= "/var/run/docker.sock"

if File.exists?("/.dockerinit") && !File.exists?("/usr/bin/docker")
  system("cp", "/.dockerinit", "/usr/bin/docker")
end

if containers.empty?
  cids = `docker ps -a -q`
  containers = cids.split
end

volumes = ''
containers.each do |container|
  volumes << `docker inspect --format '{{ $name := .Name }}{{ range $volPath, $hostPath := .Volumes }}-v {{ $hostPath }}:/volData{{$name}}{{ $volPath }} {{ end }}' #{container}`
end

ssh_key = open(ssh_key_path).read
hostname = `hostname`
system("/usr/bin/docker", "-H", sock, "run", "--name", "_tmp_#{hostname}_ssh_key", "-v", "/tmp", "--entrypoint", "/bin/bash", "debian:jessie", "-c \"echo #{ssh_key} >> /tmp/id_rsa && chmod 600 /tmp/id_rsa")


rsync_opts = "-e ssh -i /tmp/id_rsa -p #{ssh_port} -rzop --partial /volData #{rsync_user}@#{rsync_host}:#{remote_path} "
if rsync_extra_opts.any?
  rsync_opts << rsync_extra_opts.join(" ")
end


system("/usr/bin/docker", "-H", sock, "run", "--volumes-from", "_tmp_#{hostname}_ssh_key", "--rm", "-v", volumes.chomp, "cpuguy83/rsync", *rsnyc_opts.split)
system("/usr/bin/docker", "-H", sock, "rm", "_tmp_#{hostname}_ssh_key")
