# Lightweight, explicit serializers. No attributes are exposed unless they are
# listed here -- this keeps the public API surface auditable.
class ApplicationSerializer
  def self.one(record, **opts)
    return nil if record.nil?

    new(record, **opts).as_json
  end

  def self.many(records, **opts)
    Array(records).map { |record| new(record, **opts).as_json }
  end

  def initialize(record, **opts)
    @record = record
    @opts = opts
  end

  attr_reader :record, :opts

  def as_json
    {}
  end
end
