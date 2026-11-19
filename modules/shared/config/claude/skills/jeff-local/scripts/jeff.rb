#!/usr/bin/env ruby
# frozen_string_literal: true

# Local Jeff (github.com/firelex/jeff): setup | start [adapter ...] | stop | status | decide [request.json]

if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('3.4')
  abort("jeff-local needs Ruby >= 3.4, got #{RUBY_VERSION} (#{RbConfig.ruby}). Add a global ruby to the mise config in ~/nix-config/modules/shared/files.nix, rebuild, then mise install")
end

require 'fileutils'
require 'json'
require 'net/http'
require 'yaml'

REPO = File.expand_path(ENV.fetch('JEFF_HOME', '~/Projects/jeff'))
STATE = File.expand_path('~/.cache/jeff')
SOCKET = File.join(STATE, 'engine.sock') # AF_UNIX paths max out at 104 bytes on macOS
PORT = Integer(ENV.fetch('JEFF_PORT', '8765'))
BASE = "http://127.0.0.1:#{PORT}"
USAGE = 'usage: jeff.rb setup | start [adapter ...] | stop | status | decide [request.json]'

def pid_file(name)
  File.join(STATE, "#{name}.pid")
end

def log_file(name)
  File.join(STATE, "#{name}.log")
end

def alive(name)
  pid = File.read(pid_file(name)).to_i
  Process.kill(0, pid)
  pid
rescue Errno::ENOENT, Errno::ESRCH
  nil
end

def serving?
  Net::HTTP.get_response(URI("#{BASE}/v1/models")).code == '200'
rescue SystemCallError
  false
end

def wait_for(name, timeout)
  deadline = Time.now + timeout
  until yield
    abort(File.read(log_file(name)).lines.last(20).join) unless alive(name)
    abort("#{name} not ready after #{timeout}s, see #{log_file(name)}") if Time.now > deadline
    sleep 1
  end
end

def spawn_daemon(name, cmd, env = {})
  pid = Process.spawn(env, *cmd, chdir: REPO, pgroup: true, in: File::NULL, %i(out err) => [log_file(name), 'w'])
  Process.detach(pid)
  File.write(pid_file(name), pid)
end

def latest_base
  versions = YAML.safe_load_file(File.join(REPO, 'catalogue/bases.yaml')).fetch('jeff-base').keys
  "jeff-base@#{versions.max_by { Gem::Version.new(it.delete_prefix('v')) }}"
end

def setup
  if Dir.exist?(REPO)
    system('git', '-C', REPO, 'pull', '--ff-only', exception: true)
  else
    system('git', 'clone', 'https://github.com/firelex/jeff', REPO, exception: true)
  end
  system('uv', 'sync', chdir: REPO, exception: true)
end

def start(adapters)
  abort("#{REPO} has no .venv, run: jeff-local setup") unless Dir.exist?(File.join(REPO, '.venv'))
  return puts("already running on #{BASE}") if alive('engine') && alive('server')

  stop
  FileUtils.mkdir_p(STATE)
  engine = %W(
    uv run python -m jeff.cli runtime serve --socket #{SOCKET} --backend mlx
    --batch-window-ms 1 --max-batch-rows 8 --queue-limit-rows 256 --prepare-workers 2
  )
  engine += adapters.empty? ? ['--base-version', latest_base] : adapters.flat_map { ['--adapter', it] }
  spawn_daemon('engine', engine)
  # The first start downloads the base model (~1.7 GB)
  wait_for('engine', 900) { File.socket?(SOCKET) }

  spawn_daemon(
    'server',
    %W(uv run jeff-server serve --host 127.0.0.1 --port #{PORT} --workers 1),
    { 'JEFF_ENGINE_SOCKETS' => SOCKET, 'JEFF_MODEL_NAME' => 'jeff-local' },
  )
  wait_for('server', 60) { serving? }
  puts "running on #{BASE}/v1/systemone"
end

def stop
  %w(server engine).each do |name|
    pid = alive(name) or next
    terminate(pid)
  ensure
    FileUtils.rm_f(pid_file(name))
  end
  FileUtils.rm_f(SOCKET)
end

def terminate(pgid)
  Process.kill('TERM', -pgid)
  deadline = Time.now + 15
  sleep 0.2 while group_alive?(pgid) && Time.now < deadline
  Process.kill('KILL', -pgid) if group_alive?(pgid)
rescue Errno::ESRCH
  nil
end

def group_alive?(pgid)
  Process.kill(0, -pgid)
  true
rescue Errno::ESRCH
  false
end

def decide(path)
  request = JSON.parse(path ? File.read(path) : $stdin.read)
  abort('request needs "state" and "questions"') unless request['state'] && request['questions']
  abort('not running, run: jeff-local start') unless serving?

  request['model'] ||= 'jeff-latest'
  response = Net::HTTP.post(URI("#{BASE}/v1/systemone"), request.to_json, 'Content-Type' => 'application/json')
  abort("HTTP #{response.code}: #{response.body[0, 500]}") unless response.code == '200'
  body = JSON.parse(response.body)
  puts JSON.pretty_generate(body.fetch('answers').merge('_server_ms' => body.dig('timing', 'server_ms')))
end

case ARGV.shift
when 'setup' then setup
when 'start' then start(ARGV)
when 'stop' then stop.then { puts 'stopped' }
when 'status' then puts(serving? ? "running on #{BASE}" : 'stopped')
when 'decide' then decide(ARGV[0])
else abort(USAGE)
end
