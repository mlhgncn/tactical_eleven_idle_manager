def flutter_install_all_ios_pods(ios_dir)
  system('flutter', 'packages', 'get') if Dir.exist?(File.join(ios_dir, '..', '.dart_tool'))
end

def flutter_additional_ios_build_settings(target)
  target.build_configurations.each do |config|
    config.build_settings['ENABLE_BITCODE'] = 'NO'
  end
end
