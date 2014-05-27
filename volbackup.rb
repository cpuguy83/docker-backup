#!/usr/bin/env ruby
require 'open-uri'
begin
  gem 'slop'
rescue Gem::LoadError
  `gem install slop`
end
require 'slop'


class Volume
  attr_reader :host_path, :container_path
  def initialize(host, container)
    @host_path = host
    @container_path = container
  end

  def ==(other)
    host_path == other.host_path
  end

  def hash
    [host_path, Volume].hash
  end

  alias_method :eql?, :==

  def to_s
    "#{host_path}:#{container_path}"
  end

  def to_cli_arg
    ['-v', to_s]
  end
end

opts = Slop.parse(arguments: true) do
  banner "volbackup.rb [options]"

  on 'c', 'containers', 'Comma-sepparated list(no spaces) of Name/ID of Containers to backup volumes for', as: Array, default: []
  on 'h', 'host', 'Remote host to sync backups to, format: <user@>host<:port>', required: true
  on 'u', 'user', 'RSync/SSH user', default: 'backup'
  on 'k', 'key', 'RSync/SSH key path', default: '/Backup/.ssh/id_rsa'
  on 'p', 'port', 'RSync/SSH port', default: 22
  on 's', 'sock', 'Location of Docker socket', default: '/var/run/docker.sock'
  on 'r', 'remote_path', 'Path to store data on remote server', default: '~/backups/'
  on 'b', 'bwlimit', 'Throttle bandwidth, KBPS', default: 0
end

sock = if opts[:sock] =~ /^\//
         "unix://#{opts[:sock]}"
       else
         opts[:sock]
       end


if File.exists?("/.dockerinit") && !File.exists?("/usr/bin/docker")
  system("cp", "/.dockerinit", "/usr/bin/docker")
end

if opts[:containers].empty?
  cids = `docker -H #{sock} ps -a -q`
  containers = cids.split
else
  containers = opts[:containers]
end

volumes = containers.inject([]) { |result, container|
  vols = `docker -H #{sock} inspect --format '{{ $name := .Name }}{{ range $volPath, $hostPath := .Volumes }}{{ $hostPath }}:/volData{{$name}}{{ $volPath }} {{ end }}' #{container}`.chomp.split(' ')
  result + vols.map{|v| v.split(':')}.map{|v| Volume.new(v[0], v[1])}
}.uniq


hostname = `hostname`.chomp

begin
system("/usr/bin/docker", "-H", sock, "run", "--name", "_tmp_#{hostname}_ssh_key", "-v", "/tmp", "--entrypoint", "/bin/sh", "debian:jessie", "-c", "echo -e '#{ssh_key}' >> /tmp/id_rsa && chmod 600 /tmp/id_rsa")
raise "Could not create SSH key container" unless $?.success?

rsync_opts = "-e ssh -i /tmp/id_rsa -p #{opts[:port]} -rzop --partial --bwlimit=#{opts[:bwlimit]} --perms /volData #{opts[:user]}@#{opts[:host]}:#{opts[:remote_path]} "

system("/usr/bin/docker", "-H", sock, "run", "--volumes-from", "_tmp_#{hostname}_ssh_key", "--rm", *volumes.map{|v| v.to_cli_arg}.flatten, "cpuguy83/rsync", *rsync_opts.split)
raise "Could not run rsync container" unless $?.success?
ensure
  system("/usr/bin/docker", "-H", sock, "rm", "_tmp_#{hostname}_ssh_key")
end
