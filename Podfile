# Uncomment the next line to define a global platform for your project
 platform :ios, '12.0'

target 'JitsiSample' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for JitsiSample
  pod 'JitsiMeetSDK'
  pod 'SnapKit', '~> 5.0.1'
  
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['ENABLE_BITCODE'] = 'NO'
      end
    end
  end

end
