# frozen_string_literal: true

require_relative 'exceptions'
require_relative 'workflow/version'

module Libis::Workflow
  def self.configure
    yield Config.instance
  end
end
