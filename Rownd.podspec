Pod::Spec.new do |s|
  s.name             = "Rownd"
  s.version          = "1.0.0"
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
  s.documentation_url = "https://reswift.github.io/ReSwift/"
  s.social_media_url  = "https://twitter.com/benjaminencz"
  s.source            = {
    :git => "https://github.com/ReSwift/ReSwift.git",
    :tag => s.version.to_s
  }

  s.ios.deployment_target     = '14.0'

  s.requires_arc     = true
  s.source_files     = 'Sources/**/*.swift'
  s.swift_versions   = [ "5.5", "5.4", "5.3", "5.2", "5.0" ]
end
