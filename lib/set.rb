#!/usr/bin/env ruby
#--
# set.rb - defines the Set class
#++
# Copyright (c) 2002-2008 Akinori MUSHA <knu@iDaemons.org>
#
# Documentation by Akinori MUSHA and Gavin Sinclair.
#
# All rights reserved.  You can redistribute and/or modify it under the same
# terms as Ruby.
#
#   $Id$
#
# == Overview
#
# This library provides the Set class, which deals with a collection
# of unordered values with no duplicates.  It is a hybrid of Array's
# intuitive inter-operation facilities and Hash's fast lookup.  If you
# need to keep values ordered, use the SortedSet class.
#
# The method +to_set+ is added to Enumerable for convenience.
#
# See the Set and SortedSet documentation for examples of usage.


#
# Set implements a collection of unordered values with no duplicates.
# This is a hybrid of Array's intuitive inter-operation facilities and
# Hash's fast lookup.
#
# The equality of each couple of elements is determined according to
# Object#eql? and Object#hash, since Set uses Hash as storage.
#
# Set is easy to use with Enumerable objects (implementing +each+).
# Most of the initializer methods and binary operators accept generic
# Enumerable objects besides sets and arrays.  An Enumerable object
# can be converted to Set using the +to_set+ method.
#
# == Example
#
#   require 'set'
#   s1 = Set.new [1, 2]                   # -> #<Set: {1, 2}>
#   s2 = [1, 2].to_set                    # -> #<Set: {1, 2}>
#   s1 == s2                              # -> true
#   s1.add("foo")                         # -> #<Set: {1, 2, "foo"}>
#   s1.merge([2, 6])                      # -> #<Set: {6, 1, 2, "foo"}>
#   s1.subset? s2                         # -> false
#   s2.subset? s1                         # -> true
#
# == Contact
#
#   - Akinori MUSHA <knu@iDaemons.org> (current maintainer)
#
class Set
  include Enumerable

  attr_reader :elements

  # Creates a new set containing the given objects.
  def self.[](*ary)
    new(ary)
  end

  # Creates a new set containing the elements of the given enumerable
  # object.
  #
  # If a block is given, the elements of enum are preprocessed by the
  # given block.
  def initialize(enum = nil, &block) # :yields: o
    @elements ||= Hash.new

    enum.nil? and return

    if block
      do_with_enum(enum) { |o| add(block[o]) }
    else
      merge(enum)
    end
  end

  def do_with_enum(enum, &block)
    if enum.respond_to?(:each_entry)
      enum.each_entry(&block)
    elsif enum.respond_to?(:each)
      enum.each(&block)
    else
      raise ArgumentError, "value must be enumerable"
    end
  end
  private :do_with_enum

  # Copy internal hash.
  def initialize_copy(orig)
    @elements = orig.elements.dup
  end

  def freeze        # :nodoc:
    super
    @elements.freeze
    self
  end

  def taint        # :nodoc:
    super
    @elements.taint
    self
  end

  def untaint        # :nodoc:
    super
    @elements.untaint
    self
  end

  # Returns the number of elements.
  def size
    @elements.size
  end
  alias length size

  # Returns true if the set contains no elements.
  def empty?
    @elements.empty?
  end

  # Removes all elements and returns self.
  def clear
    @elements.clear
    self
  end

  # Replaces the contents of the set with the contents of the given
  # enumerable object and returns self.
  def replace(enum)
    if enum.instance_of?(self.class)
      @elements.replace(enum.elements)
    else
      clear
      merge(enum)
    end

    self
  end

  # Converts the set to an array.  The order of elements is uncertain.
  def to_a
    @elements.keys
  end

  def flatten_merge(set, seen = Set.new)
    set.each { |e|
      if e.is_a?(Set)
        if seen.include?(e_id = e.object_id)
          raise ArgumentError, "tried to flatten recursive Set"
        end

        seen.add(e_id)
        flatten_merge(e, seen)
        seen.delete(e_id)
      else
        add(e)
      end
    }

    self
  end
  protected :flatten_merge

  # Returns a new set that is a copy of the set, flattening each
  # containing set recursively.
  def flatten
    self.class.new.flatten_merge(self)
  end

  # Equivalent to Set#flatten, but replaces the receiver with the
  # result in place.  Returns nil if no modifications were made.
  def flatten!
    if detect { |e| e.is_a?(Set) }
      replace(flatten())
    else
      nil
    end
  end

  # Returns true if the set contains the given object.
  def include?(o)
    @elements.include?(o)
  end
  alias member? include?

  # Returns true if the set is a superset of the given set.
  def superset?(set)
    set.is_a?(Set) or raise ArgumentError, "value must be a set"
    return false if size < set.size
    set.all? { |o| include?(o) }
  end

  # Returns true if the set is a proper superset of the given set.
  def proper_superset?(set)
    set.is_a?(Set) or raise ArgumentError, "value must be a set"
    return false if size <= set.size
    set.all? { |o| include?(o) }
  end

  # Returns true if the set is a subset of the given set.
  def subset?(set)
    set.is_a?(Set) or raise ArgumentError, "value must be a set"
    return false if set.size < size
    all? { |o| set.include?(o) }
  end

  # Returns true if the set is a proper subset of the given set.
  def proper_subset?(set)
    set.is_a?(Set) or raise ArgumentError, "value must be a set"
    return false if set.size <= size
    all? { |o| set.include?(o) }
  end

  # Calls the given block once for each element in the set, passing
  # the element as parameter.  Returns an enumerator if no block is
  # given.
  def each
    block_given? or return enum_for(__method__)
    @elements.each_key { |o| yield(o) }
    self
  end

  # Adds the given object to the set and returns self.  Use +merge+ to
  # add many elements at once.
  def add(o)
    @elements[o] = true
    self
  end
  alias << add

  # Adds the given object to the set and returns self.  If the
  # object is already in the set, returns nil.
  def add?(o)
    if include?(o)
      nil
    else
      add(o)
    end
  end

  # Deletes the given object from the set and returns self.  Use +subtract+ to
  # delete many items at once.
  def delete(o)
    @elements.delete(o)
    self
  end

  # Deletes the given object from the set and returns self.  If the
  # object is not in the set, returns nil.
  def delete?(o)
    if include?(o)
      delete(o)
    else
      nil
    end
  end

  # Deletes every element of the set for which block evaluates to
  # true, and returns self.
  def delete_if
    block_given? or return enum_for(__method__)
    to_a.each { |o| @elements.delete(o) if yield(o) }
    self
  end

  # Deletes every element of the set for which block evaluates to
  # false, and returns self.
  def keep_if
    block_given? or return enum_for(__method__)
    to_a.each { |o| @elements.delete(o) unless yield(o) }
    self
  end

  # Replaces the elements with ones returned by collect().
  def collect!
    block_given? or return enum_for(__method__)
    set = self.class.new
    each { |o| set << yield(o) }
    replace(set)
  end
  alias map! collect!

  # Equivalent to Set#delete_if, but returns nil if no changes were
  # made.
  def reject!
    block_given? or return enum_for(__method__)
    n = size
    delete_if { |o| yield(o) }
    size == n ? nil : self
  end

  # Equivalent to Set#keep_if, but returns nil if no changes were
  # made.
  def select!
    block_given? or return enum_for(__method__)
    n = size
    keep_if { |o| yield(o) }
    size == n ? nil : self
  end

  # Merges the elements of the given enumerable object to the set and
  # returns self.
  def merge(enum)
    if enum.instance_of?(self.class)
      @elements.update(enum.elements)
    else
      do_with_enum(enum) { |o| add(o) }
    end

    self
  end

  # Deletes every element that appears in the given enumerable object
  # and returns self.
  def subtract(enum)
    do_with_enum(enum) { |o| delete(o) }
    self
  end

  # Returns a new set built by merging the set and the elements of the
  # given enumerable object.
  def |(enum)
    dup.merge(enum)
  end
  alias + |                ##
  alias union |                ##

  # Returns a new set built by duplicating the set, removing every
  # element that appears in the given enumerable object.
  def -(enum)
    dup.subtract(enum)
  end
  alias difference -        ##

  # Returns a new set containing elements common to the set and the
  # given enumerable object.
  def &(enum)
    n = self.class.new
    do_with_enum(enum) { |o| n.add(o) if include?(o) }
    n
  end
  alias intersection &        ##

  # Returns a new set containing elements exclusive between the set
  # and the given enumerable object.  (set ^ enum) is equivalent to
  # ((set | enum) - (set & enum)).
  def ^(enum)
    n = Set.new(enum)
    each { |o| if n.include?(o) then n.delete(o) else n.add(o) end }
    n
  end

  # Returns true if two sets are equal.  The equality of each couple
  # of elements is defined according to Object#eql?.
  def ==(other)
    if self.equal?(other)
      true
    elsif other.instance_of?(self.class)
      @elements == other.elements
    elsif other.is_a?(Set) && self.size == other.size
      other.all? { |o| @elements.include?(o) }
    else
      false
    end
  end

  def hash        # :nodoc:
    @elements.hash
  end

  def eql?(o)        # :nodoc:
    return false unless o.is_a?(Set)
    @elements.eql?(o.elements)
  end

  # Classifies the set by the return value of the given block and
  # returns a hash of {value => set of elements} pairs.  The block is
  # called once for each element of the set, passing the element as
  # parameter.
  #
  # e.g.:
  #
  #   require 'set'
  #   files = Set.new(Dir.glob("*.rb"))
  #   hash = files.classify { |f| File.mtime(f).year }
  #   p hash    # => {2000=>#<Set: {"a.rb", "b.rb"}>,
  #             #     2001=>#<Set: {"c.rb", "d.rb", "e.rb"}>,
  #             #     2002=>#<Set: {"f.rb"}>}
  def classify # :yields: o
    block_given? or return enum_for(__method__)

    h = {}

    each { |i|
      x = yield(i)
      (h[x] ||= self.class.new).add(i)
    }

    h
  end

  # Divides the set into a set of subsets according to the commonality
  # defined by the given block.
  #
  # If the arity of the block is 2, elements o1 and o2 are in common
  # if block.call(o1, o2) is true.  Otherwise, elements o1 and o2 are
  # in common if block.call(o1) == block.call(o2).
  #
  # e.g.:
  #
  #   require 'set'
  #   numbers = Set[1, 3, 4, 6, 9, 10, 11]
  #   set = numbers.divide { |i,j| (i - j).abs == 1 }
  #   p set     # => #<Set: {#<Set: {1}>,
  #             #            #<Set: {11, 9, 10}>,
  #             #            #<Set: {3, 4}>,
  #             #            #<Set: {6}>}>
  def divide(&func)
    func or return enum_for(__method__)

    if func.arity == 2
      require 'tsort'

      class << dig = {}                # :nodoc:
        include TSort

        alias tsort_each_node each_key
        def tsort_each_child(node, &block)
          fetch(node).each(&block)
        end
      end

      each { |u|
        dig[u] = a = []
        each{ |v| func.call(u, v) and a << v }
      }

      set = Set.new()
      dig.each_strongly_connected_component { |css|
        set.add(self.class.new(css))
      }
      set
    else
      Set.new(classify(&func).values)
    end
  end

  InspectKey = :__inspect_key__         # :nodoc:

  # Returns a string containing a human-readable representation of the
  # set. ("#<Set: {element1, element2, ...}>")
  def inspect
    ids = (Thread.current[InspectKey] ||= [])

    if ids.include?(object_id)
      return sprintf('#<%s: {...}>', self.class.name)
    end

    begin
      ids << object_id
      return sprintf('#<%s: {%s}>', self.class, to_a.inspect[1..-2])
    ensure
      ids.pop
    end
  end

  def pretty_print(pp)        # :nodoc:
    pp.text sprintf('#<%s: {', self.class.name)
    pp.nest(1) {
      pp.seplist(self) { |o|
        pp.pp o
      }
    }
    pp.text "}>"
  end

  def pretty_print_cycle(pp)        # :nodoc:
    pp.text sprintf('#<%s: {%s}>', self.class.name, empty? ? '' : '...')
  end
