Pod::Spec.new do |s|
  s.name             = "Rownd"
  s.version          = "2.5.0"
  s.summary          = "Rownd bindings for iOS"
  s.description      = <<-DESC
                        Rownd is a user management platform designed to make authentication
                        and user lifecycle easy, frictionless, and seamless for both devs and end-users
                        DESC
  s.homepage         = "https://github.com/rownd/ios"
  s.license          = { :type => "Apache 2.0", :file => "LICENSE.txt" }
  s.author           = {
    "Rownd" => "support@rownd.io",
  }
  s.documentation_url = "https://github.com/rownd/ios"
  s.source            = {
    :git => "https://github.com/rownd/ios.git",
    :tag => s.version.to_s
  }

  s.ios.deployment_target     = '14.0'

  s.dependency 'LBBottomSheet', '~> 1.0.24'
  s.dependency 'AnyCodable-FlightSchool', '~> 0.6.5'
  s.dependency 'JWTDecode', '~> 3.0.0'
  s.dependency 'ReSwift', '~> 6.1.0'
  s.dependency 'ReSwiftThunk', '~> 2.0.1'
  s.dependency 'Sodium', '~> 0.9.1'
  s.dependency 'SwiftKeychainWrapper', '~> 4.0.1'
  s.dependency 'CodeScanner_Rownd', '~> 2.2.1'
  s.dependency 'Get', '~> 2.0.1'
  s.dependency 'GoogleSignIn', '~> 6.2.4'
  s.dependency 'lottie-ios', '~> 3.4.3'
  s.dependency 'Factory', '~> 1.2.8'
  s.dependency 'Kronos', '~> 4.2.1'

  s.requires_arc     = true
  s.source_files     = 'Sources/**/*'
  s.swift_versions   = [ "5.5", "5.4", "5.3", "5.2", "5.0" ]
end
