Pod::Spec.new do |spec|

  spec.name         = "WatchFolder"
  spec.version      = "0.0.1"
  spec.summary      = "观察文件夹内文件的变化."
  spec.description  = 

  spec.homepage     = "https://github.com/cezres/WatchFolder"

  spec.license      = { :type => "MIT", :file => "LICENSE" }

  spec.author       = { "cezres" => "cezr@sina.com" }

  spec.source       = { :git => "https://github.com/cezres/WatchFolder.git", :tag => "#{spec.version}" }

  spec.source_files  = "WatchFolder/*.{h,swift}"
  spec.public_header_files = "WatchFolder/**/*.h"

end
