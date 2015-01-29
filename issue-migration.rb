require 'rubygems'
require 'bundler/setup'

require 'slop'
require 'octokit'
require 'faraday-http-cache'
require 'active_support/all'

opts = Slop.parse(help: true) do |o|
  o.string '-u', '--user', 'GitHubアカウントID'
  o.string '-p', '--password', 'GitHubアカウントパスワード'
  o.string '-l', '--label', '移行したIssueに付与するlabel'
  o.bool '-v', '--verbose', '詳細出力モード'
end

def error_exit_if_empty(value, error_message)
  unless value
    STDERR.puts error_message
    STDERR.puts opts
    exit
  end
end

def use_http_cache
  # 一度の起動で同じリクエストは何度もしないと思われるが念のため
  stack = Faraday::RackBuilder.new do |builder|
    builder.use Faraday::HttpCache
    builder.use Octokit::Response::RaiseError
    builder.adapter Faraday.default_adapter
  end
  Octokit.middleware = stack
end

def print_ratelimit(client)
  ratelimit = client.ratelimit
  puts "Rate Limit: #{ratelimit.limit}"
  puts "Rate Limit Remaining: #{ratelimit.remaining}"
  puts "Rate Limit Resets At: #{ratelimit.resets_at}"
end

def print_milestone(milestone)
  puts "number: #{milestone.number}"
  puts "state: #{milestone.state}"
  puts "title: #{milestone.title}"
  puts "description: #{milestone.description}"
  puts "creator: #{milestone.creator.login}"
  puts "open_issues: #{milestone.open_issues}"
  puts "closed_issues: #{milestone.closed_issues}"
  puts "closed_at: #{milestone.closed_at}"
  puts "due_on: #{milestone.due_on}"
end

def print_issue(issue)
  puts "number: #{issue.number}"
  puts "state: #{issue.state}"
  puts "title: #{issue.title}"
  puts "user: #{issue.user.login}"
  puts "labels: #{issue.labels.map(&:name).join(',')}"
  puts "assignee: #{issue.assignee.try(:login)}"
  puts "milestone: #{issue.milestone.try(:number)}"
  puts "comments: #{issue.comments}"
  puts "pull_request: #{issue.pull_request.try(:html_url)}"
  puts "closed_at: #{issue.closed_at}"
end

def print_comment(comment)
  puts "\tbody: #{comment.body}"
  puts "\tuser: #{comment.user.login}"
  puts "\tcreated_at: #{comment.created_at}"
end

class Sawyer::Resource
  def open?
    respond_to?(:state) && state == "open"
  end

  def closed?
    respond_to?(:state) && state == "closed"
  end

  def pull_request?
    respond_to?(:pull_request) && pull_request.present?
  end
end

def generate_random_color
  rand(0x1000000).to_s(16).rjust(6, "0")
end

def copy_milestone(client, dst_repo_name, src_milestone)
  creator_memo = "_@#{src_milestone.creator.login} さんが #{src_milestone.created_at.getlocal} に作成。_\n\n"
  options = {}
  options[:state] = src_milestone.state
  options[:description] = creator_memo + src_milestone.description
  options[:due_on] = src_milestone.due_on
  created_milestone = client.create_milestone(dst_repo_name, src_milestone.title, options)
  sleep 0.5
  created_milestone
end

