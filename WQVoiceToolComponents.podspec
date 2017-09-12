#
#  Be sure to run `pod spec lint WQBasicComponents.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  These will help people to find your library, and whilst it
  #  can feel like a chore to fill in it's definitely to your advantage. The
  #  summary should be tweet-length, and the description more in depth.
  #

  s.name         = "WQVoiceToolComponents"
  s.version      = "0.0.5"
  s.summary      = "音频组件"

  s.description  = <<-DESC
                      将之前的组件进行细致拆分
                      DESC
              

  s.homepage     = "https://github.com/wang68543/WQVoiceToolComponents"


  s.license      = 'MIT'


  s.author             = { "王强" => "wang68543@163.com" }
 

  s.source       = { :git => "https://github.com/wang68543/WQVoiceToolComponents.git", :tag => "#{s.version}" }


  s.platform     = :ios, "8.0"

  s.pod_target_xcconfig = { 'ENABLE_BITCODE' => 'NO' }
  
     non_arc_files = 'WQVoiceToolComponents/amrwapper/*.{h,m}'
     s.requires_arc = true

     s.exclude_files = non_arc_files
     s.subspec 'WavAmrHelp' do |sna|
     sna.requires_arc = false
     sna.source_files = non_arc_files
     sna.vendored_libraries = "WQVoiceToolComponents/amrwapper/libopencore-amrnb.a","WQVoiceToolComponents/amrwapper/libopencore-amrwb.a"
     end

     s.subspec 'lame' do |sna|
     sna.source_files = 'WQVoiceToolComponents/lame/lame.h'
     sna.vendored_libraries = "WQVoiceToolComponents/lame/libmp3lame.a"
     end

    s.subspec 'VoiceTool' do |ss|
      ss.dependency 'WQVoiceToolComponents/WavAmrHelp'
      ss.dependency 'WQVoiceToolComponents/lame'
      ss.source_files = 'WQVoiceToolComponents/WQVoiceManager/*.{h,m}'
    end

end
