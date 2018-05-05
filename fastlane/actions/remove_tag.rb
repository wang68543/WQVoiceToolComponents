module Fastlane
  module Actions
    module SharedValues
      REMOVE_TAG_CUSTOM_VALUE = :REMOVE_TAG_CUSTOM_VALUE
    end
    # 自定义Actions参考
    # https://github.com/fastlane/fastlane/tree/master/fastlane/lib/fastlane/actions
    class RemoveTagAction < Action
      def self.run(params)
      tagName = params[:tag]
      isRemoveLocalTag = params[:rL]
      isRemoveRemoteTag = params[:rR]
      
#        git tag -d tagName
#        git push origin :tagName
        # 先定义一个数组 用来存储所有的命令
        cmds = []
        # 往数组里面添加所有的命令
        if isRemoveLocalTag
        cmds << "git tag -d #{tagName} "
        end
    
        if isRemoveRemoteTag
        cmds << "git push origin :#{tagName} "
      end
        #执行数组里面的所有命令 ()
        result = Actions.sh(cmds.join('&'))
        return result
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "使用这个Action进行删除tag"
      end

      def self.details
        # Optional:
        # this is your chance to provide a more detailed description of this action
        "You can use this action to do cool things..."
      end

      def self.available_options
        # Define all options your action supports. 
        
        # Below a few examples
        [
        FastlaneCore::ConfigItem.new(key: :tag,
                             description: "需要被删除的标签名称",
                             is_string: true ),
        FastlaneCore::ConfigItem.new(key: :rL,
                             description: "是否删除本地标签",
                                optional:false,
                             is_string: false,
                             default_value: true),
        FastlaneCore::ConfigItem.new(key: :rR,
                             description: "是否删除远程标签",
                             optional:false,
                             is_string: false,
                             default_value: true)
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        [
          ['REMOVE_TAG_CUSTOM_VALUE', 'A description of what this value contains']
        ]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.authors
        # So no one will ever forget your contribution to fastlane :) You are awesome btw!
        ["Wang68543"]
      end

      def self.is_supported?(platform)
        # you can do things like
        # 
        #  true
        # 
        #  platform == :ios
        # 
        #  [:ios, :mac].include?(platform)
        # 

        platform == :ios
      end
    end
  end
end
