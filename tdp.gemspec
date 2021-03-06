Gem::Specification.new do |s|
  s.name        = 'tdp'
  s.version     = '1.1.0'
  s.date        = '2016-03-05'
  s.summary     = 'Tiny Database Patcher'
  s.description = 'Tool for pure-SQL database migrations'
  s.authors     = ['Ivan Appel']
  s.email       = 'ivan.appel@gmail.com'
  s.files       = ['lib/tdp.rb']
  s.executables << 'tdp'
  s.homepage    = 'http://github.com/geekyfox/tdp'
  s.license     = 'MIT'

  s.add_runtime_dependency 'sequel', '~> 4.40'
  s.add_development_dependency 'simplecov', '~> 0.12'
  s.add_development_dependency 'sqlite3', '~> 1.3'
  s.add_development_dependency 'test-unit', '~> 3.2'
end
