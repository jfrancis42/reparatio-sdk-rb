#!/usr/bin/env ruby
# frozen_string_literal: true

# Reparatio Ruby SDK — runnable examples.
#
# Each example is a self-contained method. Run the whole file:
#
#   ruby examples/examples.rb
#
# Or run a single example:
#
#   ruby -e "require_relative 'examples/examples'; ex_inspect_csv"
#
# These examples require REPARATIO_API_KEY to be set in the environment.
# Get a key at https://reparatio.app (Professional plan).

require "json"
require "stringio"
require "tempfile"
require "zlib"
require "pathname"

$LOAD_PATH.unshift File.join(__dir__, "..", "lib")
require "reparatio"

# ── Shared configuration ──────────────────────────────────────────────────────

API_KEY = ENV.fetch("REPARATIO_API_KEY", "EXAMPLE-EXAMPLE-EXAMPLE")

def client
  Reparatio::Client.new(api_key: API_KEY)
end

def sep(title)
  puts "\n#{"─" * 60}"
  puts "  #{title}"
  puts "─" * 60
end

# ── Example 1: formats() — list supported formats (no key required) ───────────

def ex_formats
  sep("1. formats() — list supported input/output formats")

  c = Reparatio::Client.new  # no key needed
  f = c.formats

  puts "Input formats  (#{f.input.length}): #{f.input.first(8).join(", ")} …"
  puts "Output formats (#{f.output.length}): #{f.output.first(8).join(", ")} …"
  raise "csv not in input"    unless f.input.include?("csv")
  raise "parquet not in output" unless f.output.include?("parquet")
  puts "PASS"
end

# ── Example 2: me() — account info ───────────────────────────────────────────

def ex_me
  sep("2. me() — account / subscription details")

  me = client.me

  puts "Email:      #{me.email}"
  puts "Plan:       #{me.plan}"
  puts "Active:     #{me.active}"
  puts "API access: #{me.api_access}"
  raise "not active"     unless me.active
  raise "no api_access"  unless me.api_access
  puts "PASS"
end

# ── Example 3: inspect() — file metadata from inline CSV ─────────────────────

def ex_inspect_csv
  sep("3. inspect() — CSV from inline string data")

  csv_data = "country,county\nEngland,Kent\nEngland,Essex\nWales,Gwent\n"
  result = client.inspect(csv_data, filename: "counties.csv")

  puts "Filename:  #{result.filename}"
  puts "Rows:      #{result.rows}"
  puts "Encoding:  #{result.detected_encoding}"
  puts "Columns (#{result.columns.length}):"
  result.columns.each do |col|
    puts "  %-25s %-15s nulls=#{col.null_count}" % [col.name, col.dtype]
  end
  puts "Preview row 0: #{result.preview[0].inspect}"
  raise "wrong column count" unless result.columns.length == 2
  raise "wrong row count"    unless result.rows == 3
  raise "wrong column names" unless result.columns.map(&:name) == %w[country county]
  puts "PASS"
end

# ── Example 4: inspect() — pass raw bytes with explicit filename ──────────────

def ex_inspect_bytes
  sep("4. inspect() — raw bytes (in-memory CSV)")

  csv_bytes = "id,name,score\n1,Alice,95\n2,Bob,87\n3,Carol,92\n"
  result = client.inspect(csv_bytes, filename: "scores.csv")

  puts "Rows:    #{result.rows}"
  puts "Columns: #{result.columns.map(&:name).inspect}"
  puts "Preview: #{result.preview.inspect}"
  raise "wrong row count" unless result.rows == 3
  raise "wrong columns"   unless result.columns.map(&:name) == %w[id name score]
  puts "PASS"
end

# ── Example 5: inspect() — inline TSV data ───────────────────────────────────

def ex_inspect_tsv
  sep("5. inspect() — TSV from inline string data")

  tsv_data = "id\tname\tscore\n1\tAlice\t95\n2\tBob\t87\n"
  result = client.inspect(tsv_data, filename: "data.tsv")

  puts "Filename: #{result.filename}"
  puts "Rows:     #{result.rows}"
  puts "Columns:  #{result.columns.map(&:name).inspect}"
  raise "wrong row count"    unless result.rows == 2
  raise "wrong column count" unless result.columns.length == 3
  raise "wrong column names" unless result.columns.map(&:name) == %w[id name score]
  puts "PASS"
