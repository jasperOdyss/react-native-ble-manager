require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name           = 'react-native-ble-manager'
  s.version        = package['version']
  s.summary        = package['description']
  s.description    = package['description']
  s.license        = package['license']
  s.author         = package['author']
  s.homepage       = package['homepage']
  s.source         = { :git => 'https://github.com/jasperOdyss/react-native-ble-manager.git', :tag => s.version }

  s.requires_arc   = true
  s.platform       = :ios, '13.0'

  s.source_files   = 'ios/**/*.{swift,h,m}'
  s.swift_version  = '5.0'

  s.dependency 'React-Core'
end
