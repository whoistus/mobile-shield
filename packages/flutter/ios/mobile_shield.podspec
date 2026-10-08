Pod::Spec.new do |s|
  s.name             = 'mobile_shield'
  s.version          = '0.1.0'
  s.summary          = 'In-house mobile security SDK wrapper for Flutter.'
  s.homepage         = 'https://github.com/whoistus/mobile-shield'
  s.license          = { :type => 'Proprietary', :file => '../LICENSE' }
  s.author           = 'mobile-shield authors'
  s.source           = { :path => '.' }
  s.source_files     = 'mobile_shield/Sources/mobile_shield/**/*.swift'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.vendored_frameworks = 'mobile_shield/Frameworks/MobileShieldCore.xcframework'
  s.swift_version    = '5.0'
end
