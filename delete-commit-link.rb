require 'uri'

repo = ARGV[0]
old_msg = $stdin.read

if repo.nil?
  $stderr.puts "Usage: ruby #{File.basename(__FILE__)} <org>/<repo>"
  exit 1
end

def delete_commit_url(text, repo)
  commit_link_path_regrex = %r(/#{repo}/commit/)

  URI.extract(text, ['http', 'https']).uniq.sort_by { |uri| uri.length }.reverse.each do |str_uri|
    uri = URI.parse(str_uri)
    if uri.host =~ /^([^.]+\.)*github\.com$/ && uri.path =~ commit_link_path_regrex
      text.gsub! str_uri, ''
    end
  end
  text
end

new_msg = delete_commit_url(old_msg, repo)

print new_msg
