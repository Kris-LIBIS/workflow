# encoding: utf-8
require 'digest'

require 'libis/exceptions'
require 'libis/workflow/workitems'

class ChecksumTester < ::LIBIS::Workflow::Task

  parameter checksum_type: 'MD5'

  def process(item)
    return unless item.is_a? TestFileItem

    case options[:checksum_type]
      when 'MD5'
        checksum = ::Digest::MD5.hexdigest(File.read(item.long_name))
        raise ::LIBIS::WorkflowError, "Checksum test failed for #{item.long_name}" unless item.properties[:checksum] == checksum
      when 'SHA1'
        checksum = ::Digest::SHA1.hexdigest(File.read(item.long_name))
        raise ::LIBIS::WorkflowError, "Checksum test failed for #{item.long_name}" unless item.properties[:checksum] == checksum
      when 'SHA2'
        checksum = ::Digest::SHA2.new(256).hexdigest(File.read(item.long_name))
        raise ::LIBIS::WorkflowError, "Checksum test failed for #{item.long_name}" unless item.properties[:checksum] == checksum
      else
        # do nothing
        warn "Checksum type '#{self.options[:checksum_type]}' not supported. Check ignored."
    end

  end
end
