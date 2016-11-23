require 'rdoc/task'
require 'rake/testtask'

task default: %w(test)

Rake::TestTask.new(:test) do |t|
  t.test_files = ['test/test_suite.rb']
end

task :clean do
  Dir['*.gem'].each { |x| rm x }
end

task build: [:test, :clean] do
  sh 'gem', 'build', 'tdp.gemspec'
end

task install: :build do
  Dir['*.gem'].each { |x| sh 'gem', 'install', x }
end

RDoc::Task.new(:doc) do |doc|
  doc.main = 'README.rdoc'
  doc.title = 'TDP Documentation'
  doc.rdoc_dir = 'doc'
  doc.rdoc_files = FileList.new %w(lib/**/*.rb *.rdoc)
end
