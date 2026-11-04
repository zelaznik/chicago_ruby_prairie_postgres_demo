key = ENV["ATTRIBUTE_ENCRYPTION_KEY"]
if key.present?
  ENV["PGOPTIONS"] = "#{ENV['PGOPTIONS']} -c app.encryption_key=#{key}".strip
end
