#!/usr/bin/env ruby
# frozen_string_literal: true

# Timeframe Demo - Demonstrates the various ways to use timeframes with recall
#
# Run with:
#   HTM_DBURL="postgresql://localhost/htm_development" ruby examples/timeframe_demo.rb

require_relative "../lib/htm"

puts <<~HEADER
  ╔══════════════════════════════════════════════════════════════════╗
  ║                    HTM Timeframe Demo                            ║
  ║                                                                  ║
  ║  Demonstrates the flexible timeframe options for recall queries ║
  ╚══════════════════════════════════════════════════════════════════╝

HEADER

# Configure week start (optional - defaults to :sunday)
HTM.configure do |config|
  config.week_start = :sunday  # or :monday
end

puts "Configuration:"
puts "  week_start: #{HTM.configuration.week_start}"
puts

# Initialize HTM
htm = HTM.new(robot_name: "Timeframe Demo Robot")

puts "=" * 70
puts "TIMEFRAME OPTIONS FOR RECALL"
puts "=" * 70
puts

# ─────────────────────────────────────────────────────────────────────────────
# 1. No timeframe filter (nil)
# ─────────────────────────────────────────────────────────────────────────────
puts "1. NO TIMEFRAME FILTER (nil)"
puts "   When timeframe is nil, no time-based filtering is applied."
puts
puts "   Code:"
puts "     htm.recall('PostgreSQL', timeframe: nil)"
puts
puts "   SQL equivalent: No WHERE clause on created_at"
puts

# ─────────────────────────────────────────────────────────────────────────────
# 2. Date object - entire day
# ─────────────────────────────────────────────────────────────────────────────
puts "2. DATE OBJECT (entire day)"
puts "   A Date is expanded to cover 00:00:00 to 23:59:59 of that day."
puts
puts "   Code:"
puts "     htm.recall('meetings', timeframe: Date.today)"
puts "     htm.recall('notes', timeframe: Date.new(2025, 11, 15))"
puts

today = Date.today
range = HTM::Timeframe.normalize(today)
puts "   Date.today (#{today}) normalizes to:"
puts "     #{range.begin} .. #{range.end}"
puts

# ─────────────────────────────────────────────────────────────────────────────
# 3. DateTime object - treated same as Date
# ─────────────────────────────────────────────────────────────────────────────
puts "3. DATETIME OBJECT (entire day)"
puts "   DateTime is treated the same as Date - the entire day is included."
puts
puts "   Code:"
puts "     htm.recall('events', timeframe: DateTime.now)"
puts

datetime = DateTime.now
range = HTM::Timeframe.normalize(datetime)
puts "   DateTime.now normalizes to:"
puts "     #{range.begin} .. #{range.end}"
puts

# ─────────────────────────────────────────────────────────────────────────────
# 4. Time object - entire day
# ─────────────────────────────────────────────────────────────────────────────
puts "4. TIME OBJECT (entire day)"
puts "   Time is also normalized to cover the entire day."
puts
puts "   Code:"
puts "     htm.recall('logs', timeframe: Time.now)"
puts

time = Time.now
range = HTM::Timeframe.normalize(time)
puts "   Time.now normalizes to:"
puts "     #{range.begin} .. #{range.end}"
puts

# ─────────────────────────────────────────────────────────────────────────────
# 5. Range - passed through directly
# ─────────────────────────────────────────────────────────────────────────────
puts "5. RANGE (passed through)"
puts "   A Range of Time objects is used directly for precise control."
puts
puts "   Code:"
puts "     start_time = Time.now - (7 * 24 * 60 * 60)  # 7 days ago"
puts "     end_time = Time.now"
puts "     htm.recall('updates', timeframe: start_time..end_time)"
puts

start_time = Time.now - (7 * 24 * 60 * 60)
end_time = Time.now
puts "   Range example:"
puts "     #{start_time} .. #{end_time}"
puts

# ─────────────────────────────────────────────────────────────────────────────
# 6. String - natural language parsing via Chronic
# ─────────────────────────────────────────────────────────────────────────────
puts "6. STRING (natural language)"
puts "   Natural language time expressions are parsed using the Chronic gem."
puts
puts "   Standard expressions:"
puts "     htm.recall('notes', timeframe: 'yesterday')"
puts "     htm.recall('notes', timeframe: 'last week')"
puts "     htm.recall('notes', timeframe: 'last month')"
puts "     htm.recall('notes', timeframe: 'this morning')"
puts

expressions = ["yesterday", "last week", "last month", "today"]
expressions.each do |expr|
  result = HTM::Timeframe.normalize(expr)
  if result
    puts "   '#{expr}' => #{result.begin.strftime('%Y-%m-%d %H:%M')} .. #{result.end.strftime('%Y-%m-%d %H:%M')}"
  end
end
puts

puts "   'Few' keyword (maps to 3):"
puts "     htm.recall('notes', timeframe: 'few days ago')"
puts "     htm.recall('notes', timeframe: 'a few hours ago')"
puts "     htm.recall('notes', timeframe: 'few weeks ago')"
puts

