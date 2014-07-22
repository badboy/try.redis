# encoding: utf-8

require_relative 'helper'

class TestNamespaceTools < Minitest::Test
  def setup
    # Small hack to access parse_command
    NamespaceTools.__send__ :extend, NamespaceTools
  end

  # Pass 'ns' as namespace for all tests.
  def parse_command command, *args
    NamespaceTools::parse_command('ns', command, *args)
  end

  # Helper function.
  def parse_command_equal expected, to_send
    assert_equal expected, parse_command(*to_send)
  end

  def test_parse_command_unknown
    assert_equal nil, parse_command('foo', 'bar')
  end

  def test_parse_command_correct
    to_test = [
      [ ['set', 'ns:foo', 'bar'], ['set', 'foo', 'bar'] ],
      [ ['get', 'ns:foo'],        ['get', 'foo' ] ],
    ]

    to_test.each do |exp, cmd|
      parse_command_equal exp, cmd
    end
  end

  def test_parse_command_incorrect
    to_test = [
      [ {error: "ERR wrong number of arguments for 'set' command"}, ['set'] ],
      [ {error: "ERR wrong number of arguments for 'get' command"}, ['get'] ]
    ]

    to_test.each do |exp, cmd|
      parse_command_equal exp, cmd
    end
  end

  def test_cli_split
    to_test = [
      [ ["set", "foo", "bar"], "set foo bar" ],
      [ ["set", "b\\*", "bar"], "set b\\* bar" ],
      [ ["set", "foo bar", "baz"], 'set "foo bar" baz' ],
      [ ["set", "foo\\", "bar"], 'set foo\ bar' ],
    ]

    to_test.each do |exp, line|
      assert_equal exp, NamespaceTools.cli_split(line)
    end
  end

  # cli split converts \xFF to ASCII-8BIT, which is not the same as UTF-8
  # so we need to catch it
  def _byte_equal a, b
    a.zip(b).all? { |(l,r)| l.bytes.to_a == r.bytes.to_a }
  end

  def test_cli_split_with_special_characters
    to_test = [
      [ ["\xff\xff"],       '"\xff\xff"' ],
      [ ['\xff\xff'],       "'\\xff\\xff'" ],
      [ ["foo bar"],        '"foo bar"' ],
      [ ["foo bar", "baz"], '"foo bar" baz' ],
      [ ["foo bar"],        "'foo bar'" ],
    ]

    to_test.each do |exp, line|
      assert _byte_equal(exp, NamespaceTools.cli_split(line))
    end
  end

  def test_parse_extended_set
    to_test = [
      [ ['set', 'ns:foo', 'bar', 'ex', '1000'], ['set', 'foo', 'bar', 'ex', '1000'] ],
      [ ['set', 'ns:foo', 'bar', 'px', '1000'], ['set', 'foo', 'bar', 'px', '1000'] ],
      [ ['set', 'ns:foo', 'bar', 'nx'], ['set', 'foo', 'bar', 'nx'] ],
      [ ['set', 'ns:foo', 'bar', 'xx'], ['set', 'foo', 'bar', 'xx'] ],
      [ ['set', 'ns:foo', 'bar', 'xx', 'ex', '1000'], ['set', 'foo', 'bar', 'xx', 'ex', '1000'] ],
      [ ['set', 'ns:foo', 'bar', 'px', '1000', 'nx'], ['set', 'foo', 'bar', 'px', '1000', 'nx'] ],
      [ ['set', 'ns:foo', 'bar', 'px', '1000', 'nx'], ['set', 'foo', 'bar', 'px', '1000', 'nx'] ],
    ]

    to_test.each do |exp, cmd|
      parse_command_equal exp, cmd
    end
  end

  def test_parse_scan_family
    to_test = [
      [ ['scan', '0', 'match', 'ns:*'], ['scan', '0'] ],
      [ ['scan', '0', 'match', 'ns:foo*'], ['scan', '0', 'match', 'foo*'] ],
      [ ['hscan', 'ns:key', '0'], ['hscan', 'key', '0'] ],
      [ ['sscan', 'ns:key', '0'], ['sscan', 'key', '0'] ],
      [ ['zscan', 'ns:key', '0'], ['zscan', 'key', '0'] ],
      [ ['zscan', 'ns:key', '0', 'match', 'foo'], ['zscan', 'key', '0', 'match', 'foo'] ],
      [ ['zscan', 'ns:key', '0', 'count', '5'], ['zscan', 'key', '0', 'count', '5'] ],
    ]

    to_test.each do |exp, cmd|
      parse_command_equal exp, cmd
    end
  end

  def test_parse_pfadd
    to_test = [
      [ ['pfadd', 'ns:hll', 'foo', 'bar'], ['pfadd', 'hll', 'foo', 'bar'] ],
    ]

    to_test.each do |exp, cmd|
      parse_command_equal exp, cmd
    end
  end

  def test_parse_pfcount
    to_test = [
      [ ['pfcount', 'ns:hll'], ['pfcount', 'hll'] ],
    ]

    to_test.each do |exp, cmd|
      parse_command_equal exp, cmd
    end
  end

  def test_parse_pfmerge
    to_test = [
      [ ['pfmerge', 'ns:hll1', 'ns:hll2'], ['pfmerge', 'hll1', 'hll2'] ],
      [ ['pfmerge', 'ns:hll1', 'ns:hll2', 'ns:hll3'], ['pfmerge', 'hll1', 'hll2', 'hll3'] ],
    ]

    to_test.each do |exp, cmd|
      parse_command_equal exp, cmd
    end
  end
end
