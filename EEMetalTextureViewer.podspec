Pod::Spec.new do |s|
  s.name        = "EEMetalTextureViewer"
  s.version     = "1.0"
  s.summary     = "Fast, efficient raw pixel viewer for iOS using Metal"
  s.homepage    = "https://github.com/eldade/EEMetalTextureViewer"
  s.author      = { "eldade" => "https://github.com/eldade" }

  s.requires_arc = true
  s.osx.deployment_target = "10.10"
  s.ios.deployment_target = "10.0"
  s.watchos.deployment_target = "2.0"
  s.tvos.deployment_target = "10.0"
  s.source   = { :git => "https://github.com/eldade/EEMetalTextureViewer.git", :tag => s.version }
  s.source_files = "EEMetalTextureViewer/*"
end