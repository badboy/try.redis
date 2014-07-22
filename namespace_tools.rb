# encoding: utf-8

require_relative 'lib/shell_escape'
require_relative 'lib/redis_commands'

module NamespaceTools
   SYNTAX_ERROR = {error: "ERR Syntax error"}.freeze
   ARGUMENT_ERROR = -> cmd { {error: "ERR wrong number of arguments for '#{cmd}' command" } }

   SPECIAL_HANDLING = {
     'keys' => { error: "KEYS is an expensive command. It needs to go through the whole database. Its use is not recommended (and thus disabled in try.redis)." }
   }

  def parse_command namespace, cmd, *args
    cmd = cmd.downcase

    # Special error message for keys
    if (msg=SPECIAL_HANDLING[cmd])
      return msg
    end

    command = ALL_COMMANDS[cmd.downcase]
    return nil unless command

    unless command.check_arity *args
      return ARGUMENT_ERROR[cmd]
    end

    keys = command.get_key_positions args
    keys.each { |i| args[i] and args[i] = "#{namespace}:#{args[i]}" }

    args = special_case_scan(namespace, args) if cmd == "scan"

    [cmd, *args]
  end

  def special_case_scan namespace, args
    i = 0
    found = false
    while i < args.size
      if args[i].downcase == "match"
        found = true
        args[i+1] = "#{namespace}:#{args[i+1]}"
        i += 2
        next
      end
      i += 1
    end

    args << "match" << "#{namespace}:*" unless found
    args
  end

  # Transform redis response from ruby to redis-cli like format
  #
  # @param input [String] The value returned from redis-rb
  # @param cmd [String] The command sent to redis
  # @param arg [String] Additional argument (used only for 'info' command to specify section)
  #
  # @return [String] redis-cli like formatted string of the input data
  def to_redis_output input, cmd=nil, arg=nil
    if cmd == 'info'
      return info_output(input, arg)
    end

    if cmd == 'ping' && input == 'PONG'
      return 'PONG'
    end

    case input
    when nil
      '(nil)'
    when 'OK'
      'OK'
    when Integer
      "(integer) #{input}"
    when Array
      if input.empty?
        '(empty list or set)'
      else
        str = ""
        size = input.size.to_s.size
        input.each_with_index do |v, i|
          str << "#{(i+1).to_s.rjust(size)}) #{to_redis_output v}\n"
        end
        str
      end
    when String, Numeric
      input.inspect
    else
      input
    end
  end

  def info_output input, section=nil
    return input.tr("\r", '')
  end

  class ThrottledCommand < Exception; end
  THROTTLED_COMMANDS = %w[ setbit setrange ]
  THROTTLE_MAX_OFFSET = 8_000_000 # 1 MB = 8000000 bits
  def throttle_commands argv
    if THROTTLED_COMMANDS.include?(argv[0]) && argv[2].to_i > THROTTLE_MAX_OFFSET
      raise ThrottledCommand, "This would result in a too big value. try.redis is only for testing so keep it small."
    end

    nil
  end

  include ShellEscape
end
