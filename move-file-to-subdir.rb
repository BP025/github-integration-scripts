require 'uri'

subdir = ARGV[0]
git_ls_output = $stdin.read

if subdir.nil?
  $stderr.puts "Usage: ruby #{File.basename(__FILE__)} <subdir name>"
  exit 1
end

subdir += '/' unless subdir.end_with?('/')

git_ls_output.gsub! /\t/, "\t" + subdir

print git_ls_output
