# encoding: utf-8

module NamespaceTools
  SYNTAX_ERROR = {error: "ERR Syntax error"}.freeze
  ARGUMENT_ERROR = -> cmd { {error: "ERR wrong number of arguments for '#{cmd}' command"} }

  ALLOWED_COMMANDS = %w[
    append bitcount bitop echo getbit getrange hmget hsetnx incrbyfloat
    hincrbyfloat decr decrby del discard exec linsert lpushx persist pexpire
    pexpireat ping pttl psetex rpushx setbit setex setrange strlen time zcount
    zrank zremrangebyrank zrevrangebyscore zrevrank exists expire expireat get
    getset hdel hexists hget hgetall hincrby hkeys hlen hmset hset hvals incr
    incrby info keys lindex llen lpop lpush lrange lrem lset ltrim mget mset
    msetnx multi rename renamenx rpop rpoplpush rpush sadd scard sdiff
    sdiffstore set setnx sinter sinterstore sismember smembers smove sort spop
    srandmember srem sunion sunionstore ttl type zadd zcard zincrby zrange
    zrangebyscore zrem zremrangebyscore zrevrange zscore
    scan
  ]

  # These are manually converted to integer output
  INTEGER_COMMANDS = %w[
    incr incrby decr decrby del ttl llen
    sadd zadd
    zremrangebyrank
    hincrby
    lpush rpush lpushx rpushx lrem
  ]

  # These commands return a nested array in ruby, need to be flattened
  FLATTEN_COMMANDS = %w[
    zrange zrevrange zrangebyscore zinterstore zunionstore
  ]

  def parse_command(ns, command, *args)
    command = command.to_s.downcase

    if ALLOWED_COMMANDS.include?(command)
      case command
      when "keys"
        if args.size != 1
          return ARGUMENT_ERROR[command]
        end
      when "strlen"
        # Manually namespace this, redis-rb does not know it.
        key = add_namespace(ns, args.shift)
        return [ command, key ]
      when "zadd", "sadd", "zrem", "srem"
        return [ command, args.shift, args ]
      when "sort"
        return ARGUMENT_ERROR[command] if args.empty?

        key    = args.shift
        params = {}

        while keyword = args.shift
          case keyword.downcase
          when "by", "get", "store"
            k = keyword.intern
            params[k] = args.shift
          when "limit"
            params[:limit] = [ args.shift.to_i, args.shift.to_i ]
          when "asc", "desc", "alpha"
            params[:order] ||= ""
            params[:order] << " "
            params[:order] << keyword
          end
        end

        return [ command, key, params ]
      when "scan"
        return ARGUMENT_ERROR[command] if args.empty?

        cursor, params = extract_scan_arguments(ns, args)

        return [ command, cursor, params ]
      when "hscan", "sscan", "zscan"
        return ARGUMENT_ERROR[command] if args.size < 2

        key = args.shift
        cursor, params = extract_scan_arguments(ns, args)

        return [ command, key, cursor, params ]
      when "zrange", "zrevrange"
        # Only the first argument is a key, but special argument at the end.

        head = args.first
        tail = args[1..-1] || []
        options = {}

        if tail.last && tail.last.downcase == "withscores"
          tail.pop
          options[:withscores] = true
        end

        return [ command, head, *tail, options ]
      when "zrangebyscore"
        # Only the first argument is a key, but special arguments at the end.

        head = args.shift

        tail = [args.shift, args.shift]
        options = {}
        while keyword = args.shift
          case keyword.downcase
          when "limit"
            options[:limit] = [ args.shift.to_i, args.shift.to_i ]
          when "withscores"
            options[:withscores] = true
          else
            return SYNTAX_ERROR
          end
        end

        return [ command, head, *tail, options ]
      end

      [command, *args]
    end
  end

  def extract_scan_arguments ns, args
    cursor = args.shift
    params = {}

    while keyword = args.shift
      case keyword.downcase
      when "match"
        params[:match] = "#{ns}:#{args.shift}"
      when "count"
        params[:count] = args.shift
      end
    end

    params[:match] ||= "#{ns}:*"

    [cursor, params]
  end

  def add_namespace(namespace, key)
    return key unless namespace

    case key
    when String then "#{namespace}:#{key}"
    when Array  then key.map {|k| add_namespace(namespace, k)}
    end
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

    case input
    when nil
      '(nil)'
    when 'OK'
      'OK'
    when true
      '(integer) 1'
    when false
      '(integer) 0'
    when Array
      if input.empty?
        "(empty list or set)"
      else
        str = ""
        size = input.size.to_s.size
        input.each_with_index do |v, i|
          str << "#{(i+1).to_s.rjust(size)}) #{to_redis_output v}\n"
        end
        str
      end
    when Hash
      if input.empty?
        "(empty list or set)"
      else
        str = ""
        size = input.size.to_s.size
        i = 0
        input.each do |(k, v)|
          str << "#{(i+1).to_s.rjust(size)}) #{to_redis_output k}\n"
          str << "#{(i+2).to_s.rjust(size)}) #{to_redis_output v}\n"
          i += 2
        end
        str
      end
    when String, Numeric
      "\"#{input}\""
    else
      input
    end
  end

  INFO_SECTIONS = [
    ["Server", [ "redis_version", "redis_git_sha1", "redis_git_dirty",
                 "redis_build_id", "redis_mode", "os", "arch_bits",
                 "multiplexing_api", "gcc_version", "process_id", "run_id",
                 "tcp_port", "uptime_in_seconds", "uptime_in_days", "hz",
                 "lru_clock" ]
    ],
    ["Clients", [ "connected_clients", "client_longest_output_list",
                  "client_biggest_input_buf", "blocked_clients" ] ],
    ["Memory", [ "used_memory", "used_memory_human", "used_memory_rss",
                 "used_memory_peak", "used_memory_peak_human",
                 "used_memory_lua", "mem_fragmentation_ratio", "mem_allocator"
               ]
    ],
    ["Persistence", [ "loading", "rdb_changes_since_last_save",
                      "rdb_bgsave_in_progress", "rdb_last_save_time",
                      "rdb_last_bgsave_status", "rdb_last_bgsave_time_sec",
                      "rdb_current_bgsave_time_sec", "aof_enabled",
                      "aof_rewrite_in_progress", "aof_rewrite_scheduled",
                      "aof_last_rewrite_time_sec",
                      "aof_current_rewrite_time_sec", "aof_last_bgrewrite_status"
                    ]
    ],
    ["Stats", [ "total_connections_received", "total_commands_processed",
                "instantaneous_ops_per_sec", "rejected_connections",
                "sync_full", "sync_partial_ok", "sync_partial_err",
                "expired_keys", "evicted_keys", "keyspace_hits",
                "keyspace_misses", "pubsub_channels", "pubsub_patterns",
                "latest_fork_usec", "migrate_cached_sockets" ]
    ],
    ["Replication", [ "role", "connected_slaves", "master_repl_offset",
                      "repl_backlog_active", "repl_backlog_size",
                      "repl_backlog_first_byte_offset", "repl_backlog_histlen"
                    ]
    ],
    ["CPU", [ "used_cpu_sys", "used_cpu_user", "used_cpu_sys_children",
              "used_cpu_user_children" ]
    ],
    ["Cluster", [ "cluster_enabled" ] ],
    ["Keyspace", ["db0"] ]
  ]
  def info_output input, section=nil
    msg = ""

    # Show only data for subsection
    if section
      section_data = INFO_SECTIONS.find{|k,_| k.downcase == section }
      if section_data
        msg << "# #{section_data[0]}\n"
        section_data[1].each do |opt|
          msg << "#{opt}:#{input[opt]}\n" if input[opt]
        end
        msg << "\n"
      else
        msg = "\n\n"
      end

      return msg.chomp
    end

    INFO_SECTIONS.each do |section|
      msg << "# #{section[0]}\n"
      section[1].each do |opt|
        msg << "#{opt}:#{input[opt]}\n" if input[opt]
      end
      msg << "\n"
    end
    msg.chomp
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


  # Taken from shellwords.rb (in ruby stdlib)
  # and modified to not remove escaping
  #
  # Example:
  #
  #   argv = shellsplit('set b\* foo')
  #   argv #=> ["set", "b\\*", "foo"]
  #
  def shellsplit(line)
    words = []
    field = ''
    line.scan(/\G\s*(?>([^\s\\\'\"]+)|'([^\']*)'|"((?:[^\"\\]|\\.)*)"|(\\\S?)|(\S))(\s|\z)?/m) do
      |word, sq, dq, esc, garbage, sep|
      raise ArgumentError, "Unmatched double quote: #{line.inspect}" if garbage
      field << (word || sq || (dq && dq.gsub(/\\(.)/, '\\1')) || esc)
      if sep
        words << field
        field = ''
      end
    end
    words
  end
end
