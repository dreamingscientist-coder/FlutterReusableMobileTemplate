# =====================================================================
# release/fastlane_helpers.rb — small helpers shared by
# ios/fastlane/Fastfile and android/fastlane/Fastfile.
#
#   • load_envs     → reads app.env (committed) and .env (private)
#   • require_env!  → stops with a clear message if a value is missing
#   • pubspec_*     → reads "version: 1.2.0+7" from pubspec.yaml
#   • check_ad_ids! → blocks production releases that still use
#                     Google TEST ad IDs
#   • store texts   → turns store/<language>/*.txt into the folders
#                     fastlane needs for App Store / Google Play
# =====================================================================
require "fastlane_core"
require "fileutils"

module TemplateHelpers
  TEST_ADMOB_PUBLISHER = "ca-app-pub-3940256099942544".freeze

  module_function

  # Reads KEY=VALUE lines. Values already set in the shell win.
  def load_env_file(path)
    return unless File.exist?(path)

    File.readlines(path, encoding: "UTF-8").each do |raw|
      line = raw.strip
      next if line.empty? || line.start_with?("#")

      key, value = line.split("=", 2)
      next if key.nil? || value.nil?

      value = value.strip.sub(/\A(["'])(.*)\1\z/, '\2') # remove quotes
      ENV[key.strip] ||= value
    end
  end

  DEFAULT_MOBILE_RELEASE = "/Users/khacmuoivu/Developer/Tool/Mobile-Release".freeze

  # Order matters: the FIRST file that sets a value wins.
  #   1. .env          → this app only (private overrides)
  #   2. app.env       → this app (name, bundle ID, switches)
  #   3. developer_profile.env in Mobile-Release → YOUR fixed details,
  #      shared by every app (contact, Apple/Google keys)
  def load_envs(root)
    load_env_file(File.join(root, ".env"))
    load_env_file(File.join(root, "app.env"))
    ENV["MOBILE_RELEASE_DIR"] ||= DEFAULT_MOBILE_RELEASE
    load_env_file(File.join(ENV["MOBILE_RELEASE_DIR"], "developer_profile.env"))
  end

  # ------------------------------------------------------------------
  # Store texts: store/<language>/*.txt → fastlane folder layouts
  # ------------------------------------------------------------------
  LIMITS = {
    "name.txt" => 30, "subtitle.txt" => 30, "short_description.txt" => 80,
    "description.txt" => 4000, "keywords.txt" => 100,
    "promotional_text.txt" => 170, "release_notes.txt" => 4000
  }.freeze

  def store_languages
    ENV.fetch("STORE_LANGUAGES", "en-US").split(",").map(&:strip).reject(&:empty?)
  end

  def store_text(root, lang, file)
    path = File.join(root, "store", lang, file)
    File.exist?(path) ? File.read(path, encoding: "UTF-8").strip : ""
  end

  # Stops if a text still contains TODO or is too long.
  def check_store_texts!(root)
    problems = []
    store_languages.each do |lang|
      FastlaneCore::UI.user_error!("Folder store/#{lang} not found (see STORE_LANGUAGES in app.env)") unless File.directory?(File.join(root, "store", lang))
      LIMITS.each do |file, max|
        text = store_text(root, lang, file)
        problems << "store/#{lang}/#{file}: still contains TODO" if text.include?("TODO")
        problems << "store/#{lang}/#{file}: #{text.length} characters (max #{max})" if text.length > max
      end
    end
    return if problems.empty?

    FastlaneCore::UI.user_error!("Please fix the store texts first:\n  - #{problems.join("\n  - ")}")
  end

  # Builds build/store_metadata/ios in the layout `deliver` expects.
  # "What's New" is not allowed on an app's very first version (1.0 / 1.0.0).
  def build_ios_metadata(root)
    dir = File.join(root, "build", "store_metadata", "ios")
    FileUtils.rm_rf(dir)
    map = {
      "name.txt" => "name.txt", "subtitle.txt" => "subtitle.txt",
      "description.txt" => "description.txt", "keywords.txt" => "keywords.txt",
      "promotional_text.txt" => "promotional_text.txt"
    }
    first_version = pubspec_version_name(root).match?(/\A1(\.0)*\z/)
    map["release_notes.txt"] = "release_notes.txt" unless first_version
    store_languages.each do |lang|
      FileUtils.mkdir_p(File.join(dir, lang))
      map.each do |src, dst|
        File.write(File.join(dir, lang, dst), store_text(root, lang, src))
      end
    end
    dir
  end

  # Builds build/store_metadata/android in the layout `supply` expects.
  def build_android_metadata(root)
    dir = File.join(root, "build", "store_metadata", "android")
    FileUtils.rm_rf(dir)
    map = {
      "name.txt" => "title.txt",
      "short_description.txt" => "short_description.txt",
      "description.txt" => "full_description.txt"
    }
    store_languages.each do |lang|
      FileUtils.mkdir_p(File.join(dir, lang))
      map.each do |src, dst|
        File.write(File.join(dir, lang, dst), store_text(root, lang, src))
      end
    end
    dir
  end

  # Same URL for every language, e.g. { "en-US" => "https://...", "fr-FR" => ... }
  def per_language(url)
    store_languages.to_h { |lang| [lang, url] }
  end

  def require_env!(*keys)
    missing = keys.select { |k| ENV[k].to_s.strip.empty? }
    return if missing.empty?

    FastlaneCore::UI.user_error!(
      "Missing value(s): #{missing.join(', ')}.\n" \
      "Add them to Mobile-Release/developer_profile.env (shared) or to .env (this app only)."
    )
  end

  def require_file!(path, hint)
    return if File.exist?(path.to_s)

    FastlaneCore::UI.user_error!("File not found: #{path}\n#{hint}")
  end

  def pubspec_version_line(root)
    File.read(File.join(root, "pubspec.yaml"), encoding: "UTF-8")[/^version:\s*(\S+)/, 1] || "1.0.0+1"
  end

  # "1.2.0+7" → "1.2.0"
  def pubspec_version_name(root)
    pubspec_version_line(root).split("+").first
  end

  # "1.2.0+7" → 7
  def pubspec_build_number(root)
    pubspec_version_line(root).split("+")[1].to_i
  end

  # strict: true  → stop (production / App Store release)
  # strict: false → only warn (TestFlight / internal testing)
  def check_ad_ids!(root, strict:)
    return unless ENV["ADS_ENABLED"] == "true"

    problems = []
    required_units = ["BANNER_ID"]
    required_units << "REWARDED_ID" if ENV["REWARDED_ADS_ENABLED"] == "true"
    optional_units = %w[INTERSTITIAL_ID REWARDED_INTERSTITIAL_ID NATIVE_ID APP_OPEN_ID]
    %w[IOS ANDROID].each do |platform|
      required_units.each do |suffix|
        key = "ADMOB_#{platform}_#{suffix}"
        id = ENV[key].to_s
        problems << "#{key} (app.env or .env)" if id.empty? || id.start_with?(TEST_ADMOB_PUBLISHER)
      end
      optional_units.each do |suffix|
        key = "ADMOB_#{platform}_#{suffix}"
        id = ENV[key].to_s
        problems << "#{key} (app.env or .env)" if !id.empty? && id.start_with?(TEST_ADMOB_PUBLISHER)
      end
    end
    {
      "ios/Runner/Info.plist" => "iOS AdMob app ID",
      "android/app/src/main/AndroidManifest.xml" => "Android AdMob app ID"
    }.each do |file, label|
      path = File.join(root, file)
      problems << "#{label} (#{file})" if File.exist?(path) && File.read(path, encoding: "UTF-8").include?(TEST_ADMOB_PUBLISHER)
    end
    return if problems.empty?

    text = "Google TEST ad IDs are still used:\n  - #{problems.join("\n  - ")}"
    if strict && ENV["ALLOW_TEST_ADS"] != "true"
      FastlaneCore::UI.user_error!("#{text}\nPut your real AdMob IDs in first (see docs/NEW_APP_CHECKLIST.md).")
    else
      FastlaneCore::UI.important("#{text}\nOK for testing, NOT for the public release.")
    end
  end
end
