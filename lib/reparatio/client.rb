require "net/http"
require "uri"
require "json"
require "securerandom"
require "pathname"

require_relative "errors"
require_relative "models"

module Reparatio
  class Client
    DEFAULT_BASE_URL = "https://reparatio.app"
    DEFAULT_TIMEOUT  = 120

    # Create a Reparatio API client.
    #
    # @param api_key   [String, nil]  Your rp_... key. Falls back to
    #                                 ENV["REPARATIO_API_KEY"] when nil.
    # @param base_url  [String]       Override the API root.
    # @param timeout   [Integer]      Read/open timeout in seconds.
    def initialize(api_key: nil, base_url: DEFAULT_BASE_URL, timeout: DEFAULT_TIMEOUT)
      @api_key  = api_key || ENV.fetch("REPARATIO_API_KEY", "")
      @base_url = base_url.chomp("/")
      @timeout  = timeout
    end

    # ── formats ────────────────────────────────────────────────────────────────

    # List supported input/output formats. No API key required.
    # @return [FormatsResult]
    def formats
      data = get("/api/v1/formats")
      FormatsResult.new(input: data["input"], output: data["output"])
    end

    # ── me ─────────────────────────────────────────────────────────────────────

    # Return subscription details for the current API key.
    # @return [MeResult]
    def me
      data = get("/api/v1/me")
      MeResult.new(
        email:            data["email"],
        plan:             data["plan"],
        expires_at:       data["expires_at"],
        api_access:       data["api_access"],
        active:           data["active"],
        request_count:    data["request_count"],
        data_bytes_total: data["data_bytes_total"],
      )
    end

    # ── inspect ────────────────────────────────────────────────────────────────

    # Inspect a file: detect encoding, count rows, list column types and stats,
    # and return a data preview. No API key required.
    #
    # @param file       [String, Pathname, IO]  File path or raw bytes (String).
    # @param filename   [String, nil]  Required when passing a raw bytes String
    #                                  or an IO object.
    # @param no_header  [Boolean]
    # @param fix_encoding [Boolean]
    # @param preview_rows [Integer]
    # @param delimiter  [String]
    # @param sheet      [String]
    # @param encoding_override [String, nil]
    # @return [InspectResult]
    def inspect(file, filename: nil, no_header: false, fix_encoding: true,
                preview_rows: 8, delimiter: "", sheet: "", encoding_override: nil)
      content, fname = resolve_file(file, filename)
      fields = {
        no_header:         no_header ? "true" : "false",
        fix_encoding:      fix_encoding ? "true" : "false",
        delimiter:         delimiter,
        sheet:             sheet,
        json_max_level_str: "",
        encoding_override: encoding_override.to_s,
      }
      data = post_multipart("/preview", fields, [[:file, content, fname]])
      build_inspect_result(data)
    end

    # ── convert ────────────────────────────────────────────────────────────────

    # Convert a file to a different format.
    # Requires a Professional plan key.
    #
    # @param file          [String, Pathname, IO]
    # @param target_format [String]
    # @param filename      [String, nil]
    # @param no_header     [Boolean]
    # @param fix_encoding  [Boolean]
    # @param delimiter     [String]
    # @param sheet         [String]
    # @param columns       [Array<String>]  Rename all columns (new names in order).
    # @param select_columns [Array<String>] Columns to include.
    # @param deduplicate   [Boolean]
    # @param sample_n      [Integer]
    # @param sample_frac   [Float]
    # @param geometry_column [String]
    # @param cast_columns  [Hash]   e.g. { "price" => { "type" => "Float64" } }
    # @param null_values   [Array<String>]
    # @param encoding_override [String, nil]
    # @return [ConvertResult]
    def convert(file, target_format, filename: nil, no_header: false,
                fix_encoding: true, delimiter: "", sheet: "",
                columns: [], select_columns: [], deduplicate: false,
                sample_n: 0, sample_frac: 0.0, geometry_column: "geometry",
                cast_columns: {}, null_values: [], encoding_override: nil)
      content, fname = resolve_file(file, filename)
      fields = {
        target_format:     target_format,
        columns:           columns.to_json,
        no_header:         no_header ? "true" : "false",
        fix_encoding:      fix_encoding ? "true" : "false",
        delimiter:         delimiter,
        sheet:             sheet,
        select_columns:    select_columns.to_json,
        deduplicate:       deduplicate ? "true" : "false",
        sample_n:          sample_n.to_s,
        sample_frac:       sample_frac.to_s,
        geometry_column:   geometry_column,
        cast_columns:      cast_columns.to_json,
        null_values:       null_values.to_json,
        encoding_override: encoding_override.to_s,
        row_filter:        "",
        flatten_json:      "false",
        json_arrays:       "json",
      }
      post_multipart_binary("/api/v1/convert", fields, [[:file, content, fname]])
    end

    # ── batch_convert ──────────────────────────────────────────────────────────

    # Convert every file in a ZIP archive to a common format.
    # Returns a ZIP archive.
    # Requires a Professional plan key.
    #
    # @param zip_file      [String, Pathname, IO]
    # @param target_format [String]
    # @param filename      [String]
    # @return [ConvertResult]
    def batch_convert(zip_file, target_format, filename: "batch.zip",
                      no_header: false, fix_encoding: true, delimiter: "",
                      select_columns: [], deduplicate: false, sample_n: 0,
                      sample_frac: 0.0, cast_columns: {})
      content, fname = resolve_file(zip_file, filename)
      fields = {
        target_format:   target_format,
        no_header:       no_header ? "true" : "false",
        fix_encoding:    fix_encoding ? "true" : "false",
        delimiter:       delimiter,
        select_columns:  select_columns.to_json,
        deduplicate:     deduplicate ? "true" : "false",
        sample_n:        sample_n.to_s,
        sample_frac:     sample_frac.to_s,
        cast_columns:    cast_columns.to_json,
      }
      post_multipart_binary("/api/v1/batch-convert", fields, [[:zip_file, content, fname]])
    end

    # ── merge ──────────────────────────────────────────────────────────────────

    # Merge or join two files.
    # Requires a Professional plan key.
    #
    # @param file1      [String, Pathname, IO]
    # @param file2      [String, Pathname, IO]
    # @param operation  [String]  "append"|"left"|"right"|"outer"|"inner"
    # @param target_format [String]
    # @param filename1  [String, nil]
    # @param filename2  [String, nil]
    # @param join_on    [String]  Comma-separated join column(s).
    # @return [ConvertResult]
    def merge(file1, file2, operation, target_format, filename1: nil, filename2: nil,
              join_on: "", no_header: false, fix_encoding: true, geometry_column: "geometry")
      content1, fname1 = resolve_file(file1, filename1)
      content2, fname2 = resolve_file(file2, filename2)
      fields = {
        operation:       operation,
        target_format:   target_format,
        join_on:         join_on,
        no_header:       no_header ? "true" : "false",
        fix_encoding:    fix_encoding ? "true" : "false",
        geometry_column: geometry_column,
      }
      post_multipart_binary(
        "/api/v1/merge", fields,
        [[:file1, content1, fname1], [:file2, content2, fname2]]
      )
    end

    # ── append ─────────────────────────────────────────────────────────────────

    # Stack rows from two or more files vertically.
    # Column mismatches are filled with null.
    # Requires a Professional plan key.
    #
    # @param files         [Array<String, Pathname, IO>]  Minimum 2.
    # @param target_format [String]
    # @param filenames     [Array<String>, nil]  Override filenames (for IO/bytes input).
    # @return [ConvertResult]
    def append(files, target_format, filenames: nil, no_header: false, fix_encoding: true)
      raise ArgumentError, "At least 2 files required" if files.length < 2
      filenames ||= Array.new(files.length)
      resolved = files.each_with_index.map { |f, i| resolve_file(f, filenames[i]) }
      fields = {
        target_format: target_format,
        no_header:     no_header ? "true" : "false",
        fix_encoding:  fix_encoding ? "true" : "false",
      }
      file_parts = resolved.map { |content, fname| [:files, content, fname] }
      post_multipart_binary("/api/v1/append", fields, file_parts)
    end

    # ── query ──────────────────────────────────────────────────────────────────

    # Run a SQL query against a file. Table name in SQL is +data+.
    # Requires a Professional plan key.
    #
    # @param file          [String, Pathname, IO]
    # @param sql           [String]
    # @param target_format [String]
    # @param filename      [String, nil]
    # @return [ConvertResult]
    def query(file, sql, target_format: "csv", filename: nil,
              no_header: false, fix_encoding: true, delimiter: "", sheet: "")
      content, fname = resolve_file(file, filename)
      fields = {
        sql:           sql,
        target_format: target_format,
        no_header:     no_header ? "true" : "false",
        fix_encoding:  fix_encoding ? "true" : "false",
        delimiter:     delimiter,
        sheet:         sheet,
      }
      post_multipart_binary("/api/v1/query", fields, [[:file, content, fname]])
    end

    # ──────────────────────────────────────────────────────────────────────────
    private
    # ──────────────────────────────────────────────────────────────────────────

    # Resolve +source+ to [binary_string, filename].
    def resolve_file(source, override_filename)
      case source
      when Pathname
        path = source
        [File.binread(path.to_s), override_filename || path.basename.to_s]
      when String
        is_path = begin
          File.exist?(source)
        rescue ArgumentError
          false  # null bytes or other invalid path characters — treat as raw bytes
        end
        if is_path
          [File.binread(source), override_filename || File.basename(source)]
        else
          raise ArgumentError, "filename: is required when passing raw bytes as a String" unless override_filename
          [source.dup.force_encoding(Encoding::BINARY), override_filename]
        end
      when IO, StringIO
        raise ArgumentError, "filename: is required when passing an IO object" unless override_filename
        [source.read.force_encoding(Encoding::BINARY), override_filename]
      else
        raise ArgumentError, "Expected String (path), Pathname, or IO; got #{source.class}"
      end
    end

    # Build a multipart body; returns [body_string, content_type_header].
    def build_multipart(fields, file_parts)
      boundary = "ReparatioBoundary#{SecureRandom.hex(16)}"
      body = "".b

      fields.each do |name, value|
        next if value.nil? || value == ""
        body << "--#{boundary}\r\n"
        body << "Content-Disposition: form-data; name=\"#{name}\"\r\n\r\n"
        body << value.to_s.encode(Encoding::UTF_8).b
        body << "\r\n"
      end

      file_parts.each do |field_name, content, filename|
        body << "--#{boundary}\r\n"
        body << "Content-Disposition: form-data; name=\"#{field_name}\"; filename=\"#{filename}\"\r\n"
        body << "Content-Type: application/octet-stream\r\n\r\n"
        body << content.dup.force_encoding(Encoding::BINARY)
        body << "\r\n"
      end

      body << "--#{boundary}--\r\n"
      [body, "multipart/form-data; boundary=#{boundary}"]
    end

    # Common headers for all requests.
    def default_headers
      h = { "Accept" => "application/json" }
      h["X-API-Key"] = @api_key unless @api_key.nil? || @api_key.empty?
      h
    end

    # Execute a GET request; return parsed JSON.
    def get(path)
      uri = URI("#{@base_url}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.read_timeout = @timeout
      http.open_timeout = 10
      req = Net::HTTP::Get.new(uri.request_uri, default_headers)
      res = http.request(req)
      raise_for_status(res)
      JSON.parse(res.body)
    end

    # POST multipart; return parsed JSON.
    def post_multipart(path, fields, file_parts)
      body, content_type = build_multipart(fields, file_parts)
      uri = URI("#{@base_url}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.read_timeout = @timeout
      http.open_timeout = 10
      req = Net::HTTP::Post.new(uri.request_uri, default_headers.merge("Content-Type" => content_type))
      req.body = body
      res = http.request(req)
      raise_for_status(res)
      JSON.parse(res.body)
    end

    # POST multipart; return ConvertResult with binary content.
    def post_multipart_binary(path, fields, file_parts)
      body, content_type = build_multipart(fields, file_parts)
      uri = URI("#{@base_url}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.read_timeout = @timeout
      http.open_timeout = 10
      req = Net::HTTP::Post.new(uri.request_uri, default_headers.merge("Content-Type" => content_type))
      req.body = body
      res = http.request(req)
      raise_for_status(res)

      filename = extract_filename(res, "output")
      warning  = res["X-Reparatio-Warning"] || res["X-Reparatio-Errors"]
      ConvertResult.new(content: res.body.force_encoding(Encoding::BINARY),
                        filename: filename, warning: warning)
    end

    def extract_filename(response, fallback)
      cd = response["content-disposition"].to_s
      m  = cd.match(/filename="([^"]+)"/)
      m ? m[1] : fallback
    end

    def raise_for_status(response)
      code = response.code.to_i
      return if code < 400
      begin
        detail = JSON.parse(response.body)["detail"] || response.body
      rescue StandardError
        detail = response.body
      end
      case code
      when 401, 403 then raise AuthenticationError, detail
      when 402      then raise InsufficientPlanError, detail
      when 413      then raise FileTooLargeError, detail
      when 422      then raise ParseError, detail
      else               raise APIError.new(code, detail)
      end
    end

    def build_inspect_result(data)
      if data.key?("error")
        raise ParseError, data["error"]
      end
      columns = (data["columns"] || []).map do |c|
        ColumnInfo.new(
          name:         c["name"],
          dtype:        c["dtype"],
          null_count:   c["null_count"],
          unique_count: c["unique_count"],
        )
      end
      InspectResult.new(
        filename:           data["filename"],
        detected_encoding:  data["detected_encoding"],
        detected_delimiter: data["detected_delimiter"],
        rows:               data["rows_total"],
        sheets:             data["sheets"] || [],
        columns:            columns,
        preview:            data["preview"] || [],
      )
    end
  end
end