end

# ── Example 6: convert() — CSV → Parquet ─────────────────────────────────────

def ex_convert_csv_to_parquet
  sep("6. convert() — CSV → Parquet")

  csv_bytes = "country,county\nEngland,Kent\nEngland,Essex\nWales,Gwent\n"
  out = client.convert(csv_bytes, "parquet", filename: "counties.csv")

  puts "Output filename: #{out.filename}"
  puts "Output size:     #{out.content.bytesize.to_s.gsub(/\B(?=(\d{3})+(?!\d))/, ",")} bytes"
  raise "wrong extension"    unless out.filename.end_with?(".parquet")
  raise "empty content"      unless out.content.bytesize > 0
  raise "not a parquet file" unless out.content[0, 4] == "PAR1"
  puts "PASS"
end

# ── Example 7: convert() — CSV → JSON Lines ───────────────────────────────────

def ex_convert_csv_to_jsonl
  sep("7. convert() — CSV → JSON Lines")

  csv_bytes = "id,name,score\n1,Alice,95\n2,Bob,87\n3,Carol,92\n"
  out = client.convert(csv_bytes, "jsonl", filename: "scores.csv")

  lines = out.content.force_encoding("UTF-8").split("\n").reject(&:empty?)
  puts "Output filename: #{out.filename}"
  puts "Lines:           #{lines.length}"
  puts "First record:    #{lines[0]}"
  raise "wrong extension" unless out.filename.end_with?(".jsonl")
  raise "no lines"        unless lines.length > 0
  raise "invalid JSON"    unless JSON.parse(lines[0])
  puts "PASS"
end

# ── Example 8: convert() — select + rename columns, compress output ───────────

def ex_convert_select_columns
  sep("8. convert() — select columns, rename, and gzip")

  csv_bytes = "region,product,revenue,cost\nNorth,Widget,100,60\nSouth,Widget,200,120\n"

  # First inspect to see available columns
  info      = client.inspect(csv_bytes, filename: "sales.csv")
  col_names = info.columns.map(&:name)
  puts "Available columns: #{col_names.inspect}"

  selected = col_names.first(2)
  renamed  = %w[ColA ColB]
  out = client.convert(
    csv_bytes,
    "csv.gz",
    filename:       "sales.csv",
    select_columns: selected,
    columns:        renamed,
  )

  puts "Output filename: #{out.filename}"
  puts "Output size:     #{out.content.bytesize.to_s.gsub(/\B(?=(\d{3})+(?!\d))/, ",")} bytes (compressed)"
  raise "wrong extension" unless out.filename.end_with?(".csv.gz")
  raise "empty content"   unless out.content.bytesize > 0
  puts "PASS"
end

# ── Example 9: convert() — deduplicate and sample ────────────────────────────

def ex_convert_deduplicate_sample
  sep("9. convert() — deduplicate rows + 50% sample")

  rows      = ["name,value"] + (["Alice,1", "Alice,1", "Bob,2", "Bob,2"] * 10)
  csv_bytes = rows.join("\n")

  # First confirm raw row count
  info = client.inspect(csv_bytes, filename: "dupes.csv")
  puts "Raw rows (with dupes): #{info.rows}"

  out = client.convert(
    csv_bytes,
    "csv",
    filename:    "dupes.csv",
    deduplicate: true,
    sample_frac: 0.5,
  )

  result_rows = out.content.force_encoding("UTF-8").split("\n").reject(&:empty?)
  puts "After dedup+sample:    #{result_rows.length - 1} data rows"
  raise "expected at least header + 1 row" unless result_rows.length > 1
  puts "PASS"
end

# ── Example 10: convert() — cast column types ────────────────────────────────

