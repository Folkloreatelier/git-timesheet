#!/usr/bin/env ruby

# Avoid encoding error in Ruby 1.9 when system locale does not match Git encoding
# Binary encoding should probably work regardless of the underlying locale
Encoding.default_external='binary' if defined?(Encoding)

require 'optparse'
require 'time'

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: git-timesheet [options]"

  opts.on("-s", "--since [TIME]", "Start date for the report (default is 1 week ago)") do |time|
    options[:since] = time
  end
  
  opts.on("-a", "--author [EMAIL]", "User for the report (default is the author set in git config)") do |author|
    options[:author] = author.split(',')
  end
  
  opts.on("-r", "--repository [DIRECTORY]", "The directory of the repository") do |repository|
    options[:repository] = repository.split(',')
  end

  opts.on(nil, '--authors', 'List all available authors') do |authors|
    options[:authors] = authors
  end
end.parse!

options[:since] ||= '1 week ago'
options[:repository] ||= Dir.pwd.split(',')

if options[:authors]
  authors = options[:repository].inject([]) {|authors, repository|
      current_authors = Dir.chdir(repository) {
        `git log --no-merges --simplify-merges --format="%an (%ae)" --since="#{options[:since].gsub('"','\\"')}"`.strip.split("\n").uniq
      }
      authors.concat(current_authors)
      authors
  }
  puts authors.uniq.join("\n")
else
  options[:author] ||= nil
  authors = options[:author] ? options[:author].collect{ |author| "--author=" + author.gsub('"','\\"') }:[]
  log_lines = options[:repository].inject([]) {|log_lines, repository|
      lines = Dir.chdir(repository) {
        `git log --no-merges --simplify-merges #{authors.join(' ')} --format="%ad %s <%h>" --date=iso --since="#{options[:since].gsub('"','\\"')}"`.split("\n")
      }
      log_lines.concat(lines)
      log_lines
  }
  month_entries = log_lines.inject({}) {|months, line|
    timestamp = Time.parse line.slice!(0,25)
    day = timestamp.strftime("%Y-%m-%d")
    month = timestamp.strftime("%Y-%m")
    months[month] ||= []
    months[month].push(day) unless months[month].include?(day)
    months
  }.sort{|a,b| a[0]<=>b[0]}
  puts month_entries.map{|month, entries| "#{month} - #{entries.length} day(s)\n#{'='*10}\n\n#{entries.sort.join("\n")}\n\n"}

#  day_entries = log_lines.inject({}) {|days, line|
#    timestamp = Time.parse line.slice!(0,25)
#    day = timestamp.strftime("%Y-%m-%d")
#    days[day] ||= []
#    days[day] << timestamp.strftime("%H:%M ") + line.strip
#    days
#  }.sort{|a,b| a[0]<=>b[0]}
#  puts day_entries.map{|day, entries| "#{day}\n#{'='*10}\n\n#{entries.sort.join("\n")}\n\n"}
end
