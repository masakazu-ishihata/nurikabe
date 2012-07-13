#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

################################################################################
# default
################################################################################
@file = "p1.txt"
@show = false
@step = 100

################################################################################
# Arguments
################################################################################
require "optparse"
OptionParser.new { |opts|
  # options
  opts.on("-h","--help","Show this message") {
    puts opts
    exit
  }
  opts.on("-f [string]", "--file", "problem file"){ |f|
    @file = f
  }
  opts.on("--show", "show log"){
    @show = true
  }
  opts.on("--step [int]", "show # candidates every [int] steps"){ |f|
    @step = f.to_i
  }
  # parse
  opts.parse!(ARGV)
}

################################################################################
# classes
################################################################################
######## Panel ########
class MyPanel
  #### neighbors ####
  def MyPanel.get_neighbors(pnl)
    x = pnl[0]
    y = pnl[1]
    [ [x, y-1], [x-1, y], [x+1, y], [x, y+1] ]
  end
end

######## Patterns ########
class MyPattern
  #### new ####
  def initialize(pnl)
    @pnls = [ pnl ]       # panels
    @dist = Hash.new(-1)  # distances
    @dist[pnl] = 0
  end

  #### accessors ####
  attr_reader :pnls
  def size
    @pnls.size
  end

  #### member ####
  def member?(pnl)
    if @dist[pnl] >= 0
      true
    else
      false
    end
  end

  #### add a panel ####
  def push(pnl)
    abort("error @ MyPattern.push : multi-add") if member?(pnl)  # skip if pnl is a member

    @pnls.push(pnl)
    @dist[pnl] = get_distance(pnl)
    self
  end

  ### clone ####
  def clone
    ptn = MyPattern.new(@pnls.first)
    (@pnls - [@pnls.first]).each do |pnl|
      ptn.push(pnl)
    end
    ptn
  end

  #### show ####
  def show
    min = [0, 0]
    max = [0, 0]

    @pnls.each do |pnl|
      for i in 0..1
        min[i] = pnl[i] if pnl[i] < min[i]
        max[i] = pnl[i] if pnl[i] > max[i]
      end
    end

    bd = Array.new(max[1]-min[1]+1){|i| Array.new(max[0]-min[0]+1){|i| " _"}}
    @pnls.each do |pnl|
      bd[ pnl[1]-min[1] ][ pnl[0]-min[0] ] =  " *"
    end

    puts "--------------------------------------------------------------------------------"
    p @pnls
    p @dist
    bd.each do |line|
      puts "#{line.join()}"
    end
  end

  #### neighbors of pnl which in the pattern ####
  def get_neighbors(pnl)
    nbs = []
    MyPanel.get_neighbors(pnl).each do |n|
      nbs.push(n) if member?(n)
    end
    nbs
  end

  #### get distance of pnl ####
  def get_distance(pnl)
    return @dist[pnl] if @dist[pnl] >= 0
    return -1 if (nbs = get_neighbors(pnl)) == []
    min = nil
    nbs.each do |n|
      min = @dist[n] if min == nil || min > @dist[n]
    end
    return min + 1
  end

  #### larger than last ####
  def larger_than_last?(pnl)
    pnl[1] > @pnls.last[1] || (pnl[1] == @pnls.last[1] && pnl[0] > @pnls.last[0])
  end

  #### generate candidate panels ####
  def get_next_panels
    pnls = []
    max = @dist[@pnls.last]

    @pnls.reverse.each do |pnl|
      case @dist[pnl]
      # add neighbors with distance max+1
      when max
        MyPanel.get_neighbors(pnl).each do |n|
          pnls.push(n) if get_distance(n) == max + 1
        end
      # add neighbors with distance max & larger than last
      when max-1
        MyPanel.get_neighbors(pnl).each do |n|
          pnls.push(n) if get_distance(n) == max && larger_than_last?(n)
        end
      else
        break
      end
    end
    pnls
  end

  #### generate child patterns ####
  def get_children
    cld = []
    get_next_panels.each do |pnl|
      cld.push(clone.push(pnl))
    end
    cld
  end
end