def ex_convert_cast_columns
  sep("10. convert() — override column types with cast_columns")

  csv_bytes = [
    "id,amount,event_date",
    "1,19.99,2025-01-15",
    "2,34.50,2025-02-20",
    "3,7.00,2025-03-01",
  ].join("\n")

  out = client.convert(
    csv_bytes,
    "parquet",
    filename:     "sales.csv",
    cast_columns: {
      "id"         => { "type" => "Int32" },
      "amount"     => { "type" => "Float64" },
      "event_date" => { "type" => "Date", "format" => "%Y-%m-%d" },
    },
  )

  puts "Output filename: #{out.filename}"
  puts "Output size:     #{out.content.bytesize.to_s.gsub(/\B(?=(\d{3})+(?!\d))/, ",")} bytes"
  raise "not a parquet file" unless out.content[0, 4] == "PAR1"

  # Round-trip inspect to verify types were applied
  info     = client.inspect(out.content, filename: out.filename)
  type_map = info.columns.each_with_object({}) { |c, h| h[c.name] = c.dtype }
  puts "Column types: #{type_map.inspect}"
  # Int32 may be widened to Int64 by the server
  raise "bad id type"    unless %w[Int32 Int64].include?(type_map["id"])
  raise "bad amount type" unless type_map["amount"] == "Float64"
  # Parquet stores Date as an integer with metadata; may round-trip as Date or String
  raise "bad date type"  unless %w[Date String].include?(type_map["event_date"])
  puts "PASS"
end

# ── Example 11: query() — SQL against a CSV ───────────────────────────────────

def ex_query
  sep("11. query() — SQL aggregation against a CSV file")

  csv_bytes = [
    "region,product,revenue",
    "North,Widget,100",
    "South,Widget,200",
    "North,Gadget,150",
    "South,Gadget,300",
    "North,Widget,120",
  ].join("\n")

  out = client.query(
    csv_bytes,
    "SELECT region, SUM(revenue) AS total FROM data GROUP BY region ORDER BY total DESC",
    filename:       "sales.csv",
    target_format:  "json",
  )

  result = JSON.parse(out.content.force_encoding("UTF-8"))
  puts "Query result: #{result.inspect}"
  raise "wrong row count" unless result.length == 2
  raise "South should be first" unless result[0]["region"] == "South"
  raise "South total wrong"     unless result[0]["total"] == 500
  puts "PASS"
end

# ── Example 12: append() — stack multiple CSVs ───────────────────────────────

def ex_append
  sep("12. append() — stack multiple CSVs vertically")

  jan = "date,region,revenue\n2025-01-01,North,100\n2025-01-02,South,200\n"
  feb = "date,region,revenue\n2025-02-01,North,150\n2025-02-02,South,180\n"
  mar = "date,region,revenue\n2025-03-01,North,120\n2025-03-02,South,210\n"

  out = client.append(
    [jan, feb, mar],
    "csv",
    filenames: %w[jan.csv feb.csv mar.csv],
  )

  lines = out.content.force_encoding("UTF-8").split("\n").reject(&:empty?)
  puts "Output filename:           #{out.filename}"
  puts "Total rows (incl. header): #{lines.length}"
  puts "Header: #{lines[0]}"
  raise "expected 7 lines (1 header + 6 data)" unless lines.length == 7
  puts "PASS"
end

# ── Example 13: merge() — join two files on a key column ─────────────────────

def ex_merge_join
  sep("13. merge() — inner join two CSVs on a key column")

  orders_csv = [
    "order_id,customer_id,amount",
    "1001,C1,50.00",
    "1002,C2,75.00",
    "1003,C1,30.00",
    "1004,C3,90.00",
  ].join("\n")

  customers_csv = [
    "customer_id,name,city",
    "C1,Alice,Boston",
    "C2,Bob,Chicago",
  ].join("\n")

  out = client.merge(
    orders_csv,
    customers_csv,
    "inner",
    "csv",
    filename1: "orders.csv",
    filename2: "customers.csv",
    join_on:   "customer_id",
  )

  lines = out.content.force_encoding("UTF-8").split("\n").reject(&:empty?)
  puts "Output filename:            #{out.filename}"
  puts "Result rows (incl. header): #{lines.length}"
  puts "Header: #{lines[0]}"
  lines[1..].each { |row| puts "  #{row}" }
  # C3 has no matching customer, so inner join yields 3 matched rows
  raise "expected 4 lines (1 header + 3 data)" unless lines.length == 4
  puts "PASS"
