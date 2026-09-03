#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint onnxruntime_v2.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'onnxruntime_v2'
  s.version          = '0.0.1'
  s.summary          = 'OnnxRuntime plugin for Flutter apps.'
  s.description      = 'Cross-platform ONNX Runtime plugin for Flutter applications.'
  s.homepage         = 'https://github.com/haygcao/onnxruntime_flutter_1_22_0'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'haygcao' => 'email@example.com' }
  s.source           = { :git => 'https://github.com/haygcao/onnxruntime_flutter_1_22_0.git', :tag => s.version.to_s }

  s.dependency 'Flutter'
  s.dependency 'onnxruntime-objc', '~> 1.28.0'
  s.platform = :ios, '12.0'
  s.static_framework = true

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
