# encoding: utf-8

task :default => :test

REDIS_DIR = File.expand_path(File.join("..", "test"), __FILE__)
REDIS_CNF = File.join(REDIS_DIR, "test.conf")
REDIS_PID = File.join(REDIS_DIR, "db", "redis.pid")
REDIS_PORT = 6381

desc "Start the Redis server"
task :start do
  redis_running = \
    begin
      File.exists?(REDIS_PID) && Process.kill(0, File.read(REDIS_PID).to_i)
  rescue Errno::ESRCH
    FileUtils.rm REDIS_PID
    false
  end

  unless redis_running
    unless system("which redis-server")
      STDERR.puts "redis-server not in PATH"
      exit 1
    end

    unless system("redis-server #{REDIS_CNF}")
      STDERR.puts "could not start redis-server"
      exit 1
    end
  end

  ENV['REDIS_PORT'] = REDIS_PORT.to_s
end

desc "Stop the Redis server"
task :stop do
  if File.exists?(REDIS_PID)
    Process.kill "INT", File.read(REDIS_PID).to_i
    FileUtils.rm REDIS_PID
  end
end

require 'rake/testtask'
Rake::TestTask.new do |t|
  t.options = "-v"
  t.test_files = FileList["test/test_*.rb"]
end

GROUPED_HELP_FILE = "redis-doc/grouped_help.json"
COMMAND_LIST_FILE = "lib/redis_commands.rb"
HELP_FILE         = "~/code/redis/src/help.h"

namespace :generate do
  desc "Generate grouped help file"
  task :help do
    sh "./utils/parse_help_groups.rb #{HELP_FILE} | json > #{GROUPED_HELP_FILE}"
  end

  desc "Generate command list"
  task :command do
    sh "./utils/parse_commands.rb dump > #{COMMAND_LIST_FILE}"
  end

  desc "Generate all helper files"
  task :all => ['generate:help', 'generate:command']
end
