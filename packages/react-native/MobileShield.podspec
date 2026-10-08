require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "MobileShield"
  s.version      = "0.1.0"
  s.summary      = package["description"]
  s.homepage     = "https://github.com/whoistus/mobile-shield"
  s.license      = { :type => "Proprietary", :file => "LICENSE" }
  s.authors      = "mobile-shield authors"
  s.platforms    = { :ios => "13.0" }
  s.source       = { :git => "https://github.com/whoistus/mobile-shield.git", :tag => "v#{s.version}" }
  s.source_files = "ios/*.{h,m,mm}"
  s.vendored_frameworks = "ios/Frameworks/MobileShieldCore.xcframework"
  s.dependency "React-Core"
end
