require 'bundler/setup'
require 'tomato_shrieker/refines'

module TomatoShrieker
  using Refines

  def self.dir
    return File.expand_path('../..', __dir__)
  end

  def self.setup_bootsnap
    Bootsnap.setup(
      cache_dir: File.join(dir, 'tmp/cache'),
      development_mode: Environment.development?,
      load_path_cache: true,
      compile_cache_iseq: true,
      compile_cache_yaml: true,
    )
  end

  def self.loader
    config = YAML.load_file(File.join(dir, 'config/autoload.yaml'))
    loader = Zeitwerk::Loader.new
    loader.inflector.inflect(config['inflections'])
    loader.push_dir(File.join(dir, 'app/lib'))
    loader.collapse('app/lib/tomato_shrieker/*')
    return loader
  end

  def self.setup_debug
    Ricecream.disable
    return unless Environment.development?
    Ricecream.enable
    Ricecream.include_context = true
    Ricecream.colorize = true
    Ricecream.prefix = "#{Package.name} | "
    Ricecream.define_singleton_method(:arg_to_s, proc {|v| PP.pp(v)})
  end

  def self.load_tasks
    Dir.glob(File.join(dir, 'app/task/*.rb')).each do |f|
      require f
    end
  end

  Bundler.require
  loader.setup
  setup_bootsnap
  setup_debug
  Sequel.connect(Environment.dsn)
end