def internal_link?(uri, repo)
  uri.host =~ /^([^.]+\.)*github\.com$/ && uri.path =~ %r(^/#{repo}/)
end

def replace_links(text, src_repo_name, dst_repo_name, issue_num_offset)
  # Issueシンボル e.g. #1
  text.gsub!(/(?<=#)([0-9]+)/) do
    issue_num_offset + $1.to_i
  end

  # 内部リンクを抽出
  links = URI.extract(text, ['http', 'https'])
      .uniq
      .map { |str_uri| [str_uri, URI.parse(str_uri)] }
      .select { |str, uri| internal_link?(uri, src_repo_name) }
      .sort_by { |str, uri| -str.length }

  # 内部リンク全般 e.g. https://github.com/BP025/A/wiki
  # リポジトリ名を置換
  links.each do |link|
    link[1].path.sub!(%r!^/#{src_repo_name}(/|$)!) { "/#{dst_repo_name}" + $1 }
    text.gsub!(link[0], link[1].to_s)
    link[0] = link[1].to_s
  end

  # Issueリンク e.g. https://github.com/BP025/A/issues/1
  # 一つの文字列に置換を繰り返すため、数字の大きいものから処理する
  issue_links = links.select { |str, uri| uri.path =~ %r|(?<=/issues/)([0-9]+)| }.sort_by do |str, uri|
    _, n = *%r|.*/issues/([0-9]+)|.match(uri.path)
    [-uri.path.length, -n.to_i]
  end
  issue_links.each do |str, uri|
    uri.path.gsub!(%r|(?<=/issues/)([0-9]+)|) do
      issue_num_offset + $1.to_i
    end

    text.gsub!(str, uri.to_s)
  end

  # コミットリンク e.g. https://github.com/BP025/B/commit/3ae6ab4df4edaa3eebb3537563c81d9cc5c43b7c
  commit_links = links.select { |str, uri| uri.path =~ %r|/commit/| }
  commit_links.each do |str, uri|
    text.gsub!(str, '')
  end

  text
end

def copy_issue_with_comments(client, src_repo_name, dst_repo_name, src_issue, comments, milestone_num_offset, issue_num_offset, label)
  raise "コメント数が一致しません。(issue.comments: #{src_issue.comments}, comments.length: #{comments.length})" unless src_issue.comments == comments.length

  return if src_issue.pull_request?

  if label.present?
    client.add_label(dst_repo_name, label, generate_random_color()) unless client.labels(dst_repo_name).map(&:name).include?(label)
    src_issue.labels << client.label(dst_repo_name, label)
    sleep 0.5
  end

  creator_memo = "_@#{src_issue.user.login} さんが #{src_issue.created_at.getlocal} に作成。_\n\n"
  options = {}
  options[:labels] = src_issue.labels.map(&:name).join(",") if src_issue.labels.present?
  options[:assignee] = src_issue.assignee.login if src_issue.assignee.present?
  options[:milestone] = milestone_num_offset + src_issue.milestone.number if src_issue.milestone.present?
  body = creator_memo + replace_links(src_issue.body, src_repo_name, dst_repo_name, issue_num_offset)
  created_issue = client.create_issue(dst_repo_name, src_issue.title, body, options)
  sleep 0.5
  comments.each do |comment|
    created_issue = client.close_issue(dst_repo_name, created_issue.number) if src_issue.closed? && src_issue.closed_at < comment.created_at
    sleep 0.5

    creator_memo = "_@#{comment.user.login} さんが #{comment.created_at.getlocal} にコメント。_\n\n"
    body = creator_memo + replace_links(comment.body, src_repo_name, dst_repo_name, issue_num_offset)
    client.add_comment(dst_repo_name, created_issue.number, body)
    sleep 0.5
  end

  if src_issue.closed? && created_issue.open?
    created_issue = client.close_issue(dst_repo_name, created_issue.number)
  else
    created_issue = client.issue(dst_repo_name, created_issue.number)
  end

  created_issue
end

src_repo_name = opts.arguments[0]
error_exit_if_empty src_repo_name, '第1引数で移行元GitHubリポジトリを foo/bar 形式で指定してください。'

dst_repo_name = opts.arguments[1]
error_exit_if_empty dst_repo_name, '第2引数で移行先GitHubリポジトリを foo/bar 形式で指定してください。'

user_id = opts[:user]
error_exit_if_empty user_id, 'GitHubにログインするアカウントIDを指定してください。'

password = opts[:password]
error_exit_if_empty password, 'GitHubにログインするアカウントパスワードを指定してください。'

label = opts[:label]

use_http_cache()


client = Octokit::Client.new(login: user_id, password: password)
client.user.login
client.auto_paginate = true

print_ratelimit(client)


milestones = client.milestones(src_repo_name, state: :all, sort: :created, direction: :asc)
milestones.sort_by!(&:number)

puts "総Milestone件数: #{milestones.length}"
if opts.verbose?
  puts "移行元Milestone"
  puts "-----------------------------------------"
  milestones.each do |milestone|
    print_milestone(milestone)
    puts "-----------------------------------------"
  end
end

milestone_num_offset = client.milestones(dst_repo_name, state: :all).length
created_milestones = milestones.map do |milestone|
  copy_milestone(client, dst_repo_name, milestone)
end


issues = client.issues(src_repo_name, state: :all, sort: :created, direction: :asc)
issues.sort_by!(&:number)

puts "総Issue件数: #{issues.length}"
if opts.verbose?
  puts "移行元Issue"
  puts "-----------------------------------------"
  issues.each do |issue|
    print_issue(issue)
    puts "-----------------------------------------"
  end
end

issue_num_offset = client.issues(dst_repo_name, state: :all).length
created_issues = issues.map do |issue|
  comments = client.issue_comments(src_repo_name, issue.number)
  if opts.verbose?
    puts "移行元Comment"
    puts "-----------------------------------------"
    comments.each do |comment|
      print_comment(comment)
      puts "-----------------------------------------"
    end
  end

  copy_issue_with_comments(client, src_repo_name, dst_repo_name, issue, comments, milestone_num_offset, issue_num_offset, label)
end
created_issues.compact!


if opts.verbose?
  puts "作成したMilestone"
  puts "-----------------------------------------"
  created_milestones.each do |milestone|
    print_milestone(milestone)
    puts "-----------------------------------------"
  end
end

if opts.verbose?
  puts "作成したIssue"
  puts "-----------------------------------------"
  created_issues.each do |issue|
    print_issue(issue)
    puts "-----------------------------------------"
  end
end

puts "作成したMilestone件数: #{created_milestones.length}"
puts "作成したIssue件数: #{created_issues.length}"
puts "作成したIssue番号: #{created_issues.first.number} - #{created_issues.last.number}" unless created_issues.empty?

print_ratelimit(client)

