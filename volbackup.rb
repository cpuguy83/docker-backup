#!/usr/bin/env ruby
require 'open-uri'
require 'slop'
require 'excon'
require 'ostruct'
require 'json'


class Docker
  class Gateway
    attr_reader :conn
    def initialize(sock)
      @conn = build_conn(sock)
    end

    def get(path)
      JSON.parse(conn.get(path: path).body)
    end

    def post(path, body)
      if body
        JSON.parse(conn.post(path: path, body: body).body)
      else
        JSON.parse(conn.post(path: path).body)
      end
    end
  private
    def build_conn(sock)
      sock = if sock =~ /^\//
               "unix://#{sock}"
             else
               sock
             end
      proto = sock.split('://')[0]
      sock = sock.split('://')[1]

      conn = case proto
             when 'unix'
               Excon.new('unix:///', socket: sock)
             when 'tcp'
               Excon.new("http://#{sock}")
             else
               raise 'Unsupported socket protocol'
             end
      conn
    end

  end
  class Container < OpenStruct
    def to_json
      to_h.to_json
    end
  end

  class Volume
    attr_reader :host_path, :container_path
    def initialize(vol={})
      @container_path = vol.keys.first
      @host_path = vol.values.first
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

  attr_reader :conn
  def initialize(sock)
    @conn = Gateway.new(sock)
  end

  def fetch_all_containers
    conn.get('/containers/json?all=true').map{|c| Container.new sanitize_hash_keys(c)}
  end

  def fetch_container(id)
    Container.new sanitize_hash_keys(conn.get("/containers/#{id}/json"))
  end

  def create_container(container)
    conn.post('/containers/create', container.to_json)
  end

  def start_container(container)
    conn.post("/containers/#{container.id}/start", container.host_config.to_json)
  end

private
  def sanitize_hash_keys(hash)
    hash.inject({}) { |result, arr|
      result.merge(arr[0].downcase => arr[1])
    }
  end
end

opts = Slop.parse(arguments: true) do
  banner "volbackup.rb [options]"

  on 'c', 'containers', 'Comma-sepparated list(no spaces) of Name/ID of Containers to backup volumes for', as: Array, default: []
  on 's', 'sock', 'Location of Docker socket', default: '/var/run/docker.sock'
end

docker = Docker.new(opts[:sock])

if opts[:containers].empty?
  containers = docker.fetch_all_containers.map(&:id)
else
  containers = opts[:containers]
end

volumes = containers.map{|c|
  vol = docker.fetch_container(c).volumes
  Docker::Volume.new(vol) unless vol.keys.first == nil
}.uniq.compact

hostname = `hostname`.chomp
image = docker.fetch_container(hostname).image
backup_path = "#{ENV["RUBY_PATH"]}/bin/backup"

env = ENV.map {|key, value|
  unless ["HOSTNAME", "TERM", "PATH", "PWD", "SHLVL", "_", "LINES", "COLUMNS", "HOME"].include? key
    "#{key}=#{value}"
  end
}.compact

container = Docker::Container.new(
  Image: image,
  Entrypoint: [backup_path],
  Env: env,
  Cmd: [
    'perform',
    '--root-path',
    '/Backup/',
    '-t',
    'volumes'
  ],
)

cid = docker.create_container(container)["Id"]
container = docker.fetch_container(cid)
container.host_config = { Binds: volumes.map(&:to_s) }

docker.start_container(container)


# TODO: Convert to API instead of CLI
#exec('/usr/bin/docker', '-H', sock, 'run', '--volumes-from',  hostname, '--rm', *(volumes.map{|v| v.to_cli_arg}.flatten), *env.flatten, '--entrypoint', backup_path, image, 'perform', '--root-path', '/Backup/', '-t', 'volumes')
#
