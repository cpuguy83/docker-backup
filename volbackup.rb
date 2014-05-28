#!/usr/bin/env ruby
require 'open-uri'
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
  on 's', 'sock', 'Location of Docker socket', default: '/var/run/docker.sock'
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
image = `docker -H #{sock} inspect --format '{{ .Config.Image }}' #{hostname}`.chomp
backup_path = "#{ENV["RUBY_PATH"]}/bin/backup"

exec('/usr/bin/docker', '-H', sock, 'run', '--volumes-from',  hostname, '--rm', *(volumes.map{|v| v.to_cli_arg}.flatten), '-e', "MAIL_PASS=#{ENV['MAIL_PASS']}", '--entrypoint', backup_path, image, 'perform', '--root-path', '/Backup/', '-t', 'volumes')

