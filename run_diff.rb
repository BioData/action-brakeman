#!/usr/bin/env ruby
MERGE_BASE_REF, MERGE_BASE_SHA, CHANGED_FILES_COLON = ARGV
CHANGED_FILES = CHANGED_FILES_COLON.split(":").reject(&:empty?)
BUNDLE_EXEC = ENV['BUNDLE_EXEC'] || ''
BRAKEMAN_FLAGS = ENV['INPUT_BRAKEMAN_FLAGS'] || ''
# HERE: The order of WARNING_COLUMNS must match the order of the brakeman report output
WARNING_COLUMNS = ['Confidence', 'Category', 'Check', 'Message', 'Code', 'File', 'Line'].freeze

def generate_report(report_type)
  puts "📊 Generating #{report_type} report..."

  full_report = "#{report_type}-full-report.out"
  filtered_report = "#{report_type}-filtered-report.out"
  brakeman_cmd = "#{BUNDLE_EXEC}brakeman --quiet --no-exit-on-warn --no-exit-on-error #{BRAKEMAN_FLAGS} --color -o #{full_report}"
  # HERE: Do ** NOT ** try to grep columns followed by a colon ':', as it will not match the brakeman output
  # HERE: because each column is colored in the output and the colon is not colored, so it won't be matched.
  ##########################################################################
  # Good:                                                                  #
  # grep -E --color=never '(Colon1|Colon2)'                                #
  ##########################################################################
  # Bad:                                                                   #
  # grep -E --color=never '(Colon1|Colon2):' <--- see the colon at the end #
  ##########################################################################
  report_cmd = [
    "cat #{full_report}",
    "grep -E --color=never -A1 -B5 '(#{CHANGED_FILES.join('|')})'",
    "grep -E --color=never '(#{WARNING_COLUMNS.join('|')})'",
    %Q{awk '
      BEGIN { count=0 }
      /#{WARNING_COLUMNS[-1]}/ { count++ }
      { lines[NR]=$0 }
      END {
        printed=0
        for (i=1; i<=NR; i++) {
          print lines[i]
          if (lines[i] ~ /#{WARNING_COLUMNS[-1]}/) {
            printed++
            if (printed < count) print "------"
          }
        }
      }'}
  ].join(' | ') + " > #{filtered_report}"

  [brakeman_cmd, report_cmd].each do |cmd|
    system(cmd, exception: true)
  end

  return filtered_report
end

puts "🔍 Base ref: #{MERGE_BASE_REF}"
puts "🔍 Base SHA: #{MERGE_BASE_SHA}"
puts "📝 Changed Ruby files:\n#{CHANGED_FILES.join("\n")}"

puts "📥 Fetching base commit..."
system("git fetch --depth 1 origin #{MERGE_BASE_SHA}")

current_report = generate_report('current')

# Checkout to the base commit
system("git checkout --quiet #{MERGE_BASE_SHA}")

base_report = generate_report('base')

# Return to PR 'HEAD'
system("git checkout --quiet -")

current_count = File.read(current_report).scan(/#{WARNING_COLUMNS[0]}/).size
base_count = File.read(base_report).scan(/#{WARNING_COLUMNS[0]}/).size

puts "\n📊 Status Report:"
puts "Current commit warning count: #{current_count}"
puts "Base commit warning count: #{base_count}"

if current_count > base_count
  puts "\n📊 Current report generated:"
  system("cat #{current_report}")
  puts "\n❌ You introduced #{current_count - base_count} new Brakeman warnings in changed files."
  exit 1
end

puts "\n✅ Brakeman warning count in changed files is not higher than on base commit."
exit 0