end

# 
# SortedSet implements a Set that guarantees that it's element are
# yielded in sorted order (according to the return values of their
# #<=> methods) when iterating over them.
# 
# All elements that are added to a SortedSet must respond to the <=>
# method for comparison.
# 
# Also, all elements must be <em>mutually comparable</em>: <tt>el1 <=>
# el2</tt> must not return <tt>nil</tt> for any elements <tt>el1</tt>
# and <tt>el2</tt>, else an ArgumentError will be raised when
# iterating over the SortedSet.
#
# == Example
# 
#   require "set"
#   
#   set = SortedSet.new([2, 1, 5, 6, 4, 5, 3, 3, 3])
#   ary = []
#   
#   set.each do |obj|
#     ary << obj
#   end
#   
#   p ary # => [1, 2, 3, 4, 5, 6]
#   
#   set2 = SortedSet.new([1, 2, "3"])
#   set2.each { |obj| } # => raises ArgumentError: comparison of Fixnum with String failed
#   
class SortedSet < Set
  def initialize(*args, &block)
    @elements = Set.new(*args, &block).sort
  end

  def add(o)
    o.respond_to?(:<=>) or raise ArgumentError, "value must respond to <=>"
    i = index(o)
    @elements.insert(i, o) unless @elements.at(i - 1) == o
    self
  end
  alias << add

  def delete(o)
    i = index(o) - 1
    @elements.delete_at(i) if @elements.at(i) == o
    self
  rescue ArgumentError
    self
  end

  def each &block
    block_given? or return enum_for(__method__)
    @elements.each &block
    self
  end

  def to_a
    @elements
  end

  # Deletes every element of the set for which block evaluates to
  # true, and returns self.
  def delete_if &block
    block_given? or return enum_for(__method__)
    @elements.delete_if &block
    self
  end

  # Code borrowed from here:
  # https://github.com/chuckremes/zmqmachine/blob/69742afab4d68b1cbaade5a5721f6924e5f55ed5/lib/zm/timers.rb
  #
  # Original Ruby source Posted by Sergey Chernov (sergeych) on 2010-05-13 20:23
  # http://www.ruby-forum.com/topic/134477
  #
  # binary search; assumes underlying array is already sorted
  def index value
    l, r = 0, @elements.size - 1

    while l <= r
      m = (r + l) / 2

      case value <=> @elements.at(m)
      when -1
        r = m - 1
      when 0, 1
        l = m + 1
      else
        # This raises the correct exception for eg, nil, Fixnum, etc
        @elements.at(m) < value

        # Possibly some corner cases that won't raise above(?)
        raise ArgumentError, "comparison of %s with %s failed" %
          [@elements.at(m).class, value.class]
      end
    end

    l
  end
