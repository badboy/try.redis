# encoding: utf-8

require_relative 'helper'

class TestRedisCommands < Minitest::Test
  def setup
    port = ENV['REDIS_PORT'] || 6379
    host = ENV['REDIS_HOST'] || 'localhost'
    @r = Redic.new "redis://#{host}:#{port}"
  end

  def extract command, *args
    ALL_COMMANDS[command].extract_keys(args)
  end

  def test_key_extraction_for_basic_commands
    assert_equal ["key"], extract('set', 'key', 'val')
    assert_equal ["key"], extract('get', 'key')
    assert_equal [], extract('get')
    assert_equal ["key"], extract('set', 'key', 'val', 'foo')
  end

  def test_key_extraction_for_zunion
    assert_equal ['out', 'zset1'],
      extract('zunionstore', 'out', '1', 'zset1', 'zset2', 'weights', '2', '3')

    assert_equal ['out', 'zset1', 'zset2'],
      extract('zunionstore', 'out', '2', 'zset1', 'zset2', 'weights', '2', '3')

    assert_equal ['out', 'zset1'],
      extract('zinterstore', 'out', '1', 'zset1', 'zset2', 'weights', '2', '3')

    assert_equal ['out', 'zset1', 'zset2'],
      extract('zinterstore', 'out', '2', 'zset1', 'zset2', 'weights', '2', '3')
  end

  def test_key_extraction_for_sort
    assert_equal ['key'], extract('sort', 'key', 'alpha')

    assert_equal ['abc', 'def'], extract('sort', 'abc', 'store', 'def')
    assert_equal ['abc', 'def'],
      extract('sort', 'abc', 'store', 'invalid',
              'store', 'stillbad', 'store', 'def')
  end

  def assert_server_equal_local *args
    command = args.first
    server_rsp = @r.call :command, :getkeys, *args
    local_rsp  = extract *args

    assert_equal server_rsp, local_rsp, "Mismatch with server for: #{args*' '}"
  end

  # Just to be sure we notice all changes made to Redis server
  def test_check_key_extraction_against_server
    target_version "2.8.13" do
      assert_server_equal_local 'sort', 'abc', 'store', 'invalid',
              'store', 'stillbad', 'store', 'def'

      assert_server_equal_local 'zunionstore', 'out', '1', 'zset1', 'zset2',
        'weights', '2', '3'

      assert_server_equal_local 'zunionstore', 'out', '2', 'zset1', 'zset2',
        'weights', '2', '3'

      assert_server_equal_local 'zinterstore', 'out', '1', 'zset1', 'zset2',
        'weights', '2', '3'

      assert_server_equal_local 'zinterstore', 'out', '2', 'zset1', 'zset2',
        'weights', '2', '3'

      assert_server_equal_local 'set', 'key', 'val'
      assert_server_equal_local 'get', 'key'
      assert_server_equal_local 'get'
      assert_server_equal_local 'set', 'key', 'val', 'foo'
    end
  end
end
