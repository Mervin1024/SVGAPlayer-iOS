
Pod::Spec.new do |s|
  s.name         = "SVGAPlayer-Local"
  s.version      = "2.5.7"
  s.summary      = "SVGAPlayer 是一个高性能的动画播放器。取消支持 URL 下载，只保留本地加载"
  s.description  = <<-DESC
                   SVGA 是一种全新的动画格式，由 YY UED 团队主导开发；
                   SVGA 让动画开发分工明确，大大减少动画交互的沟通成本，提升开发效率；
                   SVGA 可以在 iOS / Android / Web / Flutter 实现高性能的动画播放。
                   DESC

  s.homepage     = "http://code.yy.com/ued/SVGAPlayer"
  s.license      = "Apache 2.0"
  s.author       = { "PonyCui" => "cuiminghui1@yy.com" }
  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/svga/SVGAPlayer-iOS.git", :tag => s.version }
  s.subspec 'Core' do |ss|
    ss.source_files  = "Source/*.{h,m}"
    ss.requires_arc = true
    ss.library = "z"
    ss.framework = "AVFoundation"
    ss.dependency 'SVGAPlayer-Local/ProtoFiles'
  end
  s.subspec 'ProtoFiles' do |ss|
    ss.source_files  = "Source/pbobjc/*.{h,m}"
    ss.requires_arc = false
    ss.dependency 'Protobuf', '~> 3.4'
    ss.pod_target_xcconfig = {
      'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS=1',
    }
  end
end