######## board ####
class MyBoard
  #### new ####
  def initialize
    @x = 0       # board width
    @y = 0       # board height
    @n = 0       # # numbers in a problem
    @board = nil # board
    @next = 0    # next number index
    @nums = []   # numbers
    @ptns = []   # patterns corresponding to numbers
  end
  attr_reader :x, :y, :n, :board, :next, :nums, :ptns

  #### initizlize a board ####
  def init_board(x, y)
    @x = x
    @y = y
    @board = Array.new(@y){|y| Array.new(@x){|x| -1}} # -1 means empty
  end

  #### load a file ####
  def load(file)
    f = open(file)

    # initialize board
    init_board(f.gets.to_i, f.gets.to_i)

    # heuristic ordering
    nums = []
    while line = f.gets
      ary = line.split(" ").map{|i| i.to_i}
      nums.push( ary )
    end
    nums.sort!{|a, b| (a[2] <=> b[2]).nonzero? or (a[0]+a[1] <=> b[0]+b[1])}

    # set numbers
    nums.each do |x, y, n|
      set(x, y, n)
    end

    f.close
  end

  #### push a number ####
  def set(x, y, n)
    @nums.push(n)
    @ptns.push(MyPattern.new([x, y]))
    @board[y][x] = @n
    @n += 1
  end

  #### add a panel pnl to a pattern @ptns[index] ####
  def add(pnl, index)
    @board[ pnl[1] ][ pnl[0] ] = index
    @ptns[index].push(pnl)
    self
  end

  #### seek the next index ####
  def seek
    while @next < @n && @ptns[@next].size == @nums[@next]
      @next += 1
    end
    return true if @next < @n
    return false
  end

  #### look ####
  def look(pnl)
    @board[pnl[1]][pnl[0]]
  end

  #### on board? ####
  def on_board?(pnl)
    (0 <= pnl[0] && pnl[0] < @x) && (0 <= pnl[1] && pnl[1] < @y)
  end

  #### show ####
  def show
    bd = Array.new(@y){|i| Array.new(@x){|j| " _"}}

    # patterns
    for i in 0..@n-1
      first = @ptns[i].pnls.first
      rests = @ptns[i].pnls - [first]

      bd[ first[1] ][ first[0] ] = sprintf("%2d", @nums[i])
      rests.each do |pnl|
        bd[pnl[1]][pnl[0]] = " *"
      end
    end

    puts "#{@x} * #{@y}"
    bd.each do |line|
      puts "#{line.join()}"
    end

    @board.each do |line|
#      p line
    end
  end

  #### clone ####
  def clone
    b = MyBoard.new.copy(self)
  end
  def copy(bd)
    init_board(bd.x, bd.y)
    for y in 0..@y-1
      for x in 0..@x-1
        @board[y][x] = bd.board[y][x]
      end
    end
    bd.nums.each do |num|
      @nums.push(num)
    end
    bd.ptns.each do |ptn|
      @ptns.push(ptn.clone)
    end
    @n = bd.n
    @next = bd.next

    self
  end

  #### get children ####
  def get_children
    [] if !seek

    cld = []
    @ptns[@next].get_next_panels.each do |pnl|
      cld.push(clone.add(pnl, @next)) if addable?(pnl)
    end
    cld
  end

  #### pnl is addable to @pnls[@next] ####
  def addable?(pnl)
    # on board & empty
    return false if !on_board?(pnl)
    return false if look(pnl) != -1

    # pnl's neighbors should be @next or 0 (empty)
    MyPanel.get_neighbors(pnl).each do |n|
      next if !on_board?(n)
      return false if look(n) != -1 && look(n) != @next
    end

    # empty area should be connected
    return connected_without?(pnl)
  end

  #### empty area without pnl is connected ####
  def connected_without?(pnl)
    @board[ pnl[1] ][ pnl[0] ] = -999 # set a temporal value

    nbs = []
    MyPanel.get_neighbors(pnl).each do |n|
      next if !on_board?(n)
      nbs.push(n) if look(n) == -1
    end

    s = nbs.first  # start
    t = nbs - [s]  # targets

    rec = Hash.new(nil) # reached
    cs = [ s ]
    rec[s] = true

    while (c = cs.pop) != nil
      break if (t -= [c]) == []
      MyPanel.get_neighbors(c).each do |n|
        next if !on_board?(n) || look(n) != -1 || rec[n] == true
        rec[n] = true
        cs.push(n)
      end
    end

    @board[ pnl[1] ][ pnl[0] ] = -1   # set "empty"

    return true if t.size == 0
    return false
  end
end

################################################################################
# main
################################################################################
b = MyBoard.new
b.load(@file)
b.show

step = 0
cs = [ b ]
while (c = cs.pop) != nil
  step += 1
  puts "#{step} steps  -> #{cs.size} candidates (next = #{c.next}/#{c.n})" if step % @step == 0
  break if !c.seek
  c.show if @show
  cs += c.get_children
end
puts "found at the #{step} step"
c.show

