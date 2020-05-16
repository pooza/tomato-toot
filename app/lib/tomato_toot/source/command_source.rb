module TomatoToot
  class CommandSource < Source
    def exec(options = {})
      return if options['silence']
      Dir.chdir(dir) if dir
      command.exec
      raise command.stderr || command.stdout unless command.status.zero?
      mastodon&.toot(status: status, visibility: visibility)
      hooks {|hook| hook.say({text: status}, :hash)}
      logger.info(source: hash, message: 'post')
    end

    def status
      template = Template.new('toot.common')
      template[:status] = command.stdout
      template[:source] = self
      return template.to_s
    end

    def dir
      return self['/source/dir']
    end

    def command
      args = self['/source/command']
      args = [args] unless args.is_a?(Array)
      @command ||= Ginseng::CommandLine.new(args)
      return @command
    end
  end
end
