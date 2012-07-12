#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

################################################################################
# default
################################################################################
@file = "p1.txt"
@@show = false
@@fast = false
@@conn = false

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
    @@show = true
  }
  opts.on("--fast", "solve by a fast version (actually, not fast)"){
    @@fast = true
  }
  opts.on("--conn", "search a solution s.t. blacks are connected"){
    @@conn = true
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

  #### on a board x * y ####
  def MyPanel.on_board?(pnl, x, y)
    (0 <= pnl[0] && pnl[0] < x) && (0 <= pnl[1] && pnl[1] < y)
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
    self if member?(pnl)  # skip if pnl is a member

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

  #### larger than last ####
  def larger_than_last?(pnl)
    pnl[1] > @pnls.last[1] || (pnl[1] == @pnls.last[1] && pnl[0] > @pnls.last[0])
  end

  #### on_board ####
  def on_board?(x, y)
    @pnls.each do |pnl|
      return false if !MyPanel.on_board?(pnl, x, y)
    end
    return true
  end

  #### consistent with ptn?####
  def consistent?(ptn)
    # common members?
    @pnls.each do |pnl|
      return false if ptn.member?(pnl)
    end

    # connected?
    @pnls.each do |pnl|
      MyPanel.get_neighbors(pnl).each do |n|
        return false if ptn.member?(n)
      end
    end

    true
  end

  #### connected? ####
  def MyPattern.connected?(pnls)
    rec = Hash.new(nil)  # reachable or not

    pnls.each do |pnl|
      rec[pnl] = -1      # set unreachable
    end

    cs = [ pnls.first ]
    while (c = cs.shift) != nil
      rec[c] = 1 # reach
      MyPanel.get_neighbors(c).each do |n|
        cs.push(n) if rec[n] == -1
      end
    end

    pnls.each do |pnl|
      return false if rec[pnl] == -1
    end
    return true
  end
end

######## solver ########
class MyNurikabe
  #### new ###
  def initialize(file)
    f = open(file)

    # load problem
    @x = f.gets.to_i
    @y = f.gets.to_i
    @n = []
    while line = f.gets
      ary = line.split(" ").map{|i| i.to_i}
      @n.push( ary )
    end
#    @n.sort!{|a, b| a[0]+a[1] <=> b[0]+b[1]}
#    @n.sort!{|a, b| a[2] <=> b[2]}
    @n.sort!{|a, b| (a[2] <=> b[2]).nonzero? or (a[0]+a[1] <=> b[0]+b[1])}

    @rest = []
    for y in 0..@y-1
      for x in 0..@x-1
        @rest.push([x, y])
      end
    end

    # init solution
    @init = Array.new(@n.size)
    @ptns = Array.new(@n.size){|i| []}
    for i in 0..@n.size-1
      x = @n[i][0]
      y = @n[i][1]
      n = @n[i][2]
      ptn = MyPattern.new([x, y])
      @init[i] = ptn
      @ptns[i].push(ptn) if n == 1
      @rest -= [ptn]
    end

    # show problem
    show_solution(@init)
  end

  #### show ####
  def show_solution(s)
    bd = Array.new(@y){|i| Array.new(@x){|j| " _"}}

    s.each do |ptn|
      ptn.pnls.each do |pnl|
        bd[pnl[1]][pnl[0]] = " *"
      end
    end

    @n.each do |x, y, n|
      bd[y][x] = sprintf("%2d", n)
    end

    bd.each do |line|
      puts "#{line.join()}"
    end
  end

  #### enumerate coandidate patterns of sol[index] ####
  def get_candidates(sol, index)
    ptns = []
    cs = [ sol[index] ]
    while (c = cs.shift) != nil
      if c.size == @n[index][2]
        # c is a pattern with n panels
        ptns.push(c)
      else
        # add neighbors which is on board & consistent with othoer patterns
        c.get_children.each do |ptn|
          cs.push(ptn) if ptn.on_board?(@x, @y) && consistent?(sol, index, ptn)
        end
      end
    end
    ptns
  end

  #### consistent ####
  def consistent?(sol, index, ptn)
    # consistent with other patterns
    for i in 0..sol.size-1
      next if i == index
      return false if !ptn.consistent?(sol[i])
    end
    return true
  end

  #### solve ####
  def solve_fast
    # enumeate all candidate pattern for each numbers
    for i in 0..@n.size-1
      next if @ptns[i].size == 1
      @ptns[i] = get_candidates(@init, i)
      if @ptns[i].size == 1
        @init[i] = @ptns[i][0]
        i = 0
      end
    end

    # show if needed
    if @@show
      for i in 0..@n.size-1
        puts "#{@n[i]} #{@ptns[i].size} candidates"
      end
    end

    # solve
    cs = [ [0, @init] ]
    while (c = cs.pop) != nil
      index = c[0]
      sol   = c[1]
      break if index == @n.size  # c is a solution

      # show if needed
      if @@show && @ptns[index].size > 0
        puts "#{index} / #{@n.size}"
        puts " --> #{@ptns[index].size} candidates"
      end

      # add children
      @ptns[index].each do |ptn|
        if consistent?(sol, index, ptn)
          cldi = index + 1
          clds = sol.clone
          clds[index] = ptn
          cs.push([cldi, clds])
        end
      end
    end

    # solution
    show_solution(sol)
  end

  #### solve slowly ####
  def solve
    cs = [ [0, @init, @rest] ]
    while (c = cs.pop) != nil
      index = c[0]
      sol   = c[1]
      rest  = c[2]
      break if index == @n.size

      # enumerate all candiate of children
      can = get_candidates(sol, index)

      # show if needed
      if @@show &&  can.size > 0
        puts "#{index} / #{@n.size}"
        puts " --> #{can.size} candidates"
      end

      # generate & add children
      can.each do |ptn|
        if consistent?(sol, index, ptn)
          cldi = index + 1
          clds = sol.clone
          cldr = rest.clone
          clds[index] = ptn
          cldr -= ptn.pnls
          cs.push([cldi, clds, cldr]) if !@@conn || MyPattern.connected?(cldr)
        end
      end
    end

    # solution
    puts "solution"
    show_solution(sol)
  end
end

################################################################################
# main
################################################################################
n = MyNurikabe.new(@file)
if @@fast
  n.solve_fast
else
  n.solve
end
