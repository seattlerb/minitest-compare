require "optparse"

module Minitest; end

class Minitest::Compare
  VERSION = "1.0.0"

  EXCLUDE = [
             /^\s*$/,
             /.rb:\d+:in/,
             /DEPRECATION|DEPRECIATED/,
             /^Command failed with status/,
             /^Finished tests in/,
             /^Run options:/,
             /^# Running tests:/,
             / warning: /,
             /[^\[]+? \[[^\]+?]:\d+\]:/,
             /^\s+\d+\) Skipped:/,
             /^[^#]+#[^\[]+\[[^\]]+\]:$/,
             /\d+ runs, \d+ assertions, \d+ failures, \d+ errors, \d+ skips/,
             /Running:/,
             /Finished in [\d.]+s, [\d.]+ runs\/s, [\d.]+ assertions\/s/,
            ]

  attr_accessor :option
  attr_accessor :times
  attr_accessor :skipped

  def self.run args=ARGV
    new.run args
  end

  def initialize
    self.option = {}
    self.times = Hash.new { |h,k| h[k] = [] }
    self.skipped = 0
  end

  def process_options args
    OptionParser.new do |opts|
      opts.on "-h", "--help", "Display this help." do
        puts opts
        exit
      end

      desc = "Filter <= N percent. (integer)"
      opts.on "-f", "--filter N", Float, desc do |m|
        option[:filter] = m.to_f
      end

      begin
        opts.parse! args
      rescue OptionParser::InvalidOption => e
        puts
        puts e
        puts
        puts opts
        exit 1
      end
    end

    option
  end

  def process_paths args
    args.each do |path|
      File.foreach(path) do |line|
        begin
          case line.chomp
          when /^([^=]+) = ([\d.]+) s = [FES]$/
            # warn about skipping this data
          when /^(.+?) = ([\d.]+) s = \.$/
            times[$1] << $2.to_f
          when *EXCLUDE then
            # do nothing
          else
            self.skipped += 1
            # warn "Unparsed: #{line.chomp}"
          end
        rescue Exception => e
          puts line
          p e
          raise e
        end
      end
    end
  end

  def report
    puts "Skipped lines   = %d" % skipped
    puts "Total records   = %d" % times.size
    puts "Skipped records = %d" % times.count { |_,v| v.size == 1 }
    puts
    puts "ordered from biggest slowdown to biggest speedup:"
    puts

    times.reject! { |_,(b,a)| a.nil? }

    calculated = times.map { |k,(b,a)| [k, b-a, 100 * (a-b) / (a+b), b, a] }

    sorted = calculated.sort_by { |k, d, p, b, a| [d, k] }

    sorted.reject! { |k, d, p, b, a| d == 0.0 }

    f = option[:filter]
    sorted.reject! { |k, d, p, b, a| f < 0 ? p >= f : p <= f } if f

    total = 0.0

    sorted.each do |name, delta, pct, before, after|
      total += delta
      puts "%6.2f = %6.2f - %6.2f (%7.2f%%) %s" % [delta, before, after, pct, name]
    end

    puts
    puts "total change = %.2f" % total
  end

  def run args
    process_options args
    process_paths args
    report
  rescue Interrupt, Errno::EPIPE
    # do nothing
  end
end
