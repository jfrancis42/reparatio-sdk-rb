module Reparatio
  # Column metadata returned by inspect.
  ColumnInfo = Struct.new(:name, :dtype, :null_count, :unique_count, keyword_init: true)

  # Result of inspect.
  InspectResult = Struct.new(
    :filename, :detected_encoding, :detected_delimiter,
    :rows, :sheets, :columns, :preview,
    keyword_init: true
  )

  # Result of me.
  MeResult = Struct.new(:email, :plan, :expires_at, :api_access, :active,
                        :request_count, :data_bytes_total, keyword_init: true)

  # Result of formats.
  FormatsResult = Struct.new(:input, :output, keyword_init: true)

  # Result of convert, append, merge, query, batch_convert.
  ConvertResult = Struct.new(:content, :filename, :warning, keyword_init: true)
end
