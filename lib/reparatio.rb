require_relative "reparatio/version"
require_relative "reparatio/errors"
require_relative "reparatio/models"
require_relative "reparatio/client"

module Reparatio
  # Convenience constructor so callers can write:
  #   client = Reparatio.new(api_key: "rp_...")
  def self.new(**kwargs)
    Client.new(**kwargs)
  end
end
