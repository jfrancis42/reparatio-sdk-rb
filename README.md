# reparatio — Ruby SDK

> **Alpha software.** The API surface may change without notice between versions. Pin to a specific version in production.

Ruby client library for the [Reparatio](https://reparatio.app) data conversion API.

Inspect, convert, merge, append, and query CSV, Excel, Parquet, JSON, GeoJSON, SQLite, and 30+ other formats with a single method call.

**See also:** [reparatio-cli](https://github.com/jfrancis42/reparatio-cli) (command-line tool) · [reparatio-mcp](https://github.com/jfrancis42/reparatio-mcp) (MCP server for AI assistants)

---

## Installation

```bash
gem install reparatio
```

Or add to your `Gemfile`:

```ruby
gem "reparatio"
```

Requires Ruby 3.0 or later. No external gem dependencies — pure stdlib.

---

## Quick start

```ruby
require "reparatio"

client = Reparatio.new(api_key: "EXAMPLE-EXAMPLE-EXAMPLE")

# Inspect a file
result = client.inspect("sales.csv")
puts "#{result.rows} rows, #{result.columns.length} columns"
result.columns.each { |col| puts "  #{col.name}: #{col.dtype}" }

# Convert to Parquet
out = client.convert("sales.csv", "parquet")
File.binwrite(out.filename, out.content)

# SQL query
out = client.query(
  "events.parquet",
  "SELECT region, SUM(revenue) FROM data GROUP BY region ORDER BY 2 DESC"
)
File.binwrite("by_region.csv", out.content)
```

---

## Authentication

The API key can be supplied in two ways, in order of precedence:

1. Passed directly: `Reparatio.new(api_key: "EXAMPLE-EXAMPLE-EXAMPLE")`
2. Environment variable: `REPARATIO_API_KEY=EXAMPLE-EXAMPLE-EXAMPLE`

Omit the key entirely for `inspect` and `formats` (no key required for those methods).

Get a key at [reparatio.app](https://reparatio.app) (Professional plan — $79/mo). API access requires the Professional plan; the Standard plan ($29/mo) covers web UI only.

---

## Reference

### `Reparatio.new(api_key:, base_url:, timeout:)`

| Parameter | Default | Description |
|---|---|---|
| `api_key` | `$REPARATIO_API_KEY` | Your `rp_...` API key |
| `base_url` | `https://reparatio.app` | Override the API host |
| `timeout` | `120` | Request timeout in seconds |

```ruby
client = Reparatio.new(api_key: "EXAMPLE-EXAMPLE-EXAMPLE")
# or rely on environment variable:
client = Reparatio.new
```

---

### `client.formats → FormatsResult`

Return the list of supported input and output formats. No API key required.

```ruby
f = client.formats
puts f.input.first(8).join(", ")
puts f.output.first(8).join(", ")
```

---

### `client.me → MeResult`

Return subscription details for the current API key.

```ruby
me = client.me
puts "#{me.email} — #{me.plan} (active: #{me.active})"
```

**`MeResult` fields:** `email`, `plan`, `active`, `api_access`, `expires_at`, `request_count`, `data_bytes_total`

---

### `client.inspect(file, ...) → InspectResult`

Detect encoding, count rows, list column types and statistics, and return a data preview.
No API key required.

```ruby
result = client.inspect(
  "data.csv",
  preview_rows: 20,
  fix_encoding: true,
)
puts "#{result.rows} rows, encoding: #{result.detected_encoding}"
result.columns.each do |col|
  puts "  #{col.name} (#{col.dtype}) — #{col.null_count} nulls"
end
result.preview.each { |row| puts row.inspect }
```

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `file` | String (path) / Pathname / IO | required | File path, IO object, or raw bytes (String) |
| `filename` | String | `nil` | Required when passing raw bytes or IO |
| `no_header` | Boolean | `false` | Treat first row as data |
| `fix_encoding` | Boolean | `true` | Auto-detect and repair encoding |
| `preview_rows` | Integer | `8` | Number of preview rows (1–100) |
| `delimiter` | String | `""` | Custom delimiter (auto-detected if blank) |
| `sheet` | String | `""` | Sheet name for Excel, ODS, or SQLite |
| `encoding_override` | String | `nil` | Force a specific encoding (e.g. `"cp037"` for EBCDIC) |

**`InspectResult` fields:** `filename`, `detected_encoding`, `detected_delimiter`, `rows`, `columns` (Array of `ColumnInfo`), `preview`, `sheets`

**`ColumnInfo` fields:** `name`, `dtype`, `null_count`, `unique_count`

---

### `client.convert(file, target_format, ...) → ConvertResult`

Convert a file from any supported input format to any supported output format.
Requires a Professional plan key ($79/mo).

```ruby
# Basic conversion
out = client.convert("sales.csv", "parquet")
File.binwrite(out.filename, out.content)

# Select and rename columns, compress output
out = client.convert(
  "big.csv",
  "csv.gz",
  select_columns: ["date", "region", "revenue"],
  columns: ["Date", "Region", "Revenue"],
)

# Deduplicate and take a 10% sample
out = client.convert("events.csv", "xlsx", deduplicate: true, sample_frac: 0.1)
```

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `file` | String (path) / Pathname / IO | required | File path, IO object, or raw bytes (String) |
| `target_format` | String | required | Output format (see [formats](#supported-formats)) |
| `filename` | String | `nil` | Required when passing raw bytes or IO |
| `no_header` | Boolean | `false` | Treat first row as data |
| `fix_encoding` | Boolean | `true` | Repair encoding |
| `delimiter` | String | `""` | Custom delimiter for CSV-like input |
| `sheet` | String | `""` | Sheet or table to read |
| `columns` | Array\<String\> | `[]` | Rename all columns (new names in order) |
| `select_columns` | Array\<String\> | `[]` | Columns to include (all if empty) |
| `deduplicate` | Boolean | `false` | Remove duplicate rows |
| `sample_n` | Integer | `0` | Random sample of N rows |
| `sample_frac` | Float | `0.0` | Random sample fraction (e.g. `0.1` for 10%) |
| `geometry_column` | String | `"geometry"` | WKT geometry column for GeoJSON output |
| `cast_columns` | Hash | `{}` | Override inferred column types (see below) |
| `null_values` | Array\<String\> | `[]` | Strings to treat as null at load time |
| `encoding_override` | String | `nil` | Force a specific encoding, bypassing auto-detection |

**`cast_columns` format:**

```ruby
out = client.convert(
  "sales.csv",
  "parquet",
  cast_columns: {
    "price" => { "type" => "Float64" },
    "date"  => { "type" => "Date", "format" => "%d/%m/%Y" },
  },
)
```

Supported types: `String`, `Int8`–`Int64`, `UInt8`–`UInt64`, `Float32`, `Float64`,
`Boolean`, `Date`, `Datetime`, `Time`. Values that cannot be cast are silently set to null.

---

### `client.batch_convert(zip_file, target_format, ...) → ConvertResult`

Convert every file inside a ZIP archive to a common format.
Returns a ZIP archive in `result.content`. Files that fail to parse are skipped;
their names and errors are available as a JSON string in `result.warning`.
Requires a Professional plan key ($79/mo).

```ruby
require "zip"  # rubyzip gem

out = client.batch_convert("monthly_reports.zip", "parquet")
File.binwrite("converted.zip", out.content)
if out.warning
  require "json"
  JSON.parse(out.warning).each { |e| puts "Skipped #{e['file']}: #{e['error']}" }
end
```

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `zip_file` | String (path) / Pathname / IO | required | ZIP archive |
| `target_format` | String | required | Output format for every file |
| `filename` | String | `"batch.zip"` | Original filename (when passing bytes) |
| `no_header` | Boolean | `false` | Treat first row as data |
| `fix_encoding` | Boolean | `true` | Repair encoding |
| `delimiter` | String | `""` | Custom delimiter |
| `select_columns` | Array\<String\> | `[]` | Columns to include (all if empty) |
| `deduplicate` | Boolean | `false` | Remove duplicate rows from each file |
| `sample_n` | Integer | `0` | Random sample of N rows per file |
| `sample_frac` | Float | `0.0` | Random sample fraction per file |
| `cast_columns` | Hash | `{}` | Column type overrides for every file |

---

### `client.merge(file1, file2, operation, target_format, ...) → ConvertResult`

Merge or join two files.
Requires a Professional plan key ($79/mo).

```ruby
out = client.merge(
  "orders.csv",
  "customers.xlsx",
  "left",
  "parquet",
  join_on: "customer_id",
)
File.binwrite(out.filename, out.content)
puts "Warning: #{out.warning}" if out.warning
```

**Operations:**

| Value | Behaviour |
|---|---|
| `append` | Stack all rows from both files; missing columns filled with null |
| `left` | All rows from file 1; matching columns from file 2 |
| `right` | All rows from file 2; matching columns from file 1 |
| `outer` | All rows from both files; nulls where no match |
| `inner` | Only rows present in both files |

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `file1` | String (path) / Pathname / IO | required | First file |
| `file2` | String (path) / Pathname / IO | required | Second file |
| `operation` | String | required | Join type (see table above) |
| `target_format` | String | required | Output format |
| `filename1` | String | `nil` | Original name of file1 (when passing bytes) |
| `filename2` | String | `nil` | Original name of file2 (when passing bytes) |
| `join_on` | String | `""` | Comma-separated column(s) to join on |
| `no_header` | Boolean | `false` | Treat first row as data |
| `fix_encoding` | Boolean | `true` | Repair encoding |
| `geometry_column` | String | `"geometry"` | WKT geometry column for GeoJSON output |

---

### `client.append(files, target_format, ...) → ConvertResult`

Stack rows from two or more files vertically.
Column mismatches are handled gracefully — missing values are filled with null.
Requires a Professional plan key ($79/mo).

```ruby
paths = Dir["monthly/*.csv"].sort
out = client.append(paths, "parquet")
File.binwrite("all_months.parquet", out.content)
```

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `files` | Array (String/Pathname/IO) | required | File paths or bytes (minimum 2) |
| `target_format` | String | required | Output format |
| `filenames` | Array\<String\> | `nil` | Original filenames (when passing bytes) |
| `no_header` | Boolean | `false` | Treat first row as data |
| `fix_encoding` | Boolean | `true` | Repair encoding |

---

### `client.query(file, sql, ...) → ConvertResult`

Run a SQL query against a file.
The file is loaded as a table named `data`.
Requires a Professional plan key ($79/mo).

```ruby
out = client.query(
  "events.parquet",
  "SELECT region, SUM(revenue) AS total FROM data WHERE year = 2025 GROUP BY region ORDER BY total DESC",
  target_format: "json",
)
puts out.content
```

Supports `SELECT`, `WHERE`, `GROUP BY`, `ORDER BY`, `LIMIT`, aggregations, and most scalar functions.

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `file` | String (path) / Pathname / IO | required | File path, IO object, or raw bytes |
| `sql` | String | required | SQL query (table name: `data`) |
| `filename` | String | `nil` | Required when passing raw bytes or IO |
| `target_format` | String | `"csv"` | Output format |
| `no_header` | Boolean | `false` | Treat first row as data |
| `fix_encoding` | Boolean | `true` | Repair encoding |
| `delimiter` | String | `""` | Custom delimiter for CSV-like input |
| `sheet` | String | `""` | Sheet or table to read |

---

### `ConvertResult`

Returned by `convert`, `merge`, `append`, `query`, and `batch_convert`.

| Field | Type | Description |
|---|---|---|
| `content` | String (binary) | Raw file content |
| `filename` | String | Suggested output filename |
| `warning` | String or nil | Server warning (e.g. column mismatch) |

Write the file to disk:

```ruby
out = client.convert("data.csv", "parquet")
File.binwrite(out.filename, out.content)
```

---

## Supported formats

### Input

CSV, TSV, CSV.GZ, CSV.BZ2, CSV.ZST, CSV.ZIP, TSV.GZ, TSV.BZ2, TSV.ZST, TSV.ZIP, GZ (any supported format), ZIP (any supported format), BZ2 (any supported format), ZST (any supported format), Excel (.xlsx / .xls), ODS, JSON, JSON.GZ, JSON.BZ2, JSON.ZST, JSON.ZIP, JSON Lines, GeoJSON, Parquet, Feather, Arrow, ORC, Avro, SQLite, YAML, BSON, SRT, VTT, HTML, Markdown, XML, SQL dump, PDF (text layer)

### Output

CSV, TSV, CSV.GZ, CSV.BZ2, CSV.ZST, CSV.ZIP, TSV.GZ, TSV.BZ2, TSV.ZST, TSV.ZIP, Excel (.xlsx), ODS, JSON, JSON.GZ, JSON.BZ2, JSON.ZST, JSON.ZIP, JSON Lines, JSON Lines.GZ, JSON Lines.BZ2, JSON Lines.ZST, JSON Lines.ZIP, GeoJSON, GeoJSON.GZ, GeoJSON.BZ2, GeoJSON.ZST, GeoJSON.ZIP, Parquet, Feather, Arrow, ORC, Avro, SQLite, YAML, BSON, SRT, VTT

---

## Error handling

All errors are subclasses of `Reparatio::Error`:

| Exception | Cause |
|---|---|
| `Reparatio::AuthenticationError` | Missing, invalid, or expired API key |
| `Reparatio::InsufficientPlanError` | Operation requires a Professional plan |
| `Reparatio::FileTooLargeError` | File exceeds the server's size limit |
| `Reparatio::ParseError` | File could not be parsed in the detected format |
| `Reparatio::APIError` | Unexpected server error (has `.status_code`) |

```ruby
require "reparatio"

begin
  out = client.convert("bad.csv", "parquet")
rescue Reparatio::AuthenticationError
  puts "Check your API key"
rescue Reparatio::ParseError => e
  puts "Could not read file: #{e}"
rescue Reparatio::APIError => e
  puts "Server error #{e.status_code}: #{e}"
end
```

---

## Privacy

Files are sent to the Reparatio API at `reparatio.app` for processing.
Files are handled in memory and never stored — see the [Privacy Policy](https://reparatio.app).