end

module Enumerable
  # Makes a set from the enumerable object with given arguments.
  # Needs to +require "set"+ to use this method.
  def to_set(klass = Set, *args, &block)
    klass.new(self, *args, &block)
  end
end

if $0 == __FILE__
  eval DATA.read, nil, $0, __LINE__+4
end

__END__

require 'test/unit'

module CommonTests
  def test_aref
    assert_nothing_raised {
      klass[]
      klass[nil]
      klass[1,2,3]
    }

    assert_equal(0, klass[].size)
    assert_equal(1, klass[nil].size)
    assert_equal(1, klass[[]].size)
    assert_equal(1, klass[[nil]].size)

    set = klass[2,4,6,4]
    assert_equal(klass.new([2,4,6]), set)
  end

  def test_s_new
    assert_nothing_raised {
      klass.new()
      klass.new(nil)
      klass.new([])
      klass.new([1,2])
      klass.new('a'..'c')
    }
    assert_raises(ArgumentError) {
      klass.new(false)
    }
    assert_raises(ArgumentError) {
      klass.new(1)
    }
    assert_raises(ArgumentError) {
      klass.new(1,2)
    }

    assert_equal(0, klass.new().size)
    assert_equal(0, klass.new(nil).size)
    assert_equal(0, klass.new([]).size)
    assert_equal(1, klass.new([nil]).size)

    ary = [2,4,6,4]
    set = klass.new(ary)
    ary.clear
    assert_equal(false, set.empty?)
    assert_equal(3, set.size)

    ary = [1,2,3]

    s = klass.new(ary) { |o| o * 2 }
    assert_equal([2,4,6], s.sort)
  end

  def test_clone
    set1 = klass.new
    set2 = set1.clone
    set1 << 'abc'
    assert_equal(klass.new, set2)
  end

  def test_dup
    set1 = klass[1,2]
    set2 = set1.dup

    assert_not_same(set1, set2)

    assert_equal(set1, set2)

    set1.add(3)

    assert_not_equal(set1, set2)
  end

  def test_size
    assert_equal(0, klass[].size)
    assert_equal(2, klass[1,2].size)
    assert_equal(2, klass[1,2,1].size)
  end

  def test_empty?
    assert_equal(true, klass[].empty?)
    assert_equal(false, klass[1, 2].empty?)
  end

  def test_clear
    set = klass[1,2]
    ret = set.clear

    assert_same(set, ret)
    assert_equal(true, set.empty?)
  end

  def test_replace
    set = klass[1,2]
    ret = set.replace('a'..'c')

    assert_same(set, ret)
    assert_equal(klass['a','b','c'], set)
  end

  def test_to_a
    set = klass[1,2,3,2]
    ary = set.to_a

    assert_equal([1,2,3], ary.sort)
  end

  def test_superset?
    set = klass[1,2,3]

    assert_raises(ArgumentError) {
      set.superset?()
    }

    assert_raises(ArgumentError) {
      set.superset?(2)
    }

    assert_raises(ArgumentError) {
      set.superset?([2])
    }

    assert_equal(true, set.superset?(klass[]))
    assert_equal(true, set.superset?(klass[1,2]))
    assert_equal(true, set.superset?(klass[1,2,3]))
    assert_equal(false, set.superset?(klass[1,2,3,4]))
    assert_equal(false, set.superset?(klass[1,4]))

    assert_equal(true, klass[].superset?(klass[]))
  end

  def test_proper_superset?
    set = klass[1,2,3]

    assert_raises(ArgumentError) {
      set.proper_superset?()
    }

    assert_raises(ArgumentError) {
      set.proper_superset?(2)
    }

    assert_raises(ArgumentError) {
      set.proper_superset?([2])
    }

    assert_equal(true, set.proper_superset?(klass[]))
    assert_equal(true, set.proper_superset?(klass[1,2]))
    assert_equal(false, set.proper_superset?(klass[1,2,3]))
    assert_equal(false, set.proper_superset?(klass[1,2,3,4]))
    assert_equal(false, set.proper_superset?(klass[1,4]))

    assert_equal(false, klass[].proper_superset?(klass[]))
  end

  def test_subset?
    set = klass[1,2,3]

    assert_raises(ArgumentError) {
      set.subset?()
    }

    assert_raises(ArgumentError) {
      set.subset?(2)
    }

    assert_raises(ArgumentError) {
      set.subset?([2])
    }

    assert_equal(true, set.subset?(klass[1,2,3,4]))
    assert_equal(true, set.subset?(klass[1,2,3]))
    assert_equal(false, set.subset?(klass[1,2]))
    assert_equal(false, set.subset?(klass[]))

    assert_equal(true, klass[].subset?(klass[1]))
    assert_equal(true, klass[].subset?(klass[]))
  end

  def test_proper_subset?
    set = klass[1,2,3]

    assert_raises(ArgumentError) {
      set.proper_subset?()
    }

    assert_raises(ArgumentError) {
      set.proper_subset?(2)
    }

    assert_raises(ArgumentError) {
      set.proper_subset?([2])
    }

    assert_equal(true, set.proper_subset?(klass[1,2,3,4]))
    assert_equal(false, set.proper_subset?(klass[1,2,3]))
    assert_equal(false, set.proper_subset?(klass[1,2]))
    assert_equal(false, set.proper_subset?(klass[]))

    assert_equal(false, klass[].proper_subset?(klass[]))
  end

  def test_each
    ary = [1,3,5,7,10,20]
    set = klass.new(ary)

    ret = set.each { |o| }
    assert_same(set, ret)

    e = set.each
    assert_instance_of(Enumerator, e)

    assert_nothing_raised {
      set.each { |o|
        ary.delete(o) or raise "unexpected element: #{o}"
      }

      ary.empty? or raise "forgotten elements: #{ary.join(', ')}"
    }
  end

  def test_add
    set = klass[1,2,3]

    ret = set.add(2)
    assert_same(set, ret)
    assert_equal(klass[1,2,3], set)

    ret = set.add?(2)
    assert_nil(ret)
    assert_equal(klass[1,2,3], set)

    ret = set.add(4)
    assert_same(set, ret)
    assert_equal(klass[1,2,3,4], set)

    ret = set.add?(5)
    assert_same(set, ret)
    assert_equal(klass[1,2,3,4,5], set)
  end

  def test_delete
    set = klass[1,2,3]

    ret = set.delete(4)
    assert_same(set, ret)
    assert_equal(klass[1,2,3], set)

    ret = set.delete?(4)
    assert_nil(ret)
    assert_equal(klass[1,2,3], set)

    ret = set.delete(2)
    assert_equal(set, ret)
    assert_equal(klass[1,3], set)

    ret = set.delete?(1)
    assert_equal(set, ret)
    assert_equal(klass[3], set)
  end

  def test_delete_if
    set = klass.new(1..10)
    ret = set.delete_if { |i| i > 10 }
    assert_same(set, ret)
    assert_equal(klass.new(1..10), set)

    set = klass.new(1..10)
    ret = set.delete_if { |i| i % 3 == 0 }
    assert_same(set, ret)
    assert_equal(klass[1,2,4,5,7,8,10], set)
  end

  def test_reject!
    set = klass.new(1..10)

    ret = set.reject! { |i| i > 10 }
    assert_nil(ret)
    assert_equal(klass.new(1..10), set)

    ret = set.reject! { |i| i % 3 == 0 }
    assert_same(set, ret)
    assert_equal(klass[1,2,4,5,7,8,10], set)
  end

  def test_merge
    set = klass[1,2,3]

    ret = set.merge([2,4,6])
    assert_same(set, ret)
    assert_equal(klass[1,2,3,4,6], set)
  end

  def test_subtract
    set = klass[1,2,3]

    ret = set.subtract([2,4,6])
    assert_same(set, ret)
    assert_equal(klass[1,3], set)
  end

  def test_plus
    set = klass[1,2,3]

    ret = set + [2,4,6]
    assert_not_same(set, ret)
    assert_equal(klass[1,2,3,4,6], ret)
  end

  def test_minus
    set = klass[1,2,3]

    ret = set - [2,4,6]
    assert_not_same(set, ret)
    assert_equal(klass[1,3], ret)
  end

  def test_and
    set = klass[1,2,3,4]

    ret = set & [2,4,6]
    assert_not_same(set, ret)
    assert_equal(klass[2,4], ret)
  end

  def test_xor
    set = klass[1,2,3,4]
    ret = set ^ [2,4,5,5]
    assert_not_same(set, ret)
    assert_equal(klass[1,3,5], ret)
  end

  # def test_hash
  # end

  # def test_eql?
  # end

  def test_classify
    set = klass.new(1..10)
    ret = set.classify { |i| i % 3 }

    assert_equal(3, ret.size)
    assert_instance_of(Hash, ret)
    ret.each_value { |value| assert_instance_of(klass, value) }
    assert_equal(klass[3,6,9], ret[0])
    assert_equal(klass[1,4,7,10], ret[1])
    assert_equal(klass[2,5,8], ret[2])
  end

  def test_divide
    set = klass.new(1..10)
    ret = set.divide { |i| i % 3 }

    assert_equal(3, ret.size)
    n = 0
    ret.each { |s| n += s.size }
    assert_equal(set.size, n)
    assert_equal(set, ret.flatten)

    set = klass[7,10,5,11,1,3,4,9,0]
    ret = set.divide { |a,b| (a - b).abs == 1 }

    assert_equal(4, ret.size)
    n = 0
    ret.each { |s| n += s.size }
    assert_equal(set.size, n)
    assert_equal(set, ret.flatten)
    ret.each { |s|
      if s.include?(0)
        assert_equal(klass[0,1], s)
      elsif s.include?(3)
        assert_equal(klass[3,4,5], s)
      elsif s.include?(7)
        assert_equal(klass[7], s)
      elsif s.include?(9)
        assert_equal(klass[9,10,11], s)
      else
        raise "unexpected group: #{s.inspect}"
      end
    }
  end

  # def test_pretty_print
  # end

  # def test_pretty_print_cycle
  # end
