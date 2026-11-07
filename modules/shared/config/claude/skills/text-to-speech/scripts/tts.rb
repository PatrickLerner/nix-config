#!/usr/bin/env ruby
# Azure Speech TTS: text/markdown file -> one mp3 next to the input.
# Key and region come from AZURE_SPEECH_KEY / AZURE_SPEECH_REGION (~/.secrets-env).

require 'cgi'
require 'net/http'
require 'uri'
require 'optparse'
require 'tmpdir'

opts = { voice: 'en-US-JessaNeural', words: 1200, out: nil }
OptionParser.new do |o|
  o.banner = 'Usage: tts.rb [--voice NAME] [--out FILE.mp3] [--words N] INPUT'
  o.on('--voice NAME') { |v| opts[:voice] = v }
  o.on('--out FILE') { |v| opts[:out] = v }
  o.on('--words N', Integer, 'max words per request (Azure caps one request at 10 min audio)') { |v| opts[:words] = v }
end.parse!

input = ARGV[0]
abort('Usage: tts.rb [--voice NAME] [--out FILE.mp3] INPUT') unless input && File.exist?(input)

def load_secrets_env
  path = File.expand_path('~/.secrets-env')
  return unless File.readable?(path)

  File.foreach(path) do |line|
    next unless line =~ /\A\s*(?:export\s+)?(AZURE_SPEECH_[A-Z_]+)=(.*)\z/

    ENV[Regexp.last_match(1)] ||= Regexp.last_match(2).strip.delete_prefix('"').delete_suffix('"')
  end
end

load_secrets_env
key = ENV['AZURE_SPEECH_KEY'] or abort('AZURE_SPEECH_KEY not set (expected in ~/.secrets-env)')
region = ENV.fetch('AZURE_SPEECH_REGION', 'eastus')
lang = opts[:voice][/\A[a-z]{2}-[A-Z]{2}/] || 'en-US'
out = opts[:out] || input.sub(/\.(txt|md)\z/, '') + '.mp3'

text = File.read(input, encoding: 'utf-8')
text = text.sub(/\A---\n.*?\n---\n/m, '')            # frontmatter
           .gsub(/!\[\[[^\]]*\]\]/, '')               # obsidian embeds
           .gsub(/\[\[(?:[^\]|]*\|)?([^\]]*)\]\]/, '\1') # wikilinks -> label
           .gsub(/^#+\s*/, '')
           .gsub(/[*_`]/, '')

# Split on paragraph, then sentence boundaries so no chunk cuts mid-sentence.
units = text.split(/\n\s*\n/).map(&:strip).reject(&:empty?).flat_map do |para|
  para.split(/\s+/).size <= opts[:words] ? [para] : para.split(/(?<=[.!?])\s+/)
end
chunks = units.each_with_object([+'']) do |u, acc|
  if !acc.last.empty? && (acc.last.split(/\s+/).size + u.split(/\s+/).size) > opts[:words]
    acc << u.dup
  else
    acc.last << (acc.last.empty? ? '' : "\n\n") << u
  end
end

def http_post(uri, headers, body)
  req = Net::HTTP::Post.new(uri)
  headers.each { |k, v| req[k] = v }
  req.body = body
  Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 300) { |h| h.request(req) }
end

token_res = http_post(URI("https://#{region}.api.cognitive.microsoft.com/sts/v1.0/issueToken"),
                      { 'Ocp-Apim-Subscription-Key' => key }, '')
abort("token: #{token_res.code} #{token_res.body}") unless token_res.code == '200'
token = token_res.body

Dir.mktmpdir do |dir|
  parts = chunks.each_with_index.map do |chunk, i|
    ssml = <<~SSML
      <speak version='1.0' xml:lang='#{lang}'><voice name='#{opts[:voice]}'>#{CGI.escapeHTML(chunk).gsub("\n\n", "<break time='600ms'/>")}</voice></speak>
    SSML
    part = File.join(dir, format('part%03d.mp3', i))
    attempts = 0
    begin
      attempts += 1
      res = http_post(URI("https://#{region}.tts.speech.microsoft.com/cognitiveservices/v1"),
                      { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/ssml+xml',
                        'X-Microsoft-OutputFormat' => 'audio-48khz-192kbitrate-mono-mp3',
                        'User-Agent' => 'tts-cli' }, ssml)
      raise "#{res.code} #{res.body}" unless res.code == '200'
    rescue StandardError => e
      if attempts < 4
        warn "part #{i + 1}: #{e.message.lines.first&.strip}, retrying"
        sleep 5 * attempts
        retry
      end
      abort("part #{i + 1} failed: #{e.message}")
    end
    File.binwrite(part, res.body)
    warn "#{i + 1}/#{chunks.size} done"
    part
  end

  list = File.join(dir, 'list.txt')
  File.write(list, parts.map { |p| "file '#{p}'" }.join("\n"))
  system('ffmpeg', '-loglevel', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', list, '-c', 'copy', out) or
    abort('ffmpeg concat failed')
end

puts out
