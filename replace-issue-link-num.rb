
start_num = ARGV[0].to_i
repo = ARGV[1]
old_msg = $stdin.read

new_msg = old_msg.gsub(%r|(?<=/#{repo}/issues/)([0-9]+)|) do |old_num|
  start_num + $1.to_i
end

print new_msg
