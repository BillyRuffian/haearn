# frozen_string_literal: true

minimum_libvips_version = Gem::Version.new('8.13.0')

Rails.application.config.active_storage.variant_processor = :vips

begin
  require 'vips'
rescue LoadError => error
  raise "libvips >= #{minimum_libvips_version} is required for Active Storage variants: #{error.message}"
end

libvips_version = Gem::Version.new(Vips.version_string)

if libvips_version < minimum_libvips_version
  raise "libvips >= #{minimum_libvips_version} is required for Active Storage variants, found #{libvips_version}"
end

Vips.block_untrusted(true)
