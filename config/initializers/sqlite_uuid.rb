if defined?(ActiveRecord::ConnectionAdapters::SQLite3Adapter)
  puts "SQLite UUID initializer loaded"
  # Map the UUID type to a char(36) column,
  # which is large enough to hold a standard UUID string.
  ActiveRecord::ConnectionAdapters::SQLite3Adapter::NATIVE_DATABASE_TYPES[:uuid] = "char(36)"
end 