few_expressions = ["few days ago", "a few hours ago", "few weeks ago"]
few_expressions.each do |expr|
  result = HTM::Timeframe.normalize(expr)
  if result
    time_point = result.is_a?(Range) ? result.begin : result
    puts "   '#{expr}' => #{time_point.strftime('%Y-%m-%d %H:%M')}"
  end
end
puts

puts "   Weekend expressions:"
puts "     htm.recall('notes', timeframe: 'last weekend')"
puts "     htm.recall('notes', timeframe: 'weekend before last')"
puts "     htm.recall('notes', timeframe: '2 weekends ago')"
puts "     htm.recall('notes', timeframe: 'three weekends ago')"
puts

weekend_expressions = ["last weekend", "weekend before last", "2 weekends ago"]
weekend_expressions.each do |expr|
  result = HTM::Timeframe.normalize(expr)
  if result && result.is_a?(Range)
    puts "   '#{expr}' =>"
    puts "     #{result.begin.strftime('%A %Y-%m-%d')} .. #{result.end.strftime('%A %Y-%m-%d')}"
  end
end
puts

# ─────────────────────────────────────────────────────────────────────────────
# 7. :auto - extract timeframe from query text
# ─────────────────────────────────────────────────────────────────────────────
puts "7. :auto (EXTRACT FROM QUERY)"
puts "   The timeframe is extracted from the query text automatically."
puts "   The temporal expression is removed from the search query."
puts
puts "   Code:"
puts "     htm.recall('what did we discuss last week about databases', timeframe: :auto)"
puts

queries = [
  "what did we discuss last week about databases",
  "show me notes from yesterday about PostgreSQL",
  "what happened few days ago with the API",
  "recent discussions about embeddings",
  "show me weekend before last notes about Ruby"
]

puts "   Examples:"
queries.each do |query|
  result = HTM::Timeframe.normalize(:auto, query: query)
  puts
  puts "   Original: '#{query}'"
  puts "   Cleaned:  '#{result.query}'"
  puts "   Extracted: '#{result.extracted}'"
  if result.timeframe
    if result.timeframe.is_a?(Range)
      puts "   Timeframe: #{result.timeframe.begin.strftime('%Y-%m-%d %H:%M')} .. #{result.timeframe.end.strftime('%Y-%m-%d %H:%M')}"
    else
      puts "   Timeframe: #{result.timeframe.strftime('%Y-%m-%d %H:%M')}"
    end
  end
end
puts

# ─────────────────────────────────────────────────────────────────────────────
# 8. Array of Ranges - multiple time windows (OR'd together)
# ─────────────────────────────────────────────────────────────────────────────
puts "8. ARRAY OF RANGES (multiple time windows)"
puts "   Multiple time windows are OR'd together in the query."
puts
puts "   Code:"
puts "     today = Date.today"
puts "     last_friday = today - ((today.wday + 2) % 7)"
puts "     two_fridays_ago = last_friday - 7"
puts "     "
puts "     htm.recall('standup notes', timeframe: [last_friday, two_fridays_ago])"
puts

today = Date.today
# Calculate last Friday
days_since_friday = (today.wday + 2) % 7
days_since_friday = 7 if days_since_friday == 0
last_friday = today - days_since_friday
two_fridays_ago = last_friday - 7

ranges = HTM::Timeframe.normalize([last_friday, two_fridays_ago])
puts "   Dates: #{last_friday} and #{two_fridays_ago}"
puts "   Normalized to #{ranges.length} ranges:"
ranges.each_with_index do |range, i|
  puts "     [#{i + 1}] #{range.begin} .. #{range.end}"
end
puts
puts "   SQL equivalent:"
puts "     WHERE (created_at BETWEEN '...' AND '...')"
puts "        OR (created_at BETWEEN '...' AND '...')"
puts

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
puts "=" * 70
puts "SUMMARY OF TIMEFRAME OPTIONS"
puts "=" * 70
puts
puts "  | Input Type      | Behavior                                    |"
puts "  |-----------------|---------------------------------------------|"
puts "  | nil             | No time filter                              |"
puts "  | Date            | Entire day (00:00:00 to 23:59:59)           |"
puts "  | DateTime        | Entire day (same as Date)                   |"
puts "  | Time            | Entire day (same as Date)                   |"
puts "  | Range           | Exact time window                           |"
puts "  | String          | Natural language parsing via Chronic        |"
puts "  | :auto           | Extract from query, return cleaned query    |"
puts "  | Array<Range>    | Multiple time windows OR'd together         |"
puts

puts "=" * 70
puts "SPECIAL KEYWORDS"
puts "=" * 70
puts
puts "  | Keyword                   | Meaning                          |"
puts "  |---------------------------|----------------------------------|"
puts "  | few, a few, several       | Maps to #{HTM::TimeframeExtractor::FEW} (configurable via FEW constant) |"
puts "  | recently, recent          | Last #{HTM::TimeframeExtractor::FEW} days                  |"
puts "  | weekend before last       | 2 weekends ago (Sat-Mon)         |"
puts "  | N weekends ago            | N weekends back (Sat-Mon range)  |"
puts

puts <<~FOOTER

  ╔══════════════════════════════════════════════════════════════════╗
  ║                      Demo Complete                               ║
  ╚══════════════════════════════════════════════════════════════════╝
FOOTER
