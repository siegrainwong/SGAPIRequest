# Uncomment the next line to define a global platform for your project
platform :ios, '9.0'

target 'SGAPIRequest' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for SGAPIRequest

  pod 'Moya', '~> 10.0.1'
  pod 'PromiseKit', '~> 4.3'
  pod 'HandyJSON', '~> 1.8.0'
  pod "AwesomeCache", "~> 5.0"

  target 'SGAPIRequestTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'SGAPIRequestUITests' do
    inherit! :search_paths
    # Pods for testing
  end

end

# 指定库使用 Swift 3
post_install do |installer|
    installer.pods_project.targets.each do |target|
        if target.name == 'HandyJSON' || target.name == 'Moya'
            target.build_configurations.each do |config|
                config.build_settings['SWIFT_VERSION'] = '3.0'
            end
        end
    end
end