end


class TC_Set < Test::Unit::TestCase
  def klass
    Set
  end

  include CommonTests

  def test_inspect
    set1 = Set[1]

    assert_equal("#<Set: {1}>", set1.inspect)

    set2 = Set[Set[0], 1, 2, set1]
    assert_equal(false, set2.inspect.include?("#<Set: {...}>"))

    set1.add(set2)
    assert_equal(true, set1.inspect.include?("#<Set: {...}>"))
  end

  def test_collect!
    set = Set[1,2,3,'a','b','c',-1..1,2..4]

    ret = set.collect! { |i|
      case i
      when Numeric
        i * 2
      when String
        i.upcase
      else
        nil
      end
    }

    assert_same(set, ret)
    assert_equal(Set[2,4,6,'A','B','C',nil], set)
  end

  def test_flatten
    # test1
    set1 = Set[
      1,
      Set[
        5,
        Set[7,
          Set[0]
        ],
        Set[6,2],
        1
      ],
      3,
      Set[3,4]
    ]

    set2 = set1.flatten
    set3 = Set.new(0..7)

    assert_not_same(set2, set1)
    assert_equal(set3, set2)

    # test2; destructive
    orig_set1 = set1
    set1.flatten!

    assert_same(orig_set1, set1)
    assert_equal(set3, set1)

    # test3; multiple occurrences of a set in an set
    set1 = Set[1, 2]
    set2 = Set[set1, Set[set1, 4], 3]

    assert_nothing_raised {
      set2.flatten!
    }

    assert_equal(Set.new(1..4), set2)

    # test4; recursion
    set2 = Set[]
    set1 = Set[1, set2]
    set2.add(set1)

    assert_raises(ArgumentError) {
      set1.flatten!
    }

    # test5; miscellaneous
    empty = Set[]
    set =  Set[Set[empty, "a"],Set[empty, "b"]]

    assert_nothing_raised {
      set.flatten
    }

    set1 = empty.merge(Set["no_more", set])

    assert_nil(Set.new(0..31).flatten!)

    x = Set[Set[],Set[1,2]].flatten!
    y = Set[1,2]

    assert_equal(x, y)
  end

  def test_include?
    set = Set[1,2,3]

    assert_equal(true, set.include?(1))
    assert_equal(true, set.include?(2))
    assert_equal(true, set.include?(3))
    assert_equal(false, set.include?(0))
    assert_equal(false, set.include?(nil))

    set = Set["1",nil,"2",nil,"0","1",false]
    assert_equal(true, set.include?(nil))
    assert_equal(true, set.include?(false))
    assert_equal(true, set.include?("1"))
    assert_equal(false, set.include?(0))
    assert_equal(false, set.include?(true))
  end

  def test_eq
    set1 = Set[2,3,1]
    set2 = Set[1,2,3]

    assert_equal(set1, set1)
    assert_equal(set1, set2)
    assert_not_equal(Set[1], [1])

    set1 = Class.new(Set)["a", "b"]
    set2 = Set["a", "b", set1]
    set1 = set1.add(set1.clone)

