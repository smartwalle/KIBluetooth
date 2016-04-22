Pod::Spec.new do |s|
  s.name         = "KIBluetooth"
  s.version      = "0.0.1"
  s.summary      = "KIBluetooth"

  s.description  = <<-DESC
                   KIBluetooth.
                   DESC

  s.homepage     = "https://github.com/smartwalle/KIBluetooth"
  s.license      = "MIT"
  s.author             = { "SmartWalle" => "smartwalle@gmail.com" }
  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/smartwalle/KIBluetooth.git", :tag => "#{s.version}" }
  s.source_files  = "KIBluetooth/KIBluetooth/**/*.{h,m}"
  s.exclude_files = "Classes/Exclude"
  s.framework  = "CoreBluetooth"
  s.requires_arc = true
end
