Gem::Specification.new do |s|
  s.name        = 'tdp'
  s.version     = '1.0.0'
  s.date        = '2016-11-26'
  s.summary     = 'Tiny Database Patcher'
  s.description = 'Tool for pure-SQL database migrations'
  s.authors     = ['Ivan Appel']
  s.email       = 'ivan.appel@gmail.com'
  s.files       = ['lib/tdp.rb']
  s.executables << 'tdp'
  s.homepage    = 'http://github.com/geekyfox/tdp'
  s.license     = 'MIT'

  s.add_runtime_dependency 'sequel'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'test-unit'
end
