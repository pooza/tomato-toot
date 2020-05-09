namespace :tomato do
  desc 'crawl'
  task :crawl do
    sh File.join(TomatoToot::Environment.dir, 'bin/crawl.rb').to_s
  end

  desc 'update timestamps'
  task :touch do
    sh "#{File.join(TomatoToot::Environment.dir, 'bin/crawl.rb')} --silence"
  end

  desc 'clear entries'
  task :clean do
    Sequel.connect(TomatoToot::Environment.dsn)
    TomatoToot::Entry.dataset.destroy
  end
end

[:crawl, :clean, :touch].each do |action|
  desc "alias of tomato:#{action}"
  task action => "tomato:#{action}"
end
