#!/usr/bin/env ruby
# frozen_string_literal: true

# Regenerates the WebP derivatives that index.html loads, plus the social
# share card and the favicons. Sources are never modified: each derivative is
# written beside its source under the same basename.
#
#   ruby bin/optimize-images.rb            rebuild only what is stale
#   ruby bin/optimize-images.rb --force    rebuild everything
#
# Requires ImageMagick 7:  brew install imagemagick

require "shellwords"

ROOT = File.expand_path("..", __dir__)
FORCE = ARGV.include?("--force")
QUALITY = 80

LOGO = "loftsonlomas.jpeg"
OG_SOURCE = "unit1/dining-and-living-room.jpeg"
OG_IMAGE = "og-image.jpg"
FAVICONS = { "favicon-32.png" => 32, "apple-touch-icon.png" => 180 }.freeze
GENERATED = [OG_IMAGE, *FAVICONS.keys].freeze

# Longest edge, in px, of each derivative. The logo renders at 256 CSS px and
# every photo at no more than half of the 1536px container, so 1200 still
# covers a 2x display. Sources already under their cap are left at their own
# size -- that is what the trailing ">" in the resize geometry means.
MAX_EDGE = Hash.new(1200).merge(LOGO => 640)

def magick(*args)
  system("magick", *args.map(&:to_s), exception: true)
end

def stale?(source, output)
  FORCE || !File.exist?(output) || File.mtime(output) < File.mtime(source)
end

def report(path)
  width, height = `magick identify -format '%w %h' #{Shellwords.escape(path)}`.split
  puts format("  %-50s %5s x %-5s %7.1f KB", path, width, height, File.size(path) / 1024.0)
end

Dir.chdir(ROOT)

sources = Dir.glob("{*,unit*/*}.{jpeg,jpg,png}").reject { |p| GENERATED.include?(p) }.sort

puts "WebP derivatives"
sources.each do |source|
  output = source.sub(/\.(jpeg|jpg|png)\z/i, ".webp")
  edge = MAX_EDGE[source]

  if stale?(source, output)
    # -auto-orient must run before -strip, or phone photos lose the EXIF
    # rotation that tells us which way is up.
    magick(source, "-auto-orient", "-resize", "#{edge}x#{edge}>", "-strip",
           "-quality", QUALITY, "-define", "webp:method=6", output)
  end
  report(output)
end

puts "\nShare card"
if stale?(OG_SOURCE, OG_IMAGE)
  # og:image wants 1.91:1. The source is 16:9, so crop rather than letterbox.
  magick(OG_SOURCE, "-auto-orient", "-resize", "1200x630^", "-gravity", "center",
         "-extent", "1200x630", "-strip", "-quality", 82, OG_IMAGE)
end
report(OG_IMAGE)

puts "\nFavicons"
FAVICONS.each do |output, size|
  if stale?(LOGO, output)
    magick(LOGO, "-auto-orient", "-resize", "#{size}x#{size}^", "-gravity", "center",
           "-extent", "#{size}x#{size}", "-strip", output)
  end
  report(output)
end

loaded = sources.map { |s| s.sub(/\.(jpeg|jpg|png)\z/i, ".webp") }
       .reject { |p| p == "unit6/03-dining-and-kitchen.webp" }
puts format("\nTotal WebP referenced by index.html: %.2f MB", loaded.sum { |p| File.size(p) } / 1048576.0)
