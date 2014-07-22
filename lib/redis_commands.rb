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
COMMANDS_WITH_KEY_PROC["zinterstore"] = COMMANDS_WITH_KEY_PROC["zunionstore"]

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
    pos.map {|p| args[p] }.compact
  end

  def check_arity *args
    return false if self.arity > 0 && self.arity != args.size+1
    return false if args.size+1 < -self.arity
    return true
  end
end

ALL_COMMANDS = {
  'type' => Command.new("type", 2, ["readonly", "fast"], 1, 1, 1),
  'zremrangebyscore' => Command.new("zremrangebyscore", 4, ["write"], 1, 1, 1),
  'substr' => Command.new("substr", 4, ["readonly"], 1, 1, 1),
  'zcount' => Command.new("zcount", 4, ["readonly", "fast"], 1, 1, 1),
  'incrby' => Command.new("incrby", 3, ["write", "denyoom", "fast"], 1, 1, 1),
  'zrange' => Command.new("zrange", -4, ["readonly"], 1, 1, 1),
  'hexists' => Command.new("hexists", 3, ["readonly", "fast"], 1, 1, 1),
  'hget' => Command.new("hget", 3, ["readonly", "fast"], 1, 1, 1),
  'ltrim' => Command.new("ltrim", 4, ["write"], 1, 1, 1),
  'rpushx' => Command.new("rpushx", 3, ["write", "denyoom", "fast"], 1, 1, 1),
  'setbit' => Command.new("setbit", 4, ["write", "denyoom"], 1, 1, 1),
  'zrevrangebyscore' => Command.new("zrevrangebyscore", -4, ["readonly"], 1, 1, 1),
  'lpush' => Command.new("lpush", -3, ["write", "denyoom", "fast"], 1, 1, 1),
  'zlexcount' => Command.new("zlexcount", 4, ["readonly", "fast"], 1, 1, 1),
  'rpoplpush' => Command.new("rpoplpush", 3, ["write", "denyoom"], 1, 2, 1),
  'zunionstore' => Command.new("zunionstore", -4, ["write", "denyoom", "movablekeys"], 0, 0, 0),
  'pexpireat' => Command.new("pexpireat", 3, ["write", "fast"], 1, 1, 1),
  'rpush' => Command.new("rpush", -3, ["write", "denyoom", "fast"], 1, 1, 1),
  'setnx' => Command.new("setnx", 3, ["write", "denyoom", "fast"], 1, 1, 1),
  'zrevrank' => Command.new("zrevrank", 3, ["readonly", "fast"], 1, 1, 1),
  'ttl' => Command.new("ttl", 2, ["readonly", "fast"], 1, 1, 1),
  'hset' => Command.new("hset", 4, ["write", "denyoom", "fast"], 1, 1, 1),
  'zrevrange' => Command.new("zrevrange", -4, ["readonly"], 1, 1, 1),
  'del' => Command.new("del", -2, ["write"], 1, -1, 1),
  'hmget' => Command.new("hmget", -3, ["readonly"], 1, 1, 1),
  'lset' => Command.new("lset", 4, ["write", "denyoom"], 1, 1, 1),
  'append' => Command.new("append", 3, ["write", "denyoom"], 1, 1, 1),
  'psetex' => Command.new("psetex", 4, ["write", "denyoom"], 1, 1, 1),
  'lpop' => Command.new("lpop", 2, ["write", "fast"], 1, 1, 1),
  'incrbyfloat' => Command.new("incrbyfloat", 3, ["write", "denyoom", "fast"], 1, 1, 1),
  'smembers' => Command.new("smembers", 2, ["readonly", "sort_for_script"], 1, 1, 1),
  'zrem' => Command.new("zrem", -3, ["write", "fast"], 1, 1, 1),
  'zrangebyscore' => Command.new("zrangebyscore", -4, ["readonly"], 1, 1, 1),
  'hmset' => Command.new("hmset", -4, ["write", "denyoom"], 1, 1, 1),
  'zadd' => Command.new("zadd", -4, ["write", "denyoom", "fast"], 1, 1, 1),
  'exec' => Command.new("exec", 1, ["noscript", "skip_monitor"], 0, 0, 0),
  'scan' => Command.new("scan", -2, ["readonly", "random"], 0, 0, 0),
  'zrank' => Command.new("zrank", 3, ["readonly", "fast"], 1, 1, 1),
  'zinterstore' => Command.new("zinterstore", -4, ["write", "denyoom", "movablekeys"], 0, 0, 0),
  'persist' => Command.new("persist", 2, ["write", "fast"], 1, 1, 1),
  'expire' => Command.new("expire", 3, ["write", "fast"], 1, 1, 1),
  'ping' => Command.new("ping", 1, ["readonly", "stale", "fast"], 0, 0, 0),
  'zremrangebylex' => Command.new("zremrangebylex", 4, ["write"], 1, 1, 1),
  'hincrby' => Command.new("hincrby", 4, ["write", "denyoom", "fast"], 1, 1, 1),
  'srandmember' => Command.new("srandmember", -2, ["readonly", "random"], 1, 1, 1),
  'role' => Command.new("role", 1, ["admin", "noscript", "loading", "stale"], 0, 0, 0),
  'zremrangebyrank' => Command.new("zremrangebyrank", 4, ["write"], 1, 1, 1),
  'lrange' => Command.new("lrange", 4, ["readonly"], 1, 1, 1),
  'sdiffstore' => Command.new("sdiffstore", -3, ["write", "denyoom"], 1, -1, 1),
  'hsetnx' => Command.new("hsetnx", 4, ["write", "denyoom", "fast"], 1, 1, 1),
  'keys' => Command.new("keys", 2, ["readonly", "sort_for_script"], 0, 0, 0),
  'hdel' => Command.new("hdel", -3, ["write", "fast"], 1, 1, 1),
  'decr' => Command.new("decr", 2, ["write", "denyoom", "fast"], 1, 1, 1),
  'echo' => Command.new("echo", 2, ["readonly", "fast"], 0, 0, 0),
  'zincrby' => Command.new("zincrby", 4, ["write", "denyoom", "fast"], 1, 1, 1),
  'hgetall' => Command.new("hgetall", 2, ["readonly"], 1, 1, 1),
  'lpushx' => Command.new("lpushx", 3, ["write", "denyoom", "fast"], 1, 1, 1),
  'pttl' => Command.new("pttl", 2, ["readonly", "fast"], 1, 1, 1),
  'hincrbyfloat' => Command.new("hincrbyfloat", 4, ["write", "denyoom", "fast"], 1, 1, 1),
  'sismember' => Command.new("sismember", 3, ["readonly", "fast"], 1, 1, 1),
  'hlen' => Command.new("hlen", 2, ["readonly", "fast"], 1, 1, 1),
  'sunionstore' => Command.new("sunionstore", -3, ["write", "denyoom"], 1, -1, 1),
  'zrangebylex' => Command.new("zrangebylex", -4, ["readonly"], 1, 1, 1),
  'info' => Command.new("info", -1, ["readonly", "loading", "stale"], 0, 0, 0),
  'lrem' => Command.new("lrem", 4, ["write"], 1, 1, 1),
  'sinter' => Command.new("sinter", -2, ["readonly", "sort_for_script"], 1, -1, 1),
  'sscan' => Command.new("sscan", -3, ["readonly", "random"], 1, 1, 1),
  'strlen' => Command.new("strlen", 2, ["readonly", "fast"], 1, 1, 1),
  'msetnx' => Command.new("msetnx", -3, ["write", "denyoom"], 1, -1, 2),
  'rpop' => Command.new("rpop", 2, ["write", "fast"], 1, 1, 1),
  'sinterstore' => Command.new("sinterstore", -3, ["write", "denyoom"], 1, -1, 1),
  'expireat' => Command.new("expireat", 3, ["write", "fast"], 1, 1, 1),
  'getrange' => Command.new("getrange", 4, ["readonly"], 1, 1, 1),
  'zcard' => Command.new("zcard", 2, ["readonly", "fast"], 1, 1, 1),
  'sadd' => Command.new("sadd", -3, ["write", "denyoom", "fast"], 1, 1, 1),
  'linsert' => Command.new("linsert", 5, ["write", "denyoom"], 1, 1, 1),
  'bitcount' => Command.new("bitcount", -2, ["readonly"], 1, 1, 1),
  'pfmerge' => Command.new("pfmerge", -2, ["write", "denyoom"], 1, -1, 1),
  'pfadd' => Command.new("pfadd", -2, ["write", "denyoom", "fast"], 1, 1, 1),
  'spop' => Command.new("spop", 2, ["write", "noscript", "random", "fast"], 1, 1, 1),
  'smove' => Command.new("smove", 4, ["write", "fast"], 1, 2, 1),
  'llen' => Command.new("llen", 2, ["readonly", "fast"], 1, 1, 1),
  'multi' => Command.new("multi", 1, ["readonly", "noscript", "fast"], 0, 0, 0),
  'sdiff' => Command.new("sdiff", -2, ["readonly", "sort_for_script"], 1, -1, 1),
  'getset' => Command.new("getset", 3, ["write", "denyoom"], 1, 1, 1),
  'hscan' => Command.new("hscan", -3, ["readonly", "random"], 1, 1, 1),
  'auth' => Command.new("auth", 2, ["readonly", "noscript", "loading", "stale", "fast"], 0, 0, 0),
  'rename' => Command.new("rename", 3, ["write"], 1, 2, 1),
  'decrby' => Command.new("decrby", 3, ["write", "denyoom", "fast"], 1, 1, 1),
  'discard' => Command.new("discard", 1, ["readonly", "noscript", "fast"], 0, 0, 0),
  'sunion' => Command.new("sunion", -2, ["readonly", "sort_for_script"], 1, -1, 1),
  'pexpire' => Command.new("pexpire", 3, ["write", "fast"], 1, 1, 1),
  'hvals' => Command.new("hvals", 2, ["readonly", "sort_for_script"], 1, 1, 1),
  'zscan' => Command.new("zscan", -3, ["readonly", "random"], 1, 1, 1),
  'get' => Command.new("get", 2, ["readonly", "fast"], 1, 1, 1),
  'exists' => Command.new("exists", 2, ["readonly", "fast"], 1, 1, 1),
  'lindex' => Command.new("lindex", 3, ["readonly"], 1, 1, 1),
  'sort' => Command.new("sort", -2, ["write", "denyoom", "movablekeys"], 1, 1, 1),
  'setex' => Command.new("setex", 4, ["write", "denyoom"], 1, 1, 1),
  'incr' => Command.new("incr", 2, ["write", "denyoom", "fast"], 1, 1, 1),
  'set' => Command.new("set", -3, ["write", "denyoom"], 1, 1, 1),
  'mget' => Command.new("mget", -2, ["readonly"], 1, -1, 1),
  'scard' => Command.new("scard", 2, ["readonly", "fast"], 1, 1, 1),
  'zscore' => Command.new("zscore", 3, ["readonly", "fast"], 1, 1, 1),
  'srem' => Command.new("srem", -3, ["write", "fast"], 1, 1, 1),
  'zrevrangebylex' => Command.new("zrevrangebylex", -4, ["readonly"], 1, 1, 1),
  'mset' => Command.new("mset", -3, ["write", "denyoom"], 1, -1, 2),
  'setrange' => Command.new("setrange", 4, ["write", "denyoom"], 1, 1, 1),
  'unwatch' => Command.new("unwatch", 1, ["readonly", "noscript", "fast"], 0, 0, 0),
  'renamenx' => Command.new("renamenx", 3, ["write", "fast"], 1, 2, 1),
  'getbit' => Command.new("getbit", 3, ["readonly", "fast"], 1, 1, 1),
  'time' => Command.new("time", 1, ["readonly", "random", "fast"], 0, 0, 0),
  'watch' => Command.new("watch", -2, ["readonly", "noscript", "fast"], 1, -1, 1),
  'bitop' => Command.new("bitop", -4, ["write", "denyoom"], 2, -1, 1),
  'pfcount' => Command.new("pfcount", -2, ["write"], 1, 1, 1),
  'bitpos' => Command.new("bitpos", -3, ["readonly"], 1, 1, 1),
}
