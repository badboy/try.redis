#!/usr/bin/env ruby
# encoding: utf-8

# These are nearly 1:1 translations from the original Redis source
COMMANDS_WITH_KEY_PROC = {
  "zunionstore" => proc{|*args|
    argc = args.size
    num = args[1].to_i
    return [] if num > (argc-2)

    keys = [0]
    0.upto(num-1) { |i|
      keys << 2+i
    }
    keys
  },
  "sort" => proc{|*args|
    num = 1
    argc = args.size
    keys = [0]
    skiplist = [["limit", 2], ["get", 1], ["by", 1]]
    i = 1
    while i < argc
      skiplist.each do |name, skip|
        if args[i] == name
          i += skip
          break
        elsif args[i] == "store" && i+1 < argc
          keys[num] = i+1
          break
        end
      end
      i += 1
    end
    keys
  },
}
COMMANDS_WITH_KEY_PROC["zunioninter"] = COMMANDS_WITH_KEY_PROC["zunionstore"]

BLOCKED_COMMANDS = [
  "brpoplpush", "pfselftest", "subscribe", "migrate", "psync", "latency",
  "bgsave", "shutdown", "readwrite", "monitor", "randomkey", "replconf",
  "blpop", "slaveof", "punsubscribe", "pfdebug", "dbsize", "lastsave", "hkeys",
  "restore", "psubscribe", "wait", "config", "asking", "client", "brpop",
  "slowlog", "restore-asking", "save", "sync", "command", "script", "flushall",
  "select", "bgrewriteaof", "cluster", "debug", "flushdb", "dump", "move",
  "readonly", "evalsha", "unsubscribe", "eval", "pubsub", "object", "publish",
]

# name     - Command name to call
# arity    - Arity of the command, negative means >= |N|
# flags    - Flags for this command
# firstkey - first argument that is a key
# lastkey  - last argument that is a key
# key_step - step to get all the keys from first to last argument
Command = Struct.new(:name, :arity, :flags, :firstkey, :lastkey, :keystep) do
  def has_keys_proc?
    COMMANDS_WITH_KEY_PROC.keys.include? self.name
  end

  def keys_proc *args
    if (p=COMMANDS_WITH_KEY_PROC[self.name])
      p.call *args
    end
  end

  def get_key_positions args
    if self.has_keys_proc?
      self.keys_proc *args
    else
      return [] if self.firstkey == 0

      last = self.lastkey
      last = args.size+(last+1) if last < 0
      keys = []
      self.firstkey.step(last, self.keystep) do |i|
        keys << i-1
      end

      keys
    end
  end

  def extract_keys args, pos=nil
    pos ||= get_key_positions args
    pos.map {|p| args[p] }
  end

  def check_arity *args
    return false if self.arity > 0 && self.arity != args.size+1
    return false if args.size+1 < -self.arity
    return true
  end
end

# END COMMAND PARSER

require 'redic'
require_relative '../lib/shell_escape'
include ShellEscape

def namespace_command cmd, namespace
  cmd, *args = cli_split cmd
  if cmd
    keys = ALL_COMMANDS[cmd.downcase].get_key_positions args
    keys.each { |i| args[i] and args[i] = "#{namespace}#{args[i]}" }
    [cmd, *args]
  else
    []
  end
end

ALL_COMMANDS = {}

def parse cmd
  r = Redic.new
  info = r.call :command, "info", cmd
  Command.new *info[0]
end

def test keys, cmd, *args
  c = parse(cmd)
  tt = c.get_key_positions(args)

  print [cmd, *args]
  print " "
  print tt.inspect
  print " "
  k = c.extract_keys(args, tt)
  p k
  if keys != k
    puts "==> ERROR! keys mismatch for: #{cmd} #{args*' '}"
  end
end

def run_test
  test ["dest", "foo", "bar"], "zunionstore", "dest", "2", "foo", "bar"
  test ["mylist"],             "sort", "mylist", "alpha"
  test ["mylist", "dest"],     "sort", "mylist", "alpha", "store", "dest"
end

def run_dump
  f = File.open(__FILE__)
  f.each do |line|
    if line =~ /^# END COMMAND PARSE/
      break
    end
    puts line
  end
  f.close

  puts "ALL_COMMANDS = {"
  r = Redic.new
  r.call(:command).each{|v|
    unless BLOCKED_COMMANDS.include?(v.first)
      puts "  '%s' => Command.new(%s)," % [v.first, v.inspect.gsub(/^\[|\]$/,'')]
    end
  }
  puts "}"
  exit
end

def run_blocked
  r = Redic.new
  cmds = r.call(:command).map{|v|
    Command.new *v
  }

  s = cmds.size
  cmds.each_with_index do |c, ind|
    print "[%03d/%d] " % [ind+1, s]

    print "#{c.name} ? "
    if BLOCKED_COMMANDS.include?(c.name)
      puts "\n→ Already blocked"
      next
    end

    if $stdin.gets.chomp == "y"
      puts "→ Blocked"
      BLOCKED_COMMANDS << c.name
    end
  end
rescue NoMethodError, Interrupt
ensure
  puts
  p BLOCKED_COMMANDS
end

def namespaced_command cmd
  cmd, *args = cli_split cmd
  c = parse cmd
  keys = get_keys_from_command c, args
  keys.each { |i| args[i] = "ns:#{args[i]}" }
  [cmd, *args].inspect
end

def run_namespace
  r = Redic.new
  cmds = r.call(:command).map{|v|
    unless BLOCKED_COMMANDS.include?(v.first)
      ALL_COMMANDS[v.first] = Command.new(*v)
    end
  }

  cmd = ARGV[1..-1].join ' '
  puts namespace_command(cmd, 'ns:').inspect
end

ARGS = {
  'ns'     => :run_namespace,
  'blocked'=> :run_blocked,
  'dump'   => :run_dump,
  'test'   => :run_test,
  'help'   => :run_help,
}

def run_help
  puts <<-EOF
usage: #{File.basename $0} [subcommand]

Available subcommands:

  EOF
  ARGS.keys.each { |k| puts "  #{k}" }
  puts
end

if $0 == __FILE__
  if (met = ARGS[ARGV.fetch(0, '').downcase])
    send met
  else
    puts "Unknown sub command: '#{met}'"
    run_help
  end
end
