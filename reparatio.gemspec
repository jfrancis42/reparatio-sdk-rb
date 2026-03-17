require_relative "lib/reparatio/version"

Gem::Specification.new do |spec|
  spec.name          = "reparatio"
  spec.version       = Reparatio::VERSION
  spec.authors       = ["Ordo Artificum LLC"]
  spec.email         = ["support@reparatio.app"]

  spec.summary       = "Ruby client for the Reparatio data conversion API"
  spec.description   = "Inspect, convert, merge, append, and query CSV, Excel, Parquet, "\
                       "JSON, GeoJSON, and 30+ other formats with a single method call."
  spec.homepage      = "https://reparatio.app"
  spec.license       = "MIT"

  spec.metadata = {
    "homepage_uri"    => spec.homepage,
    "source_code_uri" => "https://github.com/jfrancis42/reparatio-sdk-rb",
    "bug_tracker_uri" => "https://github.com/jfrancis42/reparatio-sdk-rb/issues",
    "changelog_uri"   => "https://github.com/jfrancis42/reparatio-sdk-rb/blob/main/CHANGELOG.md"
  }

  spec.required_ruby_version = ">= 3.0"

  spec.files         = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  # No runtime dependencies — pure stdlib.
end
