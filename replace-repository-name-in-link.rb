require 'uri'

old_repo_name = ARGV[0]
new_repo_name = ARGV[1]
old_msg = $stdin.read

if old_repo_name.nil? || new_repo_name.nil?
  $stderr.puts "Usage: ruby #{File.basename(__FILE__)} <old_org>/<old_repo> <new_org>/<new_repo>"
  exit 1
end

def replace_repo_name_in_url(text, from, to)
  URI.extract(text, ['http', 'https']).uniq.sort_by { |uri| uri.length }.each do |str_uri|
    uri = URI.parse(str_uri)
    if uri.host =~ /^([^.]+\.)*github\.com$/
      uri.path.sub! from, to
      text.gsub! str_uri, uri.to_s
    end
  end
  text
end

new_msg = replace_repo_name_in_url(old_msg, old_repo_name, new_repo_name)

print new_msg
