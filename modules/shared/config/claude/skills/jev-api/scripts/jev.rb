#!/usr/bin/env ruby
# Jev (TypeSafe) request: {"state": {...}, "questions": {...}} as JSON file or stdin -> answers JSON on stdout.
# Key comes from TYPESAFE_API_KEY (~/.secrets-env).

require 'json'
require 'net/http'
require 'uri'

URL = URI('https://api.typesafe.ai/v1/systemone')
DEFAULT_MODEL = 'jev-1.13.0'

def load_key
  return ENV['TYPESAFE_API_KEY'] if ENV['TYPESAFE_API_KEY']

  path = File.expand_path('~/.secrets-env')
  line = File.readable?(path) && File.foreach(path).find { it =~ /\A\s*(?:export\s+)?TYPESAFE_API_KEY=/ }
  line ? line.split('=', 2).last.strip.delete_prefix('"').delete_suffix('"') : abort('TYPESAFE_API_KEY not set (expected in ~/.secrets-env)')
end

request = JSON.parse(ARGV[0] ? File.read(ARGV[0]) : $stdin.read)
abort('request needs "state" and "questions"') unless request['state'] && request['questions']
request['model'] ||= DEFAULT_MODEL

http_request = Net::HTTP::Post.new(URL, 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{load_key}")
http_request.body = request.to_json
response = Net::HTTP.start(URL.host, URL.port, use_ssl: true, read_timeout: 60) { it.request(http_request) }
abort("HTTP #{response.code}: #{response.body[0, 500]}") unless response.code == '200'

puts JSON.pretty_generate(JSON.parse(response.body).fetch('answers'))