#    assert_equal(set1, set2)
#    assert_equal(set2, set1)
    assert_equal(set2, set2.clone)
    assert_equal(set1.clone, set1)

    assert_not_equal(Set[Exception.new,nil], Set[Exception.new,Exception.new], "[ruby-dev:26127]")
  end
end

class TC_SortedSet < Test::Unit::TestCase
  def klass
    SortedSet
  end

  include CommonTests

  def test_inspect
    set1 = SortedSet[3,4,1,2]

    assert_equal("#<SortedSet: {1, 2, 3, 4}>", set1.inspect)
  end

  def test_collect!
    set = SortedSet[1,4,2,3,-2,-1]

    ret = set.collect! { |i|
      i*i
    }

    assert_same(set, ret)
    assert_equal(SortedSet[1,4,9,16], set)
  end

  def test_include?
    set = SortedSet[1,2,3]

    assert_equal(true, set.include?(1))
    assert_equal(true, set.include?(2))
    assert_equal(true, set.include?(3))
    assert_equal(false, set.include?(0))
    assert_equal(false, set.include?(nil))

    set = SortedSet["1","2","0","1"]
    assert_equal(true, set.include?("1"))
    assert_equal(false, set.include?(0))
    assert_equal(false, set.include?(true))
    assert_equal(false, set.include?(nil))
    assert_equal(false, set.include?(false))
  end

  def test_eq
    set1 = SortedSet[2,3,1]
    set2 = SortedSet[1,2,3]

    assert_equal(set1, set1)
    assert_equal(set1, set2)
    assert_not_equal(SortedSet[1], [1])

    set1 = Class.new(SortedSet)["a", "b"]
    set2 = SortedSet["a", "b"]

    assert_equal(set1, set2)
    assert_equal(set2, set2.clone)
    assert_equal(set1.clone, set1)
  end

  def test_delete_doesnt_raise
    set = SortedSet[0,1,2]

    set.delete(nil)
    set.delete('1')
  end

  def test_add_raises_argument_error_for_non_comparable_types
    set = SortedSet[0,1,2]

    e = assert_raises(ArgumentError) do
      set.add('4')
    end

    assert_equal "comparison of Fixnum with String failed", e.message

    e = assert_raises(ArgumentError) do
      set.add(nil)
    end
  
    assert_equal "comparison of Fixnum with nil failed", e.message

    set2 = SortedSet['a', 'c', 'e']
    
    e = assert_raises(ArgumentError) do
      set2.add(4)
    end

    assert_equal "comparison of String with 4 failed", e.message 

    e = assert_raises(ArgumentError) do
      set2.add(nil)
    end

    assert_equal "comparison of String with nil failed", e.message
  end

  def test_sortedset
    s = SortedSet[4,5,3,1,2]

    assert_equal([1,2,3,4,5], s.to_a)

    prev = nil
    s.each { |o| assert(prev < o) if prev; prev = o }
    assert_not_nil(prev)

    s.map! { |o| -2 * o }

    assert_equal([-10,-8,-6,-4,-2], s.to_a)

    prev = nil
    ret = s.each { |o| assert(prev < o) if prev; prev = o }
    assert_not_nil(prev)
    assert_same(s, ret)

    s = SortedSet.new([2,1,3]) { |o| o * -2 }
    assert_equal([-6,-4,-2], s.to_a)

    s = SortedSet.new(['one', 'two', 'three', 'four'])
    a = []
    ret = s.delete_if { |o| a << o; o.start_with?('t') }
    assert_same(s, ret)
    assert_equal(['four', 'one'], s.to_a)
    assert_equal(['four', 'one', 'three', 'two'], a)

    s = SortedSet.new(['one', 'two', 'three', 'four'])
    a = []
    ret = s.reject! { |o| a << o; o.start_with?('t') }
    assert_same(s, ret)
    assert_equal(['four', 'one'], s.to_a)
    assert_equal(['four', 'one', 'three', 'two'], a)

    s = SortedSet.new(['one', 'two', 'three', 'four'])
    a = []
    ret = s.reject! { |o| a << o; false }
    assert_same(nil, ret)
    assert_equal(['four', 'one', 'three', 'two'], s.to_a)
    assert_equal(['four', 'one', 'three', 'two'], a)
  end
end

class TC_Enumerable < Test::Unit::TestCase
  def test_to_set
    ary = [2,5,4,3,2,1,3]

    set = ary.to_set
    assert_instance_of(Set, set)
    assert_equal([1,2,3,4,5], set.sort)

    set = ary.to_set { |o| o * -2 }
    assert_instance_of(Set, set)
    assert_equal([-10,-8,-6,-4,-2], set.sort)

    set = ary.to_set(SortedSet)
    assert_instance_of(SortedSet, set)
    assert_equal([1,2,3,4,5], set.to_a)

    set = ary.to_set(SortedSet) { |o| o * -2 }
    assert_instance_of(SortedSet, set)
    assert_equal([-10,-8,-6,-4,-2], set.sort)
  end
end