end

# ── Example 14: batch_convert() — ZIP of CSVs → ZIP of Parquets ──────────────

def ex_batch_convert
  sep("14. batch_convert() — ZIP of CSVs → ZIP of Parquet files")

  # Build a ZIP in memory using stdlib
  require "tmpdir"
  zip_bytes = nil
  Dir.mktmpdir do |dir|
    # Write two CSVs, then zip them using the system zip command
    File.write(File.join(dir, "sales_jan.csv"), "date,amount\n2025-01-01,100\n2025-01-02,200\n")
    File.write(File.join(dir, "sales_feb.csv"), "date,amount\n2025-02-01,150\n2025-02-02,180\n")
    zip_path = File.join(dir, "monthly.zip")
    system("zip", "-j", zip_path,
           File.join(dir, "sales_jan.csv"),
           File.join(dir, "sales_feb.csv"),
           exception: true)
    zip_bytes = File.binread(zip_path)
  end

  out = client.batch_convert(zip_bytes, "parquet", filename: "monthly.zip")

  # Unpack the returned ZIP using system unzip and verify each file
  Dir.mktmpdir do |dir|
    zip_path = File.join(dir, "result.zip")
    File.binwrite(zip_path, out.content)
    system("unzip", "-q", zip_path, "-d", dir, exception: true)
    parquet_files = Dir[File.join(dir, "*.parquet")]
    puts "Output files: #{parquet_files.map { |f| File.basename(f) }.inspect}"
    parquet_files.each do |f|
      data = File.binread(f)
      raise "#{File.basename(f)} is not a valid Parquet file" unless data[0, 4] == "PAR1"
      puts "  #{File.basename(f)}: #{data.bytesize.to_s.gsub(/\B(?=(\d{3})+(?!\d))/, ",")} bytes — valid Parquet"
    end
    raise "expected 2 parquet files" unless parquet_files.length == 2
  end

  puts "Warnings: #{out.warning}" if out.warning
  puts "PASS"
end

# ── Example 15: error handling ────────────────────────────────────────────────

def ex_error_handling
  sep("15. error handling — bad key, bad file, unsupported format")

  # Bad API key → AuthenticationError or InsufficientPlanError
  bad_client = Reparatio::Client.new(api_key: "rp_invalid")
  begin
    bad_client.convert("a,b\n1,2\n", "parquet", filename: "test.csv")
    raise "Should have raised"
  rescue Reparatio::AuthenticationError, Reparatio::InsufficientPlanError, Reparatio::APIError => e
    puts "Bad key caught:  #{e.class.name.split("::").last}: #{e}"
  end

  # Unparseable file → ParseError or APIError
  begin
    client.convert("\x00\x01\x02\x03garbage", "csv", filename: "bad.parquet")
    raise "Should have raised"
  rescue Reparatio::ParseError, Reparatio::APIError => e
    puts "Bad file caught: #{e.class.name.split("::").last}: #{e}"
  end

  puts "PASS"
end

# ── Runner ────────────────────────────────────────────────────────────────────

EXAMPLES = [
  :ex_formats,
  :ex_me,
  :ex_inspect_csv,
  :ex_inspect_bytes,
  :ex_inspect_tsv,
  :ex_convert_csv_to_parquet,
  :ex_convert_csv_to_jsonl,
  :ex_convert_select_columns,
  :ex_convert_deduplicate_sample,
  :ex_convert_cast_columns,
  :ex_query,
  :ex_append,
  :ex_merge_join,
  :ex_batch_convert,
  :ex_error_handling,
].freeze

if __FILE__ == $PROGRAM_NAME
  passed = 0
  failed = []

  EXAMPLES.each do |name|
    begin
      send(name)
      passed += 1
    rescue => e
      failed << [name, e]
      puts "  FAIL: #{e}"
    end
  end

  sep("Results: #{passed}/#{EXAMPLES.length} passed")
  if failed.any?
    failed.each { |name, e| puts "  FAIL  #{name}: #{e}" }
    exit 1
  else
    puts "  All examples passed."
  end
